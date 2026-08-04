# 07 — Leitura em cursor e o Relatório analítico de alto volume

**O que construir:** o Relatório analítico de Poupança, que é o caso de alto volume. O risco aqui é
específico e silencioso: o driver do PostgreSQL só transmite o resultado sob quatro condições, e
faltando qualquer uma ele **degrada sem avisar** e carrega o `ResultSet` inteiro na memória —
produzindo exatamente o estouro que o virtualizer existe para evitar, sem sintoma até acontecer.

**Bloqueado por:** 05.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O Relatório analítico coleta de verdade, com agrupamento, subtotais e total geral.
- [ ] A leitura satisfaz as quatro condições do driver — autocommit desligado, cursor
      forward-only, statement único e `fetchSize > 0` — ou pagina internamente.
- [ ] `CO-CURSOR-HEAP-APERTADO` — o teste roda com o heap **apertado de propósito** contra um volume
      que o excede se bufferizado. Asserção sobre configuração **não basta**: a degradação é do
      driver, e um teste que verifique `fetchSize` passa com o defeito presente.
- [ ] O volume vem da semente volumétrica, carregada só aqui e no teste de carga — uma semente única
      grande estouraria o gate leve de PR.
- [ ] Os índices que o desempenho pressupõe existem. Sem eles a Coleta vira varredura completa mais
      ordenação em disco, e o tempo estimado deixa de fazer sentido.
- [ ] As bandas do JRXML estão alinhadas numa grade comum — requisito **funcional**, não estético,
      porque a planilha sai deste mesmo print paginado e banda desalinhada vira célula mesclada.
