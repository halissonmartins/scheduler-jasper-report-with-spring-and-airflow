# 22 — Snapshot do agendamento para a fábrica de DAGs

**O que construir:** a API materializa num arquivo o que o orquestrador precisa saber — quais
Relatórios rodam, quando, e com que tempo estimado. Existe para que a fábrica de DAGs **nunca**
consulte a API durante o parse: uma chamada de rede ali é nomeada pelo próprio orquestrador como
causa de falha do processador de DAGs, e passado o timeout **as DAGs somem** sem causa visível.

**Bloqueado por:** 20.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O snapshot traz a **interseção cadastro ∩ inventário já resolvida**, com o cron do Produto e o
      tempo estimado de cada Relatório. A regra mora na API; a fábrica não a reimplementa.
- [ ] A API reescreve o arquivo a cada mudança de cadastro, e o processador de DAGs o pega no ciclo
      de parse seguinte.
- [ ] A API continua sendo a única leitora do schema de controle — a fábrica **não** lê o banco.
      Ler direto furaria a fronteira de ownership e duplicaria a regra da interseção em outra
      linguagem, com as duas divergindo.
- [ ] Fica documentado que um Relatório cadastrado durante o dia **aparece em minutos e roda
      amanhã**: sem catch-up, o primeiro disparo é a próxima ocorrência do cron.
