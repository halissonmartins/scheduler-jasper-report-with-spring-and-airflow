# 40 — Primeiro Produto: schema transacional e os dois Relatórios de exemplo

Type: grilling
Status: resolved
Blocked by: —

## Question

Como é o schema transacional de Poupança, e como são os seus dois Relatórios de exemplo?

Este ticket graduou da névoa quando o contrato do Starter e o contrato do CSV fecharam — eram os dois
que faltavam para a forma ficar nítida.

Ele é o **primeiro** dos cinco Produtos e existe para **fixar o padrão**. Os outros quatro replicam,
e é por isso que só ele virou ticket agora: depois deste, não se revela arquitetura nova.

Decidir e escrever:

- **O schema transacional de Poupança.** Tabelas, colunas, chaves e volume plausível. É base de
  exemplo, mas precisa ser realista o suficiente para que a leitura em cursor e o teste de carga
  signifiquem alguma coisa.
- **Os dois Relatórios**, com Código, nome, descrição e a consulta principal de cada um. A descrição
  inicial exige que sejam "com imagens e fontes diferentes" — decidir quais, e o que cada um está
  demonstrando.
- **Os dois JRXML**, respeitando o que já foi decidido: bandas alinhadas em grade comum (ticket 22),
  imagens embutidas e fontes **não** embutidas (trade-off do documento), e `whenNoDataType` — lembrando
  que o default é `NoPages` e que Execução sem dados nem chega a preencher (ticket 02).
- **Os rótulos de coluna para o CSV**, declarados no bean junto do mapeamento (ticket 23), e a
  disciplina de mantê-los coerentes com os cabeçalhos do JRXML.
- **O tempo estimado sugerido** de cada Relatório (ticket 21) — o valor que o bean expõe e a tela de
  cadastro oferece pré-preenchida.
- **Os dados de semente**: quantas linhas, com que distribuição, e como são gerados de forma
  repetível. É o que sustenta os testes de integração e o cenário de carga.
- **O que exatamente cada exemplo prova.** Um deles precisa exercitar o risco de substituição de
  fonte — o documento aceita o trade-off de fontes não embutidas, e a única forma de provar que ele
  está sob controle é um teste que **falhe** quando a fonte some.

## Notas de research e de tickets anteriores

- **Ticket 21**: cada Relatório é um bean implementando a SPI do Starter — Código, recurso do JRXML,
  consulta, mapeamento de campos, parâmetros e tempo estimado sugerido. O inventário é a enumeração
  desses beans, então declarar e poder executar são a mesma coisa.
- **Ticket 21**: a leitura é em **pull**, num tasklet único, com o CSV derivado do mesmo
  `JRDataSource`. A consulta precisa funcionar com cursor, respeitando as quatro condições do pgjdbc
  — autocommit desligado, `TYPE_FORWARD_ONLY`, statement único, `fetchSize > 0` — sob pena de o driver
  degradar em silêncio e bufferizar tudo.
- **Ticket 22**: o XLSX sai do mesmo `.jrprint` paginado, com configuração de exporter aplicada pela
  API. Bandas desalinhadas viram células mescladas — o alinhamento em grade é requisito funcional,
  não estético, e estes dois JRXML são a demonstração dele.
- **Ticket 23**: cabeçalho do CSV é rotulado e vem do bean; colunas são exatamente os campos do
  mapeamento, na ordem declarada.
- **Ticket 04**: a credencial deste módulo tem `SELECT` **apenas** em `transacional_poupanca`. O
  schema precisa ser autossuficiente para os dois Relatórios.
- **Descrição inicial**: `POUPANCA-0001` e `POUPANCA-0002` são os Códigos, no formato `SIGLA-NNNN` com
  sequência única por Produto.

## Notas do ticket 30 (estratégia de teste e CI)

- **Os dados de semente têm um consumidor exigente que este ticket precisa atender**: o teste do
  cursor do `JRDataSource` (ticket 21) precisa de **volume que estoure o heap se bufferizado** e passe
  se não. Isso significa que a semente não pode ser "algumas dezenas de linhas para o cenário ficar
  legível" — ela precisa ter, ao menos numa configuração, ordem de grandeza suficiente para provar o
  ponto.
- **A Coleta é testável na camada de integração**, com o job rodando in-process
  (`JobOperatorTestUtils`) contra Testcontainers de PostgreSQL e MinIO. O schema deste Produto precisa
  ser semeável de forma **repetível** nesse contexto, não só num Compose completo.
- **O teste da substituição de fonte** — que o documento exige provar — é cenário deste ticket, e o
  ticket 30 o classifica: ele roda na camada de integração, com
  `net.sf.jasperreports.awt.ignore.missing.font=false`, e precisa **falhar** quando a fonte some.
- **Os dois Relatórios entram na lista de cenários obrigatórios da especificação**, que é o gate real
  de cobertura (ticket 30) — não o percentual.

## Notas do ticket 35 (repositório S3)

- **Os Testcontainers deste ticket sobem MinIO AGPL congelado**, não AIStor — o CI não tem chave de
  licença, por decisão do ADR 0003. Fixar a tag `RELEASE.2025-10-15T17-29-55Z` explicitamente: é o
  último binário comunitário publicado, e `latest` não existe mais como caminho confiável.
- **O código de acesso ao repositório fala S3 puro atrás de uma porta**, com AWS SDK v2. "MinIO" não
  é contrato — os exemplos deste ticket não devem usar API específica de fornecedor.

## Notas do ticket 37 (versionamento do JRXML)

- **Os dois beans deste Produto são a primeira entrada do `hash_definicao`.** Eles fixam também a
  canonicidade: a ordem dos rótulos declarada aqui é a ordem que entra no hash, então a estrutura que
  os carrega precisa ser ordenada por construção — `List`, nunca `Map` iterado.
- **Diretriz herdada**: mudança que altera o **significado** do relatório (outra população, outra
  métrica) é Código novo, não versão nova. Vale considerar isso ao escolher o que `POUPANCA-0001` e
  `POUPANCA-0002` medem — dois relatórios com escopo bem delimitado envelhecem melhor que um genérico
  que vai ser reinterpretado.

## Answer

Fecha a pendência "definição dos relatórios de exemplo e seus respectivos modelos de dados" da
descrição inicial, e fixa o padrão que os outros quatro Produtos replicam.

### Artefatos escritos

| | |
|---|---|
| DDL | `relatorios-processador-poupanca/src/main/resources/db/migration/V1__schema_transacional_poupanca.sql` |
| Semente funcional | `.../src/test/resources/db/semente-funcional.sql` |
| Semente volumétrica | `.../src/test/resources/db/semente-volumetrica.sql` |
| JRXML analítico | `.../src/main/resources/relatorios/POUPANCA-0001.jrxml` |
| JRXML sintético | `.../src/main/resources/relatorios/POUPANCA-0002.jrxml` |

### O schema: seis tabelas

`agencia`, `titular`, `conta_poupanca`, `lancamento`, `remuneracao_mensal`, `saldo_diario`.

**Autossuficiente por imposição do ticket 04**: a credencial deste módulo tem `SELECT` apenas em
`transacional_poupanca`, então não há junção com o Produto Cliente — `titular` é cópia denormalizada,
não FK para outro schema. Essa é a forma que os cinco Produtos herdam.

`dia_aniversario` e `remuneracao_mensal` são o que fazem o schema ser **Poupança** e não um razão
genérico, e é a dimensão que o segundo Relatório agrega.

> **Risco aceito**: o schema rico foi escolhido sobre a alternativa de três tabelas com o custo
> declarado — semente e manutenção **× 5 Produtos**, num ticket cuja razão de existir é fixar um
> padrão replicável. Padrão caro replica caro.

### Os dois Relatórios cobrem os extremos

Cada mecanismo decidido no mapa tem um dono, e nenhum é provado duas vezes.

**`POUPANCA-0001` — Movimentação Diária por Agência** (analítico, alto volume)

```sql
SELECT a.codigo, a.nome, c.numero || '-' || c.digito AS conta, t.nome AS titular,
       l.data_movimento, l.tipo, l.valor, l.historico, l.documento
  FROM lancamento l
  JOIN conta_poupanca c ON c.id = l.conta_id
  JOIN agencia a        ON a.codigo = c.agencia_codigo
  JOIN titular t        ON t.id = c.titular_id
 WHERE l.data_movimento = :dataReferencia
 ORDER BY a.codigo, c.numero, l.data_movimento, l.id
```

- Grupos: agência → conta, com subtotais e total geral.
- Prova: leitura em cursor, streaming, CSV volumoso, e a grade de bandas no XLSX (ticket 22).
- Tempo estimado sugerido: **240 s**.
- Rótulos do CSV, na ordem: `Agência`, `Nome da Agência`, `Conta`, `Titular`, `Data do Movimento`,
  `Tipo`, `Valor`, `Histórico`, `Documento`.

**`POUPANCA-0002` — Posição Consolidada de Saldos e Remuneração** (sintético, denso)

```sql
SELECT a.codigo, a.nome, c.dia_aniversario,
       count(*)                          AS quantidade_contas,
       sum(s.saldo)                      AS saldo_total,
       coalesce(sum(r.base_calculo), 0)  AS base_calculo,
       coalesce(sum(r.valor_creditado), 0) AS rendimento
  FROM saldo_diario s
  JOIN conta_poupanca c ON c.id = s.conta_id
  JOIN agencia a        ON a.codigo = c.agencia_codigo
  LEFT JOIN remuneracao_mensal r
         ON r.conta_id = c.id
        AND date_trunc('month', r.data_aniversario) = date_trunc('month', :dataReferencia)
 WHERE s.data = :dataReferencia
 GROUP BY a.codigo, a.nome, c.dia_aniversario
 ORDER BY a.codigo, c.dia_aniversario
```

- Prova: imagens embutidas, **fontes não embutidas**, agregação e formatação densa.
- Tempo estimado sugerido: **30 s**.
- Rótulos do CSV, na ordem: `Agência`, `Nome da Agência`, `Dia de Aniversário`,
  `Quantidade de Contas`, `Saldo Total`, `Base de Cálculo`, `Rendimento Creditado`.

Dois analíticos foram recusados por provarem os mesmos mecanismos duas vezes, deixando o caminho de
formatação sem exemplo nenhum.

### A semente: dois perfis, e o truque que a torna barata

**Funcional** — 3 agências, 50 contas, ~2 mil lançamentos em **10 datas**. Carregada em todo teste de
integração. A janela é de 10 dias e não 7 porque o ticket 32 descobriu no protótipo que, com janela
igual à retenção, o estado "expirado" simplesmente **não existe** nos dados de teste.

**Volumétrica** — ~1,8 milhão de lançamentos numa **única** Data de Referência, porque é o recorte que
o `POUPANCA-0001` faz. Só no teste de cursor e no k6.

Uma semente única grande foi recusada: o ticket 09 mediu ~2 s para subir o Testcontainer, e a carga
volumétrica em todo teste engoliria isso e estouraria o gate leve de PR do ticket 30.

> **O achado que barateia o teste de cursor**: ele não precisa de volume de produção. A forma barata
> e determinística de provar que a leitura **transmite** é **apertar o heap** (`-Xmx96m` no surefire)
> contra um volume que o excede se bufferizado. Perseguir dezenas de milhões de linhas tornaria o
> teste lento sem torná-lo mais conclusivo.

Ambas geradas com `generate_series` e `setseed(0.42)` — determinísticas, server-side, sem código de
aplicação. As **datas** flutuam com `CURRENT_DATE` de propósito: os testes afirmam contagens, a Data
de Referência é sempre parâmetro explícito (ticket 20), e datas fixas envelheceriam para fora de
qualquer janela de retenção.

### A prova da fonte: a propriedade ligada no relatório real

O documento aceitou embutir imagens mas não fontes. O ticket 30 pediu "um teste que **falhe** quando a
fonte some" — e há uma forma mais barata do que simular o sumiço.

Exportar o `POUPANCA-0002` real com `net.sf.jasperreports.awt.ignore.missing.font=false` **já falha**
se a font extension não estiver no classpath, porque o Jasper lança em vez de substituir em silêncio.
O teste fica verde só enquanto a fonte existir de verdade, e vermelho no dia em que alguém tirar o jar
do build. Não é simulação — é o empacotamento real sob asserção.

**Mais um teste negativo**, com nome de fonte inexistente, para provar que a propriedade está mesmo em
vigor. Sem ele, o positivo passaria mesmo com a propriedade ignorada: falso verde, o padrão que este
mapa vem catando ticket após ticket.

Manipular o classpath em tempo de teste foi recusado por exigir ginástica de classloader frágil e
ilegível, para chegar ao mesmo lugar.

O elemento que carrega o risco é concreto: o título e os cabeçalhos do `POUPANCA-0002` usam
`fontName="Poupanca Display"`, que só existe na font extension do módulo.

### Derivado

- **A ordem dos rótulos é a que entra no `hash_definicao`** (ticket 37), então a estrutura que os
  carrega no bean é `List`, nunca `Map` iterado — senão o hash muda sozinho e o mecanismo vira ruído.
- **`whenNoDataType` fica no default (`NoPages`)** e não é declarado nos JRXML. Execução sem dados
  encerra como `SEM_DADOS` **antes** do fill (ticket 02), então declarar o atributo criaria um caminho
  que nunca é percorrido.
- **Grade comum imposta nos dois JRXML** (ticket 22): as mesmas coordenadas `x` e larguras em todas as
  bandas — cabeçalho, detalhe, rodapés de grupo e sumário. Requisito funcional, porque o XLSX sai
  deste mesmo `.jrprint` paginado e banda desalinhada vira célula mesclada.
- **As quatro condições do pgjdbc** na consulta do `POUPANCA-0001`: autocommit desligado,
  `TYPE_FORWARD_ONLY`, statement único, `fetchSize > 0`. Sob pena de o driver bufferizar tudo em
  silêncio (ticket 06) — e é justamente o que o teste de heap apertado pega.
- **Índice `ix_lancamento_data`** em `(data_movimento, conta_id)`: sem ele a Coleta de alto volume vira
  seq scan da tabela inteira mais sort em disco, e o `tempo_estimado` de 240 s deixa de fazer sentido.
- **Cron do Produto Poupança** (ticket 39): `0 3 * * *`, em `America/Sao_Paulo`.
- **Ambos os tempos estimados são folgados sob o `LIMITE_ORFA`** de 6 h, então passam pela guarda do
  cadastro (ticket 04) e pela guarda da varredura (ticket 36) sem aperto.
