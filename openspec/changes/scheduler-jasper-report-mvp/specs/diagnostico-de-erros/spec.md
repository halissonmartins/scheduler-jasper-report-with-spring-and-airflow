## ADDED Requirements

### Requirement: Contrato de erro com momento, descrição e Correlation ID
Toda mensagem de erro exibida ao usuário SHALL conter o momento do erro em ISO 8601, a descrição
do erro e o Correlation ID, e esse contrato SHALL estar documentado no OpenAPI.

#### Scenario: Erro devolvido pela API
- **WHEN** qualquer requisição termina em erro
- **THEN** a resposta traz momento em ISO 8601, descrição e Correlation ID
- **AND** o mesmo contrato está descrito no OpenAPI

#### Scenario: Erro exibido na interface
- **WHEN** a interface recebe um erro da API
- **THEN** ela exibe os três campos ao usuário, em pt-BR

### Requirement: Correlation ID único e localizável na operação
O Correlation ID SHALL ser um só do começo ao fim da requisição, formado pelo `traceId` propagado
ao MDC, e SHALL localizar a mesma ocorrência nos registros da operação.

#### Scenario: Busca pelo identificador exibido
- **WHEN** o Correlation ID exibido ao usuário é pesquisado no agregador de logs
- **THEN** os registros daquela requisição são encontrados

#### Scenario: Um só identificador por requisição
- **WHEN** uma requisição atravessa vários componentes da API
- **THEN** todos os registros carregam o mesmo Correlation ID

### Requirement: Cópia estruturada do erro para anexar em chamado
A tela de erro SHALL oferecer a cópia do erro em JSON estruturado, para anexar em chamado.

#### Scenario: Usuário copia o erro
- **WHEN** o usuário aciona a cópia na tela de erro
- **THEN** o JSON copiado contém momento, descrição e Correlation ID
