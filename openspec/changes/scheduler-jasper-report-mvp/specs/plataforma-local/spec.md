## ADDED Requirements

### Requirement: Ambiente local reproduzível
O ambiente completo SHALL subir por Docker Compose em máquina limpa, com as dependências reais e
sem serviço simulado: PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit, OTel Collector,
Graylog, Prometheus, Grafana e Jaeger. O `README.md` SHALL descrever a execução em até três
comandos, e o `.env.example` SHALL listar todas as variáveis sem nenhum segredo real.

#### Scenario: Clone limpo sobe o ambiente
- **WHEN** um clone limpo do repositório executa os comandos documentados no `README.md`
- **THEN** todos os contêineres declarados no `docker-compose.yml` atingem estado saudável
- **AND** nenhuma variável exigida está ausente do `.env.example`

#### Scenario: Segredo real nunca é versionado
- **WHEN** o scanner de segredos roda sobre o repositório
- **THEN** nenhum valor de credencial real é encontrado, inclusive no `.env.example`

### Requirement: Health check da API REST
O módulo API REST SHALL expor `liveness` e `readiness` pelo Actuator e responder `UP` quando
inicializado com sucesso.

#### Scenario: Liveness e readiness respondem UP
- **WHEN** a API REST termina a inicialização
- **THEN** `GET /actuator/health/liveness` responde `200` com status `UP`
- **AND** `GET /actuator/health/readiness` responde `200` com status `UP`

#### Scenario: Readiness reflete dependência indisponível
- **WHEN** o schema de controle está inacessível
- **THEN** `readiness` não responde `UP`

### Requirement: Timezone único do sistema
Toda a aplicação e todos os contêineres SHALL executar no fuso `America/Sao_Paulo`, que é o fuso
em que a data de referência é resolvida. Nenhum módulo pode depender do fuso do sistema
hospedeiro.

#### Scenario: Data de referência resolvida no fuso do projeto
- **WHEN** o ciclo é disparado às 03h00 de `America/Sao_Paulo`
- **THEN** a data de referência gravada é a data daquele instante nesse fuso, independentemente do
  fuso do hospedeiro

### Requirement: Versionamento de schema por migration
Todo schema PostgreSQL — transacionais e de controle — SHALL ser versionado por Flyway. Uma
migration já aplicada MUST NOT ser alterada; correção se faz por migration nova.

#### Scenario: Schema criado do zero
- **WHEN** o ambiente sobe com banco vazio
- **THEN** o Flyway aplica todas as migrations e o schema de controle fica pronto sem intervenção
  manual

#### Scenario: Alteração de migration aplicada é bloqueada
- **WHEN** o checksum de uma migration já aplicada diverge
- **THEN** a inicialização falha em vez de seguir com schema divergente

### Requirement: CI bloqueante por pull request
O GitHub Actions SHALL executar lint, compilação, testes e build a cada pull request, e o resultado
vermelho SHALL bloquear o merge. Desabilitar regra de lint ou teste para fazer o build passar é
proibido.

#### Scenario: PR com teste falhando não é mesclável
- **WHEN** um pull request contém um teste que falha
- **THEN** o workflow de CI termina em falha e o merge fica bloqueado
