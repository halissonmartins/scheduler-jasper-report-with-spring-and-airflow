# 09 — Telemetria e métricas da Coleta

**O que construir:** a Coleta passa a ser observável. O contexto de trace injetado pelo orquestrador
vira o span raiz do job, os logs carregam o mesmo identificador que o usuário vê numa tela de erro,
e o catálogo de métricas da Coleta começa a emitir.

**Bloqueado por:** 05.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O contexto de trace recebido do orquestrador vira o span raiz do job — por código do Starter,
      porque o orquestrador não propaga contexto para processos externos e a JVM não lê a variável
      de ambiente sozinha.
- [ ] Sem contexto recebido, o Starter **abre span novo e segue**: telemetria não é dependência dura
      da Coleta.
- [ ] O Correlation ID nasce no container e é gravado ao encerrar a Execução. A linha aberta antes
      dele fica com o identificador nulo — contido pelo id da execução do orquestrador, também
      gravado.
- [ ] As métricas da Coleta emitem: duração, custo de partida, contagem por status com a origem do
      encerramento, tentativas, linhas processadas, tamanho de artefato e encerramento perdido.
- [ ] A duração medida é `fim − inicio_processamento`, **a mesma janela do limiar de `ALERTA`** —
      medir por outra faria painel e tabela discordarem.
- [ ] Nenhum label fora da lista de permitidos. A regra é: um label só vale se seu conjunto de
      valores for limitado **por cadastro**, nunca por uso.
