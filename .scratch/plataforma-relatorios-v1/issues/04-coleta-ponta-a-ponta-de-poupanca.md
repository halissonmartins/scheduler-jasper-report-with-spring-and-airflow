# 04 — Coleta ponta a ponta de POUPANCA

**What to build:** A primeira Coleta real: o job lê o banco de origem de POUPANCA e grava as linhas do Relatório no MongoDB, registrando a Execução de Coleta. Nasce aqui o starter espesso e, com ele, a prova de que um módulo de Produto contribui apenas DataSource, consulta e mapeamento de linha.

**Blocked by:** 03 — Cadastro de Relatório com Código validado.

**Status:** ready-for-agent

- [ ] O job lê o sistema de origem por JDBC, em conexão somente leitura, e escreve em lote no MongoDB
- [ ] Cada documento carrega os campos de controle (Data de Referência, produto, Código, sequência, timestamp) e os dados do Relatório em subdocumento sem esquema fixo (ADR-0002)
- [ ] Índice composto de leitura ordenada existe e é usado
- [ ] A Execução de Coleta é registrada no PostgreSQL com desfecho de sucesso ou erro
- [ ] O módulo do Produto contribui somente DataSource, consulta e mapeamento — não tem acesso à mecânica interna do starter (ADR-0011)
- [ ] O starter publica o artefato de fixtures com os passos Cucumber reutilizáveis
- [ ] Seam 2 estabelecido: cenários semeiam um banco de origem em Testcontainer, executam a Coleta e verificam as linhas gravadas
