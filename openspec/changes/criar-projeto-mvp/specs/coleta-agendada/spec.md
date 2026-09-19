## ADDED Requirements

### Requirement: Ciclo diário agendado
A coleta SHALL executar diariamente às 03h00 de `America/Sao_Paulo` e apurar todos os relatórios **ativos**
(RN-06, RNF-20). O agendamento SHALL viver na declaração da DAG, e SHALL NOT ser editável pela aplicação nem
por variável de ambiente.

#### Scenario: Ciclo apura todos os relatórios ativos
- **WHEN** o ciclo diário dispara
- **THEN** cada relatório ativo do catálogo tem uma apuração disparada
- **AND** relatórios inativos não são apurados

#### Scenario: Sem reprocessamento de datas perdidas
- **WHEN** a DAG sobe com `start_date` no passado
- **THEN** nenhuma run retroativa é disparada, porque `catchup=False` está declarado explicitamente

### Requirement: Reserva do ciclo antes de qualquer apuração
A primeira etapa do ciclo SHALL gravar uma Execução por relatório ativo da data de referência, com início
nulo, antes de qualquer contêiner de processamento subir (RN-45, RA-54).

#### Scenario: Reserva precede a apuração
- **WHEN** o ciclo inicia
- **THEN** existe uma Execução reservada por relatório ativo, com data/hora de início nula
- **AND** nenhuma apuração começou ainda

#### Scenario: Relatório nunca apurado aparece como falha
- **WHEN** o contêiner de um produto nunca chega a apurar um dos seus relatórios
- **THEN** a Execução reservada daquele relatório termina em `processado com erro`
- **AND** ela permanece no denominador da métrica primária

### Requirement: Data de referência nunca informada
A Data de referência SHALL ser o dia do disparo do ciclo no fuso `America/Sao_Paulo` e SHALL NOT ser
parâmetro de entrada de nenhuma interface — aplicação, orquestrador ou reprocessamento (RN-07, RN-54, RF-53).

#### Scenario: Interface rejeita data de referência
- **WHEN** uma requisição ou um parâmetro de DAG tenta informar data de referência
- **THEN** a entrada não existe no contrato e o valor é ignorado ou rejeitado

### Requirement: Janela única de leitura por produto
Cada módulo processador SHALL ler exclusivamente o schema transacional do seu próprio produto, numa única
janela por ciclo (RA-10, RN-31). Existe no máximo **uma leitura bem-sucedida por relatório por dia**;
a retentativa SHALL reler apenas os relatórios que não concluíram (RN-44).

#### Scenario: Retentativa relê só o que faltou
- **WHEN** um relatório falha e o ciclo executa a retentativa
- **THEN** apenas os relatórios não concluídos são relidos da base
- **AND** o número de retentativas por relatório não ultrapassa o limite de RNF-17

#### Scenario: Nenhum outro módulo lê o schema transacional
- **WHEN** as dependências de conexão da API REST são inspecionadas
- **THEN** nenhum schema transacional de produto é alcançável a partir dela

### Requirement: Dois limites de tempo com papéis distintos
A apuração de um relatório SHALL ser abortada e encerrada como `processado com erro` ao atingir o dobro do
tempo estimado da própria execução, sem impedir os demais relatórios do mesmo produto (RN-13, RF-05). A task
do produto SHALL ter `execution_timeout` igual ao dobro da soma dos tempos estimados, com folga, como
interruptor de emergência.

#### Scenario: Relatório estourado não derruba os irmãos
- **WHEN** um relatório atinge o dobro do seu tempo estimado
- **THEN** ele termina em `processado com erro`
- **AND** os demais relatórios do mesmo produto seguem sendo apurados

#### Scenario: Consulta travada dentro de uma chamada JDBC
- **WHEN** uma leitura da Coleta trava dentro de uma única chamada JDBC
- **THEN** o `queryTimeout` declarado no statement interrompe a chamada
- **AND** o limite do relatório volta a ser verificável entre chunks

### Requirement: Recusa por volume de dataset
Antes de apurar, o processador SHALL contar as linhas do dataset e SHALL recusar o relatório cujo volume
ultrapasse o teto de RNF-06, encerrando como `processado com erro` com motivo explícito (RN-52, RA-64).

#### Scenario: Dataset acima do teto
- **WHEN** a contagem prévia indica volume acima do teto
- **THEN** a apuração não é executada
- **AND** a execução termina em `processado com erro` com motivo identificando o volume e o teto

### Requirement: Nenhuma execução presa em processamento
Nenhuma execução SHALL permanecer em `em processamento` indefinidamente. Quando a task de um produto termina
de forma anômala, o callback de falha do orquestrador SHALL encerrar como `processado com erro` todas as
execuções daquele produto que ficaram abertas, inclusive as reservadas que nunca iniciaram (RN-10, RA-14).

#### Scenario: Contêiner morre sem registrar encerramento
- **WHEN** o contêiner de um produto termina de forma anômala
- **THEN** toda execução aberta daquele produto é encerrada como `processado com erro`
- **AND** 30 minutos após o fim do ciclo não há execução em `em processamento`

### Requirement: Artefato gravado antes dos metadados de conclusão
Dentro de uma execução, os artefatos SHALL ser gravados antes do registro de conclusão (RA-11).

#### Scenario: Falha entre gravação e conclusão
- **WHEN** a execução falha após gravar o artefato e antes de registrar a conclusão
- **THEN** a execução não fica em `processado com sucesso`
- **AND** não existe execução em status de sucesso sem artefato correspondente
