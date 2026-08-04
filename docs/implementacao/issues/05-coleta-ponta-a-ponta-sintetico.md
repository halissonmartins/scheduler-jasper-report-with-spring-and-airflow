# 05 — Coleta ponta a ponta de um Relatório sintético

**O que construir:** a primeira Coleta que funciona de verdade. O Relatório sintético de Poupança
lê o schema transacional do seu Produto, produz o `.jrprint` e o `.csv.gz`, sobe os dois ao
repositório e fecha a Execução com o desfecho certo. Ao fim deste ticket dá para semear um schema,
rodar a Coleta e olhar o artefato e a linha de metadados.

**Bloqueado por:** 01, 02.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O job é **um step tasklet**, numa passada só. O fill do Jasper é *pull* e o chunk do Spring
      Batch é *push*: os dois não compõem, e encher uma coleção para depois passá-la ao Jasper anula
      o propósito do chunk.
- [ ] O CSV deriva do **mesmo** datasource que o Jasper consome, escrito linha a linha conforme ele
      puxa.
- [ ] `CO-CSV-MESMAS-LINHAS` — a contagem de linhas do `.csv.gz` é igual à do print. É o único teste
      que percebe se alguém desacoplar os dois numa refatoração.
- [ ] O CSV cumpre o contrato inteiro: `;`, UTF-8 **com BOM**, decimal com vírgula, `dd/MM/yyyy`,
      CRLF, quoting só quando necessário, nulo como campo vazio, cabeçalho rotulado vindo do bean e
      colunas exatamente na ordem declarada.
- [ ] O fill usa virtualizer, e os dois Artefatos são escritos **em disco local** antes de subir.
- [ ] A chave no repositório é `{yyyy-MM-dd}/{SIGLA}/{CODIGO}/{CODIGO}.{ext}`, e o schema de
      controle **grava a chave completa** em vez de recalculá-la.
- [ ] O SHA-256 de cada Artefato é calculado e gravado. O código fala S3 puro atrás de uma porta —
      "MinIO" é implementação, nunca contrato.
- [ ] A transição terminal é guardada por `AND status = 'EM_PROCESSAMENTO'`; casar zero linhas
      registra a perda e **não** sobrescreve.
- [ ] `CO-STEP-SINGLE-THREAD` — o step é single-thread, imposto pelo Starter e não deixado ao módulo.
      É **teste de arquitetura**, não de runtime: o repositório de job resourceless não é thread-safe,
      e a violação corrompe metadados em silêncio, sem nada que um teste de execução pegue por
      acidente.
- [ ] `CO-FONTE-AUSENTE-FALHA` — exportar este Relatório real com a propriedade de fonte ausente
      ligada **falha** quando a font extension sai do classpath.
- [ ] `CO-FONTE-NEGATIVO` — um teste com fonte inexistente prova que a propriedade está em vigor;
      sem ele o positivo passaria mesmo com ela ignorada.
