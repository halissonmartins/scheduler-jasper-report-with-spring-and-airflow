## ADDED Requirements

### Requirement: Solicitação de reprocessamento forçado pelo ADMINISTRADOR
O sistema SHALL permitir que apenas o ADMINISTRADOR solicite o reprocessamento forçado de um par
já concluído em `processado com sucesso` ou `processado com alerta`, exclusivamente para a data de
referência corrente. A solicitação invalida a execução anterior, gera nova apuração de origem
`reprocessamento forçado` e sobrescreve os artefatos.

#### Scenario: Reprocessamento de par concluído
- **WHEN** o ADMINISTRADOR solicita o reprocessamento de um par em `processado com sucesso`
  informando o motivo
- **THEN** uma nova Execução de origem `reprocessamento forçado` é criada e passa a vigente
- **AND** a execução anterior permanece registrada, marcada como não-vigente e invalidada
- **AND** os artefatos daquele par são sobrescritos ao fim da nova apuração

#### Scenario: Data de referência não é escolhida
- **WHEN** o ADMINISTRADOR abre a solicitação de reprocessamento
- **THEN** não existe campo de data de referência, e a apuração vale para a data corrente

### Requirement: Motivo textual obrigatório e auditado
Toda solicitação de reprocessamento forçado SHALL exigir motivo textual obrigatório e SHALL ser
registrada com o identificador do solicitante, o motivo, o momento e o Correlation ID. A execução
invalidada permanece ligada a esse registro.

#### Scenario: Solicitação sem motivo
- **WHEN** a solicitação chega com motivo ausente ou vazio
- **THEN** ela é rejeitada e nenhuma execução é criada

#### Scenario: Registro de auditoria da solicitação aceita
- **WHEN** a solicitação é aceita
- **THEN** existe registro de auditoria com solicitante, motivo, momento e Correlation ID
- **AND** o registro aponta para a execução que foi invalidada

### Requirement: Reprocessamento é privativo do ADMINISTRADOR
Usuário de perfil diferente de ADMINISTRADOR MUST NOT conseguir solicitar reprocessamento forçado,
nem pela interface nem por manipulação direta da requisição.

#### Scenario: GERENTE ou RELATOR tenta reprocessar
- **WHEN** um usuário de perfil GERENTE ou RELATOR chama o endpoint de reprocessamento
- **THEN** a requisição é negada por autorização
- **AND** nenhuma execução é criada

### Requirement: A API é quem aciona o orquestrador
A API REST SHALL ser o único acionador da DAG para reprocessamento: ela captura solicitante,
motivo e Correlation ID e só então dispara o orquestrador com o parâmetro
`forcar_reprocessamento`. O Airflow MUST NOT ser exposto ao usuário final.

#### Scenario: Contrato entre API e orquestrador
- **WHEN** a API aceita uma solicitação de reprocessamento
- **THEN** ela dispara a DAG passando `forcar_reprocessamento`
- **AND** nenhum parâmetro de data de referência é enviado

#### Scenario: Usuário não alcança o orquestrador
- **WHEN** um usuário final tenta acessar a interface do Airflow pelo ingress
- **THEN** o acesso não é exposto
