# 07 — Identidade: Keycloak, Admin API e roles no JWT

Pesquisa do ticket [07 — Stack: identidade](../issues/07-stack-identidade.md).
Fontes primárias: documentação e código-fonte do Keycloak na tag `26.5.2`, documentação de referência do Spring Security / Spring Boot, documentação do Traefik e o README do Mailpit. Onde a afirmação vem do código, o link aponta para o arquivo na tag.

Este documento levanta **fatos**. As decisões ficam com os tickets 14 (escopo do GERENTE), 15 (claim vs. banco), 16 (cadastro pendente) e 17 (sessão e logout). A seção final traz recomendações com o critério de decisão explícito.

---

## 1. Keycloak: versão e ciclo de suporte

- A versão publicada atualmente é a **26.7.0** — [keycloak.org/downloads](https://www.keycloak.org/downloads) e [keycloak.org/documentation](https://www.keycloak.org/documentation).
- **O projeto comunitário não tem LTS.** Não existe página oficial de ciclo de vida para as releases da comunidade; o que existe formalmente é o ciclo do produto comercial. O *Red Hat build of Keycloak* declara: 26.x com no mínimo **2 anos** de suporte, 27.x em diante com no mínimo **3 anos**; a fase de *Full Support* termina quando o próximo major fica disponível e a *Maintenance Support* dura pelo menos mais 6 meses; releases minor recebem correções por ~12 meses. O mesmo documento diz que as minors do produto são baseadas nas **minors pares** da comunidade — [Red Hat build of Keycloak Life Cycle](https://access.redhat.com/support/policy/updates/red_hat_build_of_keycloak_notes).
- Consequência prática para este projeto: **fixar a versão exata da imagem** (`quay.io/keycloak/keycloak:26.7.0`, não `latest`) e tratar upgrade de Keycloak como item de manutenção recorrente, porque na comunidade correção de segurança chega na versão nova, não em backport.
- Escolha do baseline: as minors **pares** (26.4, 26.6, …) são as que a Red Hat rebaseia, o que na prática significa que recebem mais escrutínio. Não é garantia formal, mas é o único sinal público de estabilidade relativa.

## 2. Import de realm na inicialização e o ADMINISTRADOR automático

O documento exige: *"Ao iniciar o container do KeyCloak, automaticamente irá criar um usuário do tipo ADMINISTRADOR (senha configurada em variável de ambiente)"*. Há duas coisas distintas em jogo, e confundi-las é um erro comum.

### 2.1 O admin de bootstrap do Keycloak ≠ o ADMINISTRADOR da aplicação

- `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` criam o administrador inicial do servidor — [containers.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/containers.adoc). As variáveis antigas `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` estão **depreciadas** desde a 26.0 — [changes-26_0_0.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/upgrading/topics/changes/changes-26_0_0.adoc).
- Essa conta é **sempre criada no realm `master`** e é explicitamente **temporária**: *"the account should exist only for the duration necessary to perform operations needed to gain permanent and more secure admin access. After that, the account needs to be removed manually"* — [Bootstrap admin and recovery](https://www.keycloak.org/server/bootstrap-admin-recovery). O mesmo guia documenta a variante `bootstrap-admin service`, que cria um **service account** (clientId + secret) em vez de um usuário.
- Portanto o ADMINISTRADOR do produto (perfil de negócio, dentro do realm da aplicação) **não é** o bootstrap admin. São duas contas em realms diferentes.

### 2.2 Import de realm no start

- Os containers têm o diretório `/opt/keycloak/data/import`; com a flag `--import-realm` o servidor importa todo `.json` regular ali (subdiretórios são ignorados) — [importExport.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/importExport.adoc) e [containers.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/containers.adoc).
- **Se o realm já existe, a importação é pulada.** *"If a realm already exists in the server, the import operation is skipped. The main reason behind this behavior is to avoid re-creating realms and potentially lose state between server restarts."* Para recriar é preciso rodar o comando `kc.sh import` (com `--override`, default `true`) com o servidor parado — [importExport.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/importExport.adoc).
  - Consequência: **o arquivo de realm é semente, não configuração declarativa.** Alterar o JSON e reiniciar não muda nada num ambiente já provisionado. Toda mudança posterior de realm precisa de outro mecanismo (Admin API, `kcadm`, ou recriação).
- O servidor **não completa o start** enquanto o import não terminar — mesma fonte. Isso interage com o healthcheck do Compose (ticket 11/28).
- **Placeholders de variável de ambiente são suportados no JSON do realm**: `"realm": "${MY_REALM_NAME}"` resolve a partir do ambiente. A própria doc alerta: *"there are currently no restrictions on what environment variables may be referenced (…) take care to ensure placeholders references do not inappropriately expose sensitive environment variable values"* — [importExport.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/importExport.adoc).
- Convenção de nome de arquivo obrigatória para import por diretório/startup: `<realm>-realm.json`, `<realm>-users-<n>.json` — mesma fonte.

**Como isso atende o requisito**: o `realm-export.json` versionado no repositório contém o usuário ADMINISTRADOR com `credentials: [{ "type": "password", "value": "${APP_ADMIN_PASSWORD}" }]`, e o Compose injeta `APP_ADMIN_PASSWORD`. Cumpre a regra do documento sem senha em claro no Git. Riscos a registrar: (a) a senha fica em claro no `.env`/Compose da VM; (b) a rotação obrigatória está **fora de escopo** por decisão do documento, então essa senha é permanente até intervenção manual.

## 3. Admin API: o mínimo que o service account de mediação precisa (base do ticket 14)

O GERENTE nunca deve receber credencial do Keycloak. A API REST intermedeia, autenticando-se com **client credentials** de um client confidencial com service account habilitado — [proc-using-a-service-account.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/oidc/proc-using-a-service-account.adoc), [admin-rest-api.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_development/topics/admin-rest-api.adoc).

As permissões administrativas são **client roles do client `realm-management`** do próprio realm (`create-client`, `manage-clients`, `manage-realm`, `manage-users`, `query-groups`, `query-users`, `view-realm`, `view-users`, …) — [master-realm.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/admin-console-permissions/master-realm.adoc). A resolução é feita em [`MgmtPermissions.hasOneAdminRole`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/MgmtPermissions.java).

### 3.1 O que cada operação do GERENTE exige, segundo o código

| Operação de negócio | Endpoint Admin REST | Verificação no código | Role clássica exigida |
|---|---|---|---|
| Criar/remover **role de relatório como realm role** | `POST/DELETE /admin/realms/{r}/roles` | [`RolePermissions.canManage(RoleContainerModel)`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/RolePermissions.java) → `realm().canManageRealm()` | **`manage-realm`** |
| Criar/remover **role de relatório como client role** | `POST/DELETE /admin/realms/{r}/clients/{id}/roles` | [`RolePermissions.canManage(RoleModel)`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/RolePermissions.java) → `clients().canConfigure(client)`; em FGAP v2, [`ClientPermissionsV2.canConfigure`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/ClientPermissionsV2.java) redireciona para `canManage(client)` | `manage-clients` **ou** permissão FGAP `manage` escopada **àquele único client** |
| Criar/remover **grupo** | `POST/DELETE /admin/realms/{r}/groups` | [`GroupPermissions.canManage()`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/GroupPermissions.java) → `manage-users`; em v2, [`GroupPermissionsV2.canManage()`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/GroupPermissionsV2.java) aceita permissão FGAP `Groups:manage` | `manage-users` **ou** FGAP `Groups:manage` |
| **Vincular role a grupo** | `POST /admin/realms/{r}/groups/{id}/role-mappings/realm` (ou `/clients/{cid}`) | [`RoleMapperResource.addRealmRoleMappings`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/RoleMapperResource.java) → `auth.roles().requireMapRole(role)` → [`RolePermissionsV2.canMapRole`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/RolePermissionsV2.java) | `manage-users` **ou** FGAP `Roles:map-role` escopada **por role** |
| **Incluir/remover usuário em grupo** | `PUT/DELETE /admin/realms/{r}/users/{uid}/groups/{gid}` | [`UserResource.joinGroup` / `removeMembership`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/UserResource.java) → `requireManageMembership(group)` → `GroupPermissionsV2.canManageMembership` | `manage-users` **ou** FGAP `Groups:manage-membership` escopada **por grupo** |
| **Excluir RELATOR** | `DELETE /admin/realms/{r}/users/{uid}` | [`UserPermissions.canManage()`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/fgap/UserPermissions.java) | `manage-users` **ou** FGAP `Users:manage` |
| Listar usuários/grupos para a UI | `GET /admin/realms/{r}/users`, `/groups` | `requireQuery()` / `canView()` | `view-users` ou `query-users` / `query-groups` |

### 3.2 O achado decisivo: `manage-users` é escalonamento de privilégio

Com `manage-users`, o service account:

- pode **resetar a senha de qualquer usuário do realm**, inclusive dos ADMINISTRADORes e outros GERENTEs (`UserPermissions.canManage()` retorna `true` para todo usuário; o escopo `reset-password` existe justamente como permissão separável no FGAP v2 — [`AdminPermissionsSchema`](https://github.com/keycloak/keycloak/blob/26.5.2/server-spi-private/src/main/java/org/keycloak/authorization/fgap/AdminPermissionsSchema.java));
- pode **mapear qualquer role não-administrativa** para qualquer usuário: `RolePermissionsV2.canMapRole` retorna `true` de imediato se o chamador tem `manage-users`.

Ou seja: **se a API REST usar um service account com `manage-users`, um bug de validação na camada de mediação vira comprometimento total do realm** — o atacante reseta a senha de um ADMINISTRADOR e loga como ele. Isso confirma e agrava o alerta da análise comportamental (§3).

E `manage-realm` é ainda pior: é essencialmente admin do realm inteiro (fluxos de autenticação, clients, mappers, chaves).

### 3.3 Fine-Grained Admin Permissions v2 (FGAP v2) — o que dá e o que não dá para escopar

- A feature `admin-fine-grained-authz:v2` é **`Type.DEFAULT`** (ligada por padrão) na 26.5.2; a v1 está **`Type.DEPRECATED`** — [`Profile.java`](https://github.com/keycloak/keycloak/blob/26.5.2/common/src/main/java/org/keycloak/common/Profile.java). É declarada suportada desde a 26.2 — [release notes 26.2](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/release_notes/topics/26_2_0.adoc). Precisa ser habilitada **por realm** (switch *Admin Permissions* em *Realm Settings*) — [changes-26_2_0.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/upgrading/topics/changes/changes-26_2_0.adoc).
- Os tipos de recurso e escopos são fixos — [`AdminPermissionsSchema`](https://github.com/keycloak/keycloak/blob/26.5.2/server-spi-private/src/main/java/org/keycloak/authorization/fgap/AdminPermissionsSchema.java):
  - `Clients`: `manage`, `view`, `map-roles`, `map-roles-client-scope`, `map-roles-composite`
  - `Groups`: `manage`, `view`, `manage-membership`, `manage-members`, `view-members`, `impersonate-members`
  - `Roles`: **apenas** `map-role`, `map-role-client-scope`, `map-role-composite`
  - `Users`: `manage`, `view`, `impersonate`, `map-roles`, `manage-group-membership`, `reset-password`
- **Limitação central**: o tipo `Roles` **não tem escopo `manage`**. E `RolePermissionsV2` **não sobrescreve** `canManage(...)` — herda o comportamento de `RolePermissions`. Logo **criar/apagar uma role não é delegável via FGAP v2**: continua exigindo `manage-realm` (para realm roles) ou `manage`/`manage-clients` sobre o client dono (para client roles).
- FGAP v2 exige atribuição explícita de cada escopo (não há transitividade: `view` e `manage` são separados) e permite escopar por recurso específico, conjunto de recursos, ou todos de um tipo — [changes-26_2_0.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/upgrading/topics/changes/changes-26_2_0.adoc). Também permite políticas negativas (ex.: "administra usuários, exceto os membros do grupo de admins") — [fine-grain-v2.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/admin-console-permissions/fine-grain-v2.adoc).

### 3.4 Consequência de arquitetura: role de relatório deve ser **client role**

Juntando 3.1 + 3.3:

- **Realm role** ⇒ o service account precisa de `manage-realm` para criar roles ⇒ ele vira admin do realm. Inaceitável.
- **Client role de um client dedicado** (ex.: client `relatorios`, sem fluxo de login, existindo só para hospedar as roles) ⇒ o service account precisa apenas de uma permissão FGAP `Clients:manage` **escopada àquele único client**. Ele não consegue tocar em nenhum outro client, nem no `realm-management`, nem em usuários.

Isso continua atendendo a regra do documento *"A Role de Relatório é uma role real do Keycloak e viaja no JWT"*: client roles são roles reais e viajam em `resource_access.<client>.roles` (§4).

Risco residual a registrar: `Clients:manage` sobre o client `relatorios` também permite alterar a configuração daquele client (redirect URIs, service account próprio). Como esse client não participa de nenhum fluxo de login e não tem service account, o dano possível é baixo — mas é um risco aceito, não zero.

### 3.5 O ponto cego do FGAP escopado por grupo

Permissões escopadas por grupo (`Groups:manage-membership`, `Users:manage` derivado de `manage-members`) **não alcançam um usuário que não está em nenhum grupo** — exatamente o estado do RELATOR recém-cadastrado. O Keycloak resolve isso com **Default Groups**: todo usuário criado ou importado entra automaticamente nos grupos default do realm — [proc-specifying-default-groups.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/roles-groups/proc-specifying-default-groups.adoc).

Insumo direto para o ticket 16: um grupo `PENDENTES` como default group resolve simultaneamente (a) a modelagem do estado "pendente de vínculo" no próprio Keycloak, (b) o alcance das permissões FGAP do service account sobre os recém-cadastrados, e (c) a listagem "quem está esperando" (`GET /admin/realms/{r}/groups/{id}/members`).

Alternativa de listagem: `GET /admin/realms/{r}/users?q=chave:valor` busca por **atributos customizados** do usuário — [`UsersResource`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/resources/admin/UsersResource.java). Não existe query nativa "usuários sem grupo".

### 3.6 Auditoria

- **Admin events** registram toda invocação da Admin REST API, com `Include representation` opcional (o JSON enviado). O tamanho do campo é limitável por `--spi-events-store--jpa--max-field-length` — [events/admin.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/events/admin.adoc).
- Fato importante para o ticket 14: como **todas** as chamadas passam pelo service account, o admin event do Keycloak registra sempre o mesmo autor. **A identidade do GERENTE que pediu a operação só existe no log da aplicação.** A trilha de auditoria com autor/alvo/motivo/Correlation ID tem que ser gravada pela API REST no schema de controle; o admin event do Keycloak é prova secundária.

## 4. Roles no token: formato, tamanho e o limite de header (base do ticket 15)

### 4.1 Formato

- Realm roles vão no claim `realm_access.roles`; client roles vão em `resource_access.<clientId>.roles` — [con-token-role-mappings.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/oidc/con-token-role-mappings.adoc):

```json
{ "realm_access": { "roles": ["role1", "role2"] },
  "resource_access": { "relatorios": { "roles": ["REL_POUPANCA-0001"] } } }
```

- Quais roles entram é a **interseção** entre as roles do usuário e os *role scope mappings* do client — [con-token-role-mappings.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/oidc/con-token-role-mappings.adoc), [con-role-scope-mappings.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/roles-groups/con-role-scope-mappings.adoc). Com *Full scope allowed* ligado (padrão), todas as roles do usuário entram.
- Os mappers vivem no client scope embutido `roles` (mappers *realm roles*, *client roles*, *audience resolve*), que é *default* em todo client do realm — [con-client-scopes.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/con-client-scopes.adoc).
- `include.in.token.scope` **não controla roles** — controla se o nome do client scope aparece no claim `scope`. O scope `roles` explicitamente *"is not added automatically to the scope claim"* — mesma fonte. Ou seja, a mitigação sugerida no ticket via `include.in.token.scope` **não reduz o tamanho do token**; quem reduz é role scope mapping, mapper seletivo ou lightweight access token.

### 4.2 Tamanho: quem estoura primeiro é o **Tomcat**, não o Traefik

- **Traefik**: `entryPoints.<nome>.http.maxHeaderBytes`, **default 1 048 576 bytes (1 MB)** — [entrypoints](https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/). A doc recomenda *reduzir* esse valor (ex.: 65 536) como defesa contra amplificação de memória em HTTP/2 — [http2-header-memory](https://doc.traefik.io/traefik/security/http2-header-memory).
- **Spring Boot**: `server.max-http-request-header-size` tem default **8 KB**, e no Tomcat o limite se aplica à **soma da request line com todos os headers** — [Application Properties](https://docs.spring.io/spring-boot/3.5/appendix/application-properties/index.html).

Estimativa (base64url infla ~4/3; assinatura RS256 = 256 B → 342 caracteres; claims básicas de um access token do Keycloak ≈ 0,9 KB JSON):

| Roles de relatório no token (nome ~20 chars) | Payload JSON | JWT resultante | `Authorization: Bearer …` vs. 8 KB |
|---|---|---|---|
| 25 | ~1,5 KB | ~2,3 KB | folgado |
| 50 | ~2,1 KB | ~3,1 KB | folgado |
| 100 | ~3,3 KB | ~4,7 KB | apertado com cookies |
| 200 | ~5,7 KB | ~7,9 KB | **estoura** |

Conclusões:
1. O gargalo real é o **default de 8 KB do Spring Boot**, não o Traefik (1 MB). A análise comportamental apontou o alvo errado.
2. Há folga confortável até ~100 roles por usuário. Acima disso é preciso decidir: subir `server.max-http-request-header-size` **e** o limite do Traefik de forma coordenada, ou tirar as roles do token.
3. O teto do domínio é conhecido: o formato `^[A-Z]{1,20}-\d{4}$` admite 9 999 relatórios por produto. Se um relator puder acumular centenas de roles, o modelo "role por relatório" no token não escala.

### 4.3 Mitigações reais

- **Mapper de group membership**: um claim `groups` com os caminhos dos grupos é ordens de grandeza menor (1 grupo cobre N relatórios) e a resolução fina fica no banco.
- **Lightweight access token**: reduz o token a poucas claims; mappers precisam do flag *Add to lightweight access token* (OFF por padrão), e há tanto o flag *Always use lightweight access token* no client quanto um executor de client policy — [release notes 24.0](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/release_notes/topics/24_0_0.adoc) e [25.0](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/release_notes/topics/25_0_0.adoc). Com introspection via `Accept: application/jwt` a API recupera o token completo quando precisar.
- **Role scope mapping / desligar Full scope allowed** no client do frontend: útil para não vazar roles de outros domínios, mas **não** ajuda no caso patológico (as roles `REL_*` são justamente as que o client precisa).

### 4.4 TTLs default (insumo da janela de revogação, ticket 15)

Do [`DefaultExportImportManager`](https://github.com/keycloak/keycloak/blob/26.5.2/model/storage-private/src/main/java/org/keycloak/storage/datastore/DefaultExportImportManager.java) na tag 26.5.2:

- `accessTokenLifespan` = **300 s (5 min)**
- `ssoSessionIdleTimeout` = **1800 s (30 min)**
- `ssoSessionMaxLifespan` = **36000 s (10 h)**
- `revokeRefreshToken` = **false**, `refreshTokenMaxReuse` = **0**

Ou seja: **por padrão a janela de revogação é de até 5 minutos** se a autorização sair da claim. Isso é um número concreto para o ticket 15 decidir se é aceitável.

- O endpoint de revogação `/realms/{r}/protocol/openid-connect/revoke` aceita **refresh tokens e access tokens** — [available-endpoints.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/securing-apps/partials/oidc/available-endpoints.adoc). Mas revogar um JWT auto-contido só surte efeito para quem faz **introspection**; um resource server que valida a assinatura offline continua aceitando o token até `exp`.

## 5. Integração Spring: resource server e mapeamento para `GrantedAuthority`

- O módulo API REST é **resource server** (`spring-boot-starter-oauth2-resource-server`), validando o JWT contra o JWK Set do realm. A extração de authorities é customizável por um conversor — [Servlet OAuth2 Resource Server / JWT](https://docs.spring.io/spring-security/reference/6.5/servlet/oauth2/resource-server/jwt.html).
- `JwtGrantedAuthoritiesConverter` permite configurar `authoritiesClaimName`, `authorityPrefix` e `authoritiesClaimDelimiter` — [Javadoc](https://docs.spring.io/spring-security/reference/6.5/api/java/org/springframework/security/oauth2/server/resource/authentication/JwtGrantedAuthoritiesConverter.html). O default lê `scope`/`scp` com prefixo `SCOPE_`.
- **Limitação relevante**: esse conversor lê um claim **plano** (string ou lista). As roles do Keycloak estão **aninhadas** (`realm_access.roles`, `resource_access.<client>.roles`). Não há conversor pronto para isso — é preciso um `Converter<Jwt, Collection<GrantedAuthority>>` próprio (poucas linhas) e injetá-lo via `JwtAuthenticationConverter.setJwtGrantedAuthoritiesConverter(...)` — [Javadoc](https://docs.spring.io/spring-security/reference/6.5/api/java/org/springframework/security/oauth2/server/resource/authentication/JwtAuthenticationConverter.html).
- Para combinar scopes **e** roles existe `DelegatingJwtGrantedAuthoritiesConverter`, que compõe vários conversores — [Javadoc](https://docs.spring.io/spring-security/reference/6.5/api/java/org/springframework/security/oauth2/server/resource/authentication/DelegatingJwtGrantedAuthoritiesConverter.html).
- Se a decisão do ticket 15 for "revogação imediata", a alternativa é **opaque token / introspection** (`spring.security.oauth2.resourceserver.opaquetoken`), ao custo de uma chamada ao Keycloak por request.

## 6. Tema customizado, página de registro e Account Console (base dos tickets 16 e 17)

### 6.1 Tema

- Tipos de tema: **Account, Admin, Email, Login, Welcome**. Todos, exceto o Welcome, são configurados **por realm** no Admin Console (*Realm Settings → Themes*) — [themes.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/ui-customization/themes.adoc).
- A página de registro é parte do tema **Login** (o template é `register.ftl`, ao lado de `login.ftl`). Deploy: copiar o diretório para `themes/` (desenvolvimento) ou empacotar um JAR com `META-INF/keycloak-themes.json` (produção, versionável) — mesma fonte.
- Textos de e-mail são customizáveis por *message bundle* do tema Email (`passwordResetSubject`, `passwordResetBody`, …) — mesma fonte.
- Dark mode passou a ser padrão nos temas `keycloak` a partir da 26.1; um tema custom que estenda os temas base pode desativá-lo com `darkMode=false` ou pelo switch *Dark mode* por realm — [release notes 26.1](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/release_notes/topics/26_1_0.adoc).

### 6.2 Registro público e validação de e-mail no cadastro

- *User registration* é um switch **por realm** (*Realm Settings → Login*) — [proc-enabling-user-registration.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/users/proc-enabling-user-registration.adoc). Campos correlatos na representação do realm: `registrationAllowed`, `registrationEmailAsUsername`, `verifyEmail`, `loginWithEmailAllowed`, `duplicateEmailsAllowed`.
- **Restrição de domínio de e-mail sem escrever código**: o *User Profile* declarativo permite validadores por atributo, entre eles `pattern` (regex + `error-message`) e `email` — [user-profile.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/users/user-profile.adoc). Um `pattern` no atributo `email` implementa allowlist de domínio, e vale em **todos os contextos** (registro, update profile, Account Console e Admin API), porque a mesma configuração renderiza e valida em todos eles — mesma fonte.
- O User Profile também suporta política de **atributos não gerenciados** (`Disabled` por padrão): atributos não declarados são ignorados. Recomendação da própria doc é manter a política mais restrita possível — mesma fonte.
- O Keycloak **não traz CAPTCHA embutido** para o formulário de registro na documentação da 26.5.2; o filtro efetivo previsto pelo produto é a aprovação manual pelo GERENTE + verificação de e-mail.

### 6.3 Account Console: o que dá e o que não dá para desligar

- O Account Console é servido em `{raiz}/realms/{realm}/account` — [account.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/account.adoc).
- **Não existe switch "só troca de senha".** O que existe é controle por **client roles do client `account`**:
  - o menu *Groups* só aparece para quem tem a role `view-groups` — [account.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/account.adoc);
  - a exclusão da própria conta exige a required action *Delete Account* habilitada **e** a role `delete-account` atribuída — [proc-allow-user-to-delete-account.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/users/proc-allow-user-to-delete-account.adoc).
  - Logo: removendo essas roles das *default roles* do realm, as respectivas telas somem para todos.
- Desligar o Account Console inteiro só é possível **no servidor** (build time), desabilitando a feature `account-api` — `ACCOUNT_V3` depende de `ACCOUNT_API` — [`Profile.java`](https://github.com/keycloak/keycloak/blob/26.5.2/common/src/main/java/org/keycloak/common/Profile.java), [features.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/server/features.adoc). Não serve aqui, porque o documento **quer** o Account Console para troca de senha.
- **O Admin Console não pode ser desligado sem perder a Admin API**: `ADMIN_V2` depende de `ADMIN_API`, e a Admin API é justamente o que a mediação usa — [`Profile.java`](https://github.com/keycloak/keycloak/blob/26.5.2/common/src/main/java/org/keycloak/common/Profile.java). **Portanto proteger `/admin` é necessariamente trabalho de rede/ingress (Traefik), não de configuração de realm.**

Isso corrige parcialmente a análise comportamental (§3): a afirmação "*a forma correta de restringir a troca de senha é desabilitar as demais features no realm, não filtrar rotas*" só vale para as telas **dentro** do Account Console (via roles do client `account`). Para o Admin Console, filtrar rota no Traefik é a **única** opção disponível. Detalhe operacional para o ticket 11: os paths do Admin Console são estáveis e bem delimitados (`/admin/**`), o que torna o bloqueio menos frágil do que a análise sugere — o frágil seria tentar filtrar *dentro* do `/realms/{r}/account/**`.

## 7. Mailpit como SMTP do Keycloak

- SMTP é configurado **por realm** (*Realm Settings → Email*): *Host*, *Port*, *From*, *From display name*, *Reply to*, *Envelope from*, *Encryption*, *Authentication* — [realms/email.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/realms/email.adoc). No JSON de import isso é o bloco `smtpServer` — exemplo real em [testrealm.json](https://github.com/keycloak/keycloak/blob/main/testsuite/integration-arquillian/tests/base/src/test/resources/testrealm.json).
- **Forgot password** é um switch por realm (*Realm Settings → Login*) e exige *Host* e *From* preenchidos na aba Email — [forgot-password.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/login-settings/forgot-password.adoc).
- Verificação de e-mail: o realm tem `verifyEmail`; a Admin API tem `PUT /admin/realms/{r}/users/{id}/send-verify-email`, que desde a 24.0 usa o template `email-verification.ftl` e aceita o parâmetro `lifespan` (default 12 h) — [changes-24_0_0.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/upgrading/topics/changes/changes-24_0_0.adoc).
- **Mailpit**: web UI em `0.0.0.0:8025`, SMTP em `0.0.0.0:1025`, sem autenticação por padrão — [README do Mailpit](https://github.com/axllent/mailpit/blob/develop/README.md). Portanto, na configuração do realm: host `mailpit`, port `1025`, *Authentication* OFF, *Encryption* OFF. Como não há autenticação, o Mailpit **não pode ser exposto** fora da rede interna do Compose.

## 8. Fim de sessão: RP-initiated logout, back-channel logout e revogação (base do ticket 17)

### 8.1 RP-initiated logout

- Endpoint: `/realms/{r}/protocol/openid-connect/logout` — [available-endpoints.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/guides/securing-apps/partials/oidc/available-endpoints.adoc).
- Desde a 18.0 o parâmetro `redirect_uri` foi **removido**; para redirecionar sem tela de confirmação é preciso `post_logout_redirect_uri` **junto com** `id_token_hint` (ou `client_id`, suportado desde a 19) — [changes-18_0_0.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/upgrading/topics/changes/changes-18_0_0.adoc), [release notes 19.0](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/release_notes/topics/19_0_0.adoc).
- A URI precisa estar registrada em **Valid Post Logout Redirect URIs** do client (`+` reaproveita as Valid Redirect URIs) — [con-oidc-auth-flows.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/sso-protocols/con-oidc-auth-flows.adoc).

### 8.2 Back-channel logout

- Configuração no client: **Backchannel logout URL**, **Backchannel logout session required** (inclui `sid` no Logout Token), **Backchannel logout revoke offline sessions** (inclui o evento `revoke_offline_access`). Só se aplica com *Front channel logout* desligado; **sem URL configurada, nenhuma requisição de logout é enviada** — [con-basic-settings.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/oidc/con-basic-settings.adoc).
- Mecânica: o Keycloak monta um `LogoutToken` (com `sid` e `events`), assina como JWT e faz **POST** com o parâmetro de formulário `logout_token` para a URL do client, esperando **200 ou 204** — [`ResourceAdminManager`](https://github.com/keycloak/keycloak/blob/26.5.2/services/src/main/java/org/keycloak/services/managers/ResourceAdminManager.java).

### 8.3 O fato que muda a decisão do ticket 17

O suporte a back-channel logout no Spring Security **pressupõe sessão de servidor**: o endpoint fica em `/logout/connect/back-channel/{registrationId}`, **exige `oauth2Login` configurado**, correlaciona ID Token ↔ sessão da aplicação num `OidcSessionRegistry` durante o login, e invalida a sessão pelo cookie (default `JSESSIONID`) — [Servlet OAuth 2.0 Login / Logout](https://docs.spring.io/spring-security/reference/6.5/servlet/oauth2/login/logout.html), [Javadoc do `OidcBackChannelServerLogoutHandler`](https://docs.spring.io/spring-security/reference/6.5/api/java/org/springframework/security/config/web/server/OidcBackChannelServerLogoutHandler.html).

Na arquitetura deste projeto — **SPA Angular como client público (Authorization Code + PKCE) e API REST como resource server stateless** — não existe sessão de servidor nem `oauth2Login`. Consequências:

1. **Back-channel logout não tem o que invalidar na API REST.** Implementá-lo lá é cerimônia sem efeito, a menos que a API mantenha uma denylist própria de `sid`/`sub` e passe a consultá-la a cada request — o que é reconstruir sessão de servidor.
2. **O que efetivamente encerra a sessão é o RP-initiated logout**, que invalida a sessão SSO no Keycloak. A partir daí não há novos tokens.
3. **O access token já emitido continua válido até `exp`** (5 min por padrão), a menos que a API use introspection. Essa é a janela real de "logout imperfeito", e é a mesma janela da revogação de permissão (§4.4) — o que simplifica: **uma única decisão de TTL resolve os dois problemas**.

### 8.4 Sessões concorrentes

O Keycloak não limita sessões concorrentes por padrão; o controle disponível é por timeouts (`SSO Session Idle/Max`, `Client Session Idle/Max`) — [timeouts.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/sessions/timeouts.adoc), [con-advanced-settings.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/clients/oidc/con-advanced-settings.adoc). O usuário vê e encerra seus dispositivos em *Account security → Device activity* — [account.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/account.adoc).

## 9. Notificação ao GERENTE de que há cadastro pendente (insumo do ticket 16)

- O Keycloak emite o evento de login **`Register`** ("A user registers") entre os tipos auditáveis; a gravação é opcional e configurada em *Realm Settings → Events → User events settings*, com expiração configurável — [events/login.adoc](https://github.com/keycloak/keycloak/blob/26.5.2/docs/documentation/server_admin/topics/events/login.adoc).
- O Keycloak **não** envia e-mail a terceiros quando alguém se cadastra. As opções primárias são: (a) um provider do **Event Listener SPI** dentro do Keycloak, (b) a aplicação **consultar** os membros do grupo `PENDENTES` (§3.5) e exibir um contador na UI, ou (c) a aplicação ler os eventos via `GET /admin/realms/{r}/events`.
- A opção (b) não exige extensão do Keycloak, é consistente com a mediação já necessária, e resolve o ponto da análise comportamental "*sem isso, o RELATOR espera indefinidamente*" com custo quase zero.

---

## Recomendação

**1. Versão e imagem.** Fixar `quay.io/keycloak/keycloak:26.7.0` (ou a minor **par** vigente no momento do primeiro deploy), nunca `latest`. Registrar como risco operacional que a comunidade não faz backport de segurança: upgrade de Keycloak é item recorrente de manutenção, não evento excepcional.

**2. Bootstrap e ADMINISTRADOR.**
- `KC_BOOTSTRAP_ADMIN_USERNAME`/`KC_BOOTSTRAP_ADMIN_PASSWORD` para o admin **temporário do `master`**, a ser removido depois do provisionamento.
- O **ADMINISTRADOR do produto** vem do `<realm>-realm.json` em `/opt/keycloak/data/import` com `--import-realm`, usando placeholder `${APP_ADMIN_PASSWORD}` na credencial.
- Documentar explicitamente que **o import é semente, não configuração declarativa** (é pulado se o realm existir). Toda mudança de realm pós-provisionamento passa por Admin API/`kcadm`, e o JSON no Git é a referência da instalação limpa — não a verdade do ambiente rodando.

**3. Role de relatório = client role de um client dedicado.** Criar um client `relatorios` (sem fluxo de login, apenas contêiner de roles) e hospedar ali as roles `REL_*`. É a única forma de o service account de mediação **criar roles sem receber `manage-realm`** (§3.3/§3.4). Critério de decisão: se por algum motivo as roles precisarem ser realm roles, então a criação de roles **não pode** ser exposta ao GERENTE em tempo de execução — teria que ser provisionamento por ADMINISTRADOR, e o ticket 14 precisa mudar o requisito.

**4. Permissões do service account de mediação — nunca `manage-users`, nunca `manage-realm`.** Habilitar *Admin Permissions* (FGAP v2) no realm e conceder ao service account somente:
- `Clients:manage` escopada ao client `relatorios` (criar/apagar roles de relatório);
- `Groups:manage` (criar/apagar grupos) e `Groups:manage-membership` escopada à subárvore de grupos de relatório;
- `Roles:map-role` escopada às roles do client `relatorios` (vincular role↔grupo);
- `Users:view`/`Users:manage` derivadas de `view-members`/`manage-members` sobre os grupos de relatório — **não** globais.

Justificativa forte: `manage-users` permite **resetar a senha de qualquer usuário do realm, inclusive dos ADMINISTRADORes** (§3.2). Com `manage-users`, uma falha de validação de prefixo na camada de mediação deixa de ser "GERENTE cria role indevida" e vira "comprometimento do realm".

**5. Grupo `PENDENTES` como Default Group.** Resolve de uma vez o estado "pendente de vínculo" (ticket 16), o alcance das permissões FGAP sobre recém-cadastrados (§3.5) e a listagem "quem está esperando" para o GERENTE (§9). Sem ele, permissões escopadas por grupo simplesmente não enxergam quem acabou de se cadastrar.

**6. Autorização: claim como filtro grosso, banco como autoridade.** As roles viajam no token (regra do documento), mas a decisão final de gerar/baixar sai do schema de controle, porque o vínculo relatório↔role já mora lá. Números para fundamentar o ticket 15: janela de revogação = `accessTokenLifespan` = **300 s** por padrão (§4.4); teto de header = **8 KB do Spring Boot**, não o 1 MB do Traefik (§4.2). Critérios de decisão:
- se o teto de roles por usuário ficar **abaixo de ~100**, manter as roles no token e não fazer nada;
- se puder passar disso, trocar por **claim de grupos** + resolução no banco, e só então mexer em limites de header;
- se alguém exigir **revogação imediata** (< 5 min), a única resposta honesta é introspection (opaque token) ou redução agressiva do `accessTokenLifespan` — ambas com custo, e a escolha é do ticket 15.

**7. Spring: escrever o conversor de authorities.** Nenhum conversor pronto lê `realm_access.roles`/`resource_access.*.roles` (claims aninhadas). Prever um `Converter<Jwt, Collection<GrantedAuthority>>` próprio no módulo comum, com prefixo `ROLE_`, composto via `DelegatingJwtGrantedAuthoritiesConverter` se também forem usados scopes (§5).

**8. Exposição do Keycloak.** Combinar as duas abordagens, porque nenhuma sozinha resolve:
- **por realm**: remover `view-groups` e `delete-account` das default roles para enxugar o Account Console às telas de perfil/senha (§6.3);
- **por rota, no Traefik**: bloquear `/admin/**`, porque desabilitar o Admin Console implicaria desabilitar a Admin API de que a mediação depende (§6.3). Isso responde o ticket 17: a análise comportamental está certa quanto às telas do Account Console e **incorreta** quanto ao Admin Console, onde o filtro de rota é a única alternativa.

**9. Logout: RP-initiated, não back-channel.** Implementar `end_session_endpoint` com `id_token_hint` + `post_logout_redirect_uri` registrado. **Não** implementar back-channel logout na API REST: sem `oauth2Login` e sem sessão de servidor não há o que invalidar (§8.3). Escrever explicitamente na spec que o access token sobrevive ao logout até `exp` e que essa janela é a mesma da revogação de permissão — um único parâmetro (`accessTokenLifespan`) governa os dois.

**10. Mailpit.** `smtpServer` no JSON do realm apontando para `mailpit:1025`, sem autenticação e sem TLS; `verifyEmail` e *Forgot password* ligados. Como o Mailpit não tem autenticação, ele fica restrito à rede interna do Compose e **nunca** é publicado pelo Traefik (§7).

**11. Restrição de domínio de e-mail sem código.** Se o ticket 16 decidir por allowlist de domínio, usar o validador `pattern` no atributo `email` do User Profile — vale no registro, no update profile, no Account Console e na Admin API de uma vez só (§6.2).

**12. Auditoria.** A trilha "quem fez o quê" **tem que ser gravada pela aplicação** no schema de controle, com autor, alvo, motivo e Correlation ID. Os admin events do Keycloak vão registrar sempre o mesmo service account e servem apenas como prova secundária (§3.6).
