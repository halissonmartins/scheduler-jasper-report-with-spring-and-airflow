# 03 — Chave de armazenamento, data de referência e fuso horário

Type: grilling
Status: resolved
Blocked by: 02

## Question

Qual é o layout normativo da chave no repositório S3, e o que exatamente a data significa?

A estrutura hoje é `yyyy-MM-dd / nome do produto / código do relatório / <dados>`, e o documento já decidiu que a data é o dia em que o job rodou.

O que falta decidir:

- **Fuso horário.** "O dia em que o job rodou" em qual fuso? Uma coleta às 23h em UTC cai no dia seguinte em relação a America/Sao_Paulo. Isso muda o que o relator enxerga no drop-down e precisa estar escrito.
- **Redundância.** O path repete o produto, que já está contido no código do relatório. Manter por legibilidade ou remover?
- **Discriminador de execução.** O path não comporta duas execuções no mesmo dia para o mesmo par. Precisa de um `executionId` no final? Isso interage diretamente com `forcar_reprocessamento` (ticket 20) — sobrescrever exige path estável, versionar exige discriminador.
- **Nomes dos objetos** dentro do path: `.jrprint`, `.csv.gz`, e o que mais (manifest? hash? metadados?).
- **Data de competência.** Se o negócio um dia precisar da data de competência dos dados (tipicamente D-1) além da data de execução, o layout comporta? Decidir agora se o modelo carrega uma ou duas datas.

## Notas de research

- **Ticket 10**: o filtro de lifecycle do MinIO é **prefixo literal, sem wildcard**. Uma retenção
  diferenciada por Produto exigiria a Sigla **antes** da data no caminho — o que inverte o layout
  atual (`yyyy-MM-dd/produto/...`). Se a retenção for global, o layout atual serve. Decidir aqui.
- **Ticket 10**: a expiração é previsível (criação + N dias, à meia-noite UTC) mas a remoção é
  assíncrona e **não atômica** entre o `.jrprint` e o `.csv.gz` — os dois não somem no mesmo
  instante. Isso afeta a promessa de "expirar juntos" e realimenta o ticket 27.
- **Ticket 01**: a Sigla do Produto é imutável, então usá-la no caminho é seguro; o Nome do
  Produto não pode aparecer no caminho, porque é mutável.

## Answer

### Correção a uma premissa deste ticket

O research 10 §7.2 concluiu que retenção diferenciada por Produto exigiria a Sigla **antes** da
data, porque o filtro de lifecycle seria prefixo literal sem wildcard. **A premissa está incompleta**:
o filtro aceita um prefixo **e zero ou mais tags**, e o MinIO implementa isso — `mc ilm rule add`
documenta `--tags` como *"one or more ampersand-delimited key-value pairs describing the object tags
to which to apply the lifecycle configuration rule"*, e a página de parâmetros descreve
`--prefix` e `--tags` como os dois mecanismos de escopo.

Ou seja: retenção por Produto é alcançável por tag, com o path em qualquer ordem. O que a ordem do
path realmente decide é **policy**, não retenção — e é sobre isso que a decisão abaixo foi tomada.

Ressalva registrada: `--tags` é mutuamente exclusivo com `--expire-delete-marker`, e etiquetar na
escrita exige `s3:PutObjectTagging` na credencial do processador, que hoje não está prevista.

### Data de Referência

Continua sendo **o dia em que a Coleta rodou**, como na descrição inicial.

Calculada em **`America/Sao_Paulo`**. Instantes (`inicio`, `fim`) permanecem em UTC, como
`timestamptz`. A regra: **data de calendário é do negócio, instante é UTC**. O Brasil extinguiu o
horário de verão em 2019, então `America/Sao_Paulo` é offset fixo `-03:00` — não há hora ambígua nem
data que exista duas vezes.

**Consequência obrigatória na DAG.** O `ds` deriva de `logical_date`, que é um instante em UTC.
Uma Coleta agendada às 22:00 BRT de 01/08 tem `logical_date = 2026-08-02T01:00Z`, e `{{ ds }}` cru
devolveria `2026-08-02`. O default do parâmetro precisa converter o fuso **antes** de formatar. O
ticket 19 deve verificar isso em teste de integração, não confiar na leitura.

O research 13 já havia fixado que `data_referencia` entra por `params` explícito, com o template
apenas como default do caminho agendado — *"do not assume the run's `data_interval` is derived from,
or equal to, the supplied `logical_date`"* em disparos manuais.

**`forcar_reprocessamento` herda a Data de Referência da Execução original**, passada como parâmetro
explícito. Sem isso, reprocessar em 03/08 uma Coleta de 01/08 geraria chave nova, a unicidade do
ticket 20 nunca dispararia, e o acervo ganharia duas entradas para o mesmo fato. A regra deixa de
ser uniforme — quem lê `data_referencia` não sabe, sozinho, se aquilo foi rodada normal ou
reprocesso — e quem desempata é a auditoria que o ticket 20 já exige (solicitante, motivo,
Correlation ID).

**Uma data só.** Competência não é modelada. Se o negócio precisar dela um dia, entra como **coluna
de metadados**, nunca como componente do caminho — o caminho precisa continuar derivável da chave
de unicidade.

### Layout da chave

```
{yyyy-MM-dd}/{SIGLA}/{CODIGO}/{CODIGO}.jrprint
{yyyy-MM-dd}/{SIGLA}/{CODIGO}/{CODIGO}.csv.gz
```

Exemplo: `2026-08-01/POUPANCA/POUPANCA-0001/POUPANCA-0001.jrprint`

A redundância entre a Sigla e o Código é deliberada: o Código inteiro no caminho e no nome do
objeto faz o artefato se identificar sozinho quando um operador o puxa do bucket com `mc cp`, sem
depender do contexto do diretório.

**Sem discriminador de execução.** Reprocessamento sobrescreve no mesmo caminho, que é o verbo da
descrição inicial e agora é bem definido, já que a data é herdada. A unicidade só admite uma
Execução em `SUCESSO` por par, então nunca existem dois conjuntos legítimos de artefatos ao mesmo
tempo — um discriminador só produziria órfãos ocupando espaço até a retenção.

O caminho é determinístico, mas **o schema de controle grava a chave completa** em vez de
recalculá-la, para sobreviver a uma eventual mudança de layout sem reescrever histórico.

O sufixo no nome do objeto deixa espaço para o segundo print (não paginado para XLSX) que o
ticket 22 pode decidir gravar: `{CODIGO}-nao-paginado.jrprint`.

O SHA-256 **não** vira arquivo no bucket — ele vive no schema de controle (research 10), e um
manifest no repositório seria uma segunda fonte de verdade para a mesma coisa.

### Riscos aceitos

1. **Data de Referência = dia em que rodou.** Argumentei por competência, porque a mesma data serve
   de chave de unicidade e de rótulo do drop-down, e as duas coisas divergem assim que uma Coleta é
   reprocessada noutro dia. Decisão: manter a letra do documento. O risco está contido pela herança
   da data no `forcar_reprocessamento` — sem essa herança, a decisão é incoerente.
2. **Ordem data-primeiro no caminho.** Argumentei pela Sigla primeiro, porque policies do MinIO
   operam por prefixo (`arn:aws:s3:::bucket/prefixo/*`) e wildcard no meio não existe: com a data na
   frente, é impossível restringir cada processador ao próprio Produto. Isso importa porque o
   research 10 §4.4 registra que a separação leitura/escrita **não** cobre processador comprometido.
   Decisão: manter a ordem documentada. Consequência: todos os processadores compartilham o mesmo
   alcance de escrita, o raio de explosão continua sendo o bucket inteiro, e o hash conferido mais o
   `ObjectInputFilter` do ticket 18 seguem sendo as únicas defesas nessa fronteira.

## Notas do ticket 39 (agendamento e fábrica de DAGs)

- **O alerta sobre `{{ ds }}` ganhou um segundo motivo, independente do fuso.** No Airflow 3 o
  `create_cron_data_intervals` passou a ter default `False`, então cron simples usa
  `CronTriggerTimetable` e a documentação de upgrade avisa que DAGs que dependem de `ds`/`ts` podem
  precisar reverter a configuração. A Data de Referência vindo como **parâmetro explícito** (ticket 20)
  torna o projeto imune aos dois problemas de uma vez.
- **O `schedule` é `CronTriggerTimetable(cron, timezone="America/Sao_Paulo")`** e o `start_date` é
  timezone-aware via pendulum — o Airflow proíbe deliberadamente os objetos de fuso da biblioteca
  padrão.
- **`PYTZDATA_TZDATADIR=/usr/share/zoneinfo` na imagem do Airflow.** O pendulum usa base de fuso
  própria, *"not updated as frequently as the IANA database"*, e `America/Sao_Paulo` é um fuso cuja
  definição mudou na última década.
