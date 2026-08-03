# 04 — Schema de controle: modelo de dados e ownership

Type: grilling
Status: resolved
Blocked by: 02

## Question

Como é o schema de controle/aplicação, quem escreve e quem lê?

O documento já decidiu que existe um terceiro schema, separado dos schemas transacionais, escrito pelos processadores e lido pela API. A análise comportamental identifica isso como pré-requisito de praticamente todo o resto: sem ele não há listagem, nem status, nem histórico.

Decidir e escrever o DDL:

- **Metadados do relatório** (pendência explícita): tempo estimado de execução em segundos, nome do produto, nome, descrição. Quem cadastra, quando, e como se relaciona com o JRXML versionado no repositório.
- **Metadados de processamento** (pendência explícita): data/hora início, data/hora fim, status, e o que mais — Correlation ID, DAG run id, contagem de linhas, hash dos artefatos, motivo do reprocessamento.
- **Histórico de downloads**: o documento diz que não é expurgado junto com os relatórios. Qual o modelo, e como ele lida com apontar para artefatos que não existem mais.
- **Produtos, grupos e vínculos** — o que vive aqui e o que vive no Keycloak. Interage com o ticket 15.
- **JobRepository do Spring Batch**: vive neste schema, num schema próprio, ou noutro banco? Ele tem DDL próprio e migrações próprias.
- **Estratégia Flyway** com três naturezas de schema (transacional por produto, controle, JobRepository): um módulo de migração por schema? Quem roda o quê, e quando.
- **Credenciais e permissões**: processadores escrevem, API lê. Isso é usuário de banco separado com GRANT restrito, ou convenção?

## Notas de research

- **Ticket 06**: uma instância Flyway **por natureza de schema** (transacional, controle,
  JobRepository), cada uma com tabela de histórico própria — é o que a própria FAQ do Flyway
  recomenda para schemas com ciclos de vida autônomos. `baselineOnMigrate=false` sempre, já que o
  projeto nasce agora. JobRepository via Flyway com `initialize-schema=never`.
- **Ticket 06**: `jsonb` fica restrito a `parametros_entrada` e `detalhe_erro` — os "dados não
  estruturados" da descrição inicial são os Artefatos no repositório, não linhas de banco.
- **Ticket 10**: gravar **SHA-256** dos Artefatos aqui (o ETag foi descartado), que é o que o
  ticket 18 confere antes de desserializar.
- **Ticket 05**: gravar também a **versão do JasperReports** usada na Execução — como o
  `serialVersionUID` do Jasper é constante fixa, é o único jeito de detectar divergência.
- **Ticket 06**: o banco de metadados do Airflow precisa ser **instância separada**; o orçamento
  de conexões estimado é ~68 de `max_connections=100`, e o botão real é o paralelismo da DAG.

## Notas do ticket 02 (ciclo de vida)

O ticket 02 fixou a máquina de estados e isso impõe colunas, guardas e permissões aqui:

- **`status`** com cinco valores: `EM_PROCESSAMENTO`, `SUCESSO`, `ALERTA`, `SEM_DADOS`, `ERRO`.
  Terminal é imutável.
- **`linhas_processadas`** é obrigatório — é o que separa `SEM_DADOS` de `SUCESSO` na origem, e o
  que a UI usa para explicar a Execução vazia.
- **`detalhe_erro`** precisa carregar a **origem** do encerramento (container, callback do Airflow,
  varredura). É o que distingue "morreu de verdade" de "fechada por limite".
- **Não existe coluna de "expirado" nem de "atrasada"** — os dois são derivados na leitura. Ver a
  regra de materializado × derivado no ticket 02.
- **`data_expurgo_prevista`** do Artefato precisa existir, porque a listagem deriva "expirado" dela
  sem consultar o MinIO.
- **Guarda no cadastro de Relatório**: recusar `2 × tempo_estimado + margem > LIMITE_ORFA`. É o que
  torna seguro o limite global de órfã do ticket 02 — sem ela, a varredura fecha Execução viva.
- **Permissões**: o **Airflow** escreve neste schema (abertura da Execução em T1, callback em T6,
  varredura em T7), além dos processadores. A **API REST só lê** — nenhuma transição parte dela.
  Isso mantém a regra arquitetural da descrição inicial de pé, mas o histórico de downloads é
  escrito pela API, então a regra "escrita pelos processadores, leitura pela API" precisa ser
  reescrita aqui com os três escritores reais.
- **Toda escrita terminal** leva `AND status = 'EM_PROCESSAMENTO'` — primeiro escritor vence.

## Notas do ticket 03 (chave e data)

- **`data_referencia` é `DATE`**, calculada em `America/Sao_Paulo`, e significa o dia em que a
  Coleta rodou. **`inicio` e `fim` são `timestamptz` em UTC.** Data de calendário é do negócio,
  instante é UTC — a distinção precisa estar explícita no DDL e nos comentários de coluna.
- **Competência não existe como coluna.** Se um dia entrar, é coluna de metadados e nunca componente
  do caminho.
- **A chave completa do Artefato é gravada**, não recalculada. O caminho é determinístico
  (`{data}/{sigla}/{codigo}/{codigo}.jrprint`), mas gravá-lo permite mudar o layout sem reescrever
  histórico — e o histórico de downloads depende disso.
- **A unicidade (data_referencia, codigo_relatorio) é imposta em T1**, na abertura da Execução pelo
  Airflow, antes de subir container. Como o `forcar_reprocessamento` herda a data original, a
  constraint continua protegendo o reprocessamento.
- **Não há discriminador de execução no caminho** — no máximo um conjunto de Artefatos por par, e o
  reprocessamento sobrescreve.

## Answer

### O JobRepository desapareceu

O **Spring Batch 6 mudou o default**: a doc do `whatsnew` diz que ele *"defaults to a resourceless
batch infrastructure using `ResourcelessJobRepository`"*, o que *"eliminates the need for an
in-memory database for job repository metadata"*. O `DefaultBatchConfiguration` entrega
`ResourcelessJobRepository` + `ResourcelessTransactionManager`, **sem `DataSource`**. A doc descreve
o caso de uso quase palavra por palavra desta arquitetura: *"suitable for one-time jobs in their own
JVM where restartability and execution context sharing are not needed"*.

Decisão: **resourceless**. Some a terceira natureza de schema, a terceira instância Flyway, o DDL do
Batch e as conexões correspondentes do orçamento de ~68/100 do research 06. E some, principalmente,
um **segundo registro do que rodou** — `BATCH_JOB_EXECUTION` duplicaria parcialmente a Execução, que
é a fonte da verdade fixada no ticket 02.

Restrições aceitas, todas documentadas: o `ResourcelessJobRepository` *"is not thread-safe and should
not be used concurrently"*, logo **steps single-thread, sem particionamento**; não há restart de meio
de job (o retry é do Airflow, que sobe container novo e reabre a Execução); e não há bean de
`JobExplorer`.

### Naturezas de schema

```
transacional_<sigla>   um por Produto — lido exclusivamente pela sua própria Coleta
controle               metadados, artefatos, inventário, downloads
```

Uma instância Flyway por natureza, cada uma com tabela de histórico própria (research 06),
`baselineOnMigrate=false`.

### Tabelas

**`produto`** — `sigla` PK (imutável, ADR 0001), `nome` (mutável, apresentacional).

**`relatorio`** — `codigo` PK no formato `SIGLA-NNNN`, FK para `produto`, `nome`, `descricao`,
`tempo_estimado_segundos`.

> A guarda do ticket 02 — recusar `2 × tempo_estimado + margem > LIMITE_ORFA` — é **validação de
> aplicação, não `CHECK`**. `LIMITE_ORFA` é variável de ambiente, e uma constraint não enxerga
> configuração. Sem essa validação a varredura fecha Execução viva, então ela é obrigatória, não
> conveniência.

**`jrxml_publicado`** — o inventário: `codigo_relatorio`, módulo/imagem de origem, caminho do JRXML,
`publicado_em`. Ver "Inventário" abaixo.

**`execucao`** — `codigo_relatorio`, `data_referencia` (`DATE`, semântica `America/Sao_Paulo`),
`status` (5 valores), `inicio`/`fim` (`timestamptz` UTC), `linhas_processadas`, `correlation_id`,
`dag_run_id`, `versao_jasperreports` (ticket 05), `parametros_entrada` `jsonb`, `detalhe_erro`
`jsonb` com a **origem** do encerramento, e os campos de reprocessamento (`solicitante`, `motivo`,
nulos quando não houve).

> **Corrigido pelo ticket 19.** A unicidade era `UNIQUE (codigo_relatorio, data_referencia)` — total.
> O ticket 19 mostrou que a constraint total, somada à imutabilidade do terminal (ticket 02), torna o
> **retry do Airflow impossível**: o container falha, grava `ERRO`, e o retry não pode abrir linha
> nova nem reabrir a existente. Passa a ser **índice único parcial**:
>
> ```sql
> CREATE UNIQUE INDEX ON execucao (codigo_relatorio, data_referencia)
>   WHERE status NOT IN ('ERRO', 'SEM_DADOS');
> ```
>
> Cada tentativa vira uma linha; o histórico mostra as falhas anteriores; o terminal segue imutável.
> Continua imposta em T1, na abertura da Execução pelo Airflow.
>
> **`SEM_DADOS` entrou na exclusão pelo ticket 20**: uma Execução que não gravou Artefato algum não
> tem o que proteger, e o caso de origem atrasada (Coleta às 3h sem dados, dados chegando às 7h)
> passa a se resolver por disparo manual simples, sem `forcar_reprocessamento`.
>
> **Este índice é a regra de unicidade inteira** — não há checagem equivalente na aplicação. A API o
> consulta apenas para decidir qual verbo de disparo oferecer (`refazer` × `reprocessar`).

**`artefato`** — 1:N com `execucao`: `tipo` (`JRPRINT`, `CSV_GZ`, e o `JRPRINT_NAO_PAGINADO` que o
ticket 22 pode acrescentar), `chave` completa, `sha256`, `tamanho_bytes`, `data_expurgo_prevista`.
`UNIQUE (execucao_id, tipo)`.

> É tabela, e não colunas em `execucao`, porque é **grupo repetitivo**: o ticket 22 acrescenta um
> terceiro objeto sem migração de DDL, e cada objeto tem hash, tamanho e chave próprios.

**`relatorio_role_relatorio`** — N:N entre `codigo_relatorio` e `nome_role` (`REL_*`).

**`download`** — ver "Histórico" abaixo.

### Inventário: quem manda sobre quais Relatórios existem

O problema que isso fecha: a descrição inicial dá ao ADMINISTRADOR o "cadastro/remoção de
relatórios" **e** diz que cada Relatório tem JRXML versionado no seu módulo. Sem amarração, o
ADMINISTRADOR cadastra `POUPANCA-0007`, a fábrica de DAGs do research 13 cria a DAG, e todo dia um
container sobe e falha — virando `ERRO` legítimo na tabela, indistinguível de falha real. O caminho
inverso também: JRXML novo que ninguém cadastra nunca roda.

Decisão: **o banco é a fonte de verdade, validado contra o inventário publicado.** O ADMINISTRADOR
só consegue cadastrar Código que exista em `jrxml_publicado`. Relatório fantasma vira impossível, e
JRXML órfão fica visível como "publicado, não cadastrado".

**Como o inventário é publicado.** A mesma imagem do processador aceita um modo
`--publicar-inventario`: sobe, varre os JRXML que carrega, grava e sai. Roda num passo idempotente
do bootstrap do deploy.

Publicar no início de cada Coleta foi descartado por criar um ciclo fechado: sem inventário não há
cadastro, sem cadastro não há DAG, sem DAG nenhuma Coleta roda, e sem Coleta não há inventário — um
ambiente novo nunca sai do lugar. Gerar o inventário como arquivo no build foi descartado por criar
uma segunda representação dos JRXML, que diverge em silêncio se a geração não for imposta no CI.

### Histórico de Downloads: fotografia, não referência

Três coisas somem por baixo do histórico, não uma: o **Artefato** (retenção de 7 dias), o
**Relatório** (o ADMINISTRADOR remove) e o **usuário** (o GERENTE exclui RELATORes). E um efeito
mais lento: nome e descrição são mutáveis, então ler por join faz renomear um Relatório **reescrever
retroativamente** o que o histórico diz que a pessoa baixou.

Decisão: a linha de `download` copia o necessário para ser lida sozinha para sempre — `ocorrido_em`,
`usuario_sub`, `usuario_nome` (na época), `codigo_relatorio`, `relatorio_nome` (na época),
`sigla_produto`, `data_referencia`, `formato`, e `execucao_id` como FK **opcional**
(`ON DELETE SET NULL`), só para navegação.

Consequência boa: dispensa soft-delete em `relatorio` e em `execucao`. Um registro de auditoria é
uma fotografia, não uma vista.

### Fronteira com o Keycloak: sem espelho

Da cadeia `Relatório ← Role de Relatório ← Grupo ← Usuário`, o Keycloak representa nativamente os
três últimos elos. O que ele não sabe representar é o primeiro — ele não faz ideia do que é um
Relatório. Então:

- **Keycloak**: Usuário, Grupo, Role de Relatório, e os vínculos entre eles. Fonte única.
- **Schema de controle**: apenas `relatorio_role_relatorio`.
- As telas do GERENTE consultam a **Admin API ao vivo**.

Espelhar foi descartado por criar segunda fonte de verdade para dado de autorização, com janela em
que o espelho velho mostra — ou concede — acesso já revogado.

Isto **não** decide o ticket 15: ele segue livre para avaliar autorização por claim do JWT ou por
consulta, porque `relatorio_role_relatorio` é local nos dois casos.

### Credenciais: o banco impõe a fronteira

**Sete usuários de aplicação.** Cada processador recebe `SELECT` **apenas** no schema transacional do
seu próprio Produto, o que faz o PostgreSQL impor a regra arquitetural da única fronteira de leitura
em vez de confiar em disciplina de código.

```
app_proc_<sigla>   SELECT em transacional_<sigla>          (5 usuários)
                   INSERT/UPDATE em controle.execucao, controle.artefato
app_airflow        INSERT/UPDATE em controle.execucao       (T1, T6, T7)
                   nenhum acesso a schema transacional
app_api            SELECT em controle.*
                   INSERT em controle.download
                   nenhum acesso a schema transacional
```

Usuários de migração são separados, com DDL, usados só no bootstrap.

Isto é a proteção por Produto que o ticket 03 não pôde dar na camada do MinIO — lá o layout
data-primeiro tornou policy por prefixo impossível. No PostgreSQL não há essa restrição.

**A regra "escrita pelos processadores, leitura pela API" da descrição inicial está reescrita**: há
três escritores — processadores, Airflow e API (só `download`) — e um leitor amplo, a API.

### Bootstrap

```
1. flyway migrate  controle
2. flyway migrate  transacional_<sigla>   (um por Produto)
3. <imagem do processador> --publicar-inventario   (um por módulo)
4. API REST sobe
```

As migrações do `controle` vivem em `relatorios-comum` e rodam **como passo de bootstrap**, nunca no
arranque de um container de aplicação — senão sete containers disputam a mesma migração.

## Adendo do ticket 14 (escopo do GERENTE)

Duas coisas entram no schema depois deste ticket:

- **`controle.auditoria_admin`** — trilha das ações administrativas do GERENTE, denormalizada pelo
  mesmo motivo de `download`: usuários, Grupos e Roles podem ser apagados do Keycloak, e um registro
  que dependa de join morre junto. Colunas: `ocorrido_em`, `autor_sub`, `autor_nome` (snapshot),
  `acao`, `alvo_tipo`, `alvo_nome` (snapshot), `resultado` (`APLICADO` | `RECUSADO`),
  `motivo_recusa`, `correlation_id`. **Tentativas recusadas são gravadas** — com GERENTE global, é a
  única evidência de alguém tateando a fronteira.
- **Constraint em `relatorio_role_relatorio`**: todos os Relatórios vinculados a uma mesma Role de
  Relatório precisam pertencer ao **mesmo Produto**. O nome da role passou a carregar a Sigla
  (`REL_<SIGLA>_<NOME>`), então a constraint é o que impede o nome de virar mentira.
- **A linha de auditoria de exclusão de RELATOR guarda só o fato** (autor, `alvo_sub`,
  `alvo_username`, instante, Correlation ID) — sem e-mail, nome ou lista de Grupos. Risco aceito
  registrado no ticket 14.

## Adendo do ticket 15 (autorização)

- **`download` ganha marcação de bypass** — uma coluna que distingue o acesso concedido pelo Perfil
  ADMINISTRADOR do concedido por Role de Relatório. Sem ela, "o que os ADMINISTRADORes andaram
  baixando" exige inferência; com ela, é um `WHERE`.
- **`relatorio_role_relatorio` é consultada no caminho quente de toda listagem e toda geração**
  (`WHERE nome_role = ANY(...)`), porque a autorização passou a sair só da claim. É a consulta mais
  frequente do schema de controle — índice por `nome_role` é requisito, não otimização.

## Adendo do ticket 20 (idempotência e reprocessamento)

- **`download` não guarda o `sha256` do Artefato entregue.** Risco aceito registrado no ticket 20. A
  consequência é que a fotografia do Download deixa de ser autoverificável depois de um
  reprocessamento — que, por decisão do mesmo ticket, **apaga** a Execução anterior e suas linhas de
  `artefato`, levando junto o hash que permitiria a comparação.
- **`download.execucao_id` com `ON DELETE SET NULL` deixa de ser precaução teórica.** O
  reprocessamento apaga Execuções em produção, então esse caminho é exercitado de verdade e precisa
  de teste.
- **Um par pode ter várias linhas em `execucao`**: `ERRO`s e `SEM_DADOS`s acumulam, e no máximo uma
  `SUCESSO`/`ALERTA` ocupa o índice. Toda consulta de listagem precisa da regra de desempate — a
  linha que ocupa o índice, ou a `SEM_DADOS` mais recente na ausência dela.
- **Sem política de retenção para linhas de `execucao`**: ~3.650 por ano com dez Relatórios diários,
  mais as tentativas falhas.

## Adendo do ticket 24 (tolerância do tempo estimado)

- **Nova coluna: `inicio_processamento` (`timestamptz`)**, gravada pelo container quando a Coleta
  começa de fato. `ALERTA` e o timeout duro são avaliados sobre `fim − inicio_processamento`; a
  varredura de órfãs continua usando `inicio`. Sem essa separação, pull de imagem e partida da JVM
  entrariam na janela de alerta e disparariam `ALERTA` em toda execução de Relatório curto.
- **A guarda do cadastro ganhou as tentativas**: recusar quando
  `3 × (2 × tempo_estimado_segundos + 120) > LIMITE_ORFA`. Como o retry reusa a linha, as
  retentativas acumulam contra o mesmo `inicio`. Com `LIMITE_ORFA` de 6 h, o teto cadastrável fica em
  ~3.540 s (~59 min).
- **`tempo_estimado_segundos` é `NOT NULL` e maior que zero**, com valor sugerido vindo do inventário
  (ticket 21).
- **O container não grava mais `ERRO`** (T5 removida pelo ticket 24), então as escritas terminais
  vindas do processador são apenas `SUCESSO`, `ALERTA` e `SEM_DADOS`. Isso estreita o que a credencial
  `app_proc_<sigla>` precisa poder fazer.

## Adendo do ticket 16 (pendente de vínculo)

- **Nada de estado de usuário entra aqui.** "Pendente de vínculo" é membresia no Default Group
  `PENDENTES` do Keycloak, não flag no schema de controle — coerente com a decisão de não espelhar.
- **A vinculação é uma operação composta** (adicionar ao Grupo real **e** remover do `PENDENTES`), e
  ela gera **uma** linha em `controle.auditoria_admin`. Se as duas chamadas à Admin API não forem
  atômicas — e não são, são dois requests — a auditoria precisa refletir o resultado real, inclusive
  o caso de a segunda falhar e o usuário ficar nos dois grupos.

## Notas do ticket 37 (versionamento do JRXML)

- **Duas colunas novas em `execucao`**: `hash_definicao` (SHA-256) e `imagem_origem`, ao lado de
  `versao_jasperreports` — e pela mesma razão que aquela existe: divergência silenciosa precisa de
  fato gravado. Ficam como **colunas**, não dentro de `parametros_entrada`, porque este ticket
  restringiu `jsonb` a parâmetros e detalhe de erro, e valor que se compara entre linhas é coluna.
- **As mesmas duas colunas em `jrxml_publicado`.** Sem elas o inventário não tem contra o quê ser
  comparado, e a detecção de inventário obsoleto — que sai de graça — deixa de existir.
- **Quem escreve `jrxml_publicado` continua sendo só o bootstrap.** A auto-cura (o container reescrever
  a linha divergente) foi recusada em parte por isso: exigiria dar escrita nessa tabela à credencial de
  runtime, furando a fronteira de sete usuários deste ticket.

## Notas do ticket 39 (agendamento e fábrica de DAGs)

- **O cadastro de Produto ganha uma coluna `cron`.** O agendamento é do Produto, não do Relatório — o
  que determina o horário é quando a base transacional daquele Produto fica pronta. Precisa de
  validação de sintaxe e de uma guarda de granularidade mínima, senão um `* * * * *` sobe container a
  cada minuto.
- **A API materializa um snapshot para o Airflow**: a interseção cadastro ∩ inventário já resolvida,
  com o cron do Produto e o `tempo_estimado` de cada Relatório. Ela reescreve a cada mudança de
  cadastro. Isso torna a API a única leitora do schema de controle, preservando a fronteira de
  ownership deste ticket — a fábrica de DAGs **não** lê o banco.

## Notas do ticket 42 (Produto Conta Corrente)

- **`agencia` passou a existir duplicada** — uma cópia em `transacional_poupanca`, outra em
  `transacional_contacorrente`. É consequência direta do isolamento decidido aqui, não erro de
  modelagem.
- **Isso precisa estar escrito na especificação.** Sem o registro, a duplicação parece defeito e alguém
  a "conserta" com um schema compartilhado — derrubando o `GRANT` que é a única coisa impondo a
  fronteira de leitura por Produto, já que o layout do repositório S3 não pôde dar essa segregação.
