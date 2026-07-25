# 19 — Processador do Produto CONTACORRENTE

**What to build:** A Coleta dos Relatórios de CONTACORRENTE passa a funcionar, reusando o starter. Se o ADR-0011 cumpriu sua promessa, este ticket é pequeno: DataSource do sistema de origem de CONTACORRENTE, a consulta que produz as linhas e o mapeamento de linha — nada de mecânica de execução ou ponteiro.

**Blocked by:** 05 — Idempotência: runId e troca de ponteiro; 06 — Metadados, Status de Processamento e alerta por Tempo Estimado.

**Status:** ready-for-agent

- [ ] Módulo do Produto CONTACORRENTE contribui apenas DataSource somente leitura, consulta e mapeamento de linha
- [ ] Coleta grava as linhas com os campos de controle e o subdocumento de dados próprio dos Relatórios de CONTACORRENTE
- [ ] runId, troca de ponteiro, metadados e Status de Processamento funcionam sem uma linha de código específica deste módulo
- [ ] Cenários Cucumber do Produto CONTACORRENTE escritos sobre os passos reutilizáveis do starter, sem andaime próprio
- [ ] Qualquer necessidade que force alteração no starter é registrada — é sinal de que a abstração do ADR-0011 está incompleta
