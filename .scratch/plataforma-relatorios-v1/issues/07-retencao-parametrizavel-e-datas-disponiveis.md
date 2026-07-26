# 07 — Retenção parametrizável e Datas de Referência disponíveis

**What to build:** Os dados coletados desaparecem sozinhos ao fim da janela de retenção, e a API passa a responder quais Datas de Referência realmente existem para um Relatório — para que ninguém peça geração do que não há.

**Blocked by:** 05 — Idempotência: runId e troca de ponteiro.

**Status:** ready-for-agent

- [ ] Índice TTL apaga automaticamente as linhas ao fim da janela de retenção, cujo valor vem de configuração e não de literal (ADR-0008, ADR-0018)
- [ ] API devolve as Datas de Referência disponíveis de um Relatório, considerando apenas execuções correntes
- [ ] A quantidade máxima de datas oferecidas deriva da janela de retenção; datas sem publicação corrente não aparecem
- [ ] Cenários cobrindo data com publicação, data sem publicação e data expirada, pelos seams 1 e 2
- [ ] Cenário com janela diferente do padrão, provando que o limite de datas acompanha o parâmetro
