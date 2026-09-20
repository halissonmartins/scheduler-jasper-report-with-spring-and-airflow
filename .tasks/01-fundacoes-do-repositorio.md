# Fundações do repositório: cada módulo compila, sobe e é barrado pelo CI

> Build this with **tlc-implement**.
> Every criterion below becomes a check with a proof, referenced by its number. Nothing under
> `Unresolved` gets settled while building.

## Intent

Não existe repositório executável. São 15 arquivos versionados e todos são documento: quem chega
para construir qualquer fatia deste sistema não tem onde escrever, não tem esqueleto para copiar e
não tem portão que recuse o que quebra. Quem paga é quem constrói a fatia seguinte — sem um módulo
de referência, o segundo módulo nasce com outra estrutura, e no nono há nove convenções diferentes
para a mesma coisa. A fonte não traz número algum sobre isso: não há histórico de build nem tempo de
integração medido, e nada aqui inventa urgência que ela não declarou.

Quando isto existir, um clone limpo compila, a API REST responde que está viva nos dois endpoints do
Actuator, todo contêiner e toda JVM correm em `America/Sao_Paulo`, e nenhum pull request entra com
lint, teste ou build vermelhos. Não há tela nesta task.

5 criteria in 1 slice · 3 one-way doors · 2 open, of which 0 block

## Criteria

1. Quando um clone limpo é construído com o Maven, então o build termina com código de saída 0 e produz artefato para todos os módulos.
2. Quando a API REST termina de subir, então `/actuator/health/liveness` e `/actuator/health/readiness` respondem `200` com `status` igual a `UP`.
3. Sempre, todo contêiner do Docker Compose e toda JVM da pilha reportam o fuso `America/Sao_Paulo`.
4. Se lint, teste ou build terminam com código de saída diferente de 0, então o merge do pull request fica impedido.
5. Enquanto o perfil de teste está ativo, o SDK do OpenTelemetry permanece desabilitado, e nenhum teste depende do Collector nem emite telemetria.

## Out of scope

- Qualquer regra de negócio — T1 entrega esqueleto e portão, não comportamento de domínio
- A primeira migration do Flyway — nasce em T2, onde existe a primeira entidade a versionar
- Protótipo descartável em HTML/CSS/JS e Swagger descartável — descartáveis por definição; promovê-los é dívida técnica no dia zero (guia, P1 e E0)
- Deploy em produção ou homologação, e Kubernetes — a primeira versão executa só em ambiente local (RA-50)

## Observable

| Surface | Decision | Landing |
| --- | --- | --- |
| API `GET /actuator/health/liveness` e `/actuator/health/readiness` | forma da resposta | 2 |
| API `GET /actuator/health/*` | forma do erro e seus códigos | n/a - o contrato do Actuator é do Spring Boot e não é redefinido aqui; o envelope de erro da aplicação é a porta registrada em T2 e provada em T8 |
| API `GET /actuator/health/*` | quem pode chamar | Unresolved 1 |
| API `GET /actuator/health/*` | versionamento | n/a - o caminho do Actuator é do framework e não recebe o prefixo `/api/v1` |
| API `GET /actuator/health/*` | limite de requisição | n/a - ambiente local sem exposição externa (RA-50) |
| comando `build Maven` | formato e verbosidade da saída | n/a - saída padrão do Maven; a fonte não a fixa e nada depende dela |
| comando `build Maven` | flags e seus padrões | n/a - nenhuma flag própria do projeto; `mvn clean install` sem parâmetro |
| comando `build Maven` | código de saída | 1 |
| comando `build Maven` | falha no meio do caminho | 4 |
| tarefa `pipeline de CI` | código de saída e o que barra o merge | 4 |

Nenhuma tela, documento ou coleção é exposta por T1.

## Swept

- validation: n/a - T1 não recebe entrada de usuário; o Actuator não tem parâmetro e o build não tem flag própria
- failure modes: 4
- idempotency and retry: n/a - o build é reexecutável por natureza e T1 não persiste estado algum
- authorization: Unresolved 1
- concurrency and ordering: n/a - nada em T1 tem dois atores sobre o mesmo estado; o build é local e o pipeline age sobre o seu próprio commit
- data lifecycle: n/a - T1 não grava linha nem objeto; a primeira tabela nasce em T2 e o primeiro artefato em T3
- external-dependency failure: Unresolved 2
- state transitions: n/a - T1 não introduz ciclo de vida
- observability: 5 — é o único aspecto de telemetria que T1 fixa; a instrumentação de log, métrica e Correlation ID é T8

## Impact

| Front | What changes |
|---|---|
| domínio | nenhum termo novo e nenhum termo com sentido alterado: T1 não introduz conceito de domínio, e os termos seguem definidos uma única vez em `docs/glossario.md` |
| dado armazenado | nada a migrar — não há base nem linha; a API de T1 sobe contra schema vazio, e a primeira migration do Flyway nasce em T2 |
| dependência externa | PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit e a pilha de telemetria passam a subir pelo Docker Compose (RA-51); nenhuma é integração com terceiro |

## Decided

| Decision | Shape | Alternative rejected |
|---|---|---|
| Versão única do JasperReports em todo o mono repositório | propriedade `jasperreports.version` no POM pai, herdada por processadores e pela API | versão por módulo — o `serialVersionUID` do `.jrprint` deixa de casar entre quem grava e quem lê, e os quatro trade-offs de `arquitetura-inicial.md` §12 caem juntos |
| Fuso fixo em toda a pilha | `TZ=America/Sao_Paulo` em todo serviço do Compose e a mesma propriedade na JVM | UTC com conversão na borda — a data de referência é resolvida no disparo do ciclo, e um ciclo de 03h00 lido em UTC cai no dia anterior (RN-07) |
| Esqueleto do módulo de referência | um módulo Maven completo — POM filho, estrutura de pacote e `src/test/resources/feature` (RA-45) — que os outros 8 módulos copiam | decidir a estrutura módulo a módulo, no diff de cada um. **Esta porta alcança além de T1:** num repositório vazio o primeiro esqueleto vira o padrão que os demais copiam, e corrigi-lo depois move nove módulos de uma vez. `plan.md` classifica estrutura de pacote como decidida no diff, o que vale para o nono módulo e não para o primeiro |

## Surface

| Route | In | Out | Status | Criteria |
|---|---|---|---|---|
| `GET /actuator/health/liveness` | — | `status` | `200`, `503` | 2 |
| `GET /actuator/health/readiness` | — | `status` | `200`, `503` | 2 |

## Sources

- `.specs/features/scheduler-jasper-report/plan.md` — fatia S1; os critérios 1 a 5 desta task correspondem aos AC 1 a 5 de lá
- `docs/arquitetura-inicial.md` — RA-01 a RA-08 (repositório e módulos), RA-39 (OTel em teste), RA-43 (Actuator), RA-45, RA-50 a RA-53
- `docs/guias/guia-app-web.md` — E1, que fixa os artefatos de fundação exigidos
- Nenhum design é fonte desta task: T1 não tem tela

This task is the record of decision. If a linked document diverges, ask before building.

## Unresolved

| # | Kind | Question | Until answered |
|---|---|---|---|
| 1 | open | Os endpoints do Actuator são expostos sem autenticação? | escrito assim: sem autenticação, porque RA-43 e a tabela `Surface` do plano declaram apenas `200` e `503`, e RA-50 restringe a execução ao ambiente local. Se a resposta for "com autenticação", o critério 2 ganha o caso `401` e a linha `quem pode chamar` de `Observable` muda de aterrissagem |
| 2 | open | O `readiness` agrega a saúde do PostgreSQL e responde `503` quando o banco não responde? | escrito assim: agrega, que é o padrão do Actuator. Se não agregar, a API declara-se pronta sem banco, e o critério 2 passa num estado em que nenhuma rota de T2 em diante funciona |
