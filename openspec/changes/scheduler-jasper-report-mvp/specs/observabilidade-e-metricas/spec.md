## ADDED Requirements

### Requirement: Telemetria centralizada no OTel Collector
Log, span, trace e métrica SHALL ser enviados ao OTel Collector, que os distribui para o agregador
de logs, o servidor de métricas e o de traces. Os logs SHALL ser estruturados e enriquecidos com
`traceId` e `spanId`.

#### Scenario: Requisição instrumentada de ponta a ponta
- **WHEN** uma exportação é solicitada
- **THEN** existem logs estruturados, spans e métricas daquela requisição no destino correspondente
- **AND** logs e spans compartilham o mesmo `traceId`

### Requirement: Labels obrigatórias das métricas
As métricas SHALL usar as labels sigla do produto e código do relatório sempre que aplicável, e a
métrica primária SHALL usar também a label origem da execução. Sem a origem é impossível separar
apuração agendada de retentativa e de reprocessamento, e as métricas se contaminam.

#### Scenario: Métrica de execução publicada
- **WHEN** uma execução termina
- **THEN** a métrica correspondente carrega sigla, código do relatório e origem

### Requirement: Métrica primária de taxa de apuração limpa
O sistema SHALL medir a taxa de apuração limpa — o percentual dos pares *Relatório + Data de
referência* cuja execução vigente de origem `agendada` terminou em `processado com sucesso` — em
janela móvel de 30 dias, com meta provisória de 98%. O denominador SHALL ser um par por relatório
ativo por dia, e reprocessamentos forçados MUST NOT entrar no cálculo.

#### Scenario: Retentativa que salvou o dia
- **WHEN** um relatório falha e a retentativa conclui com sucesso
- **THEN** o par conta como limpo, porque a execução vigente é de sucesso
- **AND** a retentativa aparece na métrica secundária de instabilidade

#### Scenario: Reprocessamento forçado fora do cálculo
- **WHEN** um par é reprocessado à força
- **THEN** essa execução não entra no numerador nem no denominador da métrica primária

#### Scenario: Relatório nunca apurado
- **WHEN** um relatório ativo não chega a ser apurado no ciclo
- **THEN** o par reservado conta como sujo no denominador, em vez de desaparecer da série

### Requirement: Métricas secundárias instrumentadas
O sistema SHALL medir, sem consulta manual ao banco: retentativas por mês, execuções presas em
`em processamento` 30 minutos após o fim do ciclo, reprocessamentos forçados por mês, exportações
que terminam em erro e exportações recusadas por limite de simultaneidade.

#### Scenario: Painel sem consulta manual
- **WHEN** a operação abre o painel de métricas
- **THEN** as cinco métricas secundárias estão disponíveis, rotuladas por sigla e código

#### Scenario: Execução presa detectada
- **WHEN** existe execução em `em processamento` 30 minutos após o fim do ciclo
- **THEN** a métrica correspondente fica maior que zero

### Requirement: SDK de telemetria desabilitado nos testes
O SDK do OpenTelemetry SHALL ser desabilitado nos testes automatizados, para que não dependam de
Collector nem gerem telemetria.

#### Scenario: Suíte de testes sem Collector
- **WHEN** a suíte de testes roda sem OTel Collector disponível
- **THEN** os testes passam sem erro de exportação de telemetria
