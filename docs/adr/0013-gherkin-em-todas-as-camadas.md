# Gherkin em todas as camadas, inclusive na Coleta

Cenários Cucumber cobrem a API REST e também os jobs de Coleta, executando contra PostgreSQL, MongoDB e Keycloak reais via Testcontainers. TDD com JUnit cobre o interior dos módulos.

Registrado porque o esperado seria restringir Gherkin à fronteira da API: cenários de batch em linguagem de negócio são verbosos e as mecânicas de execução e ponteiro são desconfortáveis de expressar assim. Aceitamos o custo em favor da rastreabilidade completa entre as regras da descrição inicial e o comportamento do sistema.

## Consequências

- Os cenários de batch são etiquetados e rodam em uma etapa própria de CI, para não pesar em cada push.
- Os passos reutilizáveis vivem no artefato `test-fixtures` do starter (ADR-0011).
