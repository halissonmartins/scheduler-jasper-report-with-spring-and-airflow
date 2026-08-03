# 48 — Deploy, upgrade e runbook de incidente

Type: grilling
Status: open
Blocked by: —

## Question

Como o sistema vai para produção, como sobe de versão, e o que se faz quando quebra?

Graduou da névoa carregando quatro procedimentos que ganharam risco próprio ao longo do mapa. A névoa
os acumulou; agora eles são específicos o bastante para virar decisão.

Decidir:

- **O procedimento de deploy.** O ticket 30 aceitou que o **CI para no teste**, então a VM constrói as
  imagens: ela precisa de toolchain de build, e o deploy tem de **fixar SHA ou tag, nunca `main`
  HEAD** — sem registry, o commit é o único elo entre o que foi testado e o que roda.
- **A ordem de subida.** O ticket 04 registrou uma sequência com `--publicar-inventario` por módulo
  (passo idempotente de bootstrap). O ticket 37 tornou o inventário obsoleto **detectável mas não
  fatal**. Decidir onde cada passo entra e o que é pré-requisito de quê.
- **O passo manual da árvore de Grupos** (ticket 38): criar a raiz, o `PENDENTES` e a marcação de
  Default Group, lembrando que o `--import-realm` é **pulado** em realm existente. A API confere por
  leitura no boot e reclama pelo health group `dependencias`.
- **O upgrade do Keycloak** (ticket 17): acumulou-se configuração viva que o import de realm não
  reproduz — allowlist do Traefik que falha fechada por decisão, permissões de FGAP, Default Group,
  Account Console enxugado. Decidir o que é reaplicado, em que ordem, e como se confere.
- **A chave de licença do AIStor** (ticket 35 / ADR 0003): obtenção no SUBNET, armazenamento,
  **renovação a cada 24 h**, e o que fazer quando ela falha — comportamento que a documentação apurada
  **não define**. É o risco aceito mais aberto do mapa.
- **Runbook de incidente.** O ticket 29 aceitou **alertas sem notificação**, então todo incidente
  começa por alguém olhando o painel-resumo. Escrever o que se faz a partir de cada sinal daquela tela:
  varredura parada, execuções fechadas pela varredura, `ALERTA` recorrente, ocupação do bucket subindo.
- **Rollback.** Imagem anterior, migração de schema já aplicada — o Flyway não desfaz. Decidir se há
  rollback ou só roll-forward, e o que isso exige das migrações.

## Notas de tickets anteriores

- **Ticket 28**: o `readiness` cai após N falhas consecutivas e volta na primeira que passa; o
  `retries` do Compose **não** basta porque o health check do Traefik reage à primeira falha.
- **Ticket 19**: uma imagem por módulo, com risco aceito de **divergência de versão do Jasper** entre
  elas, contido por comparação que alerta sem recusar. O deploy é onde essa divergência nasce.
- **Ticket 37**: `imagem_origem` é gravada em cada Execução. É o elo que liga um artefato ao commit —
  e só funciona se o deploy fixar SHA.
