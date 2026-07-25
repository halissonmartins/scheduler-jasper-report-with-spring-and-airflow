# 01 — Realm do Keycloak e autenticação da API

**What to build:** O ambiente sobe com um comando e a API autentica. Um usuário obtém token no Keycloak, chama um endpoint protegido e recebe sua identidade e tipo de usuário; sem token é recusado, e com o tipo errado também. Traz consigo a fundação mínima que todos os tickets seguintes assumem: agregador Maven, módulo `common` com os tipos de domínio e suas validações, esquema inicial do PostgreSQL e o realm versionado com o script de convergência.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Compose sobe PostgreSQL, MongoDB, Keycloak e a API; o realm é importado no primeiro boot
- [ ] Realm versionado em JSON cria os clients (frontend público com Authorization Code + PKCE, `api` como bearer-only) e as realm roles ADMINISTRADOR, GERENTE e RELATOR
- [ ] Script `kcadm` idempotente aplica alterações de realm em execuções seguintes, sem depender de realm inexistente (ADR-0014)
- [ ] ADMINISTRADOR inicial criado com senha vinda de variável de ambiente, conforme ADR-0014
- [ ] Endpoint protegido devolve identidade e tipo de usuário; ausência de token resulta em 401 e role insuficiente em 403
- [ ] Account Console habilitado: qualquer tipo de usuário troca a própria senha sem tela própria
- [ ] `common` expõe CodigoRelatorio, DataReferencia, StatusProcessamento, JanelaAgendamento e FormatoExportacao, com a validação encapsulada no próprio tipo
- [ ] Seam 1 estabelecido: cenários Cucumber em português contra a API, com PostgreSQL e Keycloak em Testcontainers
