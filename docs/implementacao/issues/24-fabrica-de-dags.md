# 24 — Fábrica de DAGs

**O que construir:** cadastrar um Produto novo passa a ser inserir uma linha, não editar o
orquestrador. A fábrica lê o snapshot local e gera uma DAG por Relatório, calculando os timeouts a
partir do cadastro.

**Bloqueado por:** 22, 23.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Uma DAG por Relatório, com tag do Produto — o que recupera na UI o agrupamento que uma DAG por
      Produto daria de graça, sem exigir seletor e tasks puladas no disparo manual.
- [ ] A fábrica **abre um arquivo local**, sem rede. `CO-FABRICA-SEM-REDE-NO-PARSE` — regressão
      barata de introduzir e cara de descobrir, porque o sintoma é DAG sumindo sem causa visível.
- [ ] `CO-SNAPSHOT-AUSENTE-EXCECAO` — snapshot ausente ou corrompido **levanta exceção**, nunca gera
      zero DAGs. Um teste que só verifique "nenhuma DAG inválida foi gerada" passa nos dois casos: o
      assert tem de ser no erro de import. Zero DAGs é indistinguível de "nenhum Relatório
      cadastrado" e passa por normal.
- [ ] `CO-FORA-DA-INTERSECAO-SEM-DAG` — nem o cadastrado sem código por trás, nem o publicado sem
      cadastro geram DAG.
- [ ] Os timeouts e o número de tentativas são **calculados** do snapshot; a fábrica não decide nada
      disso. Mudar o tempo estimado muda a DAG **sem deploy**.
- [ ] Agendamento com fuso explícito e data inicial ciente de fuso, sem catch-up — declarado na DAG
      mesmo já sendo padrão de configuração, porque padrão de configuração alguém vira globalmente.
- [ ] Concorrência por **pool dedicado** aos containers. Limite por DAG não compõe, e o paralelismo
      global contaria tasks que não sobem container.
- [ ] O pool de conexões do processador é fixado em dois — o padrão da biblioteca mantém o mínimo
      igual ao máximo, então um container **ocioso** seguraria dez conexões.
- [ ] DAG cuja definição saiu do snapshot **deixa de existir**, não fica órfã.
