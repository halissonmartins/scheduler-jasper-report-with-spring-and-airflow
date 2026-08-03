# 33 — Esqueleto Maven multi-módulo compilando

Type: task
Status: resolved
Blocked by: 01, 05, 21

## Question

O monorepo compila?

Fase inicial do documento: "Módulos compilando". Este é um ticket de execução — não há o que decidir, as decisões vieram dos tickets 01 (nomes), 05 (versões e layout) e 21 (contrato do Starter).

Entregar:

- `pom.xml` raiz com o reactor e a gestão de versão única do monorepo.
- Módulo da **biblioteca comum**.
- Módulo do **starter do processador com Spring Batch**, expondo a SPI decidida no ticket 21 (interfaces, sem implementação de produto).
- Módulo da **API REST**.
- Os **5 módulos processadores**, cada um implementando a SPI com stub — compilam, ainda sem relatório de verdade (os modelos de dados e JRXMLs estão na névoa do mapa).
- Módulo **frontend** integrado ao build conforme decidido no research 05.
- `mvnw` (wrapper) configurado.
- `mvn clean install` verde, com JaCoCo ativo.

Ao final, **solicitar revisão e aguardar aprovação** antes de encerrar a fase.

## Notas do ticket 21 (contrato do Starter)

- **A SPI do Starter é uma interface e um `ObjectProvider`** — o esqueleto precisa deixar a dependência
  `módulo processador → starter` desenhada, e cada módulo com pelo menos um bean de Relatório para
  provar que o mecanismo de descoberta funciona.
- **Estrutura interna de um módulo processador** (pendência explícita do documento, respondida no
  ticket 21): um pacote por Relatório, JRXML em `src/main/resources/jasper/`, fontes e imagens ao lado
  como recursos do próprio módulo.
- **Sem `DataSource` para o Spring Batch** (ticket 04): nenhum módulo declara datasource de
  `JobRepository`, e nenhuma migração `BATCH_*` existe. Isso muda o que o esqueleto precisa (e não
  precisa) trazer.
- **Enforcer de versão única do JasperReports no POM raiz** (ticket 05) — e ele não é o mesmo que um
  gate de versão mínima, que o ticket 18 decidiu **não** ter. Vale escrever a distinção no POM, porque
  é fácil supor que um cobre o outro.
- **Uma imagem por módulo** (ticket 19), com dois modos de execução: rodar uma Coleta e
  `--publicar-inventario`.

## Notas do ticket 29 (métricas e cardinalidade)

- **A regra de label vale desde o primeiro `Counter` escrito**: só é permitido label cujo conjunto de
  valores seja limitado por cadastro, nunca por uso. Como a guarda ficou **documental** (risco aceito
  no ticket 29), não há nada no build que a imponha — então ela precisa estar visível onde as métricas
  nascem, não só na especificação.
- **O SDK do OTel fica ligado em todo ambiente**, com `otel.*.exporter=none` nos testes (ticket 26).
  Isso é configuração do esqueleto, não de cada módulo, e é o que mantém o MDC preenchido para o
  Correlation ID.
- **O conversor de authorities e o filtro de desserialização vivem em `relatorios-comum`** — junto com
  a instrumentação compartilhada. O esqueleto define onde essas três coisas moram.

## Notas do ticket 30 (estratégia de teste e CI)

- **Os `.feature` vivem no código**, em `src/test/resources`, onde o Cucumber os executa. A
  especificação carrega apenas a **lista** dos cenários obrigatórios — o esqueleto precisa deixar o
  caminho pronto para os dois usos (integração e aceitação).
- **Testcontainers no esqueleto desde já**: `testcontainers-postgresql` e `testcontainers-minio` (2.x),
  com singleton e `@ServiceConnection`. **Reuso de container é armadilha** — a doc diz que não serve
  para CI.
- **`JobOperatorTestUtils`**, não `JobLauncherTestUtils`: mudou no Spring Batch 6. É o que permite
  rodar a Coleta in-process na camada de integração, sem Compose.
- **JaCoCo com gate de não-regressão**, não meta absoluta. O esqueleto configura a medição; o gate
  compara com a main.
- **Runners ARM64** (`ubuntu-24.04-arm`) — mesma arquitetura do desenvolvimento e da produção.
- **A VM de produção precisa de toolchain de build** (JDK, Maven, Docker), porque o CI para no teste e
  as imagens são construídas lá. Isso muda o que o `docker-compose` de produção pressupõe.

## Answer

`mvn clean install` **verde** nos onze módulos, 5 testes passando. **Fase encerrada com aprovação.**

```
relatorios-parent
  relatorios-comum                     biblioteca
  relatorios-processador-starter       biblioteca (SPI)
  relatorios-api                       executável
  relatorios-processador-{poupanca,cliente,contacorrente,consorcio,emprestimo}
                                       executáveis, 2 beans de Relatório cada
  relatorios-web                       frontend-maven-plugin no reactor
  cobertura                            report-aggregate do JaCoCo
```

Verificado, não suposto: `${revision}` **materializado** nos POMs instalados (não vaza literal);
JasperReports **7.0.7** convergindo em todos os módulos; API e processadores repackaged como
executáveis, `comum` e `starter` como jars simples; `static/index.html` dentro do jar do frontend.

### Versões confirmadas no Maven Central

Todas as decididas existem. Uma observação com consequência: **JasperReports 7.0.7 é ao mesmo tempo
o piso obrigatório (CVE-2026-6009) e a versão mais recente** — não há para onde subir hoje, e o
controle primário desta fronteira (ADR 0002) está no limite superior do que existe.

### Três achados que a fase seguinte herda

**1. A API não subia.** Com `spring-boot-starter-jdbc` no classpath, o contexto exige datasource
configurado — falhava com *"Failed to configure a DataSource"*. Configurado com
`initialization-fail-timeout: -1`, ela **sobe com o banco fora**, que é o comportamento correto:
quem reporta indisponibilidade é o `readiness`, não o arranque.

**2. O `readiness` responde UP sem banco algum.** Isso é o **default do Spring Boot**, não a decisão
do ticket 28 — que exige `ReadinessState` + PostgreSQL, com amortecimento de N falhas consecutivas.
**Não está implementado no esqueleto**, e é trabalho do ticket 34. Registrado para não parecer feito.

**3. Um falso-verde à espreita.** `/actuator/env` responde **401, não 404**: o Spring Security
intercepta antes de a exposição sequer importar. Um teste "env não responde" **passaria pelo motivo
errado**. O ticket 28 tratou a exposição default (`management.endpoints.web.exposure.include` = só
`health`) como contenção; o teste dela precisa provar que o endpoint **não é servido**, não que está
autenticado — senão alguém inclui `*` "para debugar" e o teste continua verde.

### Onde as decisões ficaram legíveis no próprio código

- **POM raiz** — distingue por extenso o enforcer de **versão única** (existe, contra divergência
  silenciosa entre módulos, porque `SERIAL_VERSION_UID` é constante fixa) do gate de **versão mínima**
  (que o ADR 0002 decidiu **não** ter). É fácil supor que um cobre o outro.
- **`RegraDeLabel`** — mora onde as métricas nascem, e não só na especificação, porque a guarda de
  cardinalidade ficou documental (ticket 29).
- **`FiltroDeDesserializacao`** — registra que é uma de **duas** defesas e que o grão de pacote não
  teria barrado o CVE que motivou o piso.
- **`ProcessadorAutoConfiguration`** — registra que os steps são obrigatoriamente single-thread, e que
  isso é imposto **pelo Starter**, não delegado ao módulo.
- **`application.yaml` da API** — o bloco `management` está no default **de propósito**, com o motivo
  escrito ao lado.

### Escopo deliberadamente não entregue

O **app Angular não existe**. O módulo `relatorios-web` prova a *integração* — Node baixado, build
executado, saída empacotada — com um script trivial no lugar de `ng build`. A arquitetura interna do
frontend está na névoa do mapa, e o protótipo do ticket 32 respondeu como as telas se comportam, não
como o frontend se organiza. Instalar Angular agora seria construir sobre decisão que não existe.

Os **JRXML e as consultas são stubs**: os modelos de dados vêm com o primeiro Produto (ticket 40).

### Correção registrada

Sobrescrevi o `.gitignore` existente — 59 linhas — com um de 6. Restaurado do git; acrescentadas
apenas as quatro entradas novas (`.flattened-pom.xml`, `**/node`, `**/node_modules`, `dist/`).
O `**/target` já existia.
