# 42 — Produto Conta Corrente: schema transacional e os dois Relatórios de exemplo

Type: grilling
Status: resolved
Blocked by: —

## Question

Como é o schema transacional de Conta Corrente, e como são os seus dois Relatórios de exemplo?

Este ticket graduou da névoa quando o [ticket 40](40-primeiro-produto-schema-e-relatorios-de-exemplo.md)
fechou e **fixou o padrão**. Ele é replicação deliberada: não revela arquitetura nova, e por isso é
folha — nada depende dele, e ele pode rodar em paralelo com os outros três ou ser adiado sem travar o
destino.

O padrão a replicar, já decidido no ticket 40:

- **Schema autossuficiente**, cinco a seis tabelas, sem junção com outro Produto (ticket 04: a
  credencial deste módulo só lê o próprio schema). Cópias denormalizadas onde um sistema real teria FK
  para outro domínio.
- **Um Relatório analítico de alto volume + um sintético denso.** O analítico prova cursor, streaming,
  CSV volumoso e grade de bandas no XLSX; o sintético prova imagens, fontes e agregação.
- **Dois perfis de semente**, gerados com `generate_series` e `setseed`, com datas relativas a
  `CURRENT_DATE` e janela **maior que a retenção**.
- **Grade comum nos JRXML** (ticket 22) e `whenNoDataType` no default.
- **Rótulos do CSV em `List` ordenada** (ticket 37), `tempo_estimado` sugerido no bean (ticket 21),
  cron no cadastro do Produto (ticket 39).

O que este ticket precisa decidir, e é onde ele não é cópia:

- **Quais tabelas modelam movimentação de conta corrente**, e o que nele é próprio o bastante para o schema não virar o de
  Poupança com outros nomes.
- **O que cada um dos dois Relatórios responde**, com Código `CONTACORRENTE-0001` e `CONTACORRENTE-0002`,
  nome, descrição e consulta.
- **O volume plausível** deste domínio, que decide se o analítico é de fato de alto volume — se não
  for, o par precisa de outra divisão de trabalho.
- **O tempo estimado sugerido** de cada um, e o cron do Produto: é o Produto com maior chance de ter o maior volume de todos — vale conferir se o `tempo_estimado` resultante ainda cabe no teto de ~59 min do ticket 24.

## Notas do ticket 40 (primeiro Produto)

- **O risco aceito lá vale aqui, e é aqui que ele custa**: o schema rico de seis tabelas foi escolhido
  sabendo que semente e manutenção se multiplicam por cinco. Se o custo se mostrar alto neste ticket,
  vale registrar — é o sinal de que a decisão do ticket 40 precisa ser revisitada antes dos dois
  Produtos restantes, não depois.
- **A prova da fonte não se repete.** O teste de `ignore.missing.font=false` já existe no ticket 40 e
  guarda o empacotamento do monorepo inteiro. Este Produto não precisa de um segundo.

## Answer

### Artefatos escritos

| | |
|---|---|
| DDL | `relatorios-processador-contacorrente/src/main/resources/db/migration/V1__schema_transacional_contacorrente.sql` |
| Sementes | `.../src/test/resources/db/semente-funcional.sql`, `.../semente-volumetrica.sql` |
| JRXML | `.../src/main/resources/relatorios/CONTACORRENTE-0001.jrxml`, `.../CONTACORRENTE-0002.jrxml` |

### A pergunta que este ticket carregava estava mirando na restrição errada

O ticket perguntava se o `tempo_estimado` do maior Produto ainda cabe no teto de ~59 min do ticket 24.
Cabe, com folga — e **não é isso que dimensiona este Produto**.

> Ticket 21: *"o limite prático de tamanho de um Relatório é o heap da API, não o do processador"* — na
> exportação o `.jrprint` inteiro volta ao heap, na mesma JVM da API (ADR 0002).

Uma Coleta pode terminar em 30 minutos, dentro de todos os limites, e produzir um artefato que **nunca
exporta**. É aqui que o risco aceito do ticket 25 — sem teto na Coleta, contido apenas por métrica de
tamanho com alerta no Grafana — encontra o seu primeiro caso concreto.

**Correção de ênfase para a especificação**: o teto de ~59 min é uma guarda de *orquestração* (deriva
do `LIMITE_ORFA` e das três tentativas). Quem limita o *tamanho* é a exportação, e os dois números não
se conversam.

### `CONTACORRENTE-0001` — Resumo Diário por Conta

Uma linha por conta, com contagem e totais do dia.

```sql
SELECT a.codigo, a.nome, c.numero || '-' || c.digito AS conta, c.titular_nome, c.tipo_conta,
       count(l.id)                                                  AS quantidade,
       coalesce(sum(l.valor) FILTER (WHERE l.natureza = 'D'), 0)     AS total_debito,
       coalesce(sum(l.valor) FILTER (WHERE l.natureza = 'C'), 0)     AS total_credito,
       s.saldo_inicial, s.saldo_final
  FROM conta_corrente c
  JOIN agencia a      ON a.codigo = c.agencia_codigo
  JOIN saldo_diario s ON s.conta_id = c.id AND s.data = :dataReferencia
  LEFT JOIN lancamento l
         ON l.conta_id = c.id AND l.data_movimento = :dataReferencia
 WHERE c.situacao = 'ATIVA'
 GROUP BY a.codigo, a.nome, c.numero, c.digito, c.titular_nome, c.tipo_conta,
          s.saldo_inicial, s.saldo_final
 ORDER BY a.codigo, c.numero
```

- Grupo por agência, com subtotais. Tempo estimado sugerido: **900 s**.
- Rótulos do CSV, na ordem: `Agência`, `Nome da Agência`, `Conta`, `Titular`, `Tipo de Conta`,
  `Quantidade de Lançamentos`, `Total de Débitos`, `Total de Créditos`, `Saldo Inicial`, `Saldo Final`.

**"Todo lançamento de todas as contas" seria extração de dados, não relatório.** Esse é o critério que
resolveu o problema em vez de contorná-lo, e vale como diretriz para os dois Produtos restantes: um
relatório é agregado ou recortado; um dump não é relatório e não deveria caber neste sistema.

A alternativa detalhada foi recusada porque escolhê-la significaria admitir que o exemplo carro-chefe
não exporta, ou reabrir o ticket 25. A alternativa "detalhado por agência" foi recusada porque exigiria
um Código por agência — a sequência de 4 dígitos viraria espaço de nomes acidental, e o cadastro, a
fábrica de DAGs e o drop-down passariam a crescer com a rede de agências.

### `CONTACORRENTE-0002` — Posição de Cheque Especial e Tarifas por Agência

Agrega `limite_uso` e `tarifa` por agência e tipo de conta: contas com limite, limite contratado,
utilizado, juros apurados e receita de tarifas. Tempo estimado sugerido: **45 s**.

- Rótulos: `Agência`, `Nome da Agência`, `Tipo de Conta`, `Contas com Limite`, `Limite Contratado`,
  `Limite Utilizado`, `Juros Apurados`, `Receita de Tarifas`.

`limite_uso` e `tarifa` são o que faz conta corrente **não ser** poupança — mesmo papel de
`remuneracao_mensal` no ticket 40 e de `segmentacao` no ticket 41. Um sintético de fluxo por agência
foi recusado por ser o analítico um nível acima; uma distribuição por faixa de saldo, por repetir a
forma que o `CLIENTE-0002` já tem.

### O schema, e a duplicação que é preço e não erro

`agencia`, `conta_corrente`, `lancamento`, `saldo_diario`, `limite_uso`, `tarifa`.

**`agencia` aparece pela segunda vez no mapa, duplicada em relação a Poupança.** É consequência direta
do isolamento do ticket 04: cada Produto é autossuficiente, então a rede de agências existe copiada em
cada schema que precise dela.

> Isso precisa estar escrito na especificação. Sem o registro, alguém "conserta" a duplicação com um
> schema compartilhado — e derruba o `GRANT` que é a única coisa impondo a fronteira de leitura por
> Produto, já que o layout do repositório S3 não pôde dar essa segregação (ticket 04).

### Derivado

- **Este Produto é o dimensionador do heap da API.** O ticket 25 registrou que dimensionar o heap "vira
  exercício obrigatório, em função do maior `JasperPrint`". O maior é este, e agora tem forma e volume
  concretos (~300 mil linhas de saída na semente volumétrica) — é o insumo que faltava.
- **A semente volumétrica tem forma própria**: o analítico agrega **por conta**, então a cardinalidade
  da *saída* é o número de contas e a do *insumo* é o número de lançamentos. As duas precisam crescer,
  e por razões diferentes — a primeira dimensiona o `.jrprint`, a segunda dimensiona a leitura. É a
  primeira semente do mapa em que os dois números divergem.
- **Índice `ix_lancamento_data_conta`** em `(data_movimento, conta_id)`: o resumo agrupa por conta sobre
  o recorte do dia na maior tabela do mapa. Sem ele, os 900 s estimados não têm chance.
- **Cron `0 5 * * *`**, seguindo o escalonamento de uma hora por Produto fixado no ticket 41.
- **A prova da substituição de fonte não se repete** — vive no `POUPANCA-0002` e guarda o empacotamento
  do monorepo inteiro.
