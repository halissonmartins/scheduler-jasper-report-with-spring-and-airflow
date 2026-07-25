# 06 — Metadados, Status de Processamento e alerta por Tempo Estimado

**What to build:** A Operação passa a ver o que rodou. Cada Execução de Coleta registra início, fim, duração, contagem de linhas e Status de Processamento — e quando passa do Tempo Estimado de Execução do Relatório, vira processado com alerta. Consultável por API.

**Blocked by:** 04 — Coleta ponta a ponta de POUPANCA.

**Status:** ready-for-agent

- [ ] Execução de Coleta registra início, fim, duração e contagem de linhas coletadas
- [ ] Status percorre em processamento → processado com sucesso, processado com erro ou processado com alerta
- [ ] Execução que ultrapassa o Tempo Estimado de Execução cadastrado termina como processado com alerta (ADR-0004 mantém esse limiar exclusivo da Coleta)
- [ ] Falha na origem ou na escrita termina como processado com erro, com a causa registrada
- [ ] API permite à Operação consultar Execuções por Relatório, Data de Referência e status
- [ ] Retentativa gera nova Execução de Coleta, sem sobrescrever o histórico da anterior
- [ ] Cenários de sucesso, erro e alerta cobertos pelo seam 2
