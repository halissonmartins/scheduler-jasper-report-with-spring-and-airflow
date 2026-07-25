# Autorização híbrida: Role de Relatório no Keycloak, mapeamento no PostgreSQL

A Role de Relatório é uma role real do Keycloak e viaja no JWT; o mapeamento role → Relatórios é dado de Cadastro no PostgreSQL. A atribuição usuário → role é feita no Keycloak via Admin API.

A Role de Relatório é um agrupamento com N:N nos dois lados (um Gerente vincula Relatórios *e* Relatores a ela), então cada usuário carrega poucas roles e o token permanece pequeno. Uma role por Relatório produziria centenas de roles e JWTs perto do limite de ~8 KB de header.

## Consequências

- Mudanças no mapeamento role → Relatórios valem na hora, sem esperar renovação de token.
- A API depende da Admin API do Keycloak para enumerar usuários nas telas do Gerente; não há espelho de usuários no PostgreSQL para divergir.
