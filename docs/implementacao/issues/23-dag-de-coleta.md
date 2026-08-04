# 23 — DAG de Coleta de um Relatório

**O que construir:** a Coleta passa a rodar sozinha, agendada. A DAG abre a Execução **antes** de
subir o container — assim toda tentativa existe na fonte da verdade, inclusive a que nem chega a
subir, e a duplicata é rejeitada sem gastar container.

**Bloqueado por:** 05, 20.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] A DAG tem duas tasks: abrir a Execução (sem retry) e rodar o container (com duas retentativas).
      Retry na primeira criaria linhas duplicadas e bateria no índice.
- [ ] O callback de falha é **obrigatório**, e agora é o caminho **principal** de encerramento em
      falha, não a exceção — o container não grava mais `ERRO`. Uma DAG gerada sem ele deixa a
      Execução aberta até a varredura, seis horas depois.
- [ ] `CO-RETRY-REUSA-LINHA` — três tentativas, **uma** linha, um único `ERRO` no fim. As tasks são
      separadas e o orquestrador retenta só a segunda: a linha é reusada, e o callback fecha uma vez
      ao esgotarem as tentativas.
- [ ] `CO-CONTAINER-NAO-GRAVA-ERRO` — cenário negativo: o container que falha deixa a linha aberta.
      Se alguém "corrigir" isso fazendo o container gravar, o retry para de funcionar e o sintoma é
      sutil.
- [ ] `CO-EXIT-CODE-JOB-FALHO` (ponta a ponta) — o orquestrador enxerga o código diferente de zero e
      retenta, em vez de marcar sucesso.
- [ ] `CO-FUSO-DATA-REFERENCIA` — uma execução lógica às 22:00 no horário local produz a Data de
      Referência do dia **anterior** ao que o template cru devolveria. Isto é para **verificar em
      teste**, não para confiar na leitura da documentação.
- [ ] A Data de Referência entra como **parâmetro explícito tipado**, nunca derivada da data lógica.
      É o que torna o projeto imune à mudança de timetable padrão do orquestrador.
- [ ] Os três degraus de timeout estão na ordem: timeout interno do container < timeout da task <
      limite de órfã.
- [ ] Credenciais entram por variáveis privadas, fora do log da task e da UI.
