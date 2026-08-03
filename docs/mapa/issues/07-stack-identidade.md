# 07 — Stack: identidade (Keycloak, Admin API, roles no JWT)

Type: research
Status: resolved
Blocked by: —

## Question

Como o Keycloak sustenta o modelo de autorização deste sistema?

Levantar com fontes primárias (use context7) e recomendar:

- **Keycloak**: versão atual, ciclo de suporte, e o estado do import de realm na inicialização do container (o documento exige criar automaticamente um ADMINISTRADOR com senha vinda de variável de ambiente).
- **Admin API**: quais escopos e client roles um service account precisa para criar roles e gerenciar grupos, e como conceder o **mínimo** possível. Isso é a base do ticket 14.
- **Roles no token**: como roles de realm/cliente aparecem no JWT, qual o tamanho típico, e o que acontece com um usuário em muitos grupos — a análise comportamental alerta para estouro de limite de header no Traefik. Levantar limites reais e mitigações (claim mapper seletivo, scope, `include.in.token.scope`).
- **Integração Spring**: `spring-boot-starter-oauth2-resource-server` para a API, e o mapeamento de roles do JWT para `GrantedAuthority`.
- **Tema customizado** para a página de registro e **Account Console**: como habilitar/desabilitar features por realm (relevante para o ticket 17).
- **Mailpit** como SMTP do Keycloak para verificação de e-mail e reset de senha.
- **Back-channel logout**: suporte, configuração e o que a aplicação precisa expor.

Registrar as descobertas em `docs/mapa/research/07-identidade.md`.

## Answer

Fatos levantados em [`../research/07-identidade.md`](../research/07-identidade.md), com fonte primária por afirmação.

- **Keycloak 26.7.0**; a comunidade **não tem LTS** nem backport de segurança — só o produto Red Hat tem ciclo formal (26.x ≥ 2 anos). Fixar a tag da imagem e tratar upgrade como manutenção recorrente.
- **Import de realm é semente, não configuração declarativa**: com `--import-realm`, se o realm já existe a importação é **pulada**. O ADMINISTRADOR do produto sai do `<realm>-realm.json` com placeholder `${VAR}` de ambiente (suportado oficialmente). Isso é distinto do `KC_BOOTSTRAP_ADMIN_*`, que cria conta **temporária no `master`**.
- **Achado de segurança principal (ticket 14)**: `manage-users` permite **resetar a senha de qualquer usuário do realm, inclusive ADMINISTRADORes** — dar isso ao service account de mediação transforma qualquer falha de validação em comprometimento do realm. E o FGAP v2 **não sabe delegar criação de role** (o tipo `Roles` só tem escopos `map-role*`). Saída: role de relatório vira **client role de um client dedicado**, e o service account recebe `Clients:manage` escopada àquele único client + permissões de `Groups`/`Users` escopadas por grupo — nunca `manage-users` nem `manage-realm`.
- Permissão escopada por grupo **não alcança usuário sem grupo**; um **Default Group `PENDENTES`** resolve simultaneamente o estado pendente, o alcance do FGAP e a listagem para o GERENTE (ticket 16).
- **Ticket 15**: janela de revogação default = `accessTokenLifespan` **300 s**. O limite de header que estoura primeiro é o **8 KB do Spring Boot**, não o **1 MB** default do Traefik — a análise comportamental apontou o alvo errado; há folga até ~100 roles. `include.in.token.scope` **não** reduz token.
- **Ticket 17**: back-channel logout no Spring Security exige `oauth2Login` + sessão de servidor + `OidcSessionRegistry`; com SPA + resource server stateless **não há o que invalidar** — usar RP-initiated logout e assumir que o access token vive até `exp`. O Admin Console **não pode** ser desligado por realm (dependeria de desabilitar a Admin API), então filtrar `/admin/**` no Traefik é a única opção; já as telas do Account Console se reduzem removendo `view-groups`/`delete-account` das default roles.
- Spring: **não existe conversor pronto** para `realm_access.roles` (claim aninhada) — é preciso um `Converter<Jwt, Collection<GrantedAuthority>>` próprio.
