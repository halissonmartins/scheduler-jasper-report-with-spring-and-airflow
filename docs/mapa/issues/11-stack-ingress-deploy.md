# 11 — Stack: ingress e deploy (Traefik, TLS, Compose em VMs)

Type: research
Status: resolved
Blocked by: —

## Question

Como o Traefik e o Docker Compose sustentam produção em VMs?

Levantar com fontes primárias (use context7) e recomendar:

- **Traefik**: versão, configuração via labels do Compose vs arquivo dinâmico, e obtenção de TLS (ACME/Let's Encrypt vs certificado próprio).
- **Exposição seletiva do Keycloak**: o documento quer expor só o Account Console e a página de registro. Levantar até onde dá para restringir por rota/path no Traefik e onde isso é frágil — a análise comportamental argumenta que o correto é desabilitar as demais features no realm, não filtrar rotas. Levantar as duas opções.
- **Limites de header**: tamanho máximo de header no Traefik e no servidor embutido do Spring, relevante para o JWT inflado por muitos grupos (ticket 15).
- **Docker Compose em produção**: organização dos arquivos (base + override por ambiente), gestão de segredos, política de restart, healthchecks, e como o Compose usa os endpoints do actuator.
- **Airflow disparando containers**: como o Airflow e o Compose coexistem na mesma VM (socket do Docker, rede, isolamento). Interage com o ticket 13.
- **ARM64**: quais imagens da stack têm build ARM64 nativo — o ambiente de desenvolvimento é aarch64.

Registrar as descobertas em `docs/mapa/research/11-ingress-deploy.md`.

## Answer

Research completo em [`../research/11-ingress-deploy.md`](../research/11-ingress-deploy.md).

- **Traefik v3.7.10**; usar `traefik:v3.7`. Configuração híbrida: labels do Compose para serviços simples, provider de arquivo para TLS, middlewares compartilhados e o roteamento do Keycloak (`tls.certificates` e `tls.options` não existem como label).
- **TLS**: decisão depende de um fato ainda não fixado — se os hostnames de produção estarão em DNS público com porta 80 alcançável. Se sim, ACME HTTP-01 com `acme.json` persistido; se não (cenário provável, stack interna), certificado de CA interna via arquivo com `defaultCertificate` sempre preenchido. Wildcard exige DNS-01.
- **Exposição do Keycloak**: a análise comportamental está certa. Account Console (`/realms/{realm}/account`) e registro vivem sob `/realms/`, o mesmo prefixo que o Keycloak marca como obrigatoriamente exposto para OIDC — não há recorte por rota que isole "só" os dois. Adotar as duas camadas: Traefik faz o recorte normativo que o Keycloak documenta (público = `/realms/` + `/resources/` + `/.well-known/`; resto atrás de `ipAllowList` com `priority: 1`; `/realms/master/` e a porta 9000 nunca publicadas) e o realm faz o fino (`registrationAllowed`, `default-roles-<realm>` reduzido a `view-profile` + `manage-account`). Modo re-encrypt com `--proxy-headers xforwarded`. Insumo direto do ticket 17, que deve corrigir a redação do documento original.
- **Headers**: o gargalo é o **Tomcat (8 KB para request line + todos os headers somados)**, não o Traefik (1 MiB). Entrada obrigatória para o teto de roles do ticket 15.
- **Compose**: base + `compose.prod.yaml` via `COMPOSE_FILE`; segredos por `secrets:`/`*_FILE` com a ressalva de que fora do Swarm é bind mount de arquivo do host (risco aceito); `restart: unless-stopped` só para serviços de longa duração, nunca para os jobs Batch; healthcheck em `/actuator/health/readiness` + `depends_on: service_healthy` + deploy por `up -d --wait`.
- **Airflow**: o Compose oficial do Airflow é declaradamente não-produtivo (risco aceito, já que K8s está fora de escopo). `DockerOperator` cria containers **irmãos**: `mount_tmp_dir=False`, `network_mode` na rede nomeada do backend, `auto_remove='force'`. O acoplamento perigoso é o socket do Docker compartilhado com o Traefik — preferir VM separada; senão, socket proxy por consumidor.
- **ARM64**: sem bloqueios — as 14 imagens de terceiros da stack publicam arm64 nativo (tabela no research).
