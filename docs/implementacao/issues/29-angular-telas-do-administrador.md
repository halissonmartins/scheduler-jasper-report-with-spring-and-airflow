# 29 — Angular: telas do ADMINISTRADOR

**O que construir:** cadastro, diagnóstico e reação. É onde o ADMINISTRADOR descobre por que um
Relatório não roda e onde ele age sobre uma Coleta que não deu certo.

**Bloqueado por:** 20, 26, 27.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Cadastro de Produto, com a Sigla **imutável** e apresentada como tal, e o cron da Coleta.
- [ ] Cadastro de Relatório, com o Código validado contra o inventário e o tempo estimado
      pré-preenchido pela sugestão.
- [ ] Inventário publicado, mostrando os dois descompassos — é a tela de diagnóstico de "por que este
      Relatório não roda".
- [ ] Histórico de Execuções com **`refazer` e `reprocessar` como dois botões distintos**, e o
      servidor decidindo qual vale. As duas ações não podem parecer a mesma coisa: uma destrói.
- [ ] O motivo é exigido na tela quando a ação é destrutiva, e a consequência é dita antes do
      clique.
- [ ] Histórico de Download, legível mesmo quando aponta para coisas que não existem mais.
- [ ] Auditoria administrativa, incluindo as **recusas**.
- [ ] Gestão de usuários GERENTE e ADMINISTRADOR.
- [ ] As duas assincronias ficam visualmente distintas: a exportação devolve bytes na hora, o disparo
      de Coleta devolve um aceite.
