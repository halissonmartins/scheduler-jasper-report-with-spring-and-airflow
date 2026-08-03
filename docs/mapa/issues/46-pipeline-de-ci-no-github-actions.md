# 46 — Pipeline de CI no GitHub Actions

Type: grilling
Status: open
Blocked by: —

## Question

Como o pipeline é escrito, dado que o ticket 30 já decidiu **o que** roda em cada camada?

Graduou da névoa quando a estratégia de teste (ticket 30) e o esqueleto Maven (ticket 33) fecharam.

O ticket 30 fixou: **PR leve, merge completo**, k6 fora do gate, cobertura por não-regressão mais a
lista de cenários obrigatórios. Falta traduzir isso em workflow.

Decidir:

- **Jobs e dependências.** Um job por camada, ou um job com fases? O que roda em paralelo, e o que a
  matriz precisa cobrir (ARM64 é a arquitetura de produção — ticket 11 — e os runners padrão do GitHub
  são x86).
- **Cache do Maven e do Testcontainers.** O ticket 09 mediu ~2 s por container **com cache**; sem
  cache, cada job paga o pull. Decidir o que é cacheado e o que é reconstruído.
- **Gate de cobertura JaCoCo.** O ticket 30 decidiu **não-regressão** em vez de percentual. Traduzir
  isso num gate executável — o que é a linha de base, onde ela é guardada, e o que acontece num PR que
  toca só configuração.
- **A lista de cenários obrigatórios é o gate real** (ticket 30). Ela é conferida a mão, ou vira teste
  nomeado que o CI exige? Onze tickets nomearam cenários; os tickets 37, 38, 39 e 40 acrescentaram mais.
- **Publicação de imagens — ou a ausência dela.** O ticket 30 aceitou o risco de **o CI parar no
  teste**, com a VM construindo as imagens. Decidir se isso continua, e se não, o que muda no ticket 30
  e no ticket 19 (divergência de versão do Jasper entre imagens).
- **Segredos.** O CI precisa de chave do AIStor? O ADR 0003 diz que **não** — Testcontainers sobem
  MinIO AGPL congelado. Confirmar que nenhum job precisa de segredo, o que simplifica PRs de fork.

## Notas de tickets anteriores

- **ADR 0003**: fixar a tag `RELEASE.2025-10-15T17-29-55Z` do MinIO explicitamente — `latest` não é
  caminho confiável desde o arquivamento.
- **Ticket 30**: o CI parar no teste **agrava** a divergência de versão do Jasper aceita no ticket 19,
  porque não há momento único de build. O deploy precisa fixar SHA ou tag, nunca `main` HEAD.
- **Ticket 40**: o teste de cursor roda com `-Xmx96m` e semente volumétrica; o de fonte usa
  `net.sf.jasperreports.awt.ignore.missing.font=false`. Os dois são caros e não pertencem ao gate leve.
- **Ticket 39**: o teste de que a fábrica **não faz chamada de rede no parse** é regressão fácil de
  introduzir — precisa estar no gate.
