## ADDED Requirements

### Requirement: Quatro status, um único não-terminal
A Execução SHALL assumir exatamente um de quatro status — `em processamento`,
`processado com sucesso`, `processado com alerta` e `processado com erro` — e apenas
`em processamento` é não-terminal. A tabela de metadados de execução SHALL ser a fonte da verdade
do status, e nenhuma outra fonte — nem o estado da task no orquestrador, nem a presença do arquivo
no repositório — pode contradizê-la.

#### Scenario: Estado da task contradiz o status registrado
- **WHEN** a task do orquestrador consta como bem-sucedida mas a execução está em
  `processado com erro`
- **THEN** o sistema apresenta `processado com erro` ao usuário e à métrica

#### Scenario: Artefato presente sem execução de sucesso
- **WHEN** existe arquivo no repositório para um par cuja execução vigente está em
  `processado com erro`
- **THEN** a exportação é recusada, porque o status manda

### Requirement: Alerta apenas por degradação de desempenho
Uma execução SHALL terminar em `processado com alerta` somente quando tiver concluído sem nenhuma
falha e sua duração tiver ultrapassado o tempo estimado registrado na própria execução. O artefato
é válido e utilizável; o alerta sinaliza degradação, não conteúdo incorreto.

#### Scenario: Concluiu sem falha acima do tempo estimado
- **WHEN** uma execução com tempo estimado de 60 s conclui sem falhas em 75 s
- **THEN** o status é `processado com alerta`
- **AND** o artefato é gravado e exportável

#### Scenario: Concluiu dentro do tempo estimado
- **WHEN** a mesma execução conclui em 45 s
- **THEN** o status é `processado com sucesso`

### Requirement: Erro prevalece sobre alerta
Qualquer falha registrada durante a execução SHALL resultar em `processado com erro`,
independentemente da duração.

#### Scenario: Falha em execução que também estourou o tempo estimado
- **WHEN** uma execução ultrapassa o tempo estimado e ainda assim registra uma falha
- **THEN** o status final é `processado com erro`, nunca `processado com alerta`

### Requirement: Limite de tempo do relatório
A apuração de um relatório SHALL ser abortada e encerrada como `processado com erro` ao atingir o
dobro do tempo estimado registrado na própria execução, sem impedir a apuração dos demais
relatórios do mesmo produto. A verificação ocorre entre chunks, e por isso todo statement de
leitura da Coleta SHALL declarar `queryTimeout` — sem ele, uma consulta travada dentro de uma
única chamada JDBC não é interrompida e o limite interno deixa de existir sem que ninguém perceba.

#### Scenario: Relatório estoura o dobro do tempo estimado
- **WHEN** um relatório de tempo estimado 60 s atinge 120 s de apuração
- **THEN** aquela apuração é abortada e encerrada como `processado com erro`
- **AND** os demais relatórios do mesmo produto continuam sendo apurados

#### Scenario: Consulta travada dentro de uma chamada JDBC
- **WHEN** um statement de leitura excede o `queryTimeout` declarado
- **THEN** a chamada é interrompida pelo driver e a execução termina em `processado com erro`

### Requirement: Limite de segurança do produto
A task de produto SHALL declarar `execution_timeout` igual ao dobro da soma dos tempos estimados
daquele produto, com folga, como interruptor de emergência para o caso de a apuração estar travada
a ponto de não conseguir aplicar o próprio limite de relatório.

#### Scenario: Apuração travada além do limite do produto
- **WHEN** a apuração de um produto ultrapassa o `execution_timeout` da task
- **THEN** a task é interrompida
- **AND** o encerramento das execuções abertas daquele produto é feito pelo callback de falha

### Requirement: Encerramento de execução anômala
Nenhuma execução SHALL permanecer em `em processamento` indefinidamente. Quando o contêiner de um
produto termina de forma anômala, o callback de falha da task SHALL encerrar como
`processado com erro` todas as execuções daquele produto que ficaram abertas, inclusive as que a
reserva criou e que nunca chegaram a começar, distinguíveis pelo início nulo.

#### Scenario: Contêiner morto sem registrar o próprio encerramento
- **WHEN** o contêiner de um produto é derrubado no meio da apuração
- **THEN** toda execução aberta daquele produto passa a `processado com erro`
- **AND** execuções de outros produtos não são afetadas

#### Scenario: Execução reservada que nunca iniciou
- **WHEN** a falha ocorre antes de a apuração de um relatório reservado começar
- **THEN** essa execução, de início nulo, também é encerrada como `processado com erro`

#### Scenario: Nenhuma execução presa após o ciclo
- **WHEN** se passam 30 minutos do fim do ciclo
- **THEN** não existe execução em `em processamento` daquela data de referência

### Requirement: Execução append-only com ponteiro de vigência
A Execução SHALL ser um registro imutável: nenhum caminho do sistema atualiza o status de uma
execução já terminal. Retentativa e reprocessamento forçado SHALL inserir linha nova e mover o
ponteiro de vigência, e as execuções anteriores permanecem marcadas como não-vigentes. Existe no
máximo uma execução vigente por par *Data de referência + Código do relatório*.

#### Scenario: Retentativa cria execução nova
- **WHEN** uma execução falha e a retentativa é disparada
- **THEN** uma nova Execução de origem `retentativa` é criada
- **AND** a execução anterior permanece, em `processado com erro`, marcada como não-vigente
- **AND** o ponteiro de vigência do par aponta para a nova

#### Scenario: Um par tem uma só execução vigente
- **WHEN** um par acumula três execuções ao longo do ciclo
- **THEN** exatamente uma delas está marcada como vigente

### Requirement: Cópia do tempo estimado no disparo
O tempo estimado vigente SHALL ser copiado para dentro da Execução no momento do disparo, e a
classificação de alerta SHALL usar essa cópia. Alterar o catálogo não reclassifica execuções
passadas.

#### Scenario: Edição do catálogo depois da execução
- **WHEN** o tempo estimado de um relatório é alterado de 60 s para 120 s após uma execução que
  durou 75 s
- **THEN** aquela execução continua em `processado com alerta`
- **AND** apenas as execuções disparadas depois da edição usam 120 s

### Requirement: Recusa de nova execução sobre par já concluído
O sistema SHALL recusar nova execução de um par cuja execução vigente esteja em
`processado com sucesso` ou `processado com alerta`, sem alterar artefatos e sem criar Execução. A recusa
SHALL ser registrada como evento de auditoria, com solicitante, momento e Correlation ID.

#### Scenario: Par já concluído com sucesso
- **WHEN** alguém dispara nova execução de um par em `processado com sucesso`
- **THEN** a solicitação é recusada
- **AND** os artefatos e os metadados originais permanecem intactos
- **AND** um evento de auditoria é registrado, e nenhuma Execução é criada

#### Scenario: Recusa não conta como falha de apuração
- **WHEN** a métrica primária é calculada no dia dessa recusa
- **THEN** a recusa não aparece como apuração suja

### Requirement: Par em erro pode ser reexecutado sem autorização especial
Um par cuja execução vigente esteja em `processado com erro` SHALL aceitar nova execução sem
qualquer autorização especial, porque não há artefato válido a preservar.

#### Scenario: Reexecução de par em erro
- **WHEN** nova execução é disparada para um par em `processado com erro`
- **THEN** a execução é aceita e nenhuma justificativa é exigida

### Requirement: Par em processamento bloqueia nova execução
Enquanto existir execução do par em `em processamento`, nova execução do mesmo par SHALL ser
recusada e registrada como evento de auditoria, sem criar Execução.

#### Scenario: Disparo durante apuração em andamento
- **WHEN** alguém dispara nova execução de um par que está `em processamento`
- **THEN** a solicitação é recusada e auditada
- **AND** a execução em andamento segue intacta
