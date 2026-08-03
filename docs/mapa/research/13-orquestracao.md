# 13 — Orquestração: Airflow, cadastro de containers e DockerOperator

Pesquisa de apoio ao ticket [`13-stack-orquestracao.md`](../issues/13-stack-orquestracao.md).
Resolve a pendência explícita do documento fonte: *"Cadastramento de novos contêineres do Spring Batch no Apache Airflow"*.

Alimenta os tickets 19 (contrato Airflow ↔ container), 24 (timeout / tempo estimado), 26 (traceparent no batch) e 02 (ciclo de vida da execução).

Todas as versões e comportamentos abaixo foram conferidos contra fonte primária (documentação oficial, código-fonte no GitHub e a especificação W3C) em 2026-08-02.

---

## 1. Airflow: versão, modelo de DAG e execução em VM com Docker Compose

### 1.1 Versão corrente

- A documentação `stable` do Apache Airflow é a da série **3.3.0** — o cabeçalho de todas as páginas oficiais consultadas identifica "Airflow 3.3.0 Documentation" ([howto/docker-compose](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html), [dynamic-dag-generation](https://airflow.apache.org/docs/apache-airflow/stable/howto/dynamic-dag-generation.html)).
- O provider Docker corrente é o **`apache-airflow-providers-docker` 4.5.8**, com **versão mínima de Airflow suportada 2.11.0** e dependências `docker>=7.1.0`, `python-dotenv>=0.21.0`, `apache-airflow-providers-common-compat>=1.10.1` ([índice do provider](https://airflow.apache.org/docs/apache-airflow-providers-docker/stable/index.html)).

Consequência: o provider Docker é compatível tanto com Airflow 2.11 quanto com Airflow 3.x. Não há razão para começar um projeto novo em Airflow 2.

### 1.2 Modelo de DAG: TaskFlow vs clássico

Os dois modelos convivem e são intercambiáveis. O que muda é a forma de declarar:

- **Clássico**: instanciar operadores (`DockerOperator(...)`) dentro de um `with DAG(...)`.
- **TaskFlow**: decoradores `@dag` / `@task`, com o `airflow.sdk` como pacote público ([Task SDK API](https://airflow.apache.org/docs/task-sdk/stable/api.html)).

Existe também o decorador `@task.docker`, que empacota uma **função Python** e a executa dentro de um container — útil quando o código a rodar é Python ([tutorial TaskFlow](https://github.com/apache/airflow/blob/main/airflow-core/docs/tutorial/taskflow.rst), [decorator docs](https://github.com/apache/airflow/blob/main/providers/docker/docs/decorators/docker.rst)).

**Para este projeto o `@task.docker` é inadequado**: ele existe para rodar Python dentro do container; aqui o container é uma imagem Java pronta cujo *entrypoint* é o Spring Batch. O operador certo é o `DockerOperator` clássico. O decorador `@dag` pode ser usado para a casca da DAG — é questão de estilo, e a fábrica de DAGs (seção 4) fica mais legível com a API clássica `DAG(...)` porque precisa atribuir o objeto a `globals()`.

### 1.3 Docker Compose em VM — e o aviso oficial

O `docker-compose.yaml` oficial do Airflow define: `airflow-scheduler`, `airflow-dag-processor`, `airflow-api-server` (porta 8080), `airflow-worker`, `airflow-triggerer`, `airflow-init`, `postgres`, `redis` e o opcional `flower` (5555), com **CeleryExecutor** ([howto/docker-compose](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html)).

Requisitos declarados na mesma página:
- Docker Compose **≥ 2.14.0**;
- **mínimo 4 GB** de memória para o Docker (8 GB recomendado em macOS);
- em Linux, `AIRFLOW_UID` deve ser definido (`echo -e "AIRFLOW_UID=$(id -u)" > .env`), senão os arquivos saem com dono errado; o default é `50000`.

**Aviso relevante e desconfortável para este projeto**: a página afirma explicitamente que esse arranjo *"can be useful for learning and exploration. However, adapting it for use in real-world situations can be complicated and the docker compose file does not provide any security guarantees required for production system"*, e recomenda Kubernetes + Helm Chart oficial para produção.

Como Kubernetes está **fora de escopo** por decisão do documento (`docs/descricao-inicial.md`, seção "Fora de escopo"), este é um **trade-off assumido**, não um esquecimento — e precisa ser registrado como tal. Mitigações concretas, todas dentro do Compose:
- não expor a API do Airflow diretamente; publicá-la só atrás do Traefik com TLS;
- trocar `LocalExecutor` por `CeleryExecutor` só se houver necessidade real de paralelismo entre VMs (o `LocalExecutor` elimina Redis e o worker, reduzindo a superfície);
- não usar as credenciais de exemplo do arquivo (`airflow:airflow`).

### 1.4 ARM64

A imagem oficial do Airflow é **multi-arquitetura**: a documentação do docker-stack afirma que *"The images we release are multi-platform AMD/ARM images"* ([docker-stack](https://airflow.apache.org/docs/docker-stack/index.html)). As tags seguem `apache/airflow:3.3.0`, `apache/airflow:3.3.0-pythonX.Y` e as variantes `slim-`.

Ressalva registrada na mesma página: *"MySQL on ARM platform has experimental support through MariaDB client library"* — irrelevante aqui, porque o metadata database será PostgreSQL.

**Conclusão**: rodar Airflow em VM ARM64 é suportado. O que precisa de atenção é a **imagem do módulo processador Spring Batch**, que é construída pelo projeto — ela precisa ser buildada para `linux/arm64` (ou multi-arch via `docker buildx`), senão o `DockerOperator` falha no `docker run` com erro de plataforma. Isso é item de CI (ticket 33), não do Airflow.

---

## 2. Como disparar o container: DockerOperator vs BashOperator vs serviço do Compose

### 2.1 `DockerOperator`

Parâmetros relevantes, com defaults, conforme a [referência de API do operador](https://airflow.apache.org/docs/apache-airflow-providers-docker/stable/_api/airflow/providers/docker/operators/docker/index.html) e o [código-fonte](https://github.com/apache/airflow/blob/main/providers/docker/src/airflow/providers/docker/operators/docker.py):

| Parâmetro | Default | Nota |
|---|---|---|
| `image` | — (obrigatório) | templated; sem tag assume `latest` |
| `command` | `None` | templated |
| `environment` | `None` | dict, **templated** |
| `private_environment` | `None` | **não** templated, não aparece nos logs/UI — é onde vão as senhas |
| `env_file` | `None` | caminho para `.env`, templated |
| `docker_url` | `unix://var/run/docker.sock` ou `DOCKER_HOST` | aceita lista de hosts |
| `docker_conn_id` | `None` | conexão do Airflow (registry / TLS) |
| `auto_remove` | `"never"` | `never` \| `success` \| `force`; valor inválido levanta `ValueError` |
| `timeout` | `60` | **timeout das chamadas à API do Docker**, não do container |
| `xcom_all` | `False` | `False` → só a última linha do log vai para o XCom |
| `skip_on_exit_code` | `None` | exit codes que marcam a task como **skipped** |
| `mem_limit`, `cpus`, `network_mode`, `mounts`, `user`, `tty`, `force_pull`, `log_opts_max_size` | — | ver referência |

`template_fields = ('image', 'command', 'environment', 'env_file', 'container_name', 'mounts')`.

**Este é o fato mais importante da seção**: `environment` é campo templated. Ou seja, `{{ params.data_referencia }}`, `{{ params.codigo_relatorio }}`, `{{ dag_run.conf[...] }}` e o `traceparent` podem ser injetados como variáveis de ambiente do container **sem escrever código Python de runtime**.

Precedência de merge das variáveis, conforme o código-fonte: `env_file_vars` < `environment` < `_private_environment`.

**Cuidados de operação**:
- O worker precisa falar com um daemon Docker. Rodando o Airflow em containers do Compose, isso significa montar `/var/run/docker.sock` no worker — o que dá ao worker poder equivalente ao do host. A própria Docker reconhece o risco ao tratar do acesso ao daemon: quem tem a chave *"can give any instructions to your Docker daemon, giving them root access to the machine hosting the daemon"* ([protect the Docker daemon socket](https://docs.docker.com/engine/security/protect-access/)). A alternativa documentada é expor o daemon por TCP **com TLS** na porta 2376 e apontar `docker_url` para lá, usando `docker_conn_id`.
- `mount_tmp_dir` (default `True`) faz bind-mount de um diretório temporário criado pela task. Quando o worker é ele próprio um container, esse caminho não existe no host e o mount quebra — nesse arranjo, `mount_tmp_dir=False`.
- Os containers disparados são **irmãos** do worker, não filhos: nascem no daemon do host. Rede, DNS e volumes precisam ser resolvidos pela rede do Compose (`network_mode` com o nome da rede do projeto), não por `links`.

### 2.2 `BashOperator` chamando `docker run`

Funciona, e propaga exit code (shell retorna o código do `docker run`, que espelha o do container quando usado sem `-d`). O que se perde em relação ao `DockerOperator`:

- **`on_kill` correto.** O `DockerOperator` sabe qual container parar (seção 7). Um `BashOperator` mata o processo `docker run`; o container pode sobreviver órfão.
- **Distinção entre exit codes.** `skip_on_exit_code` não existe.
- **Segredos.** Não há equivalente a `private_environment`; a linha de comando renderizada aparece no log da task.
- **Escape.** Montar a linha de comando por template é fonte clássica de injeção quando o `codigo_relatorio` vem de `dag_run.conf`.

Vantagem única: não exige o provider nem a biblioteca `docker`, e o `docker` CLI já está na VM. É um plano B, não a escolha.

### 2.3 Serviço do Compose acionado externamente

Modelar cada processador como um serviço `docker compose run --rm processador-poupanca`. Herda todos os problemas do `BashOperator` e acrescenta um: o ciclo de vida do job passa a depender de um arquivo `docker-compose.yaml` que o Airflow não versiona nem conhece. Um processador novo exige editar o Compose **e** o Airflow — exatamente o oposto do que o ticket pede.

**Descartado.**

### 2.4 Critério de decisão

| Critério | `DockerOperator` | `BashOperator` + `docker run` | Serviço do Compose |
|---|---|---|---|
| Exit code → estado da task | nativo, com `skip_on_exit_code` | sim, sem granularidade | sim, sem granularidade |
| Logs do container no log da task | nativo (`attach` + stream) | via stdout do shell | via stdout do shell |
| Variáveis de ambiente com Jinja | nativo (`environment` templated) | manual, com risco de injeção | manual |
| Segredos fora do log | `private_environment` | não | via `env_file` |
| Cancelamento/timeout | `on_kill` para o container | mata o cliente, não o container | idem |
| Acoplamento ao cadastrar processador novo | só configuração | só configuração | Compose + Airflow |
| Dependência extra | provider `docker` + socket/TLS | nenhuma | nenhuma |

**Recomendado: `DockerOperator`.** Só troque por `BashOperator` se a política de segurança da VM proibir tanto o bind-mount do socket quanto o daemon sobre TLS.

---

## 3. Propagação de exit code e logs

### 3.1 Lado Airflow

O `DockerOperator` aguarda o container, lê `result["StatusCode"]` e decide ([código-fonte](https://github.com/apache/airflow/blob/main/providers/docker/src/airflow/providers/docker/operators/docker.py)):

```python
if result["StatusCode"] in self.skip_on_exit_code:
    raise DockerContainerFailedSkipException(...)
if result["StatusCode"] != 0:
    raise DockerContainerFailedException(...)
```

Ou seja:
- **exit code 0** → task `success`;
- **exit code em `skip_on_exit_code`** → task `skipped` (`DockerContainerFailedSkipException`);
- **qualquer outro exit code ≠ 0** → task `failed` (`DockerContainerFailedException`), com os logs capturados anexados à exceção.

Os logs são obtidos com `self.cli.attach(..., stream=True)` e processados por `fetch_logs()`, que decodifica bytes, junta linhas parciais e **emite cada linha no log da task**. Com `xcom_all=False` (default), **apenas a última linha** vai para o XCom; com `True`, todas. Alternativamente, `retrieve_output` + `retrieve_output_path` leem um pickle de um arquivo dentro do container em vez do log.

Nota operacional: `log_opts_max_size` (ex.: `"10m"`) limita o tamanho do log do container, e o operador configura `LogConfig` no `create_host_config`. Sem isso, um job com stack trace em loop enche o disco da VM.

### 3.2 Lado Spring Batch — o exit code **não sai de graça**

Este é o ponto onde a maioria dos projetos erra e o Airflow marca `success` para um job que falhou.

1. O Spring Boot executa o `Job` na subida: *"When Spring Boot auto-configures Spring Batch, and if a single `Job` bean is found in the application context, it is executed on startup"*; com múltiplos jobs é obrigatório `spring.batch.job.name` ([referência Spring Boot — Spring Batch](https://github.com/spring-projects/spring-boot/blob/main/documentation/spring-boot-docs/src/docs/antora/modules/reference/pages/io/spring-batch.adoc)).

2. A auto-configuração registra `JobLauncherApplicationRunner` **e** um `JobExecutionExitCodeGenerator` ([`BatchJobLauncherAutoConfiguration`](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-batch/src/main/java/org/springframework/boot/batch/autoconfigure/BatchJobLauncherAutoConfiguration.java)).

3. O `JobExecutionExitCodeGenerator` devolve o **ordinal do `BatchStatus`** da primeira execução com ordinal > 0 ([fonte](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-batch/src/main/java/org/springframework/boot/batch/autoconfigure/JobExecutionExitCodeGenerator.java)):

```java
public int getExitCode() {
    for (JobExecution execution : this.executions) {
        if (execution.getStatus().ordinal() > 0) {
            return execution.getStatus().ordinal();
        }
    }
    return 0;
}
```

4. A ordem do enum `BatchStatus` ([fonte Spring Batch](https://github.com/spring-projects/spring-batch/blob/main/spring-batch-core/src/main/java/org/springframework/batch/core/BatchStatus.java)) fixa os valores:

| `BatchStatus` | ordinal → exit code |
|---|---|
| `COMPLETED` | 0 |
| `STARTING` | 1 |
| `STARTED` | 2 |
| `STOPPING` | 3 |
| `STOPPED` | 4 |
| `FAILED` | **5** |
| `ABANDONED` | 6 |
| `UNKNOWN` | 7 |

5. **A armadilha**: um `ExitCodeGenerator` só surte efeito quando `SpringApplication.exit()` é chamado. A referência do Spring Boot é literal: *"beans may implement the `ExitCodeGenerator` interface if they wish to return a specific exit code **when `SpringApplication.exit()` is called**. This exit code can then be passed to `System.exit()` to return it as a status code"* ([Application Exit](https://github.com/spring-projects/spring-boot/blob/main/documentation/spring-boot-docs/src/docs/antora/modules/reference/pages/features/spring-application.adoc)). O `JobLauncherApplicationRunner` **não lança exceção** quando o job falha — ele apenas registra o `JobExecution`. Sem `System.exit(...)` explícito, o processo termina com **0** mesmo com o job em `FAILED`, e o Airflow marca a task como sucesso.

   Portanto o `main()` do starter do processador **precisa** ser da forma `System.exit(SpringApplication.exit(SpringApplication.run(...)))`. Isso vira requisito do ticket 19 e do ticket 21 (contrato do Starter).

   A mesma referência acrescenta que exceções podem implementar `ExitCodeGenerator`, e que *"if there is more than one `ExitCodeGenerator`, the first non-zero exit code that is generated is used"* — mecanismo pelo qual erros de negócio (par data+código já processado, por exemplo) podem carregar códigos próprios.

### 3.3 Tabela de exit codes proposta (insumo para o ticket 19)

Os ordinais do `BatchStatus` ocupam 0–7; usar valores acima disso para erros de negócio evita colisão.

| Exit code | Origem | Estado no Airflow | Estado na tabela de metadados |
|---|---|---|---|
| 0 | `COMPLETED` | `success` | processado com sucesso / com alerta (quem grava é o container) |
| 5 | `FAILED` | `failed` | processado com erro (gravado pelo container) |
| 4 | `STOPPED` (timeout duro, SIGTERM tratado) | `failed` | processado com erro |
| 10 | negócio: par data+código já processado sem `forcar_reprocessamento` | `failed` | processado com erro |
| 20 | negócio: sem dados na origem | `skipped` (via `skip_on_exit_code=[20]`) | "não executado" (ticket 02) |
| 137 | SIGKILL (OOM ou fim do grace period) | `failed` | fica órfã → resolvida pelo `on_failure_callback` |

O valor 137 (`128 + 9`) é a convenção de shell para morte por SIGKILL e é justamente o caso em que o container **não** conseguiu gravar o próprio encerramento — a razão de existir o callback da seção 6.

---

## 4. DAG por produto vs DAG única parametrizada — o cadastro de um processador novo

Esta é a pergunta central do ticket. O objetivo declarado: **um módulo processador novo passa a ser agendado sem editar código do Airflow.**

### 4.1 As formas documentadas de geração dinâmica

A página [Dynamic DAG Generation](https://airflow.apache.org/docs/apache-airflow/stable/howto/dynamic-dag-generation.html) documenta quatro caminhos:

1. **Variáveis de ambiente do SO** lidas em top-level code (`os.environ.get("DEPLOYMENT", "PROD")`). Rápido, mas exige reiniciar o dag-processor a cada mudança.
2. **Código Python gerado externamente** com os metadados embutidos (`my_company_utils/common.py` com `ALL_TASKS = [...]`), importado pela DAG. Exige `__init__.py` na pasta e `my_company_utils/*` no `.airflowignore`.
3. **Arquivo de configuração externo** (JSON/YAML) ao lado dos arquivos de DAG, localizado por `__file__`:

```python
my_dir = os.path.dirname(os.path.abspath(__file__))
configuration_file_path = os.path.join(my_dir, "config.yaml")
with open(configuration_file_path) as yaml_file:
    configuration = yaml.safe_load(yaml_file)
```

   A recomendação explícita da página é *"push the data by the Dag folder"* em vez de puxar de sistemas externos durante o parsing.

4. **Fábrica com `globals()`**, registrando cada DAG gerada ([FAQ](https://github.com/apache/airflow/blob/main/airflow-core/docs/faq.rst)):

```python
globals()[dag.dag_id] = create_dag(dag_id, schedule, dag_number, default_args)
```

   com a exigência de **DAG ids estáveis entre parses**, senão a DAG some da UI.

E uma otimização, disponível desde 2.4, para quando o número de DAGs geradas é grande:

```python
from airflow.sdk import DAG, get_parsing_context

current_dag_id = get_parsing_context().dag_id
for thing in list_of_things:
    dag_id = f"generated_dag_{thing}"
    if current_dag_id is not None and current_dag_id != dag_id:
        continue  # pula a geração das DAGs não selecionadas
    with DAG(dag_id=dag_id, ...):
        ...
```

A própria documentação alerta que isso *"is not always possible to use"* e exige teste de efeitos colaterais.

Alerta adicional da mesma página: tasks e task groups devem ser gerados em **sequência consistente** (use `sorted()`), senão reordenam no Grid View a cada parse.

### 4.2 Ler a configuração do banco de controle — o custo real

O caminho mais tentador é: a DAG lê a tabela de relatórios do schema de controle e gera uma DAG (ou uma task) por relatório cadastrado. Assim, cadastrar um relatório na UI **é** cadastrá-lo no Airflow.

A documentação de [best practices](https://github.com/apache/airflow/blob/main/airflow-core/docs/best-practices.rst) é explícita contra a versão ingênua disso:

- *"Using Airflow Variables in top-level code creates a connection to the metadata DB"*, com degradação de parsing e risco de timeout — e o mesmo raciocínio vale para qualquer query no top-level;
- o exemplo `expensive_api_call()` em top-level é listado como antipadrão porque *"runs every time the DAG file is processed by the scheduler"*.

Ou seja: **ler o banco a cada parse é possível e é feito na prática, mas paga o preço de uma query a cada intervalo de parsing, em cada processo de DAG-parsing.** Com dezenas de relatórios e uma query indexada isso é irrelevante; o que não pode existir é query lenta, sem timeout, ou sem `try/except` — uma exceção no top-level derruba **todas** as DAGs do arquivo.

Mitigação recomendada e barata: **materializar** a configuração. A API REST, ao cadastrar/remover um relatório, escreve um `relatorios.json` (ou `.yaml`) no diretório de DAGs. O dag-processor lê só o arquivo. Isso é exatamente o caminho 3 da documentação, com a recomendação de "push" atendida, e elimina o banco do caminho de parsing.

### 4.3 Distribuição dos arquivos: DAG bundles (Airflow 3)

O Airflow 3 substituiu a pasta estática de DAGs por **DAG bundles** ([dag-bundles](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/dag-bundles.html)):

- `LocalDagBundle` — diretório local, **sem versionamento**: as tasks sempre executam o código mais recente;
- `GitDagBundle` — *"supports versioning. Each Dag run records the Git commit it was created with, allowing reruns to use the exact same code even if the repository has since been updated"*;
- `S3DagBundle` / `GCSDagBundle` — existem, sem versionamento.

Configuração via `[dag_processor] dag_bundle_config_list`, com `refresh_interval` controlando de quanto em quanto tempo o dag-processor procura arquivos novos, e `rerun_with_latest_version` decidindo se o rerun usa o código original ou o atual.

Isso é diretamente relevante: como o projeto é **mono repositório no GitHub**, o `GitDagBundle` apontando para o repo dá versionamento de DAG de graça e resolve a distribuição para scheduler/dag-processor/workers sem volume compartilhado. O contraponto é que, com `GitDagBundle`, o `relatorios.json` materializado pela API REST **não** pode viver no bundle — ele viveria num volume separado ou voltaria ao caminho "ler do banco".

### 4.4 As três opções, com critério de decisão

**Opção A — um arquivo de DAG por produto, versionado no repositório.**
Cinco arquivos hoje (Poupança, Cliente, Conta Corrente, Consórcio, Empréstimo). Simples, auditável, diff legível no PR, cada produto com seu próprio `schedule`.
Custo: **cadastrar um processador novo exige um commit no repositório do Airflow** — que aqui é o mesmo mono repo, o que reduz muito a dor. Cadastrar um *relatório novo dentro de um produto existente* também exige commit, se a granularidade da task for por relatório.

**Opção B — DAG única parametrizada.**
Uma DAG só, que recebe `codigo_relatorio` por `params`. Zero manutenção ao nascer um processador.
Custo alto: não há agendamento por produto (um `schedule` só para todos), o histórico de todos os produtos vira uma pilha só no Grid View, `max_active_runs` passa a ser global, e uma falha em Poupança fica visualmente indistinguível de uma falha em Consórcio. Também colide com o `execution_timeout`, que é atributo estático da task e não pode variar por "tempo estimado" do relatório sem um segundo mecanismo.

**Opção C — fábrica de DAGs a partir de configuração (recomendada).**
Um único arquivo `dag_factory.py` versionado, que lê o inventário de produtos/relatórios (arquivo materializado ou tabela de controle) e emite uma DAG por produto via `globals()[dag_id] = build_dag(produto)`, com uma task `DockerOperator` por relatório.
Ganha o que interessa: **cadastrar um produto novo é inserir uma linha na configuração**; o Airflow não é editado. Mantém agendamento, retry, timeout e histórico por produto. Permite `execution_timeout` por relatório, porque cada task é construída a partir do "tempo estimado" cadastrado (ticket 24).
Custo: um arquivo Python que exige teste — e é o teste que evita que uma configuração ruim derrube todas as DAGs.

| Critério | A: arquivo por produto | B: DAG única | C: fábrica |
|---|---|---|---|
| Processador novo sem editar Airflow | não | sim | **sim** |
| Agendamento independente por produto | sim | não | **sim** |
| `execution_timeout` por relatório | sim | não | **sim** |
| Histórico/UI legível por produto | sim | não | **sim** |
| Risco de derrubar tudo com 1 erro | baixo | médio | **médio** (mitigável com teste de parsing no CI) |
| Custo de parsing | baixo | baixo | médio (mitigável com materialização) |

**Recomendação: C**, com a configuração materializada em arquivo pela API REST, `dag_id = f"coleta_{produto}"` estável, ordenação determinística (`sorted()`) e um teste no CI que importa o arquivo e falha se qualquer DAG deixar de ser gerada.

---

## 5. Parâmetros de DAG run e restrição a ADMINISTRADOR

### 5.1 `params` (com validação) vs `dag_run.conf`

O Airflow oferece `Param`, com validação por **JSON Schema** ([core-concepts/params](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/params.html)):

```python
from airflow.sdk import DAG, Param

with DAG(
    "coleta_poupanca",
    params={
        "data_referencia": Param(None, type=["null", "string"], format="date"),
        "codigo_relatorio": Param(None, type=["null", "string"]),
        "forcar_reprocessamento": Param(False, type="boolean"),
        "solicitante": Param(None, type=["null", "string"]),
        "motivo": Param(None, type=["null", "string"]),
        "correlation_id": Param(None, type=["null", "string"]),
    },
) as dag:
    ...
```

Fatos que importam:
- Atributos suportados incluem `type`, `enum`, `minimum`/`maximum`, `minLength`/`maxLength` e `format` (`date`, `date-time`, `time`, `duration`, `multiline`, `idn-email`).
- **Timing da validação**: *"If `schedule` is defined for a Dag, params with defaults must be valid. This is validated during Dag parsing. If `schedule=None` then params are not validated during Dag parsing but before triggering a Dag."* Como as DAGs de coleta **têm** `schedule`, os defaults precisam ser válidos — daí `type=["null", "string"]` nos campos que só existem em disparo manual.
- Params definidos rendem o formulário do "Trigger DAG w/ config" na UI.
- Por default os templates renderizam string; `render_template_as_native_obj=True` preserva o tipo — necessário para `forcar_reprocessamento` chegar como booleano se ele for consumido em Python. Como aqui ele vira **variável de ambiente do container** (string), isso é dispensável: basta o contrato do ticket 19 declarar `"true"`/`"false"`.
- `core.dag_run_conf_overrides_params=False` transforma os defaults em constantes e impede override no trigger — **não** usar aqui, porque o reprocessamento depende do override.
- No template, o acesso é `{{ params.x }}`; `{{ dag_run.conf["x"] }}` também funciona, mas **só em campos templated de operadores** ([dag-run](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html)). Como `environment` do `DockerOperator` é templated, ambos servem — prefira `params`, porque só ele valida.

Nota do doc de DAG runs, relevante para "data de referência": *"do not assume the run's `data_interval` is derived from, or equal to, the supplied `logical_date`"* em disparos manuais. Ou seja: **não** derive a data de referência de `logical_date`/`ds` no caminho manual. Passe-a explicitamente por `params`, e use `{{ ds }}` apenas como default do caminho agendado.

### 5.2 Disparo externo pela API REST

Três formas documentadas de trigger manual ([dag-run](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html)): CLI (`airflow dags trigger --conf '{"conf1": "value1"}' example_dag`), UI, e **REST API / `TriggerDagRunOperator`**.

A rota para o módulo API REST do projeto é a REST API v2: `POST /api/v2/dags/{dag_id}/dagRuns`, com corpo JSON contendo `conf` e `logical_date` (o `logical_date` pode ser `null` para rodar imediatamente, mas **não pode ser omitido** — corpo vazio devolve 422).

Autenticação em Airflow 3 é **JWT**: *"Each request made to the Airflow API must include a valid JWT token in the `Authorization` header"*, obtido via `POST /auth/token` do auth manager configurado ([security/api](https://airflow.apache.org/docs/apache-airflow/stable/security/api.html)). O endpoint `/auth/token` é provido pelo auth manager, então o detalhe do fluxo depende de qual auth manager estiver ativo.

### 5.3 Como restringir a ADMINISTRADOR

O documento exige que o `forcar_reprocessamento` seja restrito a ADMINISTRADOR e que cada uso registre solicitante, motivo e Correlation ID.

**Não tente resolver isso com as permissões do Airflow.** Duas razões:
1. As roles do projeto vivem no Keycloak e viajam no JWT da aplicação (regra arquitetural do documento). Duplicá-las no auth manager do Airflow cria duas fontes de verdade de autorização.
2. O documento exige **registro** de solicitante e motivo — isso é uma escrita na tabela de auditoria da aplicação, que o Airflow não faz.

Desenho recomendado:
- A UI **nunca** fala com o Airflow. O Airflow não é exposto ao usuário final pelo Traefik (ou é exposto só para operação, com autenticação própria).
- O módulo API REST expõe `POST /reprocessamentos`, valida o JWT do Keycloak exigindo a role ADMINISTRADOR, exige `motivo` não vazio, grava a auditoria (solicitante + motivo + Correlation ID) e **só então** chama `POST /api/v2/dags/{dag_id}/dagRuns` com uma credencial de serviço dedicada.
- O `conf` enviado carrega `data_referencia`, `codigo_relatorio`, `forcar_reprocessamento=true`, `solicitante`, `motivo` e `correlation_id` — de forma que o container receba os mesmos valores e os grave nos metadados da execução.
- `dag_run_id` determinístico (ex.: `manual__{codigo_relatorio}__{data_referencia}__{n}`) dá idempotência ao POST: um retry da API REST colide em vez de disparar duas execuções.

Assim a autorização fica num lugar só, e a "restrição a ADMINISTRADOR" é uma regra da aplicação, não uma configuração do Airflow.

---

## 6. `on_failure_callback`

### 6.1 Tipos, assinatura e contexto

A [página de callbacks](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/callbacks.html) lista cinco:

| Callback | Quando |
|---|---|
| `on_success_callback` | DAG ou task com sucesso |
| `on_failure_callback` | DAG ou task falha |
| `on_retry_callback` | task entra em retry (só task) |
| `on_execute_callback` | imediatamente antes da execução (só task) |
| `on_skipped_callback` | task levanta `AirflowSkipException` (só task) |

A assinatura é `def callback(context)`; *"a context mapping that contains runtime information about a task instance is passed to every callback"*. Desde o Airflow 2.6 aceita **lista** de callbacks: `on_failure_callback=[func1, func2]`.

O que há no contexto, conforme a [templates reference](https://airflow.apache.org/docs/apache-airflow/stable/templates-ref.html):
- `dag`, `dag_run`, `run_id`, `ti` / `task_instance`, `task`, `params`, `macros`, `data_interval_start`/`end`;
- `logical_date`, `ds`, `ts` — **só em DAGs baseadas em tempo**;
- **`exception`** — *"Error occurred while running task instance"*, disponível em callbacks de erro.

Portanto o callback tem tudo o que o ticket 02 precisa: `dag_run.conf` (para recuperar `data_referencia` e `codigo_relatorio`), `params`, `ti.task_id`, `run_id` e a exceção (que, no caso do `DockerOperator`, é a `DockerContainerFailedException` com os logs capturados).

### 6.2 Onde o callback roda

Confirmado no código do Task SDK ([`task_runner.py`](https://github.com/apache/airflow/blob/main/task-sdk/src/airflow/sdk/execution_time/task_runner.py)): na finalização, `elif state == TaskInstanceState.FAILED: _run_task_state_change_callbacks(task, 'on_failure_callback', context, log)`. Ou seja, o callback roda **no processo da task, no worker**, depois da execução e antes do processo terminar. Consequência prática: ele tem acesso à rede e às conexões do worker — pode abrir conexão com o schema de controle no PostgreSQL e fazer o `UPDATE` para "processado com erro".

Cuidado documentado: *"Errors in callback functions will show up in dag processor logs rather than task logs"*, em `$AIRFLOW_HOME/logs/dag_processor/latest/dags-folder/<path>/DAG_FILE.py.log`. Um callback que falha silenciosamente é um job que fica "em processamento" para sempre. **O callback precisa de log próprio e de teste.**

### 6.3 O buraco — insumo direto para o ticket 02

A mesma página traz a restrição decisiva: os callbacks *"are only invoked when the Dag or task state changes due to execution by a worker"*, e **mudanças via CLI ou UI não disparam callbacks**.

Isso significa que o `on_failure_callback` **não cobre**:
- um operador marcando a task como failed na UI;
- a VM inteira caindo (o processo da task morre sem chegar à finalização);
- o scheduler marcando a task como `failed` por *zombie detection* após o worker sumir — não há processo de task vivo para rodar o callback.

Ou seja: o documento afirma que "o Airflow atualizará a execução para 'processado com erro' através do callback de falha da task". **Isso é verdade para o caso comum (container morreu, exit code ≠ 0) e falso para os casos de infraestrutura.** O ticket 02 precisa, além do callback, de um **job de varredura** que marque como erro toda execução em "em processamento" há mais tempo que o dobro do tempo estimado. Ele pode ser uma DAG do próprio Airflow rodando a cada N minutos.

Nota adicional: a feature de SLA do Airflow 2 **foi removida no 3.0** e substituída por *Deadline Alerts* no 3.1 ([tasks](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html)); há `DeadlineAlert` com `DeadlineReference.DAGRUN_LOGICAL_DATE` no Task SDK. Não confie em material antigo sobre `sla_miss_callback`.

---

## 7. Timeout: `execution_timeout` vs timeout duro no container

### 7.1 O que cada um faz

- **`execution_timeout`** é um atributo da task, do tipo `timedelta`, que define *"the maximum permissible runtime"*; ao estourar, levanta `AirflowTaskTimeout` ([tasks](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html)). A mesma página deixa claro que a task pode ainda entrar em retry após um `AirflowTaskTimeout`, e que retry **não** reseta o contador do `timeout` de sensores.
- **`dagrun_timeout`** existe no nível da DAG ([Task SDK](https://airflow.apache.org/docs/task-sdk/stable/api.html)) e serve como rede de segurança do run inteiro.
- **`timeout=60`** do `DockerOperator` **não é** timeout de execução: é o timeout das chamadas à API do Docker.

### 7.2 A cadeia exata de eventos (quem mata quem)

Juntando o código do Task SDK e o do provider Docker:

1. `execution_timeout` estoura. O Task SDK executa o callable dentro de `with timeout(timeout_seconds):` e trata:
   ```python
   except AirflowTaskTimeout:
       task.on_kill()
       raise
   ```
   ([`task_runner.py`](https://github.com/apache/airflow/blob/main/task-sdk/src/airflow/sdk/execution_time/task_runner.py)). O mesmo arquivo registra um handler de SIGTERM que também chama `ti.task.on_kill()`.

2. `DockerOperator.on_kill()` para o container ([fonte](https://github.com/apache/airflow/blob/main/providers/docker/src/airflow/providers/docker/operators/docker.py)):
   ```python
   def on_kill(self) -> None:
       if self.hook.client_created:
           self.log.info("Stopping docker container")
           if self.container is None:
               return
           self.cli.stop(self.container["Id"])
           if self.auto_remove == "force":
               ...
   ```

3. `cli.stop()` é chamado **sem `timeout`**. No `docker-py`, quando `timeout is None` o parâmetro `t` **não é enviado** à API, e o daemon aplica o `StopTimeout` do container ([`docker/api/container.py`](https://github.com/docker/docker-py/blob/main/docker/api/container.py)).

4. O daemon envia **SIGTERM** (ou o `STOPSIGNAL` da imagem) e, se o container não sair, envia **SIGKILL** após o timeout — cujo default é **10 segundos em Linux** ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

5. O `AirflowTaskTimeout` segue para `_handle_current_task_failed(...)`, que decide entre retry e falha, e em seguida o `on_failure_callback` roda no processo da task.

### 7.3 As consequências que o ticket 24 precisa absorver

**(a) O container tem cerca de 10 segundos entre SIGTERM e SIGKILL** — e o `DockerOperator` **não expõe** parâmetro para alterar isso. O único jeito de aumentar essa janela é definir o `StopTimeout` na própria imagem/criação do container (`--stop-timeout`) ou tratar o SIGTERM muito rápido. Isso é decisivo: **o container precisa conseguir gravar "processado com erro" em menos de 10 segundos após o SIGTERM.** Um `shutdown hook` do Spring Boot que tenta fechar um `JobRepository` congestionado não cabe nessa janela. O desenho seguro é: handler de SIGTERM que faz **um único `UPDATE`** com conexão dedicada e timeout curto, e só depois tenta o encerramento gracioso.

**(b) Quem deve estourar primeiro.** O documento diz que ao atingir o **dobro do tempo estimado** a execução é interrompida por timeout duro e encerrada como "processado com erro" — e que a tabela de metadados é a fonte da verdade. Para que o registro seja escrito pelo próprio container (o caminho confiável), o **timeout interno do container deve disparar antes** do `execution_timeout` do Airflow:

```
timeout interno do container = 2 × tempo_estimado
execution_timeout do Airflow  = 2 × tempo_estimado + margem (ex.: 120 s)
```

Assim, no caso normal: o container se autointerrompe, grava "processado com erro", sai com exit code próprio (4 ou 5), o Airflow marca `failed` e o `on_failure_callback` encontra a execução **já** encerrada — e não faz nada (deve ser idempotente: só atualiza execuções que ainda estejam em "em processamento").
No caso patológico (o container travou e nem o timeout interno funcionou): o `execution_timeout` do Airflow dispara, `on_kill` para o container, SIGKILL após ~10 s, e o `on_failure_callback` faz a reconciliação. É exatamente o cenário para o qual o callback existe.

**(c) `retries` precisa ser 0 ou tratado.** Com `retries > 0`, um retry após timeout reexecutaria a mesma combinação data+código e seria **rejeitado pela regra de unicidade** — a menos que o contrato do ticket 19 distinga "retry técnico" de "reprocessamento". Alternativa limpa: `retries=0` nas tasks de coleta, deixando o reprocessamento como ato explícito do ADMINISTRADOR.

---

## 8. `traceparent` como variável de ambiente do container

### 8.1 O formato

A especificação W3C Trace Context define o `traceparent` como `version-trace-id-parent-id-trace-flags` ([W3C TR trace-context](https://www.w3.org/TR/trace-context/)):

- **version**: 2 dígitos hex (`00`); `ff` é inválido;
- **trace-id**: **32** dígitos hex minúsculos (16 bytes); todos zeros é inválido;
- **parent-id** (span id): **16** dígitos hex minúsculos (8 bytes); todos zeros é inválido;
- **trace-flags**: 2 dígitos hex; hoje só o bit menos significativo importa — `sampled`.

Exemplo canônico: `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`.

Há também `tracestate`, com pares chave-valor de fornecedor, até 256 caracteres por valor e propagação de pelo menos 512 caracteres combinados.

### 8.2 O nome da variável

Não há convenção **normativa** da OpenTelemetry para propagar contexto por variável de ambiente. O que existe é uma convenção **de facto**, consolidada no ecossistema de CI/CD (otel-cli, plugins de CI), de usar `TRACEPARENT` e `TRACESTATE` — os mesmos nomes dos headers W3C, em maiúsculas. As convenções semânticas de CI/CD da OpenTelemetry seguem em evolução ([issue 915 de semantic-conventions](https://github.com/open-telemetry/semantic-conventions/issues/915), [OTEP 223](https://github.com/open-telemetry/oteps/pull/223/files), [semconv](https://opentelemetry.io/docs/specs/semconv/)).

**Recomendação**: usar `TRACEPARENT` (e opcionalmente `TRACESTATE`), documentando no ticket 19 que é convenção do projeto ancorada na de facto, não em norma.

### 8.3 De onde sai o trace id no lado Airflow

O Airflow pode emitir seus próprios traces OTel, com `[traces] otel_on=True`, `otel_host`, `otel_port`, `otel_application`, `otel_ssl_active`, `otel_task_log_event`, além das variáveis padrão `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_EXPORTER_OTLP_PROTOCOL`; a instalação exige `pip install 'apache-airflow[otel]'` ([traces](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/traces.html)). DAG authors podem criar spans customizados com o objeto `trace` de `airflow.sdk.observability`, e *"custom spans created this way are automatically nested as children of the Airflow-managed task span when tracing is enabled"*.

**Mas**: a documentação **não** expõe uma API para ler o contexto do span corrente e transformá-lo em `traceparent`, nem documenta propagação para processos externos. Duas alternativas, portanto:

**Opção 1 — derivar deterministicamente do `run_id` (recomendada).**
Um `trace_id` de 32 hex e um `span_id` de 16 hex derivados de um hash estável de `(dag_id, run_id)` e `(dag_id, run_id, task_id)`. Vantagens: nenhum acoplamento à instrumentação do Airflow; funciona com `otel_on=False`; é **reprodutível** — dado um DAG run, qualquer pessoa recalcula o Correlation ID e busca no Graylog. É injetado por uma função Jinja/`user_defined_macros` ou calculado na fábrica de DAGs. Cuidado obrigatório: rejeitar o resultado se der todos zeros (inválido pela spec).

**Opção 2 — usar o span real do Airflow.**
Dentro de uma task Python, `opentelemetry.trace.get_current_span().get_span_context()` devolve `trace_id`/`span_id`; formata-se o `traceparent` e empurra-se por XCom para a task `DockerOperator` seguinte. Vantagem: o trace do batch fica realmente aninhado no trace do Airflow. Custo: uma task extra por relatório e dependência de `otel_on=True` estar ativo.

Em qualquer das duas, a injeção no container é trivial porque `environment` é templated:

```python
DockerOperator(
    task_id=f"coleta_{codigo_relatorio}",
    image=imagem_do_produto,
    environment={
        "DATA_REFERENCIA": "{{ params.data_referencia or ds }}",
        "CODIGO_RELATORIO": codigo_relatorio,
        "FORCAR_REPROCESSAMENTO": "{{ params.forcar_reprocessamento | lower }}",
        "TRACEPARENT": "{{ traceparent() }}",
    },
    private_environment={"DB_PASSWORD": "...", "MINIO_SECRET_KEY": "..."},
    ...
)
```

(As senhas vão em `private_environment` justamente porque ele **não** é templated e não aparece nos logs nem na UI.)

### 8.4 Lado Java — como o `traceparent` vira o span raiz do job

A API Java da OpenTelemetry extrai contexto de qualquer *carrier* via `TextMapPropagator` + `TextMapGetter` ([OpenTelemetry Java API](https://opentelemetry.io/docs/languages/java/api/)):

```java
ContextPropagators propagators = ContextPropagators.create(
    TextMapPropagator.composite(
        W3CTraceContextPropagator.getInstance(),
        W3CBaggagePropagator.getInstance()));

Context extractedContext = propagators
    .getTextMapPropagator()
    .extract(Context.current(), carrier, textMapGetter);

try (Scope scope = extractedContext.makeCurrent()) {
    Span jobSpan = tracer.spanBuilder("coleta").startSpan();
    ...
}
```

O *carrier* aqui é simplesmente um `Map<String, String>` com `{"traceparent": System.getenv("TRACEPARENT")}`. O span do job nasce como **filho** do span do DAG run, e o `traceId` alimenta o MDC — que é exatamente o Correlation ID exigido pelo documento.

Isso resolve metade do ticket 26. A outra metade (o que fazer quando **não** há `TRACEPARENT`, por exemplo em teste com o SDK desabilitado) continua sendo decisão daquele ticket; o contrato mínimo a fixar aqui é: **se `TRACEPARENT` estiver ausente ou malformado, o container gera um trace id próprio e segue** — nunca falha por causa disso.

---

## 9. Pontos que este ticket entrega para os seguintes

- **Ticket 19 (contrato Airflow ↔ container)**: `environment` templated como canal de entrada; `private_environment` para segredos; tabela de exit codes da seção 3.3; a exigência de `System.exit(SpringApplication.exit(...))` no `main()`; `retries=0` ou distinção entre retry técnico e reprocessamento; `dag_run_id` determinístico.
- **Ticket 24 (timeout)**: o timeout interno do container deve ser **menor** que o `execution_timeout` do Airflow; a janela de **~10 s** entre SIGTERM e SIGKILL, não configurável pelo `DockerOperator`; `execution_timeout` é estático por task, o que exige a fábrica de DAGs (opção C) para variar por relatório.
- **Ticket 26 (traceparent)**: formato W3C conferido; `TRACEPARENT` como nome de convenção de facto; extração via `W3CTraceContextPropagator`; fallback obrigatório quando ausente.
- **Ticket 02 (ciclo de vida)**: o `on_failure_callback` roda no worker e tem `exception`, `dag_run` e `params` — mas **não** dispara em mudança de estado pela UI/CLI nem quando o worker morre. É obrigatório um job de varredura complementar.

---

## Recomendação

1. **Airflow 3.3.x**, imagem oficial `apache/airflow` (multi-arch AMD/ARM, portanto OK em ARM64), em Docker Compose na VM. Registrar como **risco aceito** o aviso da própria documentação de que o Compose oficial não oferece garantias de segurança de produção — mitigado por Traefik + TLS, credenciais próprias e não exposição da API ao usuário final. A imagem do módulo processador precisa ser buildada para `linux/arm64`.

2. **`DockerOperator`** (provider `apache-airflow-providers-docker` 4.5.8) para disparar o container. Ele é o único dos três candidatos que propaga exit code com granularidade (`skip_on_exit_code`), transmite os logs do container para o log da task, aceita Jinja em `environment` e sabe parar o container em `on_kill`. Acesso ao daemon preferencialmente por TCP+TLS com `docker_conn_id`; se for por socket, assumir e documentar que o worker fica root-equivalente no host. Com o worker containerizado, `mount_tmp_dir=False`.

3. **Fábrica de DAGs a partir de configuração** (opção C da seção 4.4): um `dag_factory.py` versionado que gera `coleta_<produto>` a partir de um inventário materializado pela API REST no diretório de DAGs, com uma task `DockerOperator` por relatório. **Cadastrar um processador novo passa a ser inserir uma linha na configuração** — o Airflow não é editado. `dag_id` estável, `sorted()` para ordem determinística, e um teste de parsing no CI que falha se qualquer DAG deixar de ser gerada. Distribuição via `GitDagBundle` (versionado, casa com o mono repo); se o inventário materializado não puder viver no bundle, ele fica em volume próprio ou volta a ser lido do schema de controle com query indexada e `try/except`.

4. **Entrada por `params` tipados** (`data_referencia` como `format: date`, `codigo_relatorio`, `forcar_reprocessamento`, `solicitante`, `motivo`, `correlation_id`), com defaults válidos porque as DAGs têm `schedule`. Não derivar `data_referencia` de `logical_date` no caminho manual.

5. **Autorização fora do Airflow.** O ADMINISTRADOR aciona o reprocessamento pelo módulo API REST, que valida a role do Keycloak, exige o motivo, grava a auditoria (solicitante + motivo + Correlation ID) e só então chama `POST /api/v2/dags/{dag_id}/dagRuns` com credencial de serviço e JWT obtido em `/auth/token`. `dag_run_id` determinístico para idempotência.

6. **`on_failure_callback` idempotente**, que só atualiza execuções ainda em "em processamento". Ele cobre o caso comum. **Não** cobre queda de worker/VM nem mudança manual de estado — por isso, uma DAG de varredura periódica é obrigatória (detalhar no ticket 02).

7. **Ordem dos timeouts**: timeout interno do container = `2 × tempo_estimado`; `execution_timeout` da task = `2 × tempo_estimado + margem`. O container se autointerrompe e grava o próprio "processado com erro"; o Airflow é a rede de segurança. Projetar o handler de SIGTERM para caber em **menos de 10 segundos** — um único `UPDATE`, conexão dedicada, timeout curto. `retries=0` nas tasks de coleta.

8. **`TRACEPARENT` como variável de ambiente**, no formato W3C, derivado deterministicamente de `(dag_id, run_id, task_id)` — reprodutível e independente de o OTel do Airflow estar ligado. No container, extração com `W3CTraceContextPropagator` para criar o span raiz do job; ausência ou formato inválido nunca falha a execução, apenas gera um trace id próprio.
