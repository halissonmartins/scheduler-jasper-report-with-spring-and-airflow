# 28 — Retenção parametrizável com teto e reconciliação

**What to build:** O contrato dos três parâmetros de retenção (ADR-0018): validação do teto na subida, reconciliação do índice TTL já existente e a entrada de runbook. A *leitura* do parâmetro nos pontos de uso pertence aos tickets 07, 15 e 27; este ticket é dono do parâmetro em si.

**Blocked by:** 07 — Retenção parametrizável e Datas de Referência disponíveis; 27 — Logs estruturados e tracing distribuído.

**Status:** ready-for-agent

- [ ] Três parâmetros independentes: retenção de dados coletados (padrão 7 dias), de traces e de logs (padrão 14 dias)
- [ ] Retenção de dados acima de 30 dias faz a aplicação recusar iniciar, com mensagem apontando o ADR-0018 e o ADR-0016
- [ ] Valor ausente, zero ou negativo também recusa a subida — sem cair em padrão silencioso
- [ ] Reconciliação por `collMod` na subida: alterar o parâmetro em um ambiente que **já tem** o índice TTL criado muda a expiração de fato
- [ ] Cenário que prova a reconciliação: sobe com 7, reinicia com 14, e o índice existente passa a expirar em 14 — é o caso em que um parâmetro ingênuo mentiria
- [ ] `.env` de exemplo e runbook documentam os três parâmetros, seus padrões, o teto e por que o teto existe (ADR-0016)
- [ ] Nenhum literal `7` remanescente governando retenção ou contagem de datas em código ou configuração
