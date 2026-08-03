# 34 — API REST com actuator liveness e readiness respondendo UP

Type: task
Status: resolved
Blocked by: 28, 33

## Question

A API REST sobe na 8080 e responde UP nos dois endpoints de health?

Fase inicial do documento. Ticket de execução: o comportamento dos health checks foi decidido no ticket 28, o esqueleto veio do 33.

Entregar:

- Módulo API REST executando na porta 8080.
- `GET /actuator/health/liveness` → `UP`, sem depender de recurso externo.
- `GET /actuator/health/readiness` → `UP`, verificando exatamente as dependências decididas no ticket 28.
- Configuração de exposição do actuator conforme o ticket 28.
- Healthcheck no Docker Compose apontando para esses endpoints, com `start-period` adequado.
- Um teste automatizado que prove os dois endpoints — a primeira parcela concreta da estratégia do ticket 30.

Ao final, **solicitar revisão e aguardar aprovação** antes de encerrar a fase.

## Notas do ticket 28 (readiness e liveness)

- **O conteúdo dos dois grupos está decidido**: `liveness` = `LivenessState` apenas; `readiness` =
  `ReadinessState` **+ PostgreSQL**. O MinIO fica fora, preservando a degradação parcial (lista sim,
  exporta não).
- **O indicador do banco precisa de amortecimento próprio** — DOWN só após N falhas consecutivas, UP
  na primeira que passar. Não basta o `retries` do Compose: o health check do Traefik reage à primeira
  falha, e sem amortecimento no indicador um soluço de rede tira as instâncias do balanceamento.
- **Exposição**: porta 8080 com allowlist no Traefik para os dois endpoints, e
  `management.endpoints.web.exposure.include` no **default** do Spring (só `health`) como segunda
  camada. Esta fase não deve incluir endpoint algum a mais "para facilitar o debug" — é exatamente o
  que a contenção existe para impedir.
- **Health group próprio para as dependências**, consumido por Prometheus e Grafana, nunca pelo
  Traefik.
- **Provar UP é pouco.** Esta fase entrega valor de verdade se provar também o **DOWN correto**:
  parar o PostgreSQL e ver o `readiness` cair *depois* de N falhas, e o `liveness` permanecer UP.

## Notas do ticket 33 (esqueleto Maven)

O esqueleto está de pé e a API **sobe**, inclusive com o banco fora. Três coisas herdadas:

- **O `readiness` responde UP sem banco algum**, porque o esqueleto tem o **default** do Spring Boot.
  A decisão do ticket 28 — `ReadinessState` **+ PostgreSQL**, com amortecimento de N falhas
  consecutivas — **não está implementada**. É o trabalho central desta fase, não um ajuste.
- **Cuidado com um falso-verde já identificado**: `/actuator/env` responde **401, não 404**, porque o
  Spring Security intercepta antes de a exposição importar. Um teste "env não responde" passaria pelo
  motivo errado. A asserção precisa provar que o endpoint **não é servido** — por exemplo verificando
  o conjunto de endpoints expostos, não o código HTTP de uma requisição não autenticada. Senão alguém
  inclui `*` em `management.endpoints.web.exposure.include` "para debugar" e o teste continua verde.
- **A API já tem datasource configurado** com `initialization-fail-timeout: -1`, que é o que permite o
  contexto subir com o banco fora — condição necessária para que o `readiness` seja quem reporta a
  indisponibilidade, em vez de o container morrer no arranque.
- **Esta fase precisa de um PostgreSQL disponível** para ser demonstrável de ponta a ponta, porque
  provar o DOWN correto exige derrubá-lo. Não é fase que se resolva com a aplicação sozinha.

## Answer

**Quarta e última fase inicial, encerrada com aprovação.** `mvn clean install` verde, 13 testes.

API na porta **8080**, três grupos de health, exposição no default do Spring, `compose.yaml` com
PostgreSQL e healthcheck apontando para o `readiness` (`start_period` de 60 s), e oito testes novos
no módulo da API.

### Provado de ponta a ponta, não apenas configurado

```
com banco:      UP    banco 0/–     HTTP 200
sem banco #1:   UP    banco 1/3     HTTP 200
sem banco #2:   UP    banco 2/3     HTTP 200
sem banco #3:   DOWN  banco 3/3     HTTP 503
banco de volta: UP    banco 0/–     HTTP 200
```

E o que mais importa: com o banco fora, o **`liveness` permaneceu UP e o container não reiniciou**
(`restarts=0`, `running=true`). É a prova de que "liveness nunca depende de recurso externo" está
implementado, e não só escrito.

O Compose marcou o serviço `unhealthy` na queda, como devia.

### Dois defeitos que só a prova de ponta a ponta revelou

**1. Os grupos estavam no nível errado do YAML, e o Spring ignorou em silêncio.**

Escritos em `management.group` em vez de `management.endpoint.health.group`. Chave desconhecida:
nenhum aviso, nenhuma falha no arranque, nada nos logs. O `readiness` respondia **`UP` com o
PostgreSQL derrubado** — exatamente o falso-verde que esta fase existia para não deixar passar.

Os outros testes não pegariam: o de exposição verifica quais endpoints são **servidos**, não o
**conteúdo** dos grupos. Daí ter nascido `GruposDeHealthTest`, que afirma que `readiness` contém
`banco`, que `liveness` **não** contém banco algum, e que o MinIO está fora.

**2. O `connectionTimeout` default do Hikari desativava o amortecimento inteiro.**

O default é **30 s**. Com o banco fora, `getConnection()` bloqueava até lá; o healthcheck estourava
o próprio timeout de 5 s; e a instância era marcada como não-saudável por **timeout de HTTP** — sem
que a falha jamais alcançasse o indicador `banco`. O contador de falhas consecutivas nunca
incrementava, e **o amortecimento simplesmente não acontecia**.

Este é o mais sutil dos dois: o comportamento observável estava *quase* certo — a instância saía do
ar quando devia —, mas pelo mecanismo errado, e o mecanismo errado não amortece nada. Um soluço de
rede de dois segundos teria tirado a instância do balanceamento na primeira ocorrência.

Fixado em `connection-timeout: 2000`, que cabe com folga no timeout de 5 s do healthcheck. Depois
disso o `readiness` responde em ~2 s e o contador incrementa como decidido.

### O que ficou registrado no código

- **`IndicadorDeBancoAmortecido`** — assimétrico de propósito: DOWN após N falhas, UP na primeira que
  passar. Distinto do `db` auto-configurado, que reporta estado **cru** e alimenta o grupo
  `dependencias`. Um serve para observar; o outro, para decidir tráfego.
- **`application.yaml`** — a altura do bloco `group` tem aviso explícito, porque o erro é silencioso
  e já aconteceu uma vez. O `connection-timeout` tem o motivo escrito ao lado, porque é a diferença
  entre o amortecimento funcionar e ser contornado.
- **`compose.yaml`** — registra que `retries` amortece **só** o Compose, e que o health check do
  Traefik reage à primeira falha; é por isso que o amortecimento de verdade mora na aplicação.

### Sobre o falso-verde herdado do ticket 33

`ExposicaoDoActuatorTest` verifica o **conjunto de endpoints expostos** via `WebEndpointsSupplier`,
não o código HTTP. Confirmado por medição que `/actuator/env`, `/beans` e `/heapdump` respondem
**401** — o Spring Security intercepta antes de a exposição importar —, então um teste por HTTP
passaria mesmo com `*` na configuração. O teste escrito falharia.

### Escopo

O `compose.yaml` é o da fase inicial: PostgreSQL e API. Keycloak, MinIO, Airflow, Traefik e a stack
de observabilidade entram com os tickets que os decidem. O `Dockerfile` instala `curl` para o
`HEALTHCHECK` — peso deliberado, registrado no próprio arquivo.
