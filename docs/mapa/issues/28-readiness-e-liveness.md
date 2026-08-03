# 28 — Health: readiness reflete dependências externas?

Type: grilling
Status: resolved
Blocked by: 05

## Question

O que exatamente `/actuator/health/readiness` e `/actuator/health/liveness` verificam?

O documento exige que a API REST responda UP nos dois endpoints, na porta 8080 — mas não diz o que eles checam.

Decidir:

- **Liveness nunca depende de recurso externo.** Se depender, uma indisponibilidade do PostgreSQL derruba e reinicia containers saudáveis num laço. Confirmar e escrever.
- **Readiness reflete dependências?** Se refletir PostgreSQL, MinIO e Keycloak, uma queda do MinIO tira **todas** as instâncias do balanceamento do Traefik — e a API deixa de responder até a listagem, que só precisa do banco. Pode ser o comportamento desejado ou catastrófico. Decidir por dependência: qual entra no readiness e qual não.
- **Degradação parcial.** Existe um estado em que a API lista relatórios mas não exporta (MinIO fora)? Vale expor isso como health group próprio em vez de derrubar o readiness.
- **Health dos processadores.** Um container batch efêmero precisa de health endpoint? Provavelmente não — confirmar e registrar.
- **Quem consome.** Traefik para balanceamento e Docker Compose para healthcheck e ordem de subida. Definir os intervalos e o `start-period`.
- **Exposição.** Os endpoints do actuator ficam públicos, atrás do Traefik com restrição, ou em porta separada.

## Notas do ticket 17 (sessão e exposição)

- **O Keycloak não entra no readiness.** O ticket 15 tirou o Keycloak do caminho quente (autorização
  sai só da claim) e o JWKS é cacheado. Uma queda do Keycloak impede login e refresh, mas **não**
  impede quem já tem token válido de listar e gerar relatórios. Amarrar readiness ao Keycloak tiraria
  de operação instâncias perfeitamente capazes de trabalhar — e o faria justamente no momento em que
  ninguém consegue relogar para contornar.
- **Isso deixa a pergunta interessante só para PostgreSQL e MinIO**, que têm perfis diferentes:
  sem banco, nada funciona (nem a listagem); sem MinIO, a listagem funciona e a exportação não. É o
  caso concreto de "degradação parcial" que o ticket já levanta.
- **A allowlist do Traefik é do host do Keycloak**, não da API — mas a decisão de exposição do
  actuator daqui precisa seguir o mesmo princípio de falhar fechada: publicar o que se quer público,
  não bloquear o que se lembra de bloquear.

## Answer

### O quadro

| | |
|---|---|
| `liveness` | apenas `LivenessState` — **nunca** depende de recurso externo |
| `readiness` | `ReadinessState` **+ PostgreSQL**; MinIO fora |
| Indicador do banco | DOWN só após **N falhas consecutivas**; UP na primeira que passar |
| Exposição | porta 8080, allowlist no Traefik, com a exposição default do Spring como segunda camada |

O padrão do Spring Boot 4 é o ponto de partida, e ele é explícito: *"Actuator configures 'liveness'
and 'readiness' probes as Health Groups... **By default, Spring Boot does not add other health
indicators to these groups**."* Incluir o PostgreSQL é ato deliberado, registrado abaixo como risco
aceito.

### `liveness` nunca depende de nada externo

Confirmado e escrito. Um `liveness` que reflita o banco derruba e reinicia containers saudáveis num
laço durante uma indisponibilidade — a pior reação possível, porque remove justamente a capacidade de
servir enquanto a dependência volta.

### MinIO fora do `readiness`: degradação parcial preservada

Sem MinIO, a listagem funciona e a exportação falha com código do catálogo e Correlation ID
(ticket 26). Isso é estritamente mais útil que tirar a instância do ar: o usuário descobre o que está
quebrado, e o Graylog recebe o pedido.

**As duas dependências ficam visíveis num health group próprio** — consumido por Prometheus e Grafana,
**não** pelo Traefik. É onde a observação mora sem virar decisão de balanceamento.

### Processadores não têm endpoint de health

Container efêmero que roda um job e sai. O sinal dele é o **exit code**, já contratado no ticket 19,
e não haveria quem consultasse um endpoint durante os segundos de vida do processo.

### Risco aceito 1: PostgreSQL no `readiness`

Argumentei por manter o default do Spring. O raciocínio: `readiness` responde *"mandar tráfego para
**aqui** em vez de para **outro lugar**?"* — e numa dependência **compartilhada** não existe outro
lugar. Todas as instâncias ficam igualmente afetadas, então tirá-las todas do balanceamento apenas
troca um erro de aplicação diagnosticável por um `503` opaco do gateway.

E o erro de aplicação não é qualquer um: o ticket 26 montou um catálogo RFC 9457 com Correlation ID
justamente para que a falha chegue investigável ao usuário e ao Graylog. O `503` do Traefik não tem
corpo útil, não tem código, não tem Correlation ID, e o pedido nem aparece no log da aplicação.

**Decisão: incluir o PostgreSQL.** Consequência: numa queda do banco, todas as instâncias saem juntas
e o usuário recebe `503` do Traefik.

### Contenção: o indicador espera confirmação

O risco operacional que a inclusão cria é o **oposto** do problema que ela resolve. O
`DataSourceHealthIndicator` executa uma consulta de validação a cada verificação — um soluço de dois
segundos derruba o indicador, a instância sai do balanceamento, a verificação seguinte passa, e ela
volta. Com poucas instâncias, esse vaivém é mais disruptivo que a falha original.

O indicador é **assimétrico de propósito**: DOWN só após N falhas consecutivas, UP na primeira que
passar. Sair do ar é caro; voltar é barato.

**Onde o amortecimento vive importa**: o `healthcheck` do Compose tem `retries` e amortece sozinho; o
health check do Traefik reage à **primeira** falha. Então o amortecimento precisa estar **no
indicador**, não apenas no Compose — senão o Traefik continua tirando a instância no primeiro soluço.

### Risco aceito 2: actuator na porta pública

Argumentei por `management.server.port` numa porta separada, não publicada: falharia fechada **por
construção**, sem rota pública a configurar errado, e um endpoint novo numa versão futura do Spring
nasceria inalcançável.

**Decisão: mesma porta 8080, com allowlist no Traefik** publicando apenas
`/actuator/health/liveness` e `/actuator/health/readiness`.

### Contenção: a exposição default do Spring

O Spring Boot expõe por padrão **apenas `health`** sobre HTTP. `env`, `configprops`, `beans`,
`mappings` e `heapdump` só ficam alcançáveis se alguém os incluir explicitamente em
`management.endpoints.web.exposure.include`.

**Mantendo o default, a allowlist deixa de ser a única barreira e vira a segunda.** Mesmo uma regra de
rota errada não alcança nada perigoso, porque não há nada perigoso sendo servido. É o mesmo padrão de
duas camadas que os research 07 e 11 recomendaram para o Keycloak — e aqui ele sai de graça, sem
configuração alguma.

### Consumidores e intervalos

- **Compose**: `healthcheck` com `start_period` cobrindo a partida da JVM e a subida do contexto
  Spring, mais `retries` como amortecimento próprio. As migrações não entram nessa conta — elas rodam
  no bootstrap (ticket 04), não no arranque da API.
- **Traefik**: health check no mesmo endpoint, reagindo à primeira falha — o que torna o amortecimento
  do indicador obrigatório, e não opcional.

## Notas do ticket 38 (árvore de Grupos)

- **O health group `dependencias` ganha um consumidor novo**: a conferência de que a raiz `/relatorios`
  existe, o `PENDENTES` existe e é Default Group do realm. Somente leitura.
- **Ele foi escolhido no lugar de log**: sem canal de notificação (ticket 29), "reclamar alto" no log
  é reclamar no vazio, e o grupo de dependências existe exatamente para o que precisa ser observável
  sem virar decisão de balanceamento.
- **Não toca o `readiness`**, preservando a decisão do ticket 17 de manter o Keycloak fora dele — uma
  estrutura de grupo ausente não deve tirar a instância de rotação.
