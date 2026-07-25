# 05 — Idempotência: runId e troca de ponteiro

**What to build:** Repetir uma Coleta deixa de ser perigoso. Cada linha carrega o runId que a escreveu, e só ao concluir com sucesso a execução passa a ser a corrente. Uma execução que falha no meio é invisível para quem está baixando relatório.

**Blocked by:** 04 — Coleta ponta a ponta de POUPANCA.

**Status:** ready-for-agent

- [ ] Toda linha gravada carrega o runId da Execução de Coleta que a escreveu
- [ ] Ao concluir com sucesso, a execução passa a ser a corrente para (Data de Referência, Produto, Código), de forma atômica
- [ ] Repetir a Coleta da mesma Data de Referência não duplica dados nem gera linhas misturadas de execuções diferentes
- [ ] Execução que falha no meio não altera a execução corrente: o que estava publicado continua íntegro e completo
- [ ] Linhas de execuções superadas permanecem até serem recolhidas pela retenção, sem rotina própria (ADR-0006)
- [ ] Cenários de repetição e de falha no meio cobertos pelo seam 2
