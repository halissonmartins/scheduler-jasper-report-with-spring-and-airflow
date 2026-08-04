# 26 — `refazer` e `reprocessar`

**O que construir:** os dois verbos de reação do ADMINISTRADOR. Um refaz o que não deu certo e não
destrói nada; o outro refaz o que deu certo e **apaga a Execução anterior**. O ponto central: quem
decide qual é válido é o servidor, consultando o índice — para que ninguém destrua algo achando que
está só refazendo.

**Bloqueado por:** 20, 24.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] `refazer` vale quando o par está livre no índice, não destrói e não exige motivo.
      `reprocessar` vale quando há Execução bem-sucedida ocupando o par, apaga a anterior e **exige
      motivo**.
- [ ] `CO-VERBOS-CRUZADOS` — `refazer` em par ocupado é recusado e `reprocessar` em par livre também.
      Esses testes provam que a API consulta o estado real, e não confia no que a UI mandou.
- [ ] Os dois respondem `202` — a Coleta é assíncrona por natureza, ao contrário da exportação. As
      duas telas não podem parecer a mesma coisa.
- [ ] `reprocessar` **herda a Data de Referência da Execução original**. Sem a herança, reprocessar
      dias depois geraria chave nova, a unicidade nunca dispararia, e o acervo ganharia duas entradas
      para o mesmo fato.
- [ ] `CO-DOWNLOAD-EXECUCAO-NULA` — baixar, reprocessar o par, e a linha de Download continua legível
      com a referência nula. O caminho deixa de ser precaução teórica: o reprocessamento apaga
      Execuções em produção.
- [ ] Os dois restritos a ADMINISTRADOR e auditados, com a autorização na **API** e nunca nas
      permissões do orquestrador — senão existiriam duas fontes de verdade sobre quem pode acionar.
- [ ] Fica registrado que, depois de um reprocessamento, **não sobra forma de verificar o que foi
      substituído**: a auditoria responde quem e por quê, nunca o quê.
