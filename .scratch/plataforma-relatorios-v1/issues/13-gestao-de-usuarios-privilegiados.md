# 13 — Gestão de usuários privilegiados

**What to build:** O ADMINISTRADOR passa a distribuir a administração: cadastra e remove usuários ADMINISTRADOR e GERENTE. E o sistema garante, no servidor, que um GERENTE nunca cria outro GERENTE — a escalada de privilégio depende do ADMINISTRADOR.

**Blocked by:** 01 — Realm do Keycloak e autenticação da API.

**Status:** ready-for-agent

- [ ] ADMINISTRADOR cadastra usuário com tipo ADMINISTRADOR ou GERENTE
- [ ] ADMINISTRADOR remove usuário ADMINISTRADOR ou GERENTE
- [ ] GERENTE recebe 403 ao tentar criar ou alterar usuário ADMINISTRADOR ou GERENTE, com a regra imposta no servidor e não apenas na interface
- [ ] RELATOR recebe 403 em todas as operações de gestão de usuários
- [ ] As operações usam a Admin API do Keycloak, sem espelho de usuários no PostgreSQL (ADR-0005)
- [ ] Cenários Cucumber cobrindo cada permissão e cada recusa
