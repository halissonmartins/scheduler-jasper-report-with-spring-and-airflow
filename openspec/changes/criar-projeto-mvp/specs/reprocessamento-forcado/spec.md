## ADDED Requirements

### Requirement: Reprocessamento forçado exclusivo do ADMINISTRADOR
Apenas o perfil ADMINISTRADOR SHALL solicitar reprocessamento forçado de um par já concluído com sucesso ou
alerta, e somente para a **data de referência corrente** (RN-20, RF-12).

#### Scenario: Perfil não autorizado
- **WHEN** um GERENTE ou RELATOR solicita reprocessamento forçado
- **THEN** a solicitação é negada
- **AND** nenhuma execução é criada

#### Scenario: Data de referência não é parâmetro
- **WHEN** a solicitação de reprocessamento é enviada
- **THEN** não existe campo de data de referência no contrato

### Requirement: Motivo textual obrigatório
Toda solicitação de reprocessamento forçado SHALL exigir motivo textual não vazio e SHALL ser registrada com
o identificador do solicitante, o motivo e o Correlation ID (RN-21, RF-11).

#### Scenario: Solicitação sem motivo
- **WHEN** a solicitação chega sem motivo ou com motivo em branco
- **THEN** ela é rejeitada
- **AND** nenhuma execução é criada

#### Scenario: Registro de auditoria da solicitação aceita
- **WHEN** a solicitação é aceita
- **THEN** existe registro com solicitante, motivo, momento e Correlation ID
- **AND** a execução invalidada permanece ligada a esse registro

### Requirement: Invalidação e sobrescrita
O reprocessamento forçado SHALL invalidar a execução vigente do par, criar nova Execução de origem
`reprocessamento forçado` e **sobrescrever** os artefatos (RN-20, RF-10).

#### Scenario: Execução anterior preservada e não-vigente
- **WHEN** o reprocessamento conclui
- **THEN** a execução anterior permanece registrada e marcada como não-vigente
- **AND** a nova execução é a vigente do par

#### Scenario: Artefatos sobrescritos no mesmo caminho
- **WHEN** o reprocessamento grava os artefatos
- **THEN** o `.jrprint` e o `.csv.gz` do mesmo caminho são substituídos

### Requirement: API como único acionador do orquestrador
A API REST SHALL ser quem aciona a DAG para reprocessamento, capturando solicitante, motivo e Correlation ID
antes do disparo (RA-13). O orquestrador SHALL NOT ser exposto ao usuário final.

#### Scenario: Orquestrador não exposto
- **WHEN** as rotas expostas pelo ingress são inspecionadas
- **THEN** a interface do Airflow não está entre elas
