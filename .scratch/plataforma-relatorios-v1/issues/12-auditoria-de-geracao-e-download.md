# 12 — Auditoria de geração e download

**What to build:** Toda geração passa a deixar rastro: quem pediu, qual Relatório, qual Data de Referência, qual formato, quantas linhas, quanto tempo levou e qual foi o desfecho — inclusive quando o pedido foi recusado por falta de permissão. O registro sobrevive muito além dos 7 dias dos dados.

**Blocked by:** 10 — Geração síncrona em CSV com contagem prévia.

**Status:** ready-for-agent

- [ ] Cada geração registra usuário, Código do Relatório, Data de Referência, Formato de Exportação, contagem de linhas, início, fim e desfecho
- [ ] Tentativas recusadas por permissão e por limite também são registradas, com o desfecho correspondente
- [ ] Os registros não são apagados junto com os dados coletados
- [ ] API permite consultar a auditoria por usuário, Relatório e período
- [ ] Cenários Cucumber cobrindo download bem-sucedido, recusa por permissão e recusa por limite, todos verificados na trilha
