# 11 — Produto Conta Corrente: os dois Relatórios coletando

**O que construir:** o **maior Produto do sistema**, e o que dimensiona o heap da API. O analítico é resumo por conta, não detalhe por lançamento — a diretriz que sai daqui é que "todo lançamento de todas as contas" é extração de dados, não relatório, e é a contenção mais barata do risco de exportação sem teto, porque atua antes de qualquer limite.

Ao fim deste ticket os dois Relatórios de Conta Corrente coletam de verdade, produzindo artefato e metadado
como o primeiro Produto já faz.

**Bloqueado por:** 07.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Os dois Relatórios de Conta Corrente — um analítico e um sintético denso — coletam ponta a ponta, com
      consulta, rótulos e tempo estimado sugerido reais.
- [ ] O schema transacional é **autossuficiente**: nenhuma junção com outro Produto, porque a
      credencial deste módulo não alcança outro schema. Dado que exista noutro Produto entra
      denormalizado, e essa duplicação é **preço do isolamento, não erro de modelagem**.
- [ ] As bandas dos dois JRXML estão alinhadas numa grade comum, para a planilha sair legível do
      mesmo print paginado.
- [ ] A semente tem dois perfis: funcional em todo teste de integração, volumétrica só no teste de
      cursor e no de carga. Ambas determinísticas e geradas no servidor, com as datas flutuando —
      datas fixas envelheceriam para fora de qualquer janela de retenção.
- [ ] Os índices que o desempenho pressupõe existem, e o tempo estimado cabe folgado sob a guarda do
      cadastro.
- [ ] O cron do Produto é `0 5 * * *`, seguindo o escalonamento de uma hora por Produto — dez Coletas
      partindo juntas só formariam fila e fariam a métrica de partida disparar sem que nada
      estivesse errado.
- [ ] **A prova da substituição de fonte não se repete aqui** — ela vive no Relatório sintético de
      Poupança e guarda o empacotamento, não o comportamento do Jasper.
