# 18 — Exportação XLSX com a linha de base do exporter

**O que construir:** a planilha sai legível do mesmo print desenhado para PDF. A regra original — de
que bastaria desprezar a paginação quando o formato fosse XLSX — não funciona, porque isso atua no
preenchimento e no momento da exportação já é tarde. Existe caminho no exporter, e é ele que vale.

**Bloqueado por:** 17.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] A exportação usa a linha de base documentada para este caso: não quebrar uma aba por página,
      colapsar espaço vazio entre linhas, e detectar tipo de célula para número e data virarem tipos
      do Excel em vez de texto.
- [ ] A configuração vive no **código da API**, aplicada a toda exportação dos cinco Produtos, e não
      no JRXML. O critério é o que acontece por **omissão**: com a linha de base no JRXML, um
      Relatório novo cujo autor esqueceu produz planilha ruim e ninguém percebe até alguém reclamar.
- [ ] Propriedades no JRXML ficam reservadas para exceção deliberada — o que vira revisão, não
      descuido.
- [ ] Sai de **um** print só. Gravar um segundo, não paginado, foi recusado: o datasource é consumido
      uma vez, e dois preenchimentos exigiriam segunda leitura da origem (reintroduzindo a
      divergência já eliminada por construção) ou materializar linhas em memória.
- [ ] O XLSX continua sendo **visão formatada**, coerente com PDF e DOCX — não vira dado. Gerá-lo a
      partir do CSV seria mais barato e faria perder título, grupos, subtotais e imagens.
