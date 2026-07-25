# 17 — DAGs dinâmicas com Janelas de Agendamento e fallback de cache

**What to build:** A Coleta passa a acontecer sozinha. O Airflow gera DAGs a partir do Cadastro, uma por Produto e Janela de Agendamento, e dispara o processador de cada Produto. Cadastrar um novo Relatório de Produto existente passa a não exigir deploy — e uma instabilidade do PostgreSQL não faz as DAGs desaparecerem.

**Blocked by:** 04 — Coleta ponta a ponta de POUPANCA.

**Status:** ready-for-agent

- [ ] DAGs geradas dinamicamente do Cadastro, uma por (Produto × Janela de Agendamento), disparando o processador em container (ADR-0007)
- [ ] Cadastrar novo Relatório de Produto existente passa a ser coletado sem qualquer deploy
- [ ] Falha ou indisponibilidade do PostgreSQL faz o parse usar a última lista válida em cache, mantendo as DAGs presentes em vez de fazê-las desaparecer
- [ ] Intervalo de reprocessamento de arquivos e timeout de conexão configurados para que o parse não trave o scheduler
- [ ] Interface do Airflow acessível somente pela rede interna, sem regra de exposição pública (ADR-0009)
- [ ] Seam 3 estabelecido: testes em Python sobre a geração de DAGs, incluindo explicitamente o caminho de fallback do cache
