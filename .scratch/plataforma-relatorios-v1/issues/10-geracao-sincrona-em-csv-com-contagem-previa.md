# 10 — Geração síncrona em CSV com contagem prévia

**What to build:** O Relator finalmente baixa um relatório. Escolhe Relatório e Data de Referência, e recebe o CSV na própria resposta. Se o volume passar do limite, a recusa vem na hora — antes de qualquer trabalho — dizendo o limite e quantas linhas foram encontradas.

**Blocked by:** 09 — Vínculo de Role a Relator, catálogo filtrado e exclusão de Relator.

**Status:** ready-for-agent

- [ ] Relator gera e baixa CSV de um Relatório e Data de Referência a que tem acesso, em resposta síncrona transmitida em streaming (ADR-0004)
- [ ] A geração lê apenas as linhas da execução corrente, na ordem determinística do índice composto
- [ ] Contagem prévia pelo índice recusa de imediato, com 4xx explícito, o pedido acima do limite do formato, informando limite e contagem
- [ ] Limite de CSV é constante versionada no código, valor inicial de 500.000 linhas (ADR-0004)
- [ ] Tentativa de gerar Relatório sem Role de Relatório correspondente resulta em 403
- [ ] Nome do arquivo contém Código do Relatório, Data de Referência e formato
- [ ] CSV é produzido em streaming a partir do cursor, sem materializar o conteúdo em memória e **sem passar pelo Jasper** (ADR-0021) — a primeira linha é o cabeçalho de colunas
- [ ] Teste que falharia se a escrita deixasse de ser incremental, para que um `toList()` acidental não reintroduza o OOM em silêncio
- [ ] Cenários Cucumber cobrindo geração bem-sucedida, recusa por limite, recusa por permissão e data inexistente
