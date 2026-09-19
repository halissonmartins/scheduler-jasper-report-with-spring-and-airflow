## ADDED Requirements

### Requirement: Contrato de erro com Correlation ID
Toda mensagem de erro exibida ao usuário SHALL conter momento do erro em ISO 8601, descrição e Correlation ID
(RN-40, RA-41, RF-38). O contrato SHALL estar documentado no OpenAPI.

#### Scenario: Erro exibido ao usuário
- **WHEN** qualquer erro é devolvido ao usuário
- **THEN** a resposta contém momento, descrição e Correlation ID

#### Scenario: Cópia estruturada para chamado
- **WHEN** o usuário aciona a cópia do erro na interface
- **THEN** o conteúdo copiado é um JSON com os três campos do contrato

### Requirement: Correlation ID rastreável na operação
O Correlation ID SHALL ser o `traceId` propagado para os logs via MDC, e SHALL localizar a ocorrência nos
registros da operação (RN-41, RA-37, RF-40).

#### Scenario: Busca pelo identificador exibido
- **WHEN** o Correlation ID exibido ao usuário é pesquisado na ferramenta de logs
- **THEN** a ocorrência correspondente é encontrada

### Requirement: Telemetria estruturada e centralizada
Log, span, trace e métrica SHALL ser enviados ao OTel Collector, que os distribui para as ferramentas de
logs, métricas e traces (RA-36). Os logs SHALL ser estruturados e enriquecidos com `traceId` e `spanId`
(RA-38).

#### Scenario: Log emitido durante uma requisição
- **WHEN** uma requisição gera log
- **THEN** o registro é estruturado e carrega `traceId` e `spanId`

### Requirement: Telemetria desabilitada nos testes
O SDK do OpenTelemetry SHALL ser desabilitado nos testes automatizados, que SHALL NOT depender de Collector
nem gerar telemetria (RA-39).

#### Scenario: Suíte de testes sem Collector
- **WHEN** a suíte de testes roda sem Collector disponível
- **THEN** os testes passam sem erro de exportação de telemetria

### Requirement: Métricas do PRD instrumentadas e rotuladas
As métricas de PRD §6 SHALL ser mensuráveis sem consulta manual ao banco e rotuladas por sigla do produto e
código do relatório; as métricas de execução SHALL carregar também a **origem da execução** (RA-40).

#### Scenario: Separar agendada de retentativa
- **WHEN** a taxa de apuração limpa é consultada
- **THEN** é possível filtrar por origem `agendada`, isolando retentativa e reprocessamento

#### Scenario: Execuções presas detectáveis
- **WHEN** 30 minutos se passam após o fim do ciclo
- **THEN** existe métrica que reporta o número de execuções em `em processamento`

### Requirement: Health check por módulo
A API REST SHALL responder `UP` em `/actuator/health/liveness` e `/actuator/health/readiness` (RA-43).

#### Scenario: Módulo iniciado
- **WHEN** o módulo termina a inicialização
- **THEN** ambos os endpoints respondem `UP`
