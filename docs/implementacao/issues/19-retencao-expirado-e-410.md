# 19 — Retenção: marcação de expirado e `410`

**O que construir:** os Artefatos somem em sete dias e o histórico fica. O usuário precisa saber
disso antes de clicar, sem que a promessa seja rígida demais — porque o expurgo é assíncrono e o que
está marcado como expirado muitas vezes ainda baixa.

**Bloqueado por:** 16.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] A retenção é **global**, por variável de ambiente com padrão de sete dias, numa regra de
      lifecycle nativo com **filtro vazio** sobre o bucket inteiro. Nenhuma credencial apaga objeto.
- [ ] `CO-XAMZ-EXPIRATION` — a data prevista vem do header do servidor quando ele o emite, com
      fallback para o cálculo local. O teste cobre os dois caminhos e revela qual está em uso.
- [ ] `CO-EXPIRADO-QUE-BAIXA` — item marcado como expirado **baixa com sucesso** quando o objeto
      ainda está lá. Testar exatamente isso é o que impede alguém "alinhar" listagem e exportação
      depois, achando que é bug.
- [ ] `CO-410-OBJETO-AUSENTE` — `410` só quando o objeto realmente sumiu, com a **data real** do
      expurgo na resposta. A UI nunca promete "sete dias" ao pé da letra: o arredondamento é em UTC e
      a Data de Referência é local.
- [ ] A listagem **não** antecipa por formato. Cada formato responde pelo que existe no instante do
      pedido — o que dissolve a não-atomicidade entre os dois Artefatos em vez de modelá-la.
- [ ] `CO-LIFECYCLE-ORFAO` — objeto sem linha de metadado é alcançado pela regra. É a única limpeza
      que existe.
- [ ] `CO-DEGRADACAO-MINIO` — com o repositório fora, o readiness segue UP, a listagem funciona, e só
      a exportação falha, com código do catálogo e Correlation ID.
- [ ] A distinção entre "houve arquivo e não há mais" e "nunca houve arquivo" é nítida na UI.
      Confundi-las faz o relator procurar por um relatório que nunca existiu.
