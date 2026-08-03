# 11 — Ingress e deploy: Traefik, TLS e Docker Compose em VMs

Research do ticket [`docs/mapa/issues/11-stack-ingress-deploy.md`](../issues/11-stack-ingress-deploy.md).
Data do levantamento: 2026-08-02. Ambiente alvo: VMs Linux **aarch64 (ARM64)**, produção em Docker Compose (Kubernetes está fora de escopo por decisão do `docs/descricao-inicial.md`).

Método: fontes primárias apenas — documentação oficial do Traefik, do Docker, do Keycloak (inclusive o código-fonte e os guias `.adoc` do repositório), do Spring Boot e do Airflow; e a API de registro (Docker Hub / Quay) para as manifests multi-arquitetura. Consultas de biblioteca feitas via MCP context7; leitura de fonte bruta via WebFetch/curl onde o context7 não cobria (ex.: os `.adoc` do Keycloak e as manifests de imagem).

---

## 1. Traefik: versão e onde mora cada pedaço da configuração

### 1.1 Versão

- A release estável mais recente é **v3.7.10**, publicada em 2026-07-31 (`GET https://api.github.com/repos/traefik/traefik/releases/latest`).
- A documentação oficial de setup com Docker já usa a tag `traefik:v3.7` no exemplo canônico de Compose — [Setup / Docker](https://doc.traefik.io/traefik/setup/docker).
- Recomendação de pin: **`traefik:v3.7`** (minor fixo, patch flutuante). Evitar `latest`; evitar `v3` puro porque atravessa minor.

### 1.2 Estática × dinâmica — a separação que o Traefik impõe

O Traefik divide a configuração em duas camadas, e isso não é opcional:

- **Estática**: entryPoints, providers, API/dashboard, log, métricas, certificate resolvers. Lida **uma vez no boot**. Vai em flags `command:` do serviço, em variáveis `TRAEFIK_*` ou num `traefik.yml`.
- **Dinâmica**: routers, services, middlewares, `tls.certificates`, `tls.stores`. **Recarregada a quente**.

O guia do próprio Keycloak descreve a divisão nesses termos: *"A **static configuration** file (`traefik.yaml`) that defines entrypoints and providers, loaded once at startup"* e *"A **dynamic configuration** file (`keycloak.yaml`) that defines routing, TLS, and backend transport settings, hot-reloaded by Traefik at runtime"* — [keycloak/docs/guides/server/traefik-reencrypt.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/traefik-reencrypt.adoc).

### 1.3 Labels do Compose × arquivo dinâmico

Ambos são providers de configuração **dinâmica**, e o Traefik permite os dois ligados ao mesmo tempo.

**Provider Docker (labels):**

```yaml
command:
  - "--providers.docker=true"
  - "--providers.docker.exposedbydefault=false"
  - "--providers.docker.network=proxy"
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

Fonte: [Setup / Docker](https://doc.traefik.io/traefik/setup/docker). O `exposedByDefault=false` é o que faz cada serviço precisar de `traefik.enable=true` explícito para ser publicado — sem isso, todo container do Compose vira rota.

Labels típicas por serviço (roteamento + porta do backend):

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.my-router.rule=Host(`example.com`)"
  - "traefik.http.services.my-service.loadbalancer.server.port=80"
```

Fonte: [Dynamic configuration methods](https://doc.traefik.io/traefik/reference/routing-configuration/dynamic-configuration-methods). O label `loadbalancer.server.port` é necessário sempre que o container expõe mais de uma porta — por padrão *"Traefik automatically detects and uses the lowest exposed port of a container"* ([Swarm provider reference](https://doc.traefik.io/traefik/reference/routing-configuration/other-providers/swarm)), o que é exatamente o caso do Keycloak (8443 + 9000) e da API Spring (8080 + porta de management, se separada).

**Provider de arquivo:**

```yaml
providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true
```

Fonte: [File provider](https://doc.traefik.io/traefik/reference/routing-configuration/other-providers/file). O mesmo doc mostra que `tls.certificates` (certFile/keyFile) só existe no provider de arquivo — **não há label de Docker para instalar um certificado próprio**.

**Interoperação:** um router declarado por label pode referenciar um middleware declarado em arquivo usando o sufixo `@file`:

```yaml
labels:
  - "traefik.http.routers.my-container.middlewares=add-foo-prefix@file"
```

Fonte: [Providers overview](https://doc.traefik.io/traefik/providers/overview).

**O que fica melhor em cada lugar (com critério de decisão):**

| Configuração | Onde | Por quê |
|---|---|---|
| Router/serviço trivial de um app do Compose (host, entrypoint, porta) | Label | Fica junto do serviço; nasce e morre com ele |
| `tls.certificates`, `tls.stores.default.defaultCertificate` | Arquivo | Não existe equivalente em label |
| `tls.options` (clientAuth, minVersion, cipher suites) | Arquivo | Idem |
| Middlewares reutilizados por vários serviços (ipAllowList, headers, rate limit) | Arquivo | Um lugar só, referenciado por `@file` |
| Roteamento com prioridade explícita e regras compostas (o caso do Keycloak, seção 3) | Arquivo | Legível, revisável e diffável como uma unidade; label de `priority` fica ilegível |
| `serversTransport` (mTLS para o backend) | Arquivo | Idem |

**Recomendação:** híbrido — labels para o caso simples, arquivo dinâmico (`./traefik/dynamic/*.yml`, montado read-only) para TLS, middlewares compartilhados e para o bloco de roteamento do Keycloak.

### 1.4 O socket do Docker é o ponto fraco desse arranjo

A doc do provider Docker é explícita: *"Exposing the Docker socket directly presents security risks, as a compromised Traefik instance could grant an attacker access to the host. Recommended security practices include using TCP or SSH with authentication, employing a Docker socket proxy, or using authorization plugins to restrict API access."* — [Docker provider / Security note](https://doc.traefik.io/traefik/providers/docker).

E o `:ro` **não protege**: a doc do Docker registra que `readonly` num bind mount atua no nível do sistema de arquivos, não no nível da API — a comunicação com o daemon usa `connect/sendmsg/recvmsg`, não escrita de arquivo ([Bind mounts](https://github.com/docker/docs/blob/main/content/manuals/engine/storage/bind-mounts.md)). Quem alcança o socket é root no host: *"Docker allows you to share a directory between the Docker host and a guest container ... you can start a container where the `/host` directory is the `/` directory on your host"* — [Engine security](https://github.com/docker/docs/blob/main/content/manuals/engine/security/_index.md).

Consequência prática para este projeto: **duas coisas na mesma VM querem o socket** — o Traefik e o Airflow (seção 6). Ver a recomendação de socket proxy na seção 8.

Endurecimentos que a própria doc do Traefik traz no exemplo de Compose: `security_opt: [no-new-privileges:true]`, `--api.insecure=false`, dashboard atrás de `basicauth` e de router com TLS ([Setup / Docker](https://doc.traefik.io/traefik/setup/docker)).

---

## 2. TLS: ACME/Let's Encrypt × certificado próprio

### 2.1 ACME — como se configura

```yaml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  myresolver:
    acme:
      email: your-email@example.com
      storage: acme.json
      httpChallenge:
        entryPoint: web
```

Fonte: [HTTPS / ACME](https://doc.traefik.io/traefik/https/acme).

### 2.2 Os pré-requisitos que decidem se ACME serve ou não

Da referência de certificate resolvers ([ACME reference](https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/)):

- **HTTP-01**: o entryPoint do desafio *"must be reachable by Let's Encrypt through port 80"*.
- **TLS-ALPN-01**: *"Traefik must be reachable by Let's Encrypt through port 443"*.
- **DNS-01**: não exige porta aberta; provisiona um registro DNS. É o único que emite **wildcard**.
- *"Every domain must have A/AAAA records pointing to Traefik"* — ou seja, **DNS público resolvível**.
- `caServer` default `https://acme-v02.api.letsencrypt.org/directory`; `keyType` default `RSA4096`.

Wildcard tem armadilha própria: *"Requesting a wildcard certificate alongside its root domain requires two separate DNS-01 challenges, which may result in identical DNS TXT records. This can cause challenges to fail if the DNS provider's TTL exceeds the challenge timeout"* — [ACME / Domain definition](https://doc.traefik.io/traefik/https/acme).

Rate limit: *"Let's Encrypt enforces rate limits that cannot be overridden and persist for one week. To avoid hitting these limits, especially during container restarts, ensure certificate storage is persisted. When experimenting, use the staging server via the caServer configuration option"* — [Certificate resolvers / concepts](https://doc.traefik.io/traefik-hub/api-gateway/intro/concepts). O `acme.json` precisa portanto de volume persistente: `- "./letsencrypt:/letsencrypt"` ([Expose / Docker / advanced](https://doc.traefik.io/traefik/expose/docker/advanced)).

### 2.3 Certificado próprio (arquivo)

```yaml
tls:
  certificates:
    - certFile: /certs/example.crt
      keyFile: /certs/example.key
  stores:
    default:
      defaultCertificate:
        certFile: path/to/cert.crt
        keyFile: path/to/cert.key
```

Fonte: [TLS certificates](https://doc.traefik.io/traefik/reference/routing-configuration/http/tls/tls-certificates/). Dois detalhes da mesma página:

- Certificados podem ser adicionados/removidos **com o Traefik já rodando** (é config dinâmica).
- Existe **um único store global**: *"the `stores` list will actually be ignored and automatically set to `[\"default\"]`"*. O `defaultCertificate` é o que atende cliente sem SNI ou com SNI que não casa; sem ele *"Traefik will use the generated one"* (autoassinado interno).

E o serviço do Traefik monta o diretório read-only: `- "./certs:/certs:ro"` ([Expose / Docker / basic](https://doc.traefik.io/traefik/expose/docker/basic)).

### 2.4 Critério de decisão

| Critério | ACME/Let's Encrypt | Certificado próprio (arquivo) |
|---|---|---|
| Hostnames em DNS público, porta 80/443 alcançável pela internet | **Sim** — HTTP-01 resolve sozinho | Funciona, mas é trabalho manual |
| Stack só em rede interna / VPN / sem DNS público | Só com **DNS-01** e provider suportado | **Sim** — CA interna ou autoassinado |
| Wildcard (`*.relatorios.example`) | Exige DNS-01 + credencial do provedor DNS no Traefik | **Sim**, trivialmente |
| Renovação | Automática | Manual/externa (cron + reload por `watch`) |
| Risco de rate limit em rebuild/redeploy frequente | Real; mitigado por volume persistente e `caServer` de staging | Nenhum |
| Confiança do browser sem configuração no cliente | Sim | Só se a CA interna estiver instalada nas máquinas |

**Recomendação para este projeto:** decidir por **qual é o cenário de rede da VM de produção**, que ainda não está fixado no `descricao-inicial.md`.

- Se as VMs publicarem hostnames em DNS público (ex.: `relatorios.example.com`, `auth.relatorios.example.com`) → **ACME com HTTP-01**, `acme.json` em volume nomeado, `caServer` de staging no ambiente de homologação. É o caminho de menor manutenção.
- Se a stack for interna (o mais provável, dado que Graylog, Grafana, Jaeger, Mailpit e o console do MinIO não devem ir para a internet) → **certificado próprio de uma CA interna** via provider de arquivo, com `defaultCertificate` configurado. ACME por DNS-01 só se já existir provedor DNS automatizável.
- Em qualquer um dos dois: **nunca deixar o `defaultCertificate` ausente** em produção, senão um SNI não casado recebe o autoassinado gerado pelo Traefik e o erro fica difícil de diagnosticar.

---

## 3. Exposição seletiva do Keycloak — a pergunta central do ticket

O `descricao-inicial.md` diz: *"O Account Console e a página de registro do Keycloak (com tema customizado) serão expostos seletivamente pelo Traefik para troca de senha e cadastro"*. A análise comportamental (seção 3) contesta: *"Roteamento por path no Traefik é granularidade grossa; a forma correta de restringir a troca de senha é desabilitar as demais features no realm, não filtrar rotas."*

Levantei as duas opções contra a documentação do Keycloak. **As duas estão certas em parte, e o resultado é que elas não são alternativas — são camadas.**

### 3.1 O que o Keycloak diz sobre filtrar path no proxy

O Keycloak **documenta e recomenda** filtragem de path no reverse proxy. Tabela normativa "Exposed path recommendations" de [reverseproxy.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/reverseproxy.adoc):

| Path do Keycloak | Exposto | Motivo (citação) |
|---|---|---|
| `/` | **Não** | *"When exposing all paths, admin paths are exposed unnecessarily."* |
| `/admin/` | **Só internamente** | *"Exposed admin paths lead to an unnecessary attack vector."* |
| `/realms/` | **Sim** | *"This path is needed to work correctly, for example, for OIDC endpoints."* |
| `/realms/master/` | **Só internamente** | Isolar a autenticação do realm administrativo |
| `/resources/` | **Sim** | *"This path is needed to serve assets correctly."* |
| `/.well-known/` | **Sim** | RFC 8414 |
| `/metrics` | **Não** | *"Exposed metrics lead to an unnecessary attack vector."* |
| `/health` | **Não** | *"Exposed health checks lead to an unnecessary attack vector."* |
| `/lb-check` | Sim | Health check para load balancer externo (só com feature `stateless`/`multi-site`) |

E existe um **blueprint oficial Keycloak + Traefik** ([traefik-reencrypt.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/traefik-reencrypt.adoc), com Compose pronto no [keycloak-quickstarts](https://github.com/keycloak/keycloak-quickstarts/tree/main/proxy/traefik/reencrypt)) que implementa exatamente esse recorte com dois routers:

```yaml
routers:
  keycloak-public:
    entryPoints: [keycloak]
    rule: "PathPrefix(`/realms/`) || PathPrefix(`/resources/`) || PathPrefix(`/.well-known/`)"
    middlewares: [filter-headers, pass-client-cert]
    tls: {}
    service: keycloak

  keycloak-internal:
    entryPoints: [keycloak]
    rule: "PathPrefix(`/`)"
    priority: 1
    middlewares: [filter-headers, pass-client-cert, ip-allowlist]
    tls: {}
    service: keycloak
```

Detalhes que o guia explica e que valem copiar:

- O `priority: 1` é *"set deliberately low so that Traefik always evaluates the more specific public router first"*. Confirma o modelo de prioridade do Traefik: *"The smaller the number, the lower the priority"* ([routers](https://doc.traefik.io/traefik-hub/api-gateway/expose/routers)).
- O router interno não é "bloqueado" — ele existe, mas leva o middleware `ipAllowList` com as faixas internas.
- O guia avisa do efeito colateral: *"With these settings, the redirect to the welcome screen or Admin UI will not work from external IP addresses, and this is expected."*
- Há um middleware `filter-headers` que **zera** headers de proxy e de tracing que o cliente possa injetar (`X-Forwarded-*`, `X-Real-IP`, `X-Forwarded-Access-Token`, `traceparent`, `b3`, `uber-trace-id`, …), com a observação de que *"Unlike HAProxy, Traefik does not support regex-based header matching, so each header variant must be listed explicitly."* Isso importa aqui porque o projeto propaga `traceparent` (ticket 26) — **o traceparent externo deve ser descartado na borda**, não aceito.
- Health check do serviço aponta para `/health/ready` na porta **9000**, que **não é proxied**: *"You should not proxy port 9000 because health checks and metrics use that port directly, and you do not want to expose this information to external callers"* ([reverseproxy.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/reverseproxy.adoc)).

Modo TLS: o guia trata **re-encrypt** como o padrão de produção — *"Re-encrypt is the most common choice for production deployments. It allows the proxy to set forwarded headers, filter URL paths, and apply HTTP-level policies"*. Na tabela de comparação do mesmo doc, "Proxy can filter URL paths" é **Yes** em re-encrypt e **No** em passthrough. Configuração do lado Keycloak: `--proxy-headers xforwarded`, e o aviso de que *"if you are using a reverse proxy ... and do not set the proxy-headers option, then by default you will see 403 Forbidden responses to requests via the proxy that perform origin checking"*.

### 3.2 Onde a filtragem por path **quebra** para o que o documento pediu

O documento quer expor **só** o Account Console e a página de registro. Isso não é implementável por path, e a razão é estrutural:

- O Account Console vive em **`{server-root}/realms/{realm-name}/account`** — *"In a web browser, enter a URL in this format: server-root/realms/{realm-name}/account"* ([account.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/account.adoc)).
- A página de registro é alcançada pelo link *Register* na página de login, dentro do mesmo `/realms/{realm}/...` ([con-user-registration.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/users/con-user-registration.adoc)).
- E `/realms/` é justamente o prefixo que a tabela normativa marca como **"Sim, exposto"** porque *"is needed to work correctly, for example, for OIDC endpoints"*.

Ou seja: **Account Console, registro, `/authz`, `/token`, `/userinfo`, `/logout` e todo o resto do protocolo compartilham o mesmo prefixo obrigatório**. Expor "só o Account Console" por path significaria enumerar sub-paths dentro de `/realms/{realm}/` — e aí valem as duas objeções do ticket 17: são muitas rotas (o console v3 é uma SPA que puxa `/resources/` e a Account REST API) e elas **mudam entre versões do Keycloak**, sem contrato de compatibilidade. O que o proxy consegue separar com segurança é `/admin/`, `/realms/master/`, `/metrics`, `/health` — que é exatamente o recorte da tabela oficial, e não o recorte que o documento pediu.

**A análise comportamental está correta neste ponto.**

### 3.3 O que se desliga no realm / no servidor

Controles reais, por camada:

**a) Registro público — chave de realm.**
*"Click Realm Settings → Login tab → Toggle User Registration to ON"* ([proc-enabling-user-registration.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/users/proc-enabling-user-registration.adoc)). É `registrationAllowed` no `RealmRepresentation`. Este é o liga/desliga do cadastro público, e é por realm — não por rota.

Relevante para o ticket 16 (registro público é vetor de abuso): o Keycloak traz **reCAPTCHA v2/v3 e reCAPTCHA Enterprise** como execução do flow *Registration* ([proc-enabling-recaptcha.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/users/proc-enabling-recaptcha.adoc)), e documenta a interação com *Verify email*: *"When self-registrations is enabled together with Verify email realm switch, then password will not be set by default on the registration form"* ([con-user-registration.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/users/con-user-registration.adoc)).

**b) Account Console — clients do realm.**
Os clients padrão do realm incluem `account` e `account-console`:

```java
public static final String ACCOUNT_MANAGEMENT_CLIENT_ID = "account";
public static final String ACCOUNT_CONSOLE_CLIENT_ID    = "account-console";
public static final String ADMIN_CONSOLE_CLIENT_ID      = "security-admin-console";
```
([Constants.java](https://github.com/keycloak/keycloak/blob/main/server-spi-private/src/main/java/org/keycloak/models/Constants.java))

Desabilitar o client `account-console` desliga o console para aquele realm. E o **conteúdo** do console é governado pelas roles do client `account`, cujo default é enxuto:

```java
String VIEW_PROFILE = "view-profile";
String MANAGE_ACCOUNT = "manage-account";
String DELETE_ACCOUNT = "delete-account";
String VIEW_GROUPS = "view-groups";
String VIEW_APPLICATIONS = "view-applications";
...
String[] DEFAULT = {VIEW_PROFILE, MANAGE_ACCOUNT};
```
([AccountRoles.java](https://github.com/keycloak/keycloak/blob/main/server-spi-private/src/main/java/org/keycloak/models/AccountRoles.java))

Isto é o mecanismo fino que o ticket procura: as abas do console aparecem em função de role. A doc confirma para *Groups*: *"You need to have the view-groups account role for being able to view Groups menu"* ([account.adoc](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/account.adoc)). Removendo `delete-account`, `view-groups`, `view-applications`, `manage-consent` etc. do composite `default-roles-<realm>`, o console fica reduzido a perfil + credenciais — que é o que o documento quer ("troca de senha").

**c) Features do servidor — build-time e global.**
`--features-disabled="<name>[,<name>]"` / `--feature-<name>=disabled`, aplicadas **no build** da imagem ([features.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/features.adoc)). Do enum de features ([Profile.java](https://github.com/keycloak/keycloak/blob/main/common/src/main/java/org/keycloak/common/Profile.java)):

- `ACCOUNT_API` — "Account Management REST API", `Type.DEFAULT`
- `ACCOUNT_V3` — "Account Console version 3", `Type.DEFAULT`, **depende de `ACCOUNT_API`**
- `ADMIN_API` — "Admin API", `Type.DEFAULT`
- `ADMIN_V2` — "New Admin Console", `Type.DEFAULT`, depende de `ADMIN_API`
- `IMPERSONATION` — `Type.DEFAULT`

Duas consequências: (i) desligar `account-api` derruba junto o Account Console (dependência declarada); (ii) essas flags são **do servidor inteiro**, não do realm — inúteis se houvesse mais de um realm com políticas diferentes (não é o caso deste projeto, que tem um realm). E **não dá para desligar `admin-api`** sem quebrar a mediação do GERENTE, que precisa da Admin API (ticket 14).

**d) Hostname separado para o Admin Console.**
`--hostname https://my.keycloak.org --hostname-admin https://admin.my.keycloak.org:8443` ([hostname.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/hostname.adoc)). Permite que o Traefik publique só o host público e nem tenha router para o host administrativo.

### 3.4 As duas opções, lado a lado

| | **A — Filtrar rotas no Traefik** | **B — Desligar features no realm/servidor** |
|---|---|---|
| O que consegue | Bloquear `/admin/`, `/realms/master/`, `/metrics`, `/health`; restringir por IP | Desligar registro público; desligar/reduzir o Account Console; desligar Admin Console |
| O que **não** consegue | Separar Account Console e registro do resto de `/realms/` — mesmo prefixo obrigatório | Bloquear a Admin **API** sem quebrar a mediação do GERENTE |
| Fragilidade | Paths internos mudam entre versões; enumerar sub-paths de `/realms/{realm}/` é contrato não suportado | `--features-disabled` é build-time e global ao servidor |
| Suporte oficial | **Sim**, com tabela normativa e blueprint Traefik | **Sim**, opções documentadas de realm e de servidor |
| Custo de manutenção | Baixo no recorte oficial; alto se sair dele | Baixo (config de realm exportada com o realm) |

**Recomendação:** **as duas, com divisão de responsabilidade clara.**

1. **Traefik faz o recorte grosso e só o oficial**: router público com `PathPrefix('/realms/') || PathPrefix('/resources/') || PathPrefix('/.well-known/')`; router `PathPrefix('/')` com `priority: 1` + `ipAllowList` para `/admin/` e o resto; **nunca** publicar a porta 9000; middleware de header filtering (inclusive `traceparent`) em ambos. Adicionalmente, um router de negação para `/realms/master/` externo.
2. **O realm faz o recorte fino**: `registrationAllowed=true` no realm da aplicação (com verificação de e-mail e reCAPTCHA se o ticket 16 decidir assim), `master` sem registro; composite `default-roles-<realm>` reduzido a `view-profile` + `manage-account` (retirar `delete-account`, `view-groups`, `view-applications`); tema customizado aplicado ao login/registro.
3. **Não** tentar expor "só" o Account Console por path. Registrar isso como correção explícita à frase do `descricao-inicial.md` — é o insumo direto do ticket 17.

---

## 4. Limites de tamanho de header (JWT inflado — ticket 15)

**Traefik**: default de **1 MiB**, configurável por entryPoint.

```yaml
entryPoints:
  websecure:
    address: ':443'
    http:
      maxHeaderBytes: 65536
```

*"The maxHeaderBytes option limits the size of request headers Traefik reads. By reducing this value from the default of 1 MiB to the minimum required for legitimate traffic, you can reject oversized header blocks before they cause significant memory amplification."* — [HTTP/2 header memory](https://doc.traefik.io/traefik/security/http2-header-memory).

**Spring Boot (Tomcat embutido)**: default de **8 KB**.
*"The maximum HTTP request header size is set to 8KB by default. Note that the application of this limit varies by the underlying embedded server; for instance, Tomcat applies it to the combined size of the request line and all headers, while Netty applies it to each individual header."* — [Application properties / Server](https://docs.spring.io/spring-boot/3.5/appendix/application-properties/index.html). Propriedade: `server.max-http-request-header-size`. Há também `server.tomcat.max-http-response-header-size` para a resposta ([ServerProperties.Tomcat](https://docs.spring.io/spring-boot/3.5/api/java/org/springframework/boot/autoconfigure/web/ServerProperties.Tomcat.html)).

**Conclusão que interessa ao ticket 15:** o gargalo **não é o Traefik** (1 MiB), é o **Tomcat (8 KB, contando request line + todos os headers juntos)**. E o Keycloak também é Quarkus/Vert.x com limite próprio no caminho de volta.

Ordem de grandeza para dimensionar o teto de roles: um `Authorization: Bearer <JWT>` ocupa ~4/3 do JWS compacto por causa do base64url. Com 8 KB para *todo* o bloco de headers (cookies, `User-Agent`, `traceparent`, `X-Forwarded-*` re-escritos pelo Traefik incluídos), o orçamento realista para o Bearer fica em torno de 5–6 KB, ou seja ~4 KB de JWT decodificado. Cada role de relatório no claim `realm_access.roles` custa o comprimento do nome + 3 bytes de JSON; com nomes tipo `REL_POUPANCA_0001` (17 chars) dá ~20 bytes por role no payload e ~27 bytes no header depois do base64. Algumas centenas de roles cabem; alguns milhares não. **Recomendação:** não deixar isso implícito — subir explicitamente `server.max-http-request-header-size` (ex.: 16KB) na API REST, fixar `maxHeaderBytes` no entryPoint do Traefik num valor deliberado (ex.: 65536, bem abaixo do 1 MiB default, para não virar amplificador de memória), e o ticket 15 decidir o teto de roles por usuário com base nesse orçamento — ou tirar a lista de roles do token.

---

## 5. Docker Compose em produção

### 5.1 Organização dos arquivos: base + override por ambiente

Três mecanismos, todos oficiais:

**`-f` múltiplo (merge por ordem):** *"Files are merged in the order provided, with later files overriding earlier ones"* — `docker compose -f compose.yaml -f compose.admin.yaml run backup_db` ([multiple-compose-files/merge.md](https://github.com/docker/docs/blob/main/content/manuals/compose/how-tos/multiple-compose-files/merge.md)).

**`COMPOSE_FILE`:** `COMPOSE_FILE=compose.yaml:compose.prod.yaml` ([envvars.md](https://github.com/docker/docs/blob/main/content/manuals/compose/how-tos/environment-variables/envvars.md)) — evita repetir `-f` em todo comando e é o que se põe no `.env` da VM.

**`include`** (composição de projetos) e **`extends`** (herança de serviço):
```yaml
include:
  - path:
      - ../commons/compose.yaml
      - ./commons-override.yaml
```
```yaml
services:
  webapp:
    extends:
      file: ../commons/compose.yaml
      service: base
```
([include.md](https://github.com/docker/docs/blob/main/content/reference/compose-file/include.md), [extends.md](https://github.com/docker/docs/blob/main/content/manuals/compose/how-tos/multiple-compose-files/extends.md)).

**Armadilha documentada:** *"As any values in a Compose file can be interpolated with variable substitution ... interpolation is applied before a merge on a per-file basis"* ([interpolation.md](https://github.com/docker/docs/blob/main/content/reference/compose-file/interpolation.md)). Ou seja, `${VAR:?erro}` num serviço que seria removido depois pela filtragem de profile **ainda assim quebra o parse**. Consequência: variáveis obrigatórias precisam estar definidas no ambiente onde o arquivo é lido, mesmo que o serviço não vá subir ali.

**Recomendação de layout:**

```
compose.yaml              # base: todos os serviços, sem porta publicada, sem segredo
compose.override.yaml     # dev local (carregado automaticamente): portas, Mailpit UI, etc.
compose.prod.yaml         # produção: restart, healthcheck estrito, secrets, labels do Traefik
compose.obs.yaml          # Graylog/Prometheus/Grafana/Jaeger/OTel (opcional por VM)
.env                      # COMPOSE_FILE, COMPOSE_PROJECT_NAME, tags de imagem
```

Nota: `compose.override.yaml` é carregado **automaticamente** junto do base — por isso é o arquivo de *dev*, e produção usa `COMPOSE_FILE=compose.yaml:compose.prod.yaml` explicitamente, sem o override.

### 5.2 Segredos

```yaml
services:
  db:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
secrets:
  db_password:
    file: ./db_password.txt
```

*"Secrets are mounted as a file in `/run/secrets/<secret_name>` inside the container"* ([use-secrets.md](https://github.com/docker/docs/blob/main/content/manuals/compose/how-tos/use-secrets.md)). Duas origens: `file:` e `environment:`. A justificativa oficial contra variável de ambiente: elas *"são frequentemente disponíveis a todos os processos"* e podem *"vazar em logs durante depuração sem o seu conhecimento"*; segredos oferecem *"granular access control within a service container via standard filesystem permissions"*.

**Ressalva importante e não amenizável:** em Compose (fora do Swarm) o segredo é um **bind mount de um arquivo do host** — não há o cofre criptografado que o Swarm tem (*"Docker mounts these secrets as files ... These files are managed in memory and are never persisted on disk"* vale para [Swarm](https://github.com/docker/docs/blob/main/content/manuals/engine/swarm/secrets.md)). Portanto, em Compose, a proteção real é permissão de arquivo no host (`0600`, dono root) + o arquivo fora do repositório Git. Isso precisa entrar como **risco aceito** documentado.

Aplicação a este projeto: senha do PostgreSQL, senha inicial do ADMINISTRADOR do Keycloak (`KC_BOOTSTRAP_ADMIN_PASSWORD`), root user/password do MinIO e o client secret do service account que a API usa contra a Admin API — todos via `*_FILE` quando a imagem suportar; onde não suportar, entrypoint que lê `/run/secrets/...` e exporta.

### 5.3 Restart

`no` | `always` | `on-failure[:max-retries]` | `unless-stopped` ([services.md](https://github.com/docker/docs/blob/main/content/reference/compose-file/services.md)): *"`unless-stopped` restarts irrespective of exit code, but stops when the service is stopped or removed"*.

**Recomendação:** `unless-stopped` para os serviços de longa duração (Traefik, Keycloak, PostgreSQL, MinIO, API, Airflow, observabilidade). **Nunca** `always`/`unless-stopped` para os containers Spring Batch disparados pelo Airflow — eles são jobs; devem sair com exit code e ser removidos (`auto_remove`, seção 6). Se um job carregar `restart: unless-stopped` por herança de um bloco comum, um job que falha vira loop infinito e a tabela de metadados nunca chega a "processado com erro".

### 5.4 Healthchecks e ordem de subida

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy
        restart: true
      keycloak:
        condition: service_healthy
  db:
    image: postgres:18
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      retries: 5
      start_period: 30s
      timeout: 10s
```
([startup-order.md](https://github.com/docker/docs/blob/main/content/manuals/compose/how-tos/startup-order.md), [services.md](https://github.com/docker/docs/blob/main/content/reference/compose-file/services.md)). Parâmetros disponíveis: `test`, `interval`, `timeout`, `retries`, `start_period`, `start_interval`; `test: NONE` ou `disable: true` desliga inclusive um healthcheck herdado da imagem.

Nota sobre `$$`: o `$$` no exemplo oficial é escape do Compose — a variável é resolvida **dentro** do container, não pelo Compose.

### 5.5 Como o Compose usa o actuator

O Spring Boot expõe os grupos de saúde `liveness`/`readiness` em `/actuator/health/liveness` e `/actuator/health/readiness` ([Actuator endpoints](https://docs.spring.io/spring-boot/3.5/reference/actuator/endpoints.html)), com `management.endpoint.health.group.readiness.include=readinessState,customCheck` para acrescentar indicadores ao grupo, e `AvailabilityProbesAutoConfiguration` provendo os indicadores ([javadoc](https://docs.spring.io/spring-boot/3.5/api/java/org/springframework/boot/actuate/autoconfigure/availability/AvailabilityProbesAutoConfiguration.html)). Isso é exatamente o que os tickets 28 e 34 exigem.

Mapeamento para Compose:

- **`healthcheck` do serviço da API** → `readiness` (o container está pronto para receber tráfego?). Este é o que o `depends_on: condition: service_healthy` de outros serviços observa.
- **`restart: unless-stopped` + liveness** → o Compose **não** tem probe de liveness que reinicia o container; ele só reinicia quando o processo morre. Liveness fica sendo consumida pelo Prometheus/alertas, não pelo Compose. Vale registrar essa diferença em relação ao Kubernetes para não criar expectativa errada no ticket 28.
- **`docker compose up -d --wait --wait-timeout N`** bloqueia até os serviços ficarem `running|healthy` ([`cmd/compose/up.go`](https://github.com/docker/compose/blob/main/cmd/compose/up.go): *"Wait for services to be running|healthy. Implies detached mode."*, incompatível com `--abort-on-container-exit`/`--attach`). É o comando de deploy: se o readiness não subir, o deploy falha em vez de "parecer" ter dado certo.

**Armadilha prática:** o `test` do healthcheck roda **dentro** do container da API. Imagens JRE mínimas frequentemente não têm `curl` nem `wget`. Opções: (a) instalar `curl` na imagem final; (b) usar o `HEALTHCHECK` do Dockerfile com um cliente próprio; (c) expor a probe pela porta de management e checar de fora. Decidir isso junto com o ticket 33/34 e não descobrir na primeira subida.

**Healthcheck no Traefik também**, que é independente do healthcheck do Docker (o Traefik tira o backend do pool sem esperar o Docker marcar unhealthy):

```yaml
labels:
  - "traefik.http.services.api.loadbalancer.healthcheck.path=/actuator/health/readiness"
  - "traefik.http.services.api.loadbalancer.healthcheck.interval=10s"
  - "traefik.http.services.api.loadbalancer.healthcheck.timeout=3s"
```
([load balancing / service](https://doc.traefik.io/traefik/reference/routing-configuration/http/load-balancing/service); o namespace completo, incluindo `healthcheck.port` e `healthcheck.scheme`, está na [referência de dynamic config do provider Docker](https://doc.traefik.io/traefik-enterprise/references/configuration/dynamic/docker)).

Detalhe de drenagem que o Keycloak documenta e vale para a API também: com `interval: 5s` e `timeout: 3s`, *"it takes up to 8 seconds for Traefik to mark a Keycloak instance as down"* — daí o `--shutdown-delay=8s` no Keycloak ([traefik-reencrypt.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/server/traefik-reencrypt.adoc)). O equivalente no Spring é o graceful shutdown com `spring.lifecycle.timeout-per-shutdown-phase` ≥ janela de detecção, e `stop_grace_period` no Compose maior que isso.

---

## 6. Airflow e Compose na mesma VM (interage com o ticket 13)

### 6.1 O aviso oficial, que precisa constar da spec

O guia oficial de Docker Compose do Airflow (versão corrente **3.3.0**) diz literalmente: *"This procedure can be useful for learning and exploration. However, adapting it for use in real-world situations can be complicated and the docker compose file does not provide any security guarantees required for production system"* — e recomenda Kubernetes + Helm chart para produção ([howto/docker-compose](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html)).

Como Kubernetes está **fora de escopo por decisão do projeto**, isso vira um **risco aceito explícito**: o `docker-compose.yaml` do Airflow é ponto de partida, não produto — a spec precisa dizer o que foi endurecido em cima dele. Requisitos que o mesmo guia registra: *"you may need to configure Docker to use at least 4.00 GB of memory"* e `AIRFLOW_UID` no `.env` (*"the quick-start needs to know your host user id and needs to have group id set to 0. Otherwise the files created in dags, logs, config and plugins will be created with root user ownership"*, default 50000). Insumo direto para o dimensionamento de VM ("Operação e capacidade" no map.md).

### 6.2 Containers irmãos, não filhos

O `DockerOperator` fala com o daemon do host: `docker_url` tem default *"unix://var/run/docker.sock if DOCKER_HOST environment variable is unset"* ([DockerOperator API](https://airflow.apache.org/docs/apache-airflow-providers-docker/stable/_api/airflow/providers/docker/operators/docker/index.html)). O provider exige Airflow ≥ 2.11.0 e `docker` ≥ 7.1.0 ([provider index](https://airflow.apache.org/docs/apache-airflow-providers-docker/stable/index.html)).

O container Spring Batch nasce como **irmão** do worker do Airflow, no daemon do host. Isso produz três consequências que a spec precisa tratar:

1. **Paths de mount são do host, não do worker.** Um `mounts` que aponta para um caminho que só existe dentro do container do Airflow não resolve. O próprio parâmetro `mount_tmp_dir` (default `True`) cria um diretório temporário **no host** e o monta como `AIRFLOW_TMP_DIR`; a doc recomenda *"set to False for remote Docker engines or docker-in-docker setups"*. **Recomendação: `mount_tmp_dir=False`** — o contrato deste projeto passa dados por PostgreSQL e MinIO, não por arquivo compartilhado.
2. **Rede.** O container irmão não herda a rede do worker. `network_mode` aceita `bridge`, `none`, `container:<name|id>`, `host` ou *"a custom network name or ID created via docker network create"*. **Recomendação: rede nomeada externa do Compose** (ex.: `backend`), para o processador alcançar PostgreSQL, MinIO e o OTel Collector por nome de serviço. **Não** usar `host`.
3. **Ciclo de vida.** `auto_remove` default `'never'` — em produção isso acumula containers mortos na VM indefinidamente. **Recomendação: `auto_remove='force'`** (ou `'success'`, se quiser inspecionar falhas manualmente — mas aí é preciso um GC). Exit code: *"non-zero exit codes trigger task failure"*, com `skip_on_exit_code` para códigos que devem virar *skipped*. Logs vêm do stream do container; `xcom_all` (default `False`) controla se todo o stdout ou só a última linha vai para XCom. Isso fecha o contrato de exit code/log que o ticket 19 precisa.

### 6.3 Isolamento — o problema real

Airflow e Traefik **ambos** querem `/var/run/docker.sock` na mesma VM. Quem tem o socket é root no host ([Engine security](https://github.com/docker/docs/blob/main/content/manuals/engine/security/_index.md)), e o `:ro` não ajuda ([bind mounts](https://github.com/docker/docs/blob/main/content/manuals/engine/storage/bind-mounts.md)). O worker do Airflow **executa código de DAG**, o que torna esse acoplamento pior do que o do Traefik: quem consegue commitar uma DAG consegue root na VM.

Opções, com critério:

| Opção | Isolamento | Custo | Quando |
|---|---|---|---|
| Socket direto nos dois | Nenhum | Zero | Só se a VM for dedicada e o acesso a DAGs for tão restrito quanto o acesso root |
| **Socket proxy** por consumidor, em rede própria, com verbos/rotas filtrados | Bom | Um container a mais por consumidor | **Recomendado** — é a mitigação que a própria doc do Traefik indica: *"employing a Docker socket proxy, or using authorization plugins to restrict API access"* ([Docker provider](https://doc.traefik.io/traefik/providers/docker)) |
| Daemon exposto por TCP/SSH com autenticação por certificado de cliente | Bom | Gestão de certificados | Quando o Airflow ficar em VM separada |
| **VM separada para o Airflow** | Ótimo | Mais uma VM | Preferível se o orçamento permitir; o Traefik fica só na VM de ingress |

**Recomendação:** separar por VM se possível (ingress+aplicação numa, Airflow+processadores noutra); se for uma VM só, socket proxy dedicado para cada consumidor, em rede Docker própria, com o Traefik restrito a leitura de containers/eventos e o Airflow ao mínimo necessário para `create/start/logs/wait/remove`. E a rede do Traefik (`proxy`) **não** deve ser a mesma rede dos processadores (`backend`) — o `--providers.docker.network=proxy` do exemplo oficial já assume essa segmentação.

---

## 7. ARM64 — disponibilidade por imagem

Verificação feita contra os registries, lendo as manifests multi-arquitetura (Docker Hub `GET /v2/repositories/{ns}/{repo}/tags/{tag}`; Quay `GET /v2/{repo}/manifests/{tag}` com `Accept: application/vnd.oci.image.index.v1+json`), em 2026-08-02.

| Imagem | Tag verificada | Arquiteturas publicadas | ARM64 nativo |
|---|---|---|---|
| `traefik` | `v3.7` | amd64, **arm64/v8**, arm/v6, ppc64le, riscv64, s390x | Sim |
| `quay.io/keycloak/keycloak` | `26.7` | amd64, **arm64**, ppc64le | Sim |
| `postgres` | `18` | 386, amd64, arm/v5, arm/v7, **arm64/v8**, ppc64le, riscv64, s390x | Sim |
| `minio/minio` | `latest` | amd64, **arm64**, ppc64le | Sim |
| `apache/airflow` | `3.3.0` | amd64, **arm64** | Sim |
| `graylog/graylog` | `6.3` | amd64, **arm64** | Sim |
| `graylog/graylog-datanode` | `6.3` | amd64, **arm64** | Sim |
| `opensearchproject/opensearch` | `2` | amd64, **arm64** | Sim |
| `mongo` | `8.0` | amd64, **arm64** | Sim |
| `prom/prometheus` | `latest` | amd64, arm/v7, **arm64**, ppc64le, riscv64, s390x | Sim |
| `grafana/grafana` | `latest` | amd64, arm/v7, **arm64** | Sim |
| `jaegertracing/jaeger` | `latest` | amd64, **arm64**, ppc64le, s390x | Sim |
| `axllent/mailpit` | `latest` | 386, amd64, **arm64** | Sim |
| `otel/opentelemetry-collector-contrib` | `latest` | 386, amd64, arm/v7, **arm64**, ppc64le, riscv64, s390x | Sim |

**Nenhum buraco de ARM64 na stack.** Observações:

- Versões atuais confirmadas nas releases oficiais: Traefik **v3.7.10** (2026-07-31), Keycloak **26.7.0** (2026-07-09), Airflow **3.3.0** (2026-07-06).
- O Graylog não é um container só: precisa de **MongoDB** e de **OpenSearch** (ou do `graylog-datanode`, que empacota o OpenSearch). Os três têm arm64. Isso muda o dimensionamento da VM — é o serviço mais pesado da stack de observabilidade.
- `jaegertracing/jaeger` (v2, coletor unificado) tem arm64. A imagem antiga `jaegertracing/all-in-one` não é para produção; o ticket 08 decide.
- As imagens da própria aplicação (API REST, starter Spring Batch, 5 processadores, frontend Angular) serão construídas pelo projeto. Como o ambiente de dev é aarch64 e a produção pode não ser, a decisão de **buildar multi-arch (`linux/amd64,linux/arm64`) via buildx no CI** ou de fixar uma única arquitetura pertence ao ticket 30/CI — mas depende desta constatação: nada na stack de terceiros força amd64.
- A entrada `unknown/unknown` que aparece em várias manifests é o artefato de atestação (provenance/SBOM) do buildx, não uma plataforma.

---

## Recomendação

**Traefik.** Fixar `traefik:v3.7`. Modelo híbrido de configuração: labels do Compose para os serviços simples da aplicação; provider de arquivo (`--providers.file.directory=/etc/traefik/dynamic`, `watch: true`) para TLS, middlewares compartilhados e para o bloco de roteamento do Keycloak. `--providers.docker.exposedbydefault=false`, `--providers.docker.network=proxy`, `--api.insecure=false`, dashboard atrás de autenticação, `security_opt: [no-new-privileges:true]`. Fixar `entryPoints.websecure.http.maxHeaderBytes=65536` (bem abaixo do default de 1 MiB) e redirecionar `web`→`websecure` permanentemente.

**TLS.** Decisão pendente de um fato de infraestrutura que a spec ainda não fixou: os hostnames de produção estarão em DNS público com porta 80/443 alcançável? Se **sim** → ACME HTTP-01, `acme.json` em volume persistente, `caServer` de staging em homologação. Se **não** (cenário mais provável, dado Graylog/Grafana/Jaeger/Mailpit/MinIO internos) → certificado de CA interna pelo provider de arquivo, com `tls.stores.default.defaultCertificate` sempre preenchido. ACME DNS-01 só se já houver provedor DNS automatizável — e é o único caminho para wildcard.

**Exposição do Keycloak.** A análise comportamental está certa: **não dá para expor "só o Account Console e o registro" por rota**, porque ambos vivem sob `/realms/{realm}/`, o mesmo prefixo que os endpoints OIDC obrigam a expor. Adotar as duas camadas: o Traefik faz o recorte que o Keycloak documenta como normativo (público = `/realms/` + `/resources/` + `/.well-known/`; todo o resto atrás de `ipAllowList` com `priority: 1`; `/realms/master/` e a porta 9000 nunca publicadas; middleware que zera headers de proxy e de tracing recebidos do cliente), e o realm faz o recorte fino (`registrationAllowed` no realm da aplicação, `default-roles-<realm>` reduzido a `view-profile` + `manage-account`, tema customizado no login/registro). Modo **re-encrypt** com `--proxy-headers xforwarded` no Keycloak — sem isso, respostas 403 no origin check. Corrigir a redação do `descricao-inicial.md` no ticket 17.

**Headers.** O limite que morde é o do **Tomcat: 8 KB para request line + todos os headers somados**, não o do Traefik (1 MiB). Subir `server.max-http-request-header-size` na API para um valor deliberado (ex.: 16KB) e passar esse orçamento como restrição de entrada para o ticket 15 decidir o teto de roles no token — ou tirar a lista de roles do JWT.

**Compose.** `compose.yaml` (base) + `compose.prod.yaml`, selecionados por `COMPOSE_FILE` no `.env` da VM; `compose.override.yaml` reservado para dev. Segredos por `secrets:` com `file:` e consumo via `*_FILE`, cientes de que em Compose (fora do Swarm) isso é bind mount de arquivo do host — a proteção real é permissão `0600` e o arquivo fora do Git; registrar como risco aceito. `restart: unless-stopped` para serviços de longa duração e **nunca** para os jobs Spring Batch. Healthcheck da API apontando para `/actuator/health/readiness`, `depends_on: condition: service_healthy` para PostgreSQL, Keycloak e MinIO, e deploy por `docker compose up -d --wait --wait-timeout N` para que readiness quebrada reprove o deploy. Espelhar o mesmo readiness num `loadbalancer.healthcheck` do Traefik e dimensionar o graceful shutdown acima da janela de detecção do proxy. Resolver cedo como o healthcheck será executado dentro da imagem JRE (curl ausente).

**Airflow.** O `docker-compose.yaml` oficial do Airflow é declaradamente não-produtivo; como Kubernetes está fora de escopo, isso vira risco aceito com endurecimentos documentados. `DockerOperator` com `mount_tmp_dir=False`, `network_mode` apontando para a rede nomeada do backend, `auto_remove='force'`, e exit code/logs como o contrato do ticket 19. O acoplamento perigoso é o socket do Docker compartilhado entre Traefik e Airflow na mesma VM — preferir **VM separada para o Airflow**; se não der, socket proxy dedicado por consumidor, em rede própria, com verbos filtrados, e as redes `proxy` e `backend` segregadas.

**ARM64.** Sem bloqueios: as 14 imagens de terceiros da stack publicam arm64 nativo. A decisão que sobra é se as imagens **da aplicação** serão multi-arch no CI — pertence ao ticket 30, e nada na stack de terceiros a restringe.
