# 21 — Contrato do Starter do Processador com Spring Batch

Type: grilling
Status: resolved
Blocked by: 01, 04, 19

## Question

O que exatamente o Starter oferece, e o que cada módulo de produto precisa implementar?

Este é o coração da arquitetura: cinco módulos processadores implementam o mesmo Starter. Definir a SPI.

Decidir:

- **O que o Starter faz sozinho**: leitura dos parâmetros de entrada, abertura do job, gravação dos metadados de início e fim, fill do Jasper, escrita no MinIO, escrita do CSV, telemetria, timeout duro, tratamento de erro.
- **O que o módulo de produto fornece**: a query (ou o `ItemReader`), o mapeamento para o datasource do Jasper, o JRXML, os parâmetros do relatório, o tempo estimado. Definir as interfaces concretas e como são descobertas (auto-configuration? anotação? arquivo de registro?).
- **Onde o fill acontece.** No Starter, uma vez por relatório — e isso colide com o ticket 22 (paginado vs não paginado). Resolver a ordem: este ticket define o esqueleto, o 22 decide se são um ou dois fills.
- **Estrutura do job**: quantos steps, chunk vs tasklet, e se a leitura do schema transacional é paginada. Um relatório grande não cabe em memória de uma vez, mas o `JasperPrint` é um objeto único em heap — declarar o limite prático.
- **Isolamento de leitura**: a regra "cada módulo lê exclusivamente do schema do seu produto" é imposta por credencial de banco separada por módulo, ou é convenção? A Coleta é a única fronteira de leitura.
- **Arquitetura interna de um módulo processador** (pendência explícita: "Definição da arquitetura de cada módulo e sua respectiva estrutura"): pacotes, camadas, onde vive o JRXML, onde vivem as fontes e imagens.
- **JobRepository**: configuração compartilhada vinda do Starter (ver ticket 04).

## Notas de research

- **Ticket 08**: o Airflow **não propaga contexto de trace** para processos externos, e a JVM não
  lê `TRACEPARENT` de variável de ambiente sozinha. A extração do `traceparent` e a abertura do
  span raiz do job viram **código do Starter** — responsabilidade a incluir explicitamente na SPI.
- **Ticket 06**: usar `JdbcPagingItemReader` na leitura em chunk. O pgjdbc só ativa cursor com
  autocommit off, `TYPE_FORWARD_ONLY`, statement único e `fetchSize>0`; faltando qualquer uma
  dessas condições ele **degrada em silêncio** e bufferiza o ResultSet inteiro em memória.

## Notas do ticket 04 (schema de controle)

- **O JobRepository saiu da SPI.** O Spring Batch 6 traz `ResourcelessJobRepository` como default e
  o ticket 04 adotou: sem `DataSource` para o Batch, sem tabelas `BATCH_*`. **Consequência direta
  para o Starter**: os steps são obrigatoriamente **single-thread** — o `ResourcelessJobRepository`
  *"is not thread-safe and should not be used concurrently"* — então nada de `TaskExecutor` no step
  nem particionamento. Isso precisa estar imposto pelo Starter, não deixado ao módulo, porque um
  módulo que adicionar paralelismo corrompe metadados em silêncio.
- **Isolamento de leitura está resolvido**: credencial de banco **por módulo**, com `SELECT` apenas
  no schema transacional do próprio Produto. Não é convenção — é `GRANT`. O Starter precisa assumir
  que o datasource transacional que recebe já é restrito.
- **Modo `--publicar-inventario` é parte do contrato do Starter.** A mesma imagem precisa suportar
  dois modos: rodar uma Coleta, e varrer os JRXML que carrega para publicar o inventário e sair. É o
  passo de bootstrap que torna possível o cadastro de Relatórios. Decidir aqui: como o modo é
  selecionado (argumento, perfil, variável), o que exatamente é publicado, e a idempotência.
- **Caso não decidido pelo ticket 04, que cai aqui**: um Relatório está cadastrado e a imagem
  seguinte não traz mais o seu JRXML. O que `--publicar-inventario` faz — remove do inventário,
  marca como ausente, ou falha o deploy? Interage com o ticket 37.
- **A Execução é aberta pelo Airflow (T1), não pelo container.** O Starter recebe o identificador de
  uma Execução que já existe em `EM_PROCESSAMENTO` e faz apenas a transição terminal, sempre com
  `AND status = 'EM_PROCESSAMENTO'`.
- **Zero linhas encerra sem gravar Artefato** (`SEM_DADOS`, ticket 02): o Starter precisa decidir
  isso **antes** do fill, não depois — é o que evita o `.jrprint` de zero páginas.

## Notas do ticket 19 (contrato Airflow ↔ container)

- **`main()` é `System.exit(SpringApplication.exit(ctx, ...))` — requisito do Starter, não do módulo.**
  Sem isso o `ExitCodeGenerator` não age, um job Batch falho sai com código 0, e todo o contrato de
  exit code cai. É o tipo de coisa que cada módulo erraria por conta própria; o Starter tem de
  entregá-la pronta.
- **Exit codes que o Starter produz**: 0 para `SUCESSO`, `ALERTA` e `SEM_DADOS`; 5 para `ERRO` gravado
  pelo próprio container; diferente de zero quando falha antes de conseguir registrar.
- **Uma execução do container = um Relatório.** A granularidade é por Relatório (ticket 19), então o
  Starter não precisa de laço sobre Relatórios nem de lógica de "pular o que já teve sucesso".
- **Entrada por variáveis de ambiente**, com o identificador da Execução **já aberta** entre elas. O
  Starter nunca insere a linha — só faz a transição terminal, guardada por
  `AND status = 'EM_PROCESSAMENTO'`.
- **Timeout interno menor que o `execution_timeout` do Airflow.** O Starter é quem implementa esse
  autotimeout, e ele existe porque a janela entre SIGTERM e SIGKILL é de ~10 s e não é configurável —
  esperar o Airflow matar é apostar em conseguir gravar `ERRO` nesses 10 s.
- **Uma imagem por módulo** (ticket 19), então o Starter não precisa de seletor de módulo.

## Answer

### Estrutura do job: um step, uma passada

O ticket nomeava uma tensão real — *"um relatório grande não cabe em memória de uma vez, mas o
`JasperPrint` é um objeto único em heap"* — e ela se resolve reconhecendo que **o fill do Jasper é
pull e o chunk do Spring Batch é push**. Os dois não compõem: encher uma coleção para depois passá-la
ao Jasper anula o propósito do chunk.

**Um step tasklet.** O Starter envolve a leitura da origem num `JRDataSource` que, a cada linha que o
Jasper puxa, escreve também a linha correspondente do `.csv.gz`.

Isso dá **uma única leitura** da base transacional e, mais importante, **garantia estrutural de que
PDF e CSV vieram das mesmas linhas** — que é precisamente a divergência que a análise comportamental
teme. A alternativa de dois steps (chunk para o CSV, tasklet para o fill) exigiria duas leituras e,
sem transação abrangente, as duas passadas poderiam ver dados diferentes: CSV com 1.000 linhas, PDF
com 1.003, reportado como bug e sendo real.

Spring Batch fica como casca de orquestração — job, step, listeners, exit code. Não há chunk nem
restart, e o `ResourcelessJobRepository` (ticket 04) não os oferece de qualquer forma.

**Memória**: fill com `JRVirtualizer`, passado via `JRParameter.REPORT_VIRTUALIZER` — configurado em
Java, não no JRXML. Três implementações disponíveis (`JRFileVirtualizer`, `JRSwapFileVirtualizer`,
`JRGzipVirtualizer`), com `maxPages` como botão: *"too low a value leads to unnecessary
virtualization, while too high a value can cause an out-of-memory exception before virtualization
begins"*.

### A SPI

**Um bean por Relatório**, implementando a interface do Starter:

```
codigo()                   -> "POUPANCA-0001"
jrxml()                    -> recurso no classpath do módulo
consulta()                 -> SQL + parâmetros
mapear(row)                -> campos do datasource do Jasper
tempoEstimadoSugerido()    -> opcional
```

O Starter os recebe por `ObjectProvider` e seleciona pelo `CODIGO_RELATORIO` da entrada, falhando de
forma clara se não houver bean correspondente.

**O inventário é a enumeração desses beans.** Essa é a propriedade que decidiu a escolha: um arquivo
de registro pode listar um Relatório cuja classe não existe, ou omitir uma que existe, e o inventário
publicado herdaria a divergência. Com beans, **declarar e poder executar são a mesma coisa**.

### O que cada lado faz

**Starter**: ler a entrada (variáveis de ambiente, incluindo o id da Execução já aberta em T1); extrair
o `traceparent` e abrir o span raiz do job — a JVM não lê isso de variável de ambiente sozinha
(research 08), então é código do Starter; selecionar o bean; abrir a leitura; **detectar zero linhas
antes do fill** e encerrar como `SEM_DADOS` sem gravar Artefato (ticket 02); decorar o `JRDataSource`
com a escrita do CSV; preencher com virtualizer; gravar `.jrprint` e `.csv.gz`; calcular SHA-256;
gravar `artefato` e a transição terminal guardada por `AND status = 'EM_PROCESSAMENTO'`; timeout
interno; `System.exit(SpringApplication.exit(ctx, ...))`; e o modo `--publicar-inventario`.

**Módulo**: os beans, os JRXML, as fontes e as imagens.

**Imposto pelo Starter, não deixado ao módulo**: step single-thread, sem `TaskExecutor` e sem
particionamento — o `ResourcelessJobRepository` *"is not thread-safe"*, e um módulo que adicionasse
paralelismo corromperia metadados em silêncio.

**Arquitetura interna do módulo** (pendência explícita do documento): um pacote por Relatório; JRXML
em `src/main/resources/jasper/`; fontes e imagens ao lado, como recursos do próprio módulo.

### `--publicar-inventario` é declarativo

O inventário publicado passa a refletir **exatamente** os beans presentes na imagem — não é
incremental.

Quando um Relatório cadastrado some da imagem, ele **sai do inventário** e o cadastro permanece,
sinalizado como "cadastrado, não publicado" — simétrico ao estado "publicado, não cadastrado" que o
ticket 04 já nomeou. **A fábrica de DAGs deixa de gerar DAG para ele**, e é isso que impede a porta
dos fundos do problema que o ticket 04 fechou pela frente: um cadastro sobrevivente a código
removido produziria um container diário condenado a falhar, virando `ERRO` legítimo e indistinguível
de falha real.

Falhar o deploy foi considerado — seria falha fechada, no espírito da allowlist do ticket 17 — mas
tornaria aposentar um Relatório uma coreografia (descadastrar, depois implantar) cuja inversão
quebraria o deploy inteiro, inclusive dos outros Produtos.

### Tempo estimado é dado de cadastro

A verdade vive em `relatorio.tempo_estimado_segundos`, sob o ADMINISTRADOR, porque depende do volume
de dados **daquele ambiente** e muda sem que o código mude. O bean expõe um valor **sugerido**,
publicado junto com o inventário, que a tela de cadastro oferece como ponto de partida — resolvendo o
Relatório recém-criado, que não tem histórico nem palpite.

Declará-lo no código faria produção, com dez vezes o volume de homologação, herdar o mesmo número — e
corrigir um timeout passaria a exigir build e deploy. Também moveria a guarda
`2 × tempo_estimado + margem ≤ LIMITE_ORFA` (ticket 02) do cadastro para o deploy.

### Duas consequências que valem mais que as decisões

**1. O limite prático de tamanho de um Relatório é o heap da API, não o do processador.**
O virtualizer resolve a memória da Coleta. Mas o ticket 18 pôs a desserialização e a exportação na
mesma JVM da API, sem isolamento — e ali o `.jrprint` inteiro volta ao heap. Dimensionar o container
processador não protege nada. Quem define o teto real é o ticket 25.

**2. A recomendação de `JdbcPagingItemReader` do research 06 não sobrevive a esta decisão**, porque
pressupunha processamento em chunk. O alerta que a acompanhava continua valendo, e fica mais
perigoso: o pgjdbc só ativa cursor com autocommit desligado, `TYPE_FORWARD_ONLY`, statement único e
`fetchSize > 0`, e **degrada em silêncio** para buffer completo do `ResultSet` se faltar qualquer uma
das quatro. O `JRDataSource` do Starter precisa **paginar internamente** ou satisfazer as quatro
condições **com teste que prove** — errar aqui produz exatamente o OOM que o virtualizer existe para
evitar, e sem sintoma até acontecer.

## Notas do ticket 37 (versionamento do JRXML)

- **O Starter ganha um passo no início do job**: calcular o `hash_definicao` dos beans presentes —
  SHA-256 sobre o recurso JRXML, a string da consulta e a lista ordenada de rótulos — e gravá-lo na
  Execução junto com o identificador da imagem. Não é o mesmo cálculo do `--publicar-inventario`: este
  registra **o que de fato rodou**, e é a diferença entre os dois que denuncia inventário obsoleto.
- **A entrada do hash tem de ser canônica.** Ordem fixa dos rótulos (a declarada no bean), encoding
  fixo, SQL literal. Se o hash mudar por reordenação de coleção, ele vira ruído e o mecanismo morre.
- **`mapear(row)` fica fora do hash** — é método, não dado. Cobertura vem do identificador da imagem.
  Consequência para a SPI: nada muda na interface, mas a documentação dela precisa dizer que mudar o
  mapeamento **não** move o hash.

## Notas do ticket 39 (agendamento e fábrica de DAGs)

- **O pool de conexões do processador precisa ser fixado em 2.** O `minimumIdle` do HikariCP tem
  default **igual ao `maximumPoolSize` (10)**, então um container ocioso segura dez conexões — dez
  containers simultâneos zerariam o orçamento de `max_connections` sem executar trabalho nenhum. A
  Coleta é um tasklet single-thread por decisão deste ticket, e não usa mais que duas.
- **A interseção cadastro ∩ inventário é materializada pela API num snapshot** que a fábrica de DAGs
  lê. A regra continua morando na API — a fábrica não a reimplementa.

## Notas do ticket 40 (primeiro Produto)

- **Os dois primeiros beans da SPI existem**: `POUPANCA-0001` (analítico, `tempoEstimadoSugerido` 240 s)
  e `POUPANCA-0002` (sintético, 30 s), com JRXML, consulta e rótulos escritos. É o formato que os
  outros quatro Produtos replicam.
- **Os rótulos vivem numa `List`, nunca num `Map` iterado** — a ordem declarada é a que entra no
  `hash_definicao` (ticket 37), e coleção não-ordenada faria o hash mudar sozinho.
- **A consulta do analítico é o caso de teste das quatro condições do pgjdbc** que este ticket
  levantou. O `ORDER BY` e o índice `ix_lancamento_data` fazem parte do contrato de desempenho: sem o
  índice, a leitura em cursor funciona e mesmo assim estoura o tempo estimado.
