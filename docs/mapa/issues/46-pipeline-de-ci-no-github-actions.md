# 46 — Pipeline de CI no GitHub Actions

Type: grilling
Status: resolved
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

## Answer

### O que já estava fechado

O ticket 30 decidiu mais deste ticket do que ele supunha ao ser escrito: **runners
`ubuntu-24.04-arm`** (arquitetura de produção, Docker sem DinD, gratuito em repo público), as três
camadas, **k6 fora do gate** porque calibra em vez de verificar, **publicação de imagem fora** (risco
aceito), e **cobertura por não-regressão** em vez de percentual.

O que restava era o **como** — e duas peças estavam de fato indefinidas.

### A linha de base da cobertura

"Não cair em relação à main" exige ter a main com que comparar, e o ticket 30 não disse de onde ela sai.

**O workflow de merge publica o XML do JaCoCo como artefato; o PR baixa o mais recente da main e
compara.** Sem serviço externo, sem token, sem dado de cobertura saindo do repositório — coerente com
um CI que não tem segredo algum e onde PR de fork continua rodando.

**Quando o artefato não existe** — primeiro run, ou expirado nos 90 dias padrão — o job **roda a main
uma vez** para regenerá-lo. Caminho normal barato, caminho de exceção correto.

> **E o fallback precisa ser barulhento.** Baseline ausente falha **aberta** por necessidade — não ter
> a linha de base não é evidência de regressão. Mas regenerar em silêncio faria um artefato expirado
> transformar o gate em enfeite sem ninguém notar. Quando o fallback roda, ele diz que rodou.

Rodar os testes da main em todo PR seria sempre exato e **dobraria o tempo de cada PR** — com
Testcontainers em cada camada, é justamente o orçamento que o ticket 30 gastou desenhando um gate leve
para preservar. Serviço externo faria isso melhor e traria token e envio de dados para fora, decisão
que ninguém no mapa tomou.

### A lista de cenários obrigatórios vira executável

O ticket 30 chamou a lista de **"o gate que de fato importa"** e a deixou verificada em revisão. Ela já
passou de trinta itens — os tickets 37, 38, 39, 40, 43 e 45 acrescentaram os seus.

**Cada item da especificação é um identificador; cada identificador é um teste marcado; um passo do CI
afirma que todos rodaram e passaram.**

> **O assert é "rodou e passou", nunca "existe".** Um teste `@Disabled` satisfaria a presença sem
> provar nada — mesma classe de falso verde que derrubou o `readiness` no ticket 34 (grupo no nível
> errado do YAML, ignorado em silêncio) e que o ticket 37 evitou ao exigir assert na métrica.

**A conferência tem duas direções, e as duas importam:**

| | pega |
|---|---|
| id na lista sem teste | cenário removido em silêncio de uma lista de trinta itens |
| teste marcado sem id na lista | cenário que alguém marcou e ninguém justificou |

A segunda direção é o que preserva a razão de a lista existir: o ticket 30 a criou porque percentual de
cobertura premia os testes errados, e a **justificativa** de cada cenário mora no ticket que o nomeou.
Sem ela, a marcação vira decoração.

Deixar manual custaria nada a construir, e quem revisa é exatamente quem sabe por que cada cenário
importa — conhecimento que nenhum assert carrega. Mas atenção em revisão não escala com uma lista que
só cresce, e a conferência passa a acontecer quando alguém lembra.

### Os workflows

```
pr      unidade + integração
merge   + aceitação + E2E + publica o artefato de cobertura
k6      agendado ou sob demanda, fora do gate
```

- **Upgrade do Keycloak dispara o E2E completo** (ticket 17): a allowlist do Traefik falha fechada por
  decisão, e as features do realm são configuração viva que o import não reproduz.
- **Cache de Maven pelo `setup-java`; imagens Docker não.** O research 09 mediu ~13 s a frio contra ~2 s
  em cache, e restaurar camadas de imagem no runner custa mais do que economiza.
- **Nenhum segredo.** O ADR 0003 fixou MinIO AGPL na tag `RELEASE.2025-10-15T17-29-55Z` nos
  Testcontainers — não há chave do AIStor no CI.

### Derivado

- **A publicação de imagem continua fora** (risco aceito no ticket 30), o que mantém de pé a exigência
  do [ticket 48](48-deploy-upgrade-e-runbook.md): o deploy fixa **SHA ou tag, nunca `main` HEAD**,
  porque sem registry o commit é o único elo entre o que foi testado e o que roda.
- **O teste de que a fábrica de DAGs não faz chamada de rede no parse** (ticket 39) entra no gate de PR:
  é regressão barata de introduzir e cara de descobrir, porque o sintoma é DAG sumindo sem causa visível.
- **Os testes caros ficam fora do PR**: o de cursor com `-Xmx96m` e semente volumétrica, e o de fonte com
  `ignore.missing.font=false` (ticket 40). Ambos entram no merge.

## Notas do ticket 48 (deploy e runbook)

- **Cenário obrigatório novo, e é de disciplina, não de código**: a migração do release é aditiva e a
  imagem **anterior** continua subindo contra o schema novo. É o que substitui o rollback (ticket 48), e
  sem estar na lista executável é combinado que se esquece exatamente no release apertado.
- O teste tem forma concreta: aplicar as migrações do SHA novo e subir o container do SHA anterior
  contra esse banco.
