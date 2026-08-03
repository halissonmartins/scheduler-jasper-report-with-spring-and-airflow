# 19 — Contrato entre o Airflow e o container Spring Batch

Type: grilling
Status: resolved
Blocked by: 02, 13

## Question

Qual é o contrato exato na fronteira Airflow ↔ container?

O comportamento central é "Airflow dispara um container Spring Batch". Definir a interface para que qualquer módulo processador novo se encaixe sem mudar o Airflow.

Decidir e escrever:

- **Entrada.** Como o container recebe: data de referência, código do relatório (ou o produto inteiro?), `forcar_reprocessamento`, `traceparent`, credenciais de banco e de MinIO. Variáveis de ambiente, argumentos de linha de comando, ou ambos.
- **Saída.** Exit codes e o que cada um significa. O Airflow lê stdout? O container é responsável por gravar seu próprio encerramento nos metadados (o documento diz que sim) e o Airflow só cobre o caso anômalo via callback de falha.
- **Granularidade.** Uma task de Airflow por relatório, ou por produto (um container gera os 2 relatórios do módulo)? Isso muda paralelismo, retry e a leitura de status.
- **Retry.** O Airflow pode reexecutar a task automaticamente? Se sim, isso colide com a regra de unicidade data+código (ticket 20) — um retry legítimo seria rejeitado como reprocessamento. Resolver.
- **Timeout.** O `execution_timeout` do Airflow e o timeout duro do container (dobro do tempo estimado, ticket 24) — quem mata primeiro e o que fica registrado.
- **Imagem.** Uma imagem por módulo processador, ou uma imagem com todos os módulos e um seletor? Interage com o ticket 33.

## Notas de research

- **Ticket 13 — bug latente**: o Spring Boot **não** devolve exit code ≠ 0 quando o job Batch
  falha, a menos que `main()` seja `System.exit(SpringApplication.exit(...))` — o
  `ExitCodeGenerator` só age nesse caminho. Sem isso o Airflow marcaria `success` num job falho.
  `BatchStatus.FAILED` mapeia para exit code 5. Isso é requisito do contrato, não detalhe.
- **Ticket 13**: `DockerOperator` vence `BashOperator` e serviço do Compose — tem
  `skip_on_exit_code`, streama os logs para o log da task, e `environment` é campo *templated*,
  que é como `traceparent` e os parâmetros entram sem código. `private_environment` mantém
  segredos fora do log e da UI.
- **Ticket 13**: para o cadastro de módulos novos sem editar o Airflow, a recomendação é uma
  fábrica de DAGs a partir de inventário materializado pela API REST. "DAG única parametrizada"
  foi descartada por perder `execution_timeout` por relatório e agendamento por produto.

## Notas do ticket 02 (ciclo de vida)

- **A DAG ganha uma task `abrir_execucao` antes do `DockerOperator`.** É o Airflow, não o
  container, que insere a linha em `EM_PROCESSAMENTO` (transição T1). Consequências para este
  contrato: a unicidade (data + código) é rejeitada aí, **antes** de gastar container; o container
  recebe o identificador da Execução já criada como entrada; e o `on_failure_callback` vira UPDATE
  puro em vez de upsert.
- **O container nunca insere a própria linha** — ele só faz a transição terminal (T2–T5), sempre
  guardada por `AND status = 'EM_PROCESSAMENTO'`.
- **Uma tentativa que nem sobe** (erro de pull, OOM no startup) já tem linha, então é visível na
  fonte da verdade e alcançável pela varredura. Era o caso que o contrato deixava invisível.
- O **retry do Airflow** precisa ser reconciliado com T1: uma nova tentativa da mesma task reusa a
  linha existente ou abre outra? Interage com o ticket 20.

## Notas do ticket 03 (chave e data)

- **O default de `data_referencia` não pode ser `{{ ds }}` cru.** A Data de Referência é calculada
  em `America/Sao_Paulo`, e `ds` deriva de `logical_date`, que é um instante em UTC. Uma Coleta
  agendada às 22:00 BRT de 01/08 tem `logical_date = 2026-08-02T01:00Z` e `{{ ds }}` devolveria
  `2026-08-02`. O template precisa converter o fuso antes de formatar — e **isto é para verificar em
  teste de integração**, não para confiar na leitura da documentação.
- **No `forcar_reprocessamento`, o Airflow recebe a Data de Referência da Execução original** como
  parâmetro explícito, não recalcula. É o que mantém a unicidade do ticket 20 funcionando quando o
  reprocessamento acontece dias depois.
- Isso reforça o que o research 13 já dizia: `data_referencia` entra por `params` tipado
  (`format: date`), com o template servindo só de default no caminho agendado.

## Answer

### Granularidade: uma task por Relatório

Cada task cobre exatamente um par (Relatório, Data de Referência) — a mesma unidade da Execução, da
constraint de unicidade e do tempo estimado. Retry, `execution_timeout` e status ficam alinhados
um-para-um, sem lógica compensatória em lugar nenhum.

Agrupar por Produto foi recusado por dois motivos concretos: a task deixaria de mapear para uma
Execução (T1 abriria N linhas, e uma falha teria de fechar N), e um retry após falha parcial
reprocessaria o Relatório que já deu certo — batendo na constraint, o que obrigaria o container a
reimplementar dentro dele a regra que o banco já impõe. Além disso, o research 13 já registrava que
agrupar perde `execution_timeout` por Relatório.

Custo aceito: uma partida de JVM por Relatório — dez containers por dia com cinco Produtos.

### Retry: a contradição entre três tickets, e qual cedeu

Este ticket encontrou um conflito entre decisões já fechadas:

- **Ticket 04** escreveu `UNIQUE (codigo_relatorio, data_referencia)` — constraint **total**.
- **Ticket 02** fixou que estados terminais são **imutáveis**.
- **Ticket 20** parte do princípio de que a unicidade só morde pares já processados **com sucesso**.

Os três não cabem juntos. Container falha, grava `ERRO`, e o retry do Airflow não pode abrir linha
nova (a constraint total bloqueia) nem reabrir a existente (o terminal é imutável). **Retry
automático era impossível.**

Cedeu a constraint:

```sql
CREATE UNIQUE INDEX ON execucao (codigo_relatorio, data_referencia)
  WHERE status <> 'ERRO';
```

Cada tentativa abre a própria Execução; o terminal segue imutável; e o histórico passa a mostrar que
falhou duas vezes antes de passar — informação que a constraint total apagava. O
`forcar_reprocessamento` continua sendo o caminho para refazer um par já bem-sucedido (ticket 20).

Detalhe que ajuda e evita um erro: o `on_failure_callback` só dispara quando os **retries se
esgotam** — durante as tentativas o Airflow usa `on_retry_callback`. O callback não fecha a linha
prematuramente.

*Isto é emenda ao ticket 04, não nota.*

### Imagem: uma por módulo processador

*Risco aceito.* Argumentei por **uma imagem única com seletor de módulo**, porque o enforcer do POM
raiz impede divergência de versão do Jasper em tempo de **build**, mas nada impede alguém implantar
`processador-poupanca:1.4` ao lado de `processador-cliente:1.3` — divergência em tempo de **deploy**.
E ela **falha em silêncio**: `JRConstants.SERIAL_VERSION_UID` é a constante fixa `10200` em todas as
versões (ticket 05), então não há `InvalidClassException` — há relatório sutilmente errado. Imagem
única tornaria isso impossível por construção, e casaria com a regra de "monorepositório com versão
única".

Decisão: uma imagem por módulo, com imagens menores e deploy independente por Produto.

**Contenção obrigatória**: antes de desserializar, a API compara `versao_jasperreports` da Execução
(gravada pelo ticket 04) com a sua própria. Divergindo, **exporta assim mesmo**, mas registra log e
incrementa métrica. Recusar seria pior: quebraria os sete dias seguintes a qualquer upgrade legítimo,
já que todos os Artefatos vivos teriam sido gravados pela versão anterior. Um upgrade produz alerta
temporário e decrescente; um módulo esquecido numa tag antiga produz alerta constante — os dois
padrões são distinguíveis.

### Exit code: espelha o desfecho de negócio

```
SUCESSO | ALERTA | SEM_DADOS       -> 0
ERRO gravado pelo próprio container -> 5  (BatchStatus.FAILED)
falha antes de conseguir registrar  -> ≠ 0
SIGKILL (OOM ou fim do grace)       -> 137
```

**`main()` precisa ser `System.exit(SpringApplication.exit(ctx, ...))`** — sem isso o
`ExitCodeGenerator` não age e um job Batch falho sai com código 0, fazendo o Airflow marcar `success`.
Isso é requisito do contrato, não detalhe de implementação: todo o desenho acima depende dele.

Sair 0 em `ERRO` — a alternativa "o exit code só diz se consegui me registrar" — seria mais fiel à
ideia de fonte única da verdade, mas deixaria a UI do Airflow verde numa Coleta que falhou, tirando
do orquestrador a função de painel de saúde. O custo de espelhar é que o `on_failure_callback` roda
sobre linha já fechada — e não faz nada, porque é guardado por `AND status = 'EM_PROCESSAMENTO'`.

**`SEM_DADOS` não usa `skip_on_exit_code`**: `skipped` propaga rio abaixo no Airflow, e o status real
já está no banco.

### Entrada

Por variáveis de ambiente, no campo `environment` do `DockerOperator` — que é *templated*, e é assim
que `traceparent` e parâmetros entram sem código. Credenciais vão em `private_environment`, que as
mantém fora do log da task e da UI.

O container recebe: identificador da **Execução já aberta** em T1, Código de Relatório, Data de
Referência, `traceparent`, e as credenciais do seu Produto (`app_proc_<sigla>`) e do MinIO.

`data_referencia` entra por `params` tipado (`format: date`); o template é só default do caminho
agendado, **com conversão explícita de fuso** — `{{ ds }}` cru rotula errado toda Coleta agendada
depois das 21h BRT (ticket 03).

### Timeout: três degraus

```
timeout interno do container  <  execution_timeout do Airflow  <  LIMITE_ORFA
```

A janela entre SIGTERM e SIGKILL é de ~10 s e **não é configurável pelo operador** — é toda a folga
que o container tem para gravar `ERRO` antes de morrer. Por isso o timeout interno vem primeiro: o
container se mata a tempo de se registrar. O ticket 24 fixa a margem e o piso.

## Adendo do ticket 24 (tolerância do tempo estimado)

Duas correções a este ticket:

**1. "Cada tentativa abre a própria Execução" está mecanicamente errado.** `abrir_execucao` e o
`DockerOperator` são tasks separadas, e o Airflow retenta apenas a que falhou — o retry do container
não reabre nada. O ticket 24 decidiu o desenho real: **a linha é reusada**. O container sai com código
≠ 0 e a deixa aberta; o `on_failure_callback` a fecha como `ERRO` uma única vez, ao esgotarem os
retries (durante as tentativas o Airflow usa `on_retry_callback`).

Consequência: **o índice único parcial não serve ao retry automático** — ele serve ao `refazer` manual
do ticket 20. E as tentativas **acumulam** contra o `LIMITE_ORFA`, o que fixou o teto de tempo
estimado cadastrável em ~59 min.

**2. A tabela de exit codes muda numa linha.** Onde estava "`ERRO` gravado pelo próprio container →
5", passa a ser "**falha do job → 5, sem gravar terminal**". O container grava apenas `SUCESSO`,
`ALERTA` e `SEM_DADOS`.

O requisito de `System.exit(SpringApplication.exit(ctx, ...))` **continua valendo integralmente** — é
ele que faz o exit code chegar diferente de zero para o Airflow saber que deve retentar.

**3. A janela de ~10 s deixou de ser crítica**, já que o container não grava mais o encerramento em
caso de falha. A ordem dos três degraus continua, por outro motivo: saída limpa com exit code próprio
e log completo, em vez de SIGKILL.

**Números fixados pelo ticket 24**: `execution_timeout = 2 × tempo_estimado + 120 s`, com
`retries = 2` (3 tentativas).
