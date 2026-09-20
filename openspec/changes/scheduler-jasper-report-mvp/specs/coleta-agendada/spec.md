## ADDED Requirements

### Requirement: Ciclo diário às 03h00 sem catchup
A Coleta SHALL ser disparada diariamente às 03h00 no fuso `America/Sao_Paulo`, e a DAG SHALL
declarar `catchup=False` explicitamente, independentemente do padrão da versão do Airflow. Sem
essa declaração, subir a DAG com `start_date` no passado dispara uma run por dia perdido, cada uma
carimbando uma data de referência antiga com o dado de hoje.

#### Scenario: Ciclo dispara no horário
- **WHEN** o relógio atinge 03h00 de `America/Sao_Paulo`
- **THEN** o ciclo daquela data de referência começa

#### Scenario: DAG com start_date no passado
- **WHEN** a DAG é publicada com `start_date` de trinta dias atrás
- **THEN** nenhuma run retroativa é criada

### Requirement: Reserva do ciclo antes de qualquer apuração
A primeira task da DAG SHALL gravar uma Execução por relatório ativo da data de referência, com
data/hora de início nula, antes que qualquer contêiner de processamento suba. Sem a reserva, um
relatório que nunca chega a ser apurado desaparece do denominador da métrica em vez de aparecer
como falha.

#### Scenario: Reserva precede a apuração
- **WHEN** o ciclo começa com dez relatórios ativos
- **THEN** existem dez Execuções reservadas com início nulo antes de o primeiro contêiner subir

#### Scenario: Relatório inativo não é reservado
- **WHEN** um dos relatórios está inativado no momento da reserva
- **THEN** nenhuma Execução é criada para ele

#### Scenario: Contêiner cai antes de iniciar a apuração
- **WHEN** o contêiner de um produto falha logo após subir
- **THEN** as Execuções reservadas daquele produto terminam como `processado com erro`, e não
  desaparecem da série

### Requirement: Apuração dos relatórios ativos com gravação de artefato
O ciclo SHALL apurar todos os relatórios ativos de todos os produtos e SHALL gravar um artefato
por relatório concluído em `processado com sucesso` ou `processado com alerta`.

#### Scenario: Ciclo completo sem falhas
- **WHEN** o ciclo termina com todos os relatórios ativos apurados com sucesso
- **THEN** existe um artefato gravado para cada relatório ativo naquela data de referência

#### Scenario: Relatório que terminou em erro
- **WHEN** um relatório termina em `processado com erro`
- **THEN** nenhum artefato daquele relatório existe para aquela data de referência

### Requirement: Registro dos metadados de cada execução
Cada Execução SHALL registrar data de referência, data/hora de início, data/hora de fim, duração,
status e origem — `agendada`, `retentativa` ou `reprocessamento forçado`.

#### Scenario: Metadados completos ao concluir
- **WHEN** uma execução termina em qualquer status terminal
- **THEN** todos os campos de metadados estão preenchidos, exceto os que a própria falha impediu
- **AND** a origem é a que motivou o disparo

### Requirement: Janela de leitura única por produto com retentativa do que não concluiu
Existe no máximo uma janela de leitura bem-sucedida por relatório por dia, e a Coleta SHALL ser a
única fronteira de leitura das bases transacionais. Uma janela que falhou não entregou artefato e
SHALL poder ser reaberta pela retentativa, que relê apenas os relatórios que não concluíram, com
até 2 retentativas por relatório em um ciclo.

#### Scenario: Retentativa relê só o que faltou
- **WHEN** três de dez relatórios de um produto falham e a retentativa é disparada
- **THEN** apenas esses três são relidos da base transacional
- **AND** os sete concluídos não são reapurados nem têm artefato sobrescrito

#### Scenario: Teto de retentativas
- **WHEN** um relatório falha pela terceira vez no mesmo ciclo
- **THEN** nenhuma nova retentativa é disparada e a execução vigente permanece em
  `processado com erro`

#### Scenario: Nenhum outro módulo lê a base transacional
- **WHEN** a API REST atende qualquer requisição
- **THEN** ela não abre conexão com nenhum schema transacional de produto

### Requirement: Paralelismo limitado a dois produtos
As tasks de produto SHALL correr em pool de no máximo 2, porque a máquina alvo tem 4 vCPUs
disputados por toda a pilha e a contenção transformaria `processado com alerta` em ruído de
ambiente.

#### Scenario: Cinco produtos em ondas
- **WHEN** o ciclo dispara os cinco produtos
- **THEN** no máximo dois contêineres de processamento executam simultaneamente

### Requirement: Data de referência nunca é informada
A data de referência SHALL ser sempre derivada do instante do disparo do ciclo e MUST NOT ser
aceita como entrada por interface alguma — nem da aplicação, nem do orquestrador, nem do
reprocessamento forçado.

#### Scenario: Nenhum parâmetro de data
- **WHEN** a DAG e os endpoints da API são inspecionados
- **THEN** não existe parâmetro de data de referência em nenhum deles

#### Scenario: Tentativa de forjar a data pela requisição
- **WHEN** um cliente envia um campo de data de referência ao solicitar reprocessamento
- **THEN** o campo é ignorado e a apuração usa a data corrente

### Requirement: Teto do dataset verificado antes de apurar
O processador SHALL contar as linhas do dataset antes de apurar e SHALL recusar o relatório que
ultrapassar 50.000 linhas, encerrando a execução como `processado com erro` com motivo explícito.
Sem a contagem prévia, o teto só se manifestaria como falha de memória na exportação, dias depois
e em outro módulo.

#### Scenario: Dataset acima do teto
- **WHEN** a contagem prévia de um relatório retorna mais de 50.000 linhas
- **THEN** a execução termina em `processado com erro` com motivo indicando o teto e a contagem
- **AND** nenhum artefato é gravado
- **AND** os demais relatórios do mesmo produto seguem sendo apurados

### Requirement: Artefato gravado antes dos metadados de conclusão
Dentro de uma execução, os artefatos SHALL ser gravados no repositório antes do registro dos
metadados de conclusão. A ordem inversa produziria uma execução em `processado com sucesso` sem
artefato correspondente.

#### Scenario: Falha entre gravação e conclusão
- **WHEN** o processo morre depois de gravar o artefato e antes de registrar a conclusão
- **THEN** a execução é encerrada como `processado com erro` e não fica em `em processamento`
- **AND** nenhuma execução em status de sucesso existe sem artefato
