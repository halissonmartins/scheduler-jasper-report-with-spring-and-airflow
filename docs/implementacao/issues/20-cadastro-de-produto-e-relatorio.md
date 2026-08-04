# 20 — Cadastro de Produto e Relatório

**O que construir:** o ADMINISTRADOR passa a poder cadastrar. É aqui que duas guardas entram, e as
duas existem para impedir falhas que só apareceriam depois, longe da causa: um Relatório sem código
por trás rodaria todo dia condenado a falhar, e um tempo estimado alto demais faria a varredura
fechar uma Coleta viva.

**Bloqueado por:** 04, 15.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Cadastro de Produto com **Sigla própria e imutável**, única, validada por formato — nunca
      derivada do Nome. O Nome é rótulo livremente alterável, o que torna renomear seguro.
- [ ] O Produto carrega o cron da Coleta, com validação de sintaxe e guarda de granularidade mínima
      — senão um cron absurdo sobe container a cada minuto.
- [ ] `CO-CADASTRO-FORA-DO-INVENTARIO` — cadastrar um Código ausente do inventário é recusado. É o
      que torna Relatório fantasma impossível.
- [ ] A tela oferece o tempo estimado **sugerido** pelo Relatório, pré-preenchido, resolvendo o caso
      do Relatório recém-criado que não tem histórico nem palpite. A verdade fica no cadastro, porque
      depende do volume daquele ambiente e muda sem que o código mude.
- [ ] `CO-GUARDA-TEMPO-ESTIMADO` — a guarda conta as tentativas e recusa acima do teto derivado do
      limite de órfã. É **validação de aplicação, não constraint**: o limite é variável de ambiente e
      uma constraint não enxerga configuração. Sem ela a varredura fecha Execução viva.
- [ ] O inventário publicado é consultável, mostrando os dois descompassos — publicado e não
      cadastrado, cadastrado e não publicado —, senão ninguém tem como diagnosticar por que um
      Relatório não roda.
- [ ] A sequência de quatro dígitos do Código é única **por Produto**.
