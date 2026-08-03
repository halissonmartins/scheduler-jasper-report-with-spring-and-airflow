# 43 — Produto Consórcio: schema transacional e os dois Relatórios de exemplo

Type: grilling
Status: resolved
Blocked by: —

## Question

Como é o schema transacional de Consórcio, e como são os seus dois Relatórios de exemplo?

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

- **Quais tabelas modelam grupos, cotas, assembleias e contemplações**, e o que nele é próprio o bastante para o schema não virar o de
  Poupança com outros nomes.
- **O que cada um dos dois Relatórios responde**, com Código `CONSORCIO-0001` e `CONSORCIO-0002`,
  nome, descrição e consulta.
- **O volume plausível** deste domínio, que decide se o analítico é de fato de alto volume — se não
  for, o par precisa de outra divisão de trabalho.
- **O tempo estimado sugerido** de cada um, e o cron do Produto: assembleia é evento mensal, não diário — decidir se a Coleta diária faz sentido ou se o par de Relatórios precisa de recorte mensal, o que interage com a Data de Referência do ticket 03.

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
| DDL | `relatorios-processador-consorcio/src/main/resources/db/migration/V1__schema_transacional_consorcio.sql` |
| Sementes | `.../src/test/resources/db/semente-funcional.sql`, `.../semente-volumetrica.sql` |
| JRXML | `.../src/main/resources/relatorios/CONSORCIO-0001.jrxml`, `.../CONSORCIO-0002.jrxml` |

### A tensão da frequência se dissolveu — e o porquê importa

Este era o candidato mais provável a forçar a reabertura do ticket 39: o ciclo do negócio é mensal e o
agendamento é diário.

> **A assembleia é propriedade do GRUPO, não da carteira.** Com centenas de grupos, há assembleia todo
> dia útil. O ciclo mensal existe, é real, e **nunca alcança o agendamento**.

Não é conveniência nem contorno: é como uma administradora de consórcio de fato opera. O ticket 39 fica
intacto e o cron do Produto continua servindo aos dois Relatórios.

O caminho mensal foi recusado por custar uma decisão de arquitetura (mover o cron para o Relatório, ou
admitir mais de um por Produto) e por deixar a Data de Referência diária do ticket 03 semanticamente
torta — "o relatório de 15/08" perde significado num ciclo mensal.

**Diretriz que sai daqui**, e é a terceira vez neste mapa que uma tensão se resolve assim: **um evento
de ciclo próprio cabe dentro de um relatório diário como coluna datada**, em vez de virar frequência
própria. Vale para quem modelar um Produto futuro com ciclo que não seja o diário.

### `CONSORCIO-0001` — Posição Diária de Cotas

```sql
SELECT g.codigo, g.bem_referencia, c.numero, c.consorciado_nome, c.data_adesao,
       c.situacao, count(p.id) AS parcelas_pagas, g.prazo_meses,
       c.percentual_pago, g.valor_credito
  FROM cota c
  JOIN grupo g   ON g.codigo = c.grupo_codigo
  LEFT JOIN parcela p ON p.cota_id = c.id AND p.data_pagamento IS NOT NULL
 WHERE c.situacao IN ('ATIVA', 'CONTEMPLADA')
 GROUP BY g.codigo, g.bem_referencia, c.numero, c.consorciado_nome, c.data_adesao,
          c.situacao, g.prazo_meses, c.percentual_pago, g.valor_credito
 ORDER BY g.codigo, c.numero
```

- Grupo por grupo de consórcio. Tempo estimado sugerido: **420 s**.
- Rótulos: `Grupo`, `Bem de Referência`, `Cota`, `Consorciado`, `Data de Adesão`, `Situação`,
  `Parcelas Pagas`, `Prazo em Meses`, `Percentual Pago`, `Valor do Crédito`.

Mesma forma do `CLIENTE-0001` (ticket 41): fotografia da carteira, volume que não varia com a Data de
Referência — outro bom caso para o limiar fixo de +20% do ticket 24.

### `CONSORCIO-0002` — Posição dos Grupos e Assembleia do Dia

Uma linha por grupo: cotas ativas, contempladas e canceladas, fundo comum, e — quando houve assembleia
naquele dia — as contemplações por modalidade. Tempo estimado sugerido: **40 s**.

- Rótulos: `Grupo`, `Bem de Referência`, `Cotas Ativas`, `Cotas Contempladas`, `Cotas Canceladas`,
  `Fundo Comum`, `Contemplações por Sorteio`, `Contemplações por Lance`.

**Grupo sem assembleia no dia aparece com as colunas de contemplação zeradas**, não ausente: a linha
continua dizendo algo — a posição do grupo — então não é dado faltando, é evento que não ocorreu.

Um sintético só com as assembleias do dia foi recusado por falar apenas dos poucos grupos que se
reuniram e calar sobre a carteira. Uma análise de inadimplência foi recusada por ser exatamente a forma
que o Produto Empréstimo terá por natureza — os dois últimos Produtos do mapa entregariam o mesmo
relatório com outro nome.

### O schema

`grupo`, `cota`, `parcela`, `assembleia`, `contemplacao`, `lance`.

**`lance` guarda os lances perdedores**, não só o vencedor. Sem eles a assembleia registra o resultado
e apaga a disputa — e é a disputa que explica o percentual de contemplação por lance. É o substrato
próprio deste Produto, o papel que `remuneracao_mensal`, `segmentacao` e `limite_uso`/`tarifa`
cumpriram nos anteriores.

### Derivado

- **Nenhum dos dois Relatórios exercita `SEM_DADOS` naturalmente.** A opção que o faria — Coleta diária
  encerrando `SEM_DADOS` nos dias sem assembleia — foi recusada porque encheria a listagem de dias
  vazios em feriados e fins de semana, sem o relator distinguir "não houve" de "falhou". Consequência:
  o estado criado no ticket 02 segue coberto **apenas por teste** em todo o mapa. Anotado no ticket 30
  para ninguém supor cobertura de produção onde não há.
- **A semente volumétrica cresce `cota`**, não um recorte de data — mesma forma da do ticket 41
  (Cliente) e não da do ticket 40 (Poupança). Os dois formatos de semente do mapa agora têm dois
  representantes cada.
- **Índice `ix_assembleia_data`**: o sintético recorta a assembleia pelo dia, e sem ele varre todo o
  histórico de assembleias já realizadas a cada Coleta.
- **Índice parcial `ix_parcela_cota`** (`WHERE data_pagamento IS NOT NULL`): o analítico conta parcelas
  pagas por cota, e o índice parcial é menor que o total por uma margem que cresce com o histórico.
- **Cron `0 6 * * *`**, seguindo o escalonamento de uma hora por Produto do ticket 41.
- **A prova da substituição de fonte não se repete** — vive no `POUPANCA-0002`.
