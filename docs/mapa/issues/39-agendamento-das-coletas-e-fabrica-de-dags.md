# 39 — Agendamento das Coletas e a fábrica de DAGs

Type: grilling
Status: resolved
Blocked by: —

## Question

Quando cada Coleta roda, e de onde a DAG que a dispara é gerada?

A descrição inicial só diz "periodicamente". Isso nunca foi decidido em ticket algum, e agora ficou
visível porque o **formato** da DAG está fechado (ticket 19: uma task `abrir_execucao` seguida de um
`DockerOperator`, uma dupla por Relatório) mas o **gatilho** não.

Decidir:

- **Onde vive o agendamento.** É atributo do Relatório no schema de controle (cadastrado junto com o
  tempo estimado), do Produto, ou fixo no código da fábrica de DAGs? Se for do Relatório, o
  ADMINISTRADOR passa a definir cron — e isso precisa de validação.
- **Uma DAG por Produto ou por Relatório.** O ticket 19 decidiu a granularidade da **task**, não a da
  DAG. Uma DAG por Produto agrupa as tasks dos seus Relatórios; uma por Relatório dá agendamento
  independente ao custo de muitas DAGs.
- **O fuso do agendamento.** O ticket 03 fixou a Data de Referência em `America/Sao_Paulo` e alertou
  que `{{ ds }}` cru rotula errado toda Coleta agendada depois das 21h BRT. O `schedule` da DAG
  precisa ser timezone-aware, e a conversão no default do parâmetro precisa casar com ele.
- **A fábrica de DAGs.** O research 13 recomenda gerar as DAGs a partir do inventário materializado
  pela API REST, em vez de arquivo por Produto. Decidir: a fábrica consulta a API, lê um arquivo que
  a API gera, ou lê o banco direto? Com que frequência o Airflow reavalia? Um Relatório cadastrado às
  10h roda hoje ou amanhã?
- **Relatório cadastrado e não publicado, ou publicado e não cadastrado.** O ticket 04 tornou os dois
  estados possíveis e visíveis. A fábrica gera DAG só para o que está cadastrado — confirmar, e
  decidir o que acontece com uma DAG cuja definição sumiu do cadastro (fica órfã no Airflow?).
- **Catch-up e backfill.** O Airflow tem `catchup`, que ao habilitar uma DAG nova dispara todas as
  execuções desde a data inicial. Com a unicidade por (Relatório, Data de Referência) e artefatos de
  7 dias, isso quase certamente deve ficar desligado — confirmar e escrever por quê.
- **Concorrência.** Quantas Coletas simultâneas o Airflow permite? O research 06 estimou ~68 conexões
  de `max_connections=100` e apontou que o botão real é o paralelismo da DAG.

## Notas de research

- **Ticket 13**: "DAG única parametrizada" foi **descartada** por perder `execution_timeout` por
  relatório e agendamento por produto. A recomendação é fábrica de DAGs a partir de inventário.
- **Ticket 13**: `logical_date`, `ds` e `ts` existem **só em DAGs baseadas em tempo**; e em disparos
  manuais *"do not assume the run's `data_interval` is derived from, or equal to, the supplied
  `logical_date`"*.
- **Ticket 19**: a forma da DAG está fechada — `abrir_execucao` → `DockerOperator`, um par por
  Relatório, com `execution_timeout` por task e retry habilitado (o índice único parcial passou a
  permitir).
- **Ticket 06**: o banco de metadados do Airflow é instância separada; o orçamento de conexões
  estimado é ~68 de `max_connections=100`.

## Notas do ticket 20 (idempotência e reprocessamento)

- **Existem dois disparos manuais, não um.** `refazer` (permitido quando o índice deixa o par livre —
  última tentativa em `ERRO` ou `SEM_DADOS`; não destrói, não exige motivo) e `reprocessar` (exigido
  quando há `SUCESSO`/`ALERTA`; apaga a Execução anterior, exige motivo). Os dois pela API REST,
  restritos a ADMINISTRADOR. **A fábrica de DAGs precisa expor um caminho de disparo que aceite os
  dois**, com a Data de Referência vindo como parâmetro explícito e não do `logical_date`.
- **`catchup` quase certamente desligado**, e agora há um argumento a mais: com `SEM_DADOS` fora do
  índice, um backfill de datas antigas cujas origens já foram truncadas produziria uma enxurrada de
  Execuções `SEM_DADOS` legítimas — ruído sem valor, e cada uma consumindo um container.
- **A decisão de que `SEM_DADOS` não bloqueia só tem efeito com disparo manual.** O agendamento
  seguinte é sempre para outra Data de Referência, então nada refaz um par sozinho. Se este ticket
  decidir algum mecanismo de reagendamento no mesmo dia, ele interage diretamente com isso.

## Notas do ticket 21 (contrato do Starter)

- **A fábrica só gera DAG para Relatório cadastrado *e* publicado.** O ticket 21 tornou a publicação
  declarativa: um Relatório cujo bean saiu da imagem sai do inventário, e o cadastro permanece
  sinalizado como "cadastrado, não publicado". Se a fábrica gerar DAG a partir do cadastro apenas,
  ela recria a porta dos fundos que o ticket 04 fechou — um container diário condenado a falhar,
  virando `ERRO` legítimo e indistinguível de falha real. **O filtro é a interseção, não o cadastro.**
- **O estado inverso também não gera DAG**: publicado e não cadastrado significa que o JRXML existe
  na imagem mas ninguém pediu que rodasse.
- **`execution_timeout` sai do cadastro**, não do código — `relatorio.tempo_estimado_segundos` é a
  fonte (ticket 21), então a fábrica lê o mesmo dado que o ADMINISTRADOR edita. Mudar a estimativa
  deve mudar a DAG sem deploy, o que impõe uma frequência de reavaliação a este ticket.

## Notas do ticket 24 (tolerância do tempo estimado)

- **Os números que a fábrica gera estão fixados**: `execution_timeout = 2 × tempo_estimado + 120 s` e
  `retries = 2` (3 tentativas). A fábrica não decide nada disso — ela calcula a partir do cadastro.
- **O `on_failure_callback` é obrigatório em toda task de Coleta**, e agora é o caminho **principal**
  de encerramento em falha, não a exceção: o container não grava mais `ERRO` (T5 removida). Uma DAG
  gerada sem o callback deixa a Execução aberta até a varredura — seis horas depois.
- **A DAG tem duas tasks e o retry fica só na segunda.** `abrir_execucao` roda uma vez; o
  `DockerOperator` retenta. A fábrica precisa gerar exatamente isso — pôr `retries` na primeira task
  criaria linhas duplicadas e bateria no índice único.

## Notas do ticket 29 (métricas e cardinalidade)

- **`dag_run_id` é proibido como label de métrica** (regra do ticket 29: label limitado por cadastro,
  nunca por uso). Ele continua sendo coluna em `execucao` e continua indo para o log — mas a
  correlação DAG run ↔ métrica não existe por label, e sim por Código de Relatório e janela de tempo.
- **O painel-resumo mostra "Coletas do dia: N ok / M erro"**, e é o destino padrão de quem abre o
  Grafana. Isso dá a este ticket um consumidor concreto: o agendamento precisa ser tal que "o dia"
  seja uma janela com significado — se as Coletas se espalharem pelas 24 horas, o painel deixa de
  responder "está tudo bem hoje?".
- **`coleta_partida_segundos`** mede o custo de subir o container. É o número que este ticket precisa
  para calibrar a folga de 120 s do `execution_timeout`, e ele só existe depois que algo rodar — então
  o primeiro agendamento é também a primeira medição.

## Notas do ticket 36 (varredura de órfãs)

- **A DAG de varredura é estática e NÃO é gerada pela fábrica.** Ela não tem Relatório associado, não
  deriva do inventário e não sobe container algum. A fábrica não deve tentar incluí-la — nem o
  inventário vazio deve fazê-la sumir.
- **Ela roda a cada 15 minutos**, independente do agendamento das Coletas. Isso é insumo para o
  paralelismo que este ticket precisa dimensionar: são 96 DAG runs diários que existem
  independentemente de quantos Relatórios houver.

## Answer

### O quadro

| | |
|---|---|
| Onde vive o agendamento | cron no cadastro do **Produto** |
| Granularidade da DAG | **uma por Relatório**, herdando o cron do Produto |
| Fonte da fábrica | **arquivo materializado pela API**, lido no parse |
| Concorrência | **pool dedicado** às Coletas |

### O agendamento é do Produto, não do Relatório

O que determina o horário é **quando a base de origem está pronta** — e a origem é o schema
transacional do Produto. Relatórios do mesmo Produto compartilham a origem, logo compartilham a
disponibilidade: essa é a grão natural da variável.

Cron por Relatório dava mais flexibilidade e foi recusado por duas razões. A variável real não é por
Relatório, e espalhar Coletas ao longo do dia quebra o **painel-resumo** do ticket 29 — "Coletas do
dia: N ok / M erro" deixa de responder "está tudo bem hoje?" se as Coletas ocupam 24 horas. Carga se
resolve com paralelismo, não com horário.

Fixar no código foi recusado pelo padrão que o ticket 21 já estabeleceu para `tempo_estimado`: o que
varia por ambiente vive no cadastro, sob o ADMINISTRADOR, e muda sem deploy.

### Uma DAG por Relatório

O ticket 19 fixou a granularidade da **task**; esta é a da **DAG**.

O argumento decisivo é o disparo manual. O ticket 20 exige `refazer` e `reprocessar` endereçando **um
Relatório e uma Data de Referência**. Com uma DAG por Produto, isso exigiria um parâmetro seletor e
tasks puladas — que é a forma da "DAG única parametrizada" que o ticket 13 descartou, só que em escala
de Produto.

Secundário, mas real: a falha fica precisa. Uma DAG vermelha é **um Relatório**, não "o Produto" com
quatro Relatórios que foram bem.

A alternativa de separar DAG agendada e DAG de disparo manual foi recusada por produzir **duas
definições do mesmo trabalho** — e a que diverge seria a menos exercitada, porque disparo manual é
raro.

- `dag_id = coleta_<CODIGO>`, com **tag do Produto**, o que recupera na UI o agrupamento que a DAG por
  Produto teria dado de graça.
- `max_active_runs_per_dag = 1` como defesa barata (o índice único parcial do ticket 20 já impede a
  sobreposição, mas custa nada declarar).

### A fábrica lê um arquivo, nunca a API

O FAQ do Airflow é explícito sobre a alternativa:

> *"Violating this time limit, often by **querying external services for dynamic DAGs**, can cause the
> service to deteriorate and DAG file processing to fail."*

Consultar a API no parse tornaria toda avaliação de DAG dependente de uma chamada de rede. API lenta
ou fora faz o parse travar, e passado o `dagbag_import_timeout` **as DAGs somem** — as Coletas param e
a causa não aparece em lugar nenhum óbvio.

Então: a API escreve um snapshot num volume que o dag processor lê, com a **interseção cadastro ∩
inventário já resolvida** (ticket 21), o cron do Produto e o `tempo_estimado` de cada Relatório. O
arquivo da fábrica só abre um arquivo local — barato, sem rede, sem timeout.

Ler o banco de controle direto foi recusado por furar a fronteira de ownership do ticket 04 e por
duplicar em Python a regra da interseção — duas implementações da mesma regra, que divergem. Gerar no
deploy foi recusado porque o ticket 21 decidiu que mudança de `tempo_estimado` muda a DAG **sem**
deploy.

> **Arquivo ausente ou corrompido: a fábrica levanta exceção, nunca gera zero DAGs.** Zero DAGs é
> indistinguível de "nenhum Relatório cadastrado" e passa por normal; erro de import aparece na UI do
> Airflow como erro. Fail-closed, como o resto do mapa.

**A API reescreve o arquivo a cada mudança de cadastro**, e o dag processor o pega no ciclo de parse
seguinte. Consequência a escrever na especificação: um Relatório cadastrado às 10h **aparece em
minutos e roda amanhã** — com `catchup=False` e `CronTriggerTimetable`, o primeiro disparo é a próxima
ocorrência do cron.

**DAG cuja definição saiu do arquivo deixa de existir.** Um Relatório removido do cadastro, ou cujo
bean saiu da imagem (ticket 21), some do snapshot e a DAG desaparece — não fica órfã no Airflow. O
histórico de runs some da UI junto, o que é aceitável porque a fonte de verdade do sistema é a tabela
`execucao`, não o Airflow.

### Fuso: o Airflow 3 mudou o chão

Apurado na documentação de upgrade:

> *"The default value for `catchup_by_default` has changed to **False**. Additionally,
> `create_cron_data_intervals` defaults to False, meaning **CronTriggerTimetable** will be used instead
> of CronDataIntervalTimetable for bare cron strings. If your DAGs rely on
> `data_interval_start`/`data_interval_end` or templated values like `ds`/`ts`, you may need to set
> `create_cron_data_intervals=True`."*

O projeto **já está imune**, e não por sorte: o ticket 20 fez a Data de Referência vir como parâmetro
explícito, nunca de `logical_date`. A fábrica não pode reintroduzir `{{ ds }}` sem trazer o problema
de volta — e o alerta do ticket 03 sobre `{{ ds }}` cru rotular errado toda Coleta agendada depois das
21h BRT continua valendo, agora com um segundo motivo.

- `schedule = CronTriggerTimetable(cron, timezone="America/Sao_Paulo")`.
- `start_date` timezone-aware via **pendulum** — o Airflow proíbe deliberadamente os objetos de fuso da
  biblioteca padrão.
- `catchup=False` **declarado na DAG**, mesmo já sendo o default: lá é default de *configuração*
  (`catchup_by_default`), que alguém pode virar globalmente. O argumento do ticket 20 continua de pé —
  backfill de datas antigas produziria enxurrada de `SEM_DADOS` legítimos, ruído sem valor, cada um
  consumindo um container.
- **`PYTZDATA_TZDATADIR=/usr/share/zoneinfo` na imagem do Airflow.** O pendulum usa base de fuso
  própria, *"not updated as frequently as the IANA database"*. `America/Sao_Paulo` é justamente um fuso
  cuja definição mudou na última década (fim do horário de verão em 2019).

### Concorrência: pool dedicado, e o botão que o pool não alcança

Um **pool nomeado com N slots**, consumido apenas pelo `DockerOperator`. É o único botão que limita a
coisa que importa — containers simultâneos — independentemente de quantas DAGs existirem.

Limite por DAG não compõe (dez DAGs × 1 dá dez simultâneas). O `parallelism` global contaria também
`abrir_execucao`, que é um `INSERT`, e a varredura de 15 em 15 minutos (ticket 36), que não sobe
container nenhum — o número que protege o banco ficaria poluído por tasks que não custam nada.

**A varredura não consome o pool.**

**Tamanho inicial: 4 slots.** Base: o research 06 estimou ~68 de `max_connections=100` já
comprometidas, restando ~32. Número para calibrar, não para acreditar — na linha do ticket 30, carga
calibra em vez de verificar.

> **O pool não basta sozinho.** O `minimumIdle` do HikariCP tem default **igual ao
> `maximumPoolSize` (10)**, então um container **ocioso** segura dez conexões. Dez containers zerariam
> o orçamento inteiro sem executar trabalho nenhum. O processador precisa fixar o pool em **2**: a
> Coleta é um tasklet single-thread (ticket 21) e não usa mais que isso.

### Derivado

- **`execution_timeout = 2 × tempo_estimado + 120 s` e `retries = 2`** vêm do ticket 24; a fábrica os
  calcula do snapshot, não decide nada.
- **`retries` fica só na segunda task** (ticket 24) — `abrir_execucao` roda uma vez.
- **`on_failure_callback` obrigatório** em toda task de Coleta (ticket 24), agora caminho principal de
  encerramento em falha.
- **O disparo manual ganhou endereço**: `refazer` e `reprocessar` disparam a DAG do próprio Relatório
  com `data_referencia` no `conf`. Uma DAG por Relatório é o que torna isso direto.
- **A DAG de varredura (ticket 36) não sai da fábrica** — é estática, não está no snapshot, e o
  snapshot vazio não deve fazê-la sumir.

## Notas do ticket 40 (primeiro Produto)

- **O primeiro cron concreto**: Produto Poupança em `0 3 * * *`, `America/Sao_Paulo`. Os dois
  Relatórios herdam-no, gerando `coleta_POUPANCA-0001` e `coleta_POUPANCA-0002`.
- **Os dois `execution_timeout` que a fábrica calcula ficam bem distintos** — 2×240+120 = 600 s e
  2×30+120 = 180 s. É o exemplo que mostra por que o timeout sai do cadastro por Relatório e não do
  Produto.

## Notas do ticket 41 (Produto Cliente)

- **Consequência não escrita da decisão deste ticket**: com o cron no cadastro do **Produto**, os dois
  Relatórios de um Produto compartilham frequência **obrigatoriamente**. O ticket 41 esbarrou nisso ao
  considerar "deltas diários + base completa mensal", que é o desenho natural de um domínio cadastral —
  e é inexpressável hoje.
- **Não reabre este ticket**: nenhum Produto decidido precisa de frequências distintas. Mas o próximo
  que precisar está diante de decisão de arquitetura (mover ou desdobrar o agendamento), não de
  exemplo — e o [ticket 43](43-produto-consorcio-schema-e-relatorios.md), com assembleia mensal, é o
  candidato mais provável.
- **Escalonamento de uma hora por Produto** vira padrão: Poupança 03:00, Cliente 04:00, e os três
  restantes em 05:00, 06:00 e 07:00. Com pool de 4 slots, dez Coletas partindo juntas só formariam fila
  e fariam `coleta_partida_segundos` disparar sem que nada estivesse errado.

## Notas do ticket 43 (Produto Consórcio)

- **O candidato mais provável a forçar a reabertura deste ticket não forçou.** O ciclo do Consórcio é
  mensal, mas a assembleia é propriedade do **grupo**, não da carteira: com centenas de grupos há
  assembleia todo dia útil, e a mensalidade nunca alcança o agendamento.
- **Com isso, os cinco Produtos do mapa cabem no cron por Produto** — a decisão deste ticket sobrevive
  intacta a todos eles. O que a testaria de verdade seria um Produto cujo evento não tem dispersão
  natural na carteira, e nenhum dos cinco é assim.
