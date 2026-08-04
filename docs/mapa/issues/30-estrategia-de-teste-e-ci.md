# 30 — Estratégia de teste em camadas e CI

Type: grilling
Status: resolved
Blocked by: 05, 09

## Question

Quais camadas de teste existem, o que cada uma prova, e o que roda no CI?

O documento exige TDD, BDD, Gherkin para todo comportamento observável pelo negócio (aceitação e integração, **inclusive a Coleta**), JUnit 5 + Cucumber para integração, Newman + psql para E2E, Playwright para E2E de navegador, e JaCoCo para cobertura. O research 09 traz os fatos sobre H2 vs Testcontainers.

Decidir:

- **A pirâmide concreta.** O que é teste de unidade, o que é de integração, o que é de aceitação e o que é E2E neste projeto — com a fronteira escrita, não implícita. Hoje "integração" e "aceitação" ambos usam Gherkin e a diferença não está definida.
- **Onde os `.feature` vivem** e quem os escreve. Se o Gherkin é a especificação do comportamento de negócio, ele é artefato da spec ou do código?
- **Como se testa a Coleta com Gherkin.** Um cenário que dispara um job Spring Batch, lê de um schema transacional semeado e verifica artefato no MinIO e linha de metadados. Definir os fixtures e o isolamento entre cenários.
- **Banco de teste.** Consequência da decisão do research 09. Se for Testcontainers, definir reuso e tempo de CI; se ficar H2, escrever explicitamente quais migrações e tipos ficam proibidos.
- **Metas de cobertura** por módulo e o gate no CI.
- **Pipeline no GitHub Actions**: jobs, ordem, o que roda em PR vs em merge, cache do Maven e do npm, e onde os E2E entram (precisam da stack de pé — Compose no runner?).
- **Runner ARM64 vs x86.** O ambiente de desenvolvimento é aarch64; os runners do GitHub são x86 por padrão. Decidir se isso importa para as imagens.

## Notas de research

- **Ticket 09 — decidido por evidência empírica**: o H2 sai. Probe JDBC contra H2 2.4.240 em
  `MODE=PostgreSQL` mostrou que ele **aceita** `CREATE TABLE ... jsonb`, converte a coluna para
  `json` e, no mesmo `INSERT`, grava uma string escapada onde o PostgreSQL grava o objeto — teste
  verde, produção divergente, **zero sinal**. Também quebram `ON CONFLICT (cols) DO UPDATE`,
  `->>`, `@>`, `jsonb_*`, `RETURNING`, `text[]`, GIN, `timestamptz` e plpgsql. E o Spring Batch
  versiona `schema-h2.sql` ≠ `schema-postgresql.sql`, então nem o JobRepository testado seria o de
  produção.
- **Ticket 09**: o custo alegado do Testcontainers não se confirmou — ~1,5–2,0 s com imagem em
  cache e ~13 s a frio neste ARM64; o runner `ubuntu-24.04-arm` já traz Docker, sem DinD. **Reuso
  de container é armadilha** (a doc diz "not suited for CI usage"); o padrão é singleton com
  `@ServiceConnection`.
- **Ticket 09 — correções de versão**: `JobLauncherTestUtils` virou `JobOperatorTestUtils` no
  Spring Batch 6, e os módulos Testcontainers 2.x são `testcontainers-postgresql` e
  `testcontainers-minio`.

## Notas do ticket 04 (schema de controle)

Coisas que só falham em produção se não houver teste específico:

- **Sete usuários de banco com `GRANT` restrito.** O teste precisa rodar com as **credenciais
  reais**, não como superusuário — senão o isolamento por Produto passa verde em teste e falha em
  produção. Um cenário que prove que `app_proc_poupanca` **não** consegue ler
  `transacional_cliente` vale mais que o resto da suíte nesse eixo.
- **O bootstrap tem ordem** (migrações do controle → migrações transacionais →
  `--publicar-inventario` por módulo → API). Essa sequência é testável e quebra em silêncio: se o
  inventário não publicar, nada é cadastrável e o sistema simplesmente não faz nada.
- **`ResourcelessJobRepository` não é thread-safe.** Não há teste que pegue isso por acidente — é
  regra a impor no build (enforcer ou teste de arquitetura), não a verificar em runtime.
- **A guarda `2 × tempo_estimado + margem ≤ LIMITE_ORFA` é validação de aplicação**, não `CHECK`.
  Precisa de teste próprio: sem ela, a varredura do ticket 02 fecha Execução viva.
- **Cadastro de Relatório fora do inventário** deve ser recusado — cenário Gherkin natural, e é o
  que impede o Relatório fantasma que falharia todo dia.

## Notas do ticket 15 (autorização)

- **Teste obrigatório, e a decisão do ticket 15 depende dele**: excluir um usuário no Keycloak
  precisa remover a sessão, de modo que o refresh falhe. A doc confirma que o refresh verifica a
  sessão pelo id, mas não afirma que excluir o usuário a remove. Se não remover, um usuário excluído
  segue renovando o token e a janela de revogação deixa de ser limitada a 300 s — o que derruba a
  proporcionalidade que sustenta a escolha de autorizar pela claim.
- **O conversor de authorities precisa de teste próprio.** Ele lê claim aninhada
  (`resource_access.<client>.roles`), e o modo de falha é **autorização silenciosamente vazia** —
  não exceção. Um teste que apenas verifique "403 quando não autorizado" passa mesmo com o conversor
  quebrado; é preciso o caso positivo, provando que a role certa concede.
- **O bypass do ADMINISTRADOR** merece cenário explícito nos dois sentidos: alcança Relatório sem
  Role de Relatório, e a linha de `download` sai marcada como bypass.

## Notas do ticket 16 (pendente de vínculo)

- **Vincular remove do `PENDENTES`.** São duas chamadas à Admin API que precisam parecer uma. O
  cenário que importa é o do meio do caminho: entrou no Grupo real e a remoção do `PENDENTES` falhou
  — o usuário fica contando como pendente para sempre e o contador mente. Testar o caminho de falha,
  não só o feliz.
- **A listagem de pendentes filtra `emailVerified = true`.** Um cadastro não verificado entra no
  `PENDENTES` na criação. Sem cenário para isso, o filtro é fácil de perder numa refatoração e
  ninguém percebe — a lista simplesmente fica maior.
- **O conversor de authorities lê duas claims**: Perfil em `realm_access.roles` e Roles de Relatório
  em `resource_access.<client>.roles`. Já havia teste exigido para a segunda (ticket 15); a primeira
  tem o mesmo modo de falha silencioso, e é dela que depende o bypass do ADMINISTRADOR.

## Notas do ticket 17 (sessão e exposição)

- **A allowlist do Traefik falha fechada, e é isso que exige smoke test.** Login, cadastro público,
  verificação de e-mail e troca de senha no Account Console precisam de cenário E2E de navegador
  (Playwright já está na stack). Uma rota que o Keycloak passe a usar numa versão nova quebra o fluxo
  — o que é o comportamento desejado, mas só ajuda se alguém descobrir **no CI** e não em produção.
- **Upgrade do Keycloak é evento de teste, não só de deploy.** A allowlist, as features desabilitadas
  no realm e as default roles enxugadas são configuração viva que o import de realm não reproduz
  (ele é semente e é pulado se o realm existe). O pipeline precisa exercitar os fluxos públicos
  contra a versão nova antes de promover.
- **O caminho interno API → Keycloak** (rede do Compose, sem Traefik) merece cenário próprio: se
  alguém apontar a API para o host público por engano, a Admin API responde 404 pela allowlist e a
  mediação do ticket 14 para de funcionar inteira.

## Notas do ticket 18 (desserialização)

- **O enforcer do piso 7.0.7 não existe** — a atualização do JasperReports é manual por decisão
  (ADR 0002), sem gate no CI e sem robô de dependência. O enforcer de **versão única** do ticket 05
  continua valendo e é outra coisa: ele impede divergência entre módulos, não versão velha. Vale
  deixar essa distinção explícita no build, porque é fácil supor que um cobre o outro.
- **Cenário de integridade**: um `.jrprint` cujo SHA-256 não bate com o gravado precisa ser recusado.
  É teste barato de escrever e é a única defesa contra adulteração no bucket — se ele silenciar numa
  refatoração, ninguém percebe, porque o caminho feliz continua verde.
- **Cenário do `ObjectInputFilter`**: um objeto de classe fora de `net.sf.jasperreports.**` e
  `java.**` precisa ser recusado na desserialização. Sem esse teste, o filtro pode estar desligado por
  configuração e todo o resto da suíte passa.
- **Limites de exportação são teste de carga, não unitário.** Como não há isolamento (ADR 0002), o
  OOM da API é o modo de falha real — e ele só aparece com `JasperPrint` grande vezes concorrência. O
  k6 está na stack; este é o cenário que justifica usá-lo.

## Notas do ticket 19 (contrato Airflow ↔ container)

- **`System.exit(SpringApplication.exit(...))` precisa de teste.** Sem ele, um job Batch falho sai com
  código 0 e o Airflow marca `success`. O modo de falha é o pior possível: tudo parece verde. Um teste
  que rode o container com um job que falha e afirme o exit code ≠ 0 é barato e cobre um requisito de
  contrato inteiro.
- **O índice único parcial merece cenário nos dois sentidos**: uma segunda Execução do mesmo par é
  **aceita** quando a anterior está em `ERRO`, e **rejeitada** quando está em `SUCESSO`, `ALERTA` ou
  `SEM_DADOS`. Foi essa mudança que tornou o retry possível — se alguém a reverter para constraint
  total numa migração, o retry para de funcionar e nada avisa.
- **Retry do Airflow ponta a ponta**: container falha na primeira tentativa, a segunda abre linha nova
  e conclui. É o cenário que amarra ticket 19, ticket 04 e ticket 02 de uma vez.
- **Divergência de versão do Jasper**: exportar um Artefato cuja `versao_jasperreports` difere da
  versão da API precisa **funcionar** e **alertar**. Testar que não recusa é tão importante quanto
  testar que avisa — recusar quebraria os sete dias seguintes a todo upgrade.
- **Conversão de fuso no default de `data_referencia`** (herdado do ticket 03): simular
  `logical_date` às 22:00 BRT e afirmar que a Data de Referência sai como o dia anterior ao que
  `{{ ds }}` cru devolveria.

## Notas do ticket 20 (idempotência e reprocessamento)

- **O índice único parcial ganhou `SEM_DADOS`** e vale testar as quatro combinações: par com `ERRO`
  aceita nova Execução; com `SEM_DADOS` aceita; com `SUCESSO` rejeita; com `ALERTA` rejeita. É uma
  linha de DDL que carrega quatro regras de negócio.
- **`ON DELETE SET NULL` em `download.execucao_id`** deixa de ser teórico — o reprocessamento apaga
  Execuções. Cenário: baixar um relatório, reprocessar o par, e verificar que a linha de Download
  continua legível com `execucao_id` nulo. Sem esse teste, o `DELETE` pode falhar por FK em produção
  e ninguém saber antes.
- **Os dois verbos precisam de cenário cruzado**: `refazer` num par ocupado por `SUCESSO` deve ser
  recusado, e `reprocessar` num par livre também. A API escolhe pelo índice, então esses testes
  provam que ela consulta o estado real e não confia no que a UI mandou.
- **Corrida em `abrir_execucao`**: dois disparos simultâneos do mesmo par, um deve falhar. Testável
  com duas conexões e é o único lugar onde a unicidade é de fato exercitada sob concorrência.

## Notas do ticket 21 (contrato do Starter)

- **O teste que mais importa deste ticket é o do cursor.** O `JRDataSource` do Starter precisa
  paginar internamente ou satisfazer as quatro condições do pgjdbc (autocommit desligado,
  `TYPE_FORWARD_ONLY`, statement único, `fetchSize > 0`). Faltando qualquer uma, ele **degrada em
  silêncio** e bufferiza o `ResultSet` inteiro — o OOM que o virtualizer existe para evitar,
  sem sintoma até acontecer. Um teste com volume que estoure o heap se bufferizado, e passe se não,
  é o único que prova isso; asserção sobre configuração não basta, porque a degradação é do driver.
- **CSV e print vêm das mesmas linhas, por construção** — o CSV deriva do mesmo `JRDataSource`.
  Vale cenário que conte as linhas do `.csv.gz` e as do `JasperPrint` e afirme a igualdade: se alguém
  desacoplar os dois numa refatoração, é o único teste que percebe.
- **Inventário declarativo**: publicar a partir de uma imagem sem o bean de um Relatório cadastrado
  deve **retirá-lo** do inventário e deixar o cadastro sinalizado — não apagar o cadastro, não falhar.
  E a fábrica de DAGs não pode gerar DAG para ele.
- **Zero linhas antes do fill**: `SEM_DADOS` sem nenhum objeto escrito no repositório. Testar que
  **nada** foi gravado, não só que o status está certo.
- **Step single-thread**: o `ResourcelessJobRepository` não é thread-safe, e a violação corrompe
  metadados em silêncio. Isso é teste de arquitetura (nenhum `TaskExecutor` configurado em step), não
  teste de runtime.

## Notas do ticket 24 (tolerância do tempo estimado)

- **O container não pode gravar `ERRO`** (T5 removida). Vale cenário negativo: container que falha
  deixa a linha em `EM_PROCESSAMENTO`, e é o `on_failure_callback` que a fecha, **uma vez**, ao
  esgotarem os retries. Se alguém "corrigir" isso fazendo o container gravar, o retry para de
  funcionar e o sintoma é sutil.
- **A duração usa `inicio_processamento`, não `inicio`.** O teste que pega uma regressão aqui é o do
  Relatório curto: `E = 10 s`, partida artificialmente lenta, e o resultado tem de ser `SUCESSO` —
  não `ALERTA`. Medindo por `inicio`, ele viraria `ALERTA` e ninguém notaria a troca.
- **A guarda do cadastro conta as tentativas**: `3 × (2E + 120) ≤ LIMITE_ORFA`. Testar o limite exato
  (~3.540 s aceito, acima disso recusado) — é uma fórmula fácil de simplificar por engano numa
  refatoração, e o efeito é a varredura fechar Coleta viva.
- **Retry ponta a ponta com reuso de linha**: três tentativas, uma única linha, um único `ERRO` no
  fim. Amarra ticket 24, ticket 19 e ticket 02 num cenário só.
- **Artefato parcial**: interromper a Coleta durante a escrita e verificar que **nada** foi registrado
  em `artefato` e que a Execução não ficou `SUCESSO`. O staging local é o que garante isso, e é
  invisível em teste unitário.

## Notas do ticket 25 (geração sob demanda)

- **O teste de carga deixou de ser opcional e virou fonte de dois números.** O k6 precisa estabelecer
  (a) o multiplicador entre o tamanho do `.jrprint` serializado e o heap que ele ocupa desserializado,
  e (b) o `N` do semáforo que daí decorre. Nenhum dos dois sai de cálculo, e sem eles o
  dimensionamento do heap da API é chute — com OOM da API inteira como modo de falha (ADR 0002).
- **Vazamento de semáforo é o teste mais valioso e o menos óbvio.** A vaga é adquirida **antes** de
  buscar o objeto, e há vários caminhos de saída depois disso: hash divergente, `ObjectInputFilter`,
  timeout, OOM. Um caminho de erro que não libere esgota a capacidade da API sem sintoma além de
  `503` crescente. Cenário: forçar cada modo de falha em sequência e afirmar que a ocupação volta a
  zero.
- **`409` e `503` não podem ser confundidos.** Um é permanente (Artefato acima do teto), o outro é
  transitório (semáforo cheio). Vale cenário para cada um, porque a UI se comporta de forma oposta
  nos dois.
- **O CSV não consome semáforo.** Testar que N exportações de CSV simultâneas passam mesmo com o
  semáforo saturado por PDFs — se ele for parar na mesma fila numa refatoração, o formato mais barato
  do sistema passa a ser limitado pelo mais caro.

## Notas do ticket 26 (formato de erro)

- **A configuração de telemetria dos testes mudou, e é premissa de outros testes.** O ticket 26
  reescreveu a regra do documento: SDK do OTel **ligado** em todo ambiente, com `otel.*.exporter=none`
  nos testes. É isso que mantém o MDC preenchido e faz o cenário Gherkin exercitar o **mesmo** caminho
  que roda em produção. Se alguém "otimizar" para `otel.sdk.disabled=true`, os cenários de Correlation
  ID passam a testar o fallback e ninguém percebe — eles continuam verdes.
- **Confirmar que o SDK ligado não vira dependência de Collector no CI.** É a preocupação original do
  documento, atendida por outro meio; vale um teste que rode sem Collector algum no ambiente.
- **Cenário para a exceção documentada**: requisição com cabeçalho acima do limite do Tomcat é
  rejeitada **sem** corpo padronizado e **sem** Correlation ID. Vale testar que é isso mesmo que
  acontece — é a única lacuna conhecida da garantia, e transformá-la em teste impede que ela vire
  surpresa.
- **Erros do próprio Spring saem em `application/problem+json`**: JSON malformado, `@Valid` reprovado,
  405, 415. Vale cenário para pelo menos um deles, provando que não há segundo formato de erro
  circulando pela API.

## Notas do ticket 27 (retenção × histórico)

- **`x-amz-expiration` é o item de verificação deste ticket.** O research 10 registra que a
  especificação S3 define esse header no `PutObject`, mas **não localizou afirmação de que o MinIO o
  emite**. O ticket 27 decidiu preferi-lo ao cálculo local, com fallback — então o teste precisa
  cobrir os dois caminhos, e revelar qual está de fato em uso.
- **Listagem e exportação divergem por desenho**, e isso precisa de cenário para não ser "corrigido"
  depois: a listagem marca expirado pela data prevista, mas a exportação entrega se o objeto ainda
  existir. Testar exatamente esse caso — item marcado como expirado que **baixa com sucesso** — é o
  que impede alguém alinhar os dois achando que é bug.
- **`410` só quando o objeto realmente sumiu**, com Testcontainers do MinIO deletando o objeto por
  fora para simular o scanner.
- **A regra de lifecycle tem filtro vazio**, então ela recolhe também objeto órfão sem metadado. Vale
  cenário: subir objeto no bucket sem linha em `artefato` e confirmar que a regra o alcança — é a
  única limpeza que existe, já que nenhuma credencial tem `s3:DeleteObject`.

## Notas do ticket 28 (readiness e liveness)

- **O amortecimento do indicador do banco precisa de teste próprio, e ele é temporal.** Uma falha
  isolada **não** pode derrubar o `readiness`; N consecutivas **precisam**. É o tipo de lógica que
  passa despercebida numa refatoração — e o sintoma da regressão é vaivém de instância em produção,
  não teste vermelho.
- **`liveness` permanece UP com o PostgreSQL parado.** Cenário barato e importante: se alguém acoplar
  o banco ao `liveness`, o container entra em laço de reinício durante toda indisponibilidade, que é
  a pior reação possível.
- **A exposição default do Spring é contenção, então merece asserção.** Testar que `/actuator/env`,
  `/actuator/beans` e `/actuator/heapdump` **não** respondem. Se alguém incluir `*` em
  `management.endpoints.web.exposure.include` "para debugar", a única barreira que resta é a regra do
  Traefik — e este teste é o que avisa.
- **Degradação parcial com MinIO fora**: `readiness` UP, listagem funcionando, exportação devolvendo
  erro do catálogo com Correlation ID. Amarra os tickets 28, 26 e 25 num cenário só.

## Notas do ticket 29 (métricas e cardinalidade)

- **A guarda de cardinalidade ficou documental** (risco aceito no ticket 29), então **não** existe
  teste percorrendo o `MeterRegistry`. Se este ticket quiser reverter isso, é aqui — e o argumento
  está registrado lá: cardinalidade não dá sintoma até o Prometheus adoecer, e o diagnóstico chega
  semanas depois, longe da causa.
- **A instrumentação de métrica fica ativa em teste**, porque o SDK do OTel passou a ficar ligado com
  exportador `none` (ticket 26). Vale confirmar que isso **não** vira dependência de Collector no CI —
  é a preocupação original da descrição inicial, atendida por outro meio.
- **`coleta_duracao_segundos` mede `fim − inicio_processamento`**, a mesma janela do limiar de
  `ALERTA`. Um teste que afirme a coerência entre a métrica e o status evita que painel e tabela
  discordem depois de uma refatoração — os dois derivam da mesma decisão, mas de código diferente.
- **Nenhum alerta notifica** (risco aceito no ticket 29). Não há canal a testar; o que existe é o
  painel-resumo, e ele não é testável automaticamente. Vale registrar essa lacuna em vez de fingir
  cobertura.

## Answer

### As camadas são definidas pela infraestrutura necessária

A fronteira entre "integração" e "aceitação" estava indefinida porque as duas usam Gherkin. A saída
não foi escolher vocabulário — foi definir a camada por **o que precisa estar de pé**, que é
verificável (basta olhar o que o teste sobe) e dá a cada camada um custo de CI previsível.

| Camada | O que precisa estar de pé |
|---|---|
| unidade | nada — só a JVM |
| **integração** | Testcontainers: PostgreSQL, MinIO, Keycloak conforme o caso; um módulo por vez |
| **aceitação** | stack do Compose, exercitada pela API — inclusive a Coleta |
| **E2E** | Playwright (navegador) e Newman, contra Traefik e Keycloak reais |
| carga | k6 — camada própria, **não é gate** |

O Gherkin atravessa integração e aceitação, como a descrição inicial exige, sem que isso confunda a
classificação.

### A Coleta é mais barata de testar do que o enunciado sugeria

Quase todo o comportamento da Coleta cai na camada de **integração**: o job roda **in-process** com
`JobOperatorTestUtils` (que substituiu `JobLauncherTestUtils` no Spring Batch 6, research 09) contra
Testcontainers de PostgreSQL e MinIO. Não é preciso Compose nem Airflow para semear um schema
transacional, rodar a Coleta e verificar Artefato e linha de metadados.

Só o **contrato com o Airflow** precisa da camada pesada: exit code, retry ponta a ponta, conversão de
fuso no `data_referencia`.

**Isolamento**: singleton com `@ServiceConnection`. Reuso de container é armadilha — a própria
documentação do Testcontainers diz que não serve para CI (research 09).

### Pipeline

```
PR      unidade + integração                     (minutos)
merge   + aceitação + E2E                        (gate antes de promover)
fora    k6                                       (agendado ou sob demanda)
```

O PR cobre **a maior parte** dos cenários que os onze tickets exigiram, a um custo de segundos por
container (~1,5–2,0 s com imagem em cache, ~13 s a frio — research 09).

O **k6 sai do gate por natureza**: ele não verifica regressão, ele **calibra**. Precisa empurrar até
o OOM para estabelecer o multiplicador entre `.jrprint` serializado e heap ocupado, e o `N` do
semáforo que daí decorre — números que o ticket 25 deixou explicitamente para ele produzir.

**Upgrade do Keycloak dispara o E2E completo** (ticket 17), porque a allowlist do Traefik falha
fechada e as features do realm são configuração viva que o import não reproduz.

**Runners ARM64** (`ubuntu-24.04-arm`), que já trazem Docker sem DinD — é a arquitetura de produção e
do ambiente de desenvolvimento.

### Cobertura: não-regressão, mais a lista

O JaCoCo mede sempre; o gate exige que a cobertura **não caia** em relação à main. Nenhum número
absoluto.

O motivo é específico deste mapa: os onze tickets não pediram "mais testes" — nomearam **cenários**,
várias vezes com a justificativa *"é o único sinal que existe"*. Testar o cursor do `JRDataSource`
com volume que estoure o heap se bufferizado cobre poucas linhas; vinte getters cobrem muitas. Uma
meta absoluta é atingível escrevendo exatamente os testes errados, e sob pressão de prazo essa passa
a ser a escolha racional.

**Os cenários nomeados viram lista explícita na especificação**, verificada em revisão. É o gate que
de fato importa. E essa lista é também o artefato que resolve "onde os `.feature` vivem": eles ficam
**no código**, onde o Cucumber os executa, e a especificação carrega a lista — sem duplicação e sem
deriva, porque um `.feature` fora do runner é documentação que apodrece.

### Risco aceito: o CI para no teste

Argumentei por publicar imagens versionadas em merge, deixando o deploy manual: uma imagem construída
uma vez e promovida é **a mesma** que passou nos testes.

Decisão: as imagens são construídas na VM no momento do deploy.

**Isto compõe com um risco já aceito no ticket 19.** Lá se escolheu uma imagem por módulo, aceitando
que divergência de versão do JasperReports entre eles é possível em deploy — e que ela **falha em
silêncio**, porque `JRConstants.SERIAL_VERSION_UID` é constante fixa. Construir na VM torna isso mais
provável, não menos: não há momento único de build, e os cinco processadores podem acabar em builds de
dias diferentes.

A contenção existente — a API comparar `versao_jasperreports` do Artefato com a sua e alertar
(ticket 19) — passa a carregar mais peso do que carregava quando foi decidida.

**Requisito que decorre disso**: o deploy tem de fixar **SHA ou tag**, nunca `main` HEAD. Sem
registry, o único elo entre "o que foi testado" e "o que roda" é o commit. Se a VM construir de `main`
no momento do deploy, ela constrói o que quer que tenha entrado desde o merge que passou no gate.

**Consequência operacional**: a VM precisa de toolchain de build — JDK, Maven, Docker — o que amplia
o que existe na máquina de produção.

## Notas do ticket 35 (repositório S3)

- **O CI roda um servidor S3 diferente do de produção**: MinIO AGPL congelado
  (`RELEASE.2025-10-15T17-29-55Z`) nos Testcontainers, AIStor Free em produção. Risco aceito no
  ADR 0003, e é a mesma forma do problema que fez este projeto remover o H2 — só que com delta muito
  menor. A contenção é uma **lista nomeada**, e ela entra nos cenários obrigatórios daqui.
- **Seis verificações contra o AIStor real, antes de promover**: lifecycle com filtro vazio,
  `x-amz-expiration` no `PutObject`, ausência de `s3:DeleteObject`, ausência de `s3:ListBucket` na
  credencial da API, expurgo de objeto órfão, e **imagem ARM64 do AIStor**.
- **Isso não é teste automatizado do CI** — o CI não tem chave de licença, de propósito. É verificação
  de promoção, e precisa ter dono e momento definidos, senão vira "alguém confere um dia".
- **O binário congelado dispensa chave**, então a suíte roda sem credencial de fornecedor. Preservar
  essa propriedade importa: com AIStor no CI, um desenvolvedor novo não conseguiria rodar os testes.

## Notas do ticket 37 (versionamento do JRXML)

- **Cenário obrigatório novo: o hash é estável.** Calcular o `hash_definicao` do mesmo bean duas vezes,
  em JVMs distintas, tem de dar o mesmo valor. É o teste que protege a canonicidade da entrada — se a
  ordem dos rótulos vier de coleção não-ordenada, o hash muda sozinho e o mecanismo inteiro vira ruído
  sem que nada acuse.
- **Cenário obrigatório novo: divergência registra e não falha.** Inventário com hash diferente do que
  o container calcula → job termina em `SUCESSO`, métrica incrementada. É a forma do ticket 19 (alerta
  sem recusar), e um teste que só verifique "o job passou" não distingue isso de a comparação não
  existir — o assert tem de ser na métrica.
- **O teste do hash é barato**: não precisa de Testcontainers nem de banco. Cai na camada de unidade,
  o que o põe no gate leve de PR.

## Notas do ticket 38 (árvore de Grupos)

- **Quatro cenários obrigatórios novos**, todos na camada que sobe Keycloak:
  1. a mediação **recusa apagar o Default Group** do realm;
  2. **vincular a Grupo sem nenhuma Role é recusado**;
  3. o indicador de `dependencias` **cai** quando o `PENDENTES` deixa de ser Default Group;
  4. a mediação cria Grupo sempre como **filho direto da raiz**, nunca de outro Grupo.
- **O primeiro merece atenção especial**: como a guarda em código é a única barreira (risco aceito no
  ticket 38), ele é o teste que substitui a barreira estrutural que não existe. Um teste que só
  verifique "a chamada falhou" não basta — precisa provar que falhou **pela guarda**, senão passa
  igual no dia em que a guarda sumir e outra coisa recusar por acaso.

## Notas do ticket 39 (agendamento e fábrica de DAGs)

- **Cenário obrigatório: snapshot ausente ou corrompido faz a fábrica levantar exceção**, e não gerar
  zero DAGs. Um teste que só verifique "nenhuma DAG inválida foi gerada" passa nos dois casos — o
  assert tem de ser no erro de import.
- **Cenário obrigatório: a fábrica não faz chamada de rede no parse.** É o que o FAQ do Airflow nomeia
  como causa de falha do dag processor, e a regressão é fácil de introduzir sem ninguém notar.
- **Cenário obrigatório: um Relatório fora da interseção não gera DAG** — nem o cadastrado sem bean,
  nem o publicado sem cadastro (ticket 21).
- **O tamanho do pool de Coletas é número para calibrar, não para verificar** — cai fora do gate, na
  mesma classe do k6.

## Notas do ticket 40 (primeiro Produto)

- **O teste da substituição de fonte mudou de forma.** Não simula o sumiço: exporta o `POUPANCA-0002`
  real com `net.sf.jasperreports.awt.ignore.missing.font=false`, o que **já falha** se a font extension
  não estiver no classpath. Acompanha um teste negativo com fonte inexistente, senão o positivo passa
  mesmo com a propriedade ignorada — falso verde.
- **A semente tem dois perfis**: funcional (~2 mil lançamentos, 10 datas) em todo teste de integração,
  volumétrica só no teste de cursor e no k6. Uma semente única grande estouraria o gate leve de PR.
- **O teste de cursor roda com `-Xmx96m`.** A prova de que a leitura transmite vem de apertar o heap
  contra um volume que o excede se bufferizado — não de perseguir volume de produção, que seria lento
  sem ser mais conclusivo.

## Notas do ticket 43 (Produto Consórcio)

- **`SEM_DADOS` não é exercitado por nenhum Produto do mapa.** O ticket 43 considerou e recusou o único
  desenho que o faria naturalmente (Coleta diária de assembleias, vazia em feriados e fins de semana),
  porque encheria a listagem de dias vazios sem o relator distinguir "não houve" de "falhou".
- **Consequência para a cobertura**: o estado criado no ticket 02 fica coberto **apenas por teste**, em
  todo o mapa. Ele precisa estar na lista de cenários obrigatórios com essa nota explícita — senão
  alguém supõe que a produção o exercita e afrouxa o teste.

## Notas do ticket 46 (pipeline de CI)

- **A lista de cenários obrigatórios deixou de ser verificada em revisão e virou executável.** Cada item
  da especificação é um identificador, cada identificador é um teste marcado, e o CI afirma que todos
  **rodaram e passaram** — não que existem, porque `@Disabled` satisfaria a presença sem provar nada.
- **A conferência é nas duas direções**: id sem teste (cenário removido em silêncio) e teste marcado sem
  id (cenário sem justificativa). A segunda preserva o motivo pelo qual este ticket criou a lista.
- **A não-regressão de cobertura ganhou mecanismo**: artefato do JaCoCo publicado no merge, baixado pelo
  PR. Baseline ausente **regenera rodando a main uma vez**, e o fallback é barulhento — regenerar em
  silêncio faria um artefato expirado transformar o gate em enfeite.
