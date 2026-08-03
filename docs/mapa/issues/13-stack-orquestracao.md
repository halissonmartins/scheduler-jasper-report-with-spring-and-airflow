# 13 — Stack: orquestração (Airflow, cadastro de containers, DockerOperator)

Type: research
Status: resolved
Blocked by: —

## Question

Como o Airflow dispara e cadastra os containers Spring Batch?

Pendência explícita do documento: "Cadastramento de novos contêineres do Spring Batch no Apache Airflow".

Levantar com fontes primárias (use context7) e recomendar:

- **Airflow**: versão atual, o modelo de DAG (TaskFlow vs clássico) e como ele roda em VM com Docker Compose.
- **Como disparar o container**: `DockerOperator` vs `BashOperator` chamando `docker run` vs um serviço do Compose acionado externamente. Levantar como cada um propaga exit code, logs e variáveis de ambiente.
- **DAG por produto vs DAG única parametrizada**: quando um novo módulo processador nasce, o que é preciso fazer para ele passar a ser agendado? Levantar geração dinâmica de DAG a partir de configuração/banco vs um arquivo de DAG por produto versionado no repositório.
- **Parâmetros de DAG run**: como passar `data de referência`, `código do relatório`, `forcar_reprocessamento`, e como restringir o acionamento a ADMINISTRADOR (o documento exige registro de solicitante, motivo e Correlation ID).
- **Callback de falha**: `on_failure_callback` da task, o que ele consegue acessar, e como ele atualiza a tabela de metadados para "processado com erro". Base do ticket 02.
- **Timeout**: `execution_timeout` da task vs o timeout duro dentro do container (ticket 24) — quem mata quem, e em que ordem.
- **traceparent**: como injetar como variável de ambiente do container para correlacionar DAG run ↔ execução Spring Batch ↔ logs no Graylog (ticket 26).

Registrar as descobertas em `docs/mapa/research/13-orquestracao.md`.

## Answer

Pesquisa completa em [`../research/13-orquestracao.md`](../research/13-orquestracao.md).

**Airflow 3.3.x** em Docker Compose na VM — a imagem oficial é multi-arquitetura AMD/ARM, então ARM64 está coberto; a imagem do processador é que precisa ser buildada para `linux/arm64`. A própria documentação avisa que o Compose oficial não dá garantias de segurança de produção: risco aceito, já que Kubernetes está fora de escopo.

**`DockerOperator`** (provider `apache-airflow-providers-docker` 4.5.8) vence `BashOperator`/serviço do Compose: propaga exit code com granularidade (`skip_on_exit_code` → `skipped`, demais ≠ 0 → `failed`), transmite os logs do container para o log da task, aceita Jinja em `environment` (é assim que `traceparent` e parâmetros entram) e mantém segredos fora do log via `private_environment`.

**Descoberta que muda o projeto**: o Spring Boot **não** devolve exit code ≠ 0 quando o job falha, a menos que o `main()` seja `System.exit(SpringApplication.exit(...))`. Sem isso o Airflow marca sucesso em job falho. `BatchStatus.FAILED` → exit code 5.

**Cadastro de processador novo**: fábrica de DAGs (`dag_factory.py` único, versionado) que gera `coleta_<produto>` a partir de um inventário materializado pela API REST — cadastrar um produto vira inserir uma linha em configuração, sem editar o Airflow. Distribuição por `GitDagBundle` (versionado, casa com o mono repo).

**Timeouts**: timeout interno do container = `2 × tempo_estimado`; `execution_timeout` do Airflow = isso + margem. O `on_kill` para o container com SIGTERM e o daemon manda SIGKILL após **~10 s não configuráveis pelo operador** — o handler de SIGTERM tem que caber nessa janela.

**`on_failure_callback`** roda no worker, tem `exception`/`dag_run`/`params`, mas **não** dispara em mudança de estado pela UI/CLI nem se o worker morrer — logo o ticket 02 precisa também de um job de varredura.

**Autorização** do `forcar_reprocessamento` fica na API REST (role do Keycloak + auditoria de solicitante/motivo/Correlation ID), que então chama `POST /api/v2/dags/{dag_id}/dagRuns` com JWT de serviço. O Airflow não é exposto ao usuário final.
