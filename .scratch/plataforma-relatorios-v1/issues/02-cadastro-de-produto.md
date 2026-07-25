# 02 — Cadastro de Produto

**What to build:** O ADMINISTRADOR cadastra, lista e remove Produtos pela API. Quem não é ADMINISTRADOR não consegue nem listar alterações nem alterar nada.

**Blocked by:** 01 — Realm do Keycloak e autenticação da API.

**Status:** ready-for-agent

- [ ] ADMINISTRADOR cadastra Produto com sigla, nome e descrição
- [ ] Sigla é única e limitada a 20 caracteres maiúsculos, sem hífen (o hífen é separador do Código do Relatório)
- [ ] ADMINISTRADOR lista e remove Produto
- [ ] GERENTE e RELATOR recebem 403 em todas as operações de Produto
- [ ] Cenários Cucumber cobrindo cada regra acima pelo seam 1
