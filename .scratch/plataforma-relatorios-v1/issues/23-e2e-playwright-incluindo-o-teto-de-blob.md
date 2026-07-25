# 23 — E2E Playwright incluindo o teto de blob

**What to build:** O caminho do Relator validado no navegador de verdade, de ponta a ponta: login no Keycloak, catálogo, escolha de data e formato, download concluído. É o único lugar que prova o risco mais afiado do desenho — que um CSV próximo ao limite realmente completa no navegador, e não apenas no servidor.

**Blocked by:** 15 — Frontend do Relator.

**Status:** ready-for-agent

- [ ] Seam 4 estabelecido: cenário de login no Keycloak, catálogo, seleção de data e download bem-sucedido
- [ ] Download de um CSV próximo ao limite vigente completa no navegador e o arquivo resultante é íntegro
- [ ] Recusa por limite aparece ao usuário como mensagem compreensível
- [ ] Relator sem Role de Relatório vê catálogo vazio e não consegue gerar
- [ ] Cenários etiquetados para rodar em etapa própria de CI, não a cada push
