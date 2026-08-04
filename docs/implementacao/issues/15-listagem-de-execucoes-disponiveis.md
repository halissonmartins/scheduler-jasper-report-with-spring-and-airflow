# 15 — Listagem de Execuções disponíveis

**O que construir:** a primeira tela útil do sistema, vista pela API. O relator pede o que está
disponível e recebe **só** o que ele pode ver, com os estados que distinguem um item baixável de um
que ficou lento, de um sem dados e de um expirado. Listagem e geração passam a sair da mesma fonte
de autorização, então nunca discordam.

**Bloqueado por:** 02, 14.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] A autorização sai **só da claim**, sem I/O: as Roles vêm do token e o resto é uma consulta
      local. Nenhuma chamada ao provedor de identidade no caminho quente.
- [ ] Uma listagem filtrável só, não três endpoints em cascata — o conjunto inteiro cabe numa
      resposta, e o drop-down troca de nível sem ir à rede.
- [ ] Filtros por Data de Referência, Produto e Código.
- [ ] Os campos derivados que distinguem os estados vêm na resposta: tem dados, expirado e a data
      prevista de expurgo. Sem os três, disponível, sem dados e expirado ficam parecidos.
- [ ] A regra de desempate está aplicada: um par pode ter várias linhas, e a listagem mostra a que
      **ocupa o índice**; na ausência dela, a mais recente sem dados. Sem isso o mesmo Relatório
      aparece duas vezes na mesma data.
- [ ] `CO-BYPASS-ADMINISTRADOR` (alcance) — o ADMINISTRADOR alcança todos os Relatórios sem Role
      alguma. Passar pela mesma cadeia inverteria a hierarquia: quem decide o que ele enxerga
      passaria a ser quem está abaixo dele.
- [ ] **Lista vazia é estado, não erro** — nunca modelada como 403. Quatro situações distintas
      produzem lista vazia, e a saída é a mesma **por decisão**.
