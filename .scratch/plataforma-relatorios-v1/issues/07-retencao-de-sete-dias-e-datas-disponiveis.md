# 07 — Retenção de 7 dias e Datas de Referência disponíveis

**What to build:** Os dados coletados desaparecem sozinhos após 7 dias, e a API passa a responder quais Datas de Referência realmente existem para um Relatório — para que ninguém peça geração do que não há.

**Blocked by:** 05 — Idempotência: runId e troca de ponteiro.

**Status:** ready-for-agent

- [ ] Índice de retenção apaga automaticamente as linhas 7 dias após a gravação (ADR-0008)
- [ ] API devolve as Datas de Referência disponíveis de um Relatório, considerando apenas execuções correntes
- [ ] Nunca são oferecidas mais de sete datas, e datas sem publicação corrente não aparecem
- [ ] Cenários cobrindo data com publicação, data sem publicação e data expirada, pelos seams 1 e 2
