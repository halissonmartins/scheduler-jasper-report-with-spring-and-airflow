## ADDED Requirements

### Requirement: Metadados como fonte da verdade do status
A tabela de metadados de execução SHALL ser a única fonte da verdade do status (RN-09, RA-25). Nem o estado
da task no orquestrador nem a presença do arquivo no repositório SHALL contradizê-la.

#### Scenario: Divergência entre repositório e metadados
- **WHEN** existe artefato no repositório para uma execução registrada como `processado com erro`
- **THEN** o sistema trata o par como sem artefato válido e recusa a exportação

### Requirement: Registro completo de cada execução
Cada Execução SHALL registrar data de referência, data/hora de início, data/hora de fim, duração, status,
origem e o tempo estimado copiado no momento do disparo (RN-46, RN-47, RF-02).

#### Scenario: Origem declarada
- **WHEN** uma execução é criada
- **THEN** sua origem é exatamente uma entre `agendada`, `retentativa` e `reprocessamento forçado`

#### Scenario: Edição de catálogo não reclassifica o passado
- **WHEN** o tempo estimado de um relatório é editado no catálogo
- **THEN** execuções já registradas mantêm o tempo estimado que copiaram
- **AND** seus status não são recalculados

### Requirement: Execução append-only com ponteiro de vigência
A Execução SHALL ser um registro imutável: nenhum caminho do sistema SHALL atualizar o status de uma execução
já terminal (RN-15, RA-67). "Vigente" SHALL ser um ponteiro, e existe no máximo **uma execução vigente** por
par *Data de referência + Código do relatório* (RN-16).

#### Scenario: Retentativa cria linha nova
- **WHEN** uma execução falha e a retentativa ocorre
- **THEN** uma nova Execução de origem `retentativa` é inserida e passa a vigente
- **AND** a execução anterior permanece registrada, marcada como não-vigente

#### Scenario: Unicidade da vigência
- **WHEN** as execuções de um par são consultadas
- **THEN** exatamente uma está marcada como vigente

### Requirement: Classificação de status ao encerrar
Uma execução concluída sem nenhuma falha e com duração acima do tempo estimado da própria execução SHALL
terminar em `processado com alerta` (RN-11). Qualquer falha registrada SHALL resultar em
`processado com erro`, independentemente da duração — **o erro sempre prevalece sobre o alerta** (RN-12).

#### Scenario: Lenta e sem falha
- **WHEN** a execução conclui sem falha em duração acima do tempo estimado copiado
- **THEN** o status é `processado com alerta` e o artefato é válido

#### Scenario: Lenta e com falha
- **WHEN** a execução registra uma falha e também ultrapassa o tempo estimado
- **THEN** o status é `processado com erro`

### Requirement: Bloqueio de nova execução por status vigente
O sistema SHALL recusar nova execução de par cuja execução vigente esteja em `processado com sucesso`,
`processado com alerta` ou `em processamento` (RN-17, RN-43), e SHALL aceitar nova execução, sem autorização
especial, quando a execução vigente estiver em `processado com erro` (RN-19).

#### Scenario: Recusa sobre sucesso
- **WHEN** uma nova execução é solicitada para par com execução vigente em sucesso ou alerta
- **THEN** ela é recusada
- **AND** os artefatos e metadados originais permanecem intactos

#### Scenario: Aceite sobre erro
- **WHEN** uma nova execução é solicitada para par com execução vigente em erro
- **THEN** ela é aceita normalmente

### Requirement: Recusa registrada como auditoria, não como execução
A recusa de nova execução SHALL ser registrada como evento de auditoria com solicitante, momento e
Correlation ID, e SHALL NOT criar uma Execução (RN-18, RF-08).

#### Scenario: Tentativa recusada não vira falha de apuração
- **WHEN** uma solicitação de execução é recusada
- **THEN** existe um evento de auditoria correspondente
- **AND** o número de execuções do par não aumenta
- **AND** a métrica primária não registra falha

### Requirement: Retenção indefinida dos metadados
Os metadados de Execução SHALL NOT ser expurgados em momento algum (RN-51, RA-62).

#### Scenario: Artefato expurgado, execução preservada
- **WHEN** o artefato de uma data de referência é expurgado pela política de retenção
- **THEN** os metadados daquela execução continuam consultáveis
- **AND** a métrica de janela de 30 dias permanece calculável

### Requirement: Métrica primária restrita a execuções vigentes agendadas
A taxa de apuração limpa SHALL considerar exclusivamente execuções **vigentes** de origem `agendada`
(PRD §6, RF-52).

#### Scenario: Retentativa bem-sucedida conta como limpa
- **WHEN** um relatório falha e a retentativa conclui com sucesso
- **THEN** o par aparece como limpo na métrica primária
- **AND** a retentativa é contada na métrica secundária de instabilidade

#### Scenario: Reprocessamento forçado fora do denominador
- **WHEN** um par tem execução vigente de origem `reprocessamento forçado`
- **THEN** ele não entra no cálculo da métrica primária
