# 06 — Os desfechos não-felizes da Coleta

**O que construir:** o que acontece quando a Coleta não termina bem. Fecha a máquina de estados do
lado do container: origem vazia encerra sem gravar nada, o container se mata antes de o orquestrador
matá-lo, e a saída do processo diz ao Airflow o que houve. Sem isso, uma Coleta que falha parece
verde.

**Bloqueado por:** 05.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] `CO-SEM-DADOS-NADA-GRAVADO` — zero linhas é detectado **antes** do fill e encerra sem
      **nenhum** objeto escrito no repositório. Testar que nada foi gravado, não só que o status
      está certo. É o que evita de saída o print de zero páginas.
- [ ] O container grava apenas `SUCESSO`, `ALERTA` e `SEM_DADOS`. **Nunca `ERRO`** — ele sai com
      código diferente de zero e deixa a linha aberta.
- [ ] `CO-DURACAO-INICIO-PROCESSAMENTO` — com tempo estimado curto e partida artificialmente lenta,
      o desfecho é `SUCESSO`, não `ALERTA`. A duração avaliada é `fim − inicio_processamento`;
      medida pelo `inicio`, a partida da JVM comeria a margem e todo Relatório curto alertaria.
- [ ] O limiar de `ALERTA` é **fixo** em +20% sobre o cadastrado, e o timeout duro interno é o dobro
      — o container se mata antes do orquestrador, para sair limpo e com log completo.
- [ ] `CO-EXIT-CODE-JOB-FALHO` — um job que falha sai com código diferente de zero. Sem isso o
      orquestrador marca sucesso num job falho, que é o pior modo de falha possível porque tudo
      parece verde.
- [ ] `CO-ARTEFATO-PARCIAL` — interromper a Coleta durante a escrita não registra `artefato` algum e
      não deixa a Execução em `SUCESSO`. O objeto órfão fica sem metadado, invisível ao sistema, e é
      recolhido pela retenção — não há limpeza possível, porque nenhuma credencial apaga objeto.
