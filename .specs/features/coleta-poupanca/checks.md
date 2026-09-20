# Coleta do produto POUPANCA checks

Profile: ui
Plan: `.specs/features/coleta-poupanca/plan.md`

45 checks em 5 slices · 10 one-way doors · 4 questões abertas, das quais 0 bloqueiam a
implementação e 1 bloqueia go-live.

**Sobre a forma dos proofs.** Nada disto existe ainda: os comandos passam a existir porque esta
feature os cria, e nenhum deles foi inventado. Testes unitários rodam no Surefire com
`-Dtest='Classe#metodo'`; os cenários Gherkin que RA-44 exige rodam no Failsafe com
`-Dit.test='<Suite>' -Dcucumber.filter.name='<cenário>'`, um suite por arquivo `.feature` em
`src/test/resources/feature` (RA-45). `validate_checks.py` avisa que o segundo formato "não nomeia
selector" — é falso negativo da lista de tokens dele, que conhece `-Dtest=` e não `-Dit.test=`.

## Checks

### S1 - Build, schema e infra local · 13 arquivos · ~34 KB · ~8,5k

**C1** - `mvn clean verify` num clone limpo sai 0 e o reator declara exatamente 4 módulos: `scheduler-jasper-report`, `biblioteca-comum`, `processador-starter`, `processador-poupanca` (AC 1)
Proof: `bash scripts/proof/clone-limpo.sh` - clona em diretório temporário, roda `mvn clean verify`, e afirma exit 0 e as 4 linhas de `--- maven-...` do reator

**C2** - As migrations aplicadas a um PostgreSQL vazio criam o schema `controle` com as tabelas `produto`, `relatorio`, `execucao` e `artefato`, e o schema `poupanca` (AC 2)
Proof: `mvn -pl biblioteca-comum -am test -Dtest='MigrationSchemaTest#criaControleEPoupanca'`

**C3** - Alterar o checksum de uma migration já aplicada aborta a inicialização com `FlywayValidateException` e deixa `flyway_schema_history` com a mesma contagem de linhas de antes (AC 3)
Proof: `mvn -pl biblioteca-comum -am test -Dtest='MigrationSchemaTest#checksumAlteradoAborta'`

**C4** - `docker compose up --wait` sai 0, com os serviços `postgres` e `minio` em estado `healthy` e o bucket `artefatos` existente e vazio (AC 4)
Proof: `bash scripts/proof/compose-sobe.sh` - roda `docker compose up --wait`, afirma exit 0, consulta `docker compose ps --format json` por `health=healthy` nos dois serviços, e lista o bucket

**C5** - O workflow de CI dispara em `pull_request`, executa `mvn verify` e não declara `continue-on-error` em passo algum (AC 5)
Proof: `bash scripts/proof/ci-bloqueante.sh` - lê `.github/workflows/ci.yml` e afirma as três condições

### S2 - Catálogo derivado do código · 10 arquivos · ~26 KB · ~6,5k

**C6** - Ao iniciar contra um schema `controle` vazio, o módulo publica o produto `POUPANCA` e os relatórios `POUPANCA-0001` e `POUPANCA-0002`, cada um com nome, descrição e tempo estimado inicial não nulos (AC 6)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='CatalogoIT' -Dcucumber.filter.name='Publica o produto e os dois relatórios na primeira inicialização'`

**C7** - Reiniciar o módulo depois de `controle.relatorio.nome` ter sido alterado preserva o nome alterado (AC 7)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='CatalogoIT' -Dcucumber.filter.name='Reinício preserva o nome editado pela aplicação'`

**C8** - Reiniciar o módulo preserva `descricao` e `tempo_estimado_segundos` alterados pela aplicação (AC 7)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='CatalogoIT' -Dcucumber.filter.name='Reinício preserva descrição e tempo estimado editados'`

**C9** - Dois relatórios declarados com os mesmos 4 dígitos recusam a inicialização, a mensagem contém o código duplicado, e o processo sai com código 2 (AC 8)
Proof: `mvn -pl processador-starter -am test -Dtest='PublicacaoCatalogoTest#codigoDuplicadoRecusaComExit2'`

**C10** - Sigla fora de `^[A-Z]{1,20}$` recusa a inicialização, nas 4 bordas: 1 caractere aceita, 20 aceita, 21 recusa, minúscula recusa (AC 9)
Proof: `mvn -pl processador-starter -am test -Dtest='SiglaProdutoTest#bordasDoRegex'`

**C11** - Código fora de `^[A-Z]{1,20}-\d{4}$` recusa a inicialização, nas 4 bordas: `POUPANCA-0001` aceita, `POUPANCA-1` recusa, `POUPANCA-00001` recusa, `poupanca-0001` recusa (AC 9)
Proof: `mvn -pl processador-starter -am test -Dtest='CodigoRelatorioTest#bordasDoRegex'`

**C12** - Tempo estimado declarado menor ou igual a zero recusa a inicialização, nos 2 casos `-1` e `0` (AC 10)
Proof: `mvn -pl processador-starter -am test -Dtest='PublicacaoCatalogoTest#tempoEstimadoNaoPositivoRecusa'`

**C13** - Soma dos tempos estimados ativos recusa acima de 600 s, nas 3 bordas: 599 aceita, 600 aceita, 601 recusa (AC 11)
Proof: `mvn -pl processador-starter -am test -Dtest='PublicacaoCatalogoTest#bordasDoTetoDaSoma'`

**C14** - Relatório antes publicado que deixa de ser declarado passa a `ativo = false` e a linha permanece consultável pelo seu código (AC 12)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='CatalogoIT' -Dcucumber.filter.name='Relatório retirado do código é inativado e não apagado'`

**C15** - A contagem de linhas de `controle.produto` e `controle.relatorio` não diminui após uma inicialização que declara menos relatórios que a anterior (AC 12)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='CatalogoIT' -Dcucumber.filter.name='Nenhuma linha de catálogo é apagada'`

### S3 - Apuração, artefatos e status · 22 arquivos · ~70 KB · ~17,5k

**C16** - O job cria 2 linhas de `execucao` com `inicio IS NULL` e status `em processamento` para a data corrente, uma por relatório ativo (AC 13)
Proof: `mvn -pl processador-starter -am verify -Dit.test='ReservaIT' -Dcucumber.filter.name='Reserva cria uma execução por relatório ativo'`

**C17** - Com o schema transacional inacessível, as 2 linhas reservadas existem mesmo assim - a reserva precede a leitura (AC 13)
Proof: `mvn -pl processador-starter -am verify -Dit.test='ReservaIT' -Dcucumber.filter.name='Reserva sobrevive à base transacional indisponível'`

**C18** - A Execução guarda o tempo estimado que estava no catálogo no disparo; alterar o catálogo depois não muda o valor gravado na Execução (AC 14)
Proof: `mvn -pl processador-starter -am test -Dtest='ExecucaoTest#tempoEstimadoCopiadoNoDisparo'`

**C19** - Uma apuração sem falha grava exatamente 2 objetos por relatório, em `<yyyy-MM-dd>/POUPANCA/POUPANCA-0001.jrprint` e `<yyyy-MM-dd>/POUPANCA/POUPANCA-0001.csv.gz` (AC 15)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='ApuracaoIT' -Dcucumber.filter.name='Grava o jrprint e o csv.gz no caminho da data, sigla e código'`

**C20** - Com o MinIO indisponível, nenhuma Execução termina em `processado com sucesso` - o artefato é gravado antes do encerramento (AC 15)
Proof: `mvn -pl processador-starter -am verify -Dit.test='ApuracaoIT' -Dcucumber.filter.name='Falha ao gravar artefato impede encerramento em sucesso'`

**C21** - Apuração sem falha cuja duração não ultrapassa o tempo estimado copiado encerra em `processado com sucesso` (AC 16)
Proof: `mvn -pl processador-starter -am test -Dtest='ClassificacaoStatusTest#semFalhaDentroDoEstimadoDaSucesso'`

**C22** - Apuração sem falha cuja duração ultrapassa o tempo estimado copiado encerra em `processado com alerta`, e os 2 artefatos continuam presentes (AC 17)
Proof: `mvn -pl processador-starter -am test -Dtest='ClassificacaoStatusTest#semFalhaAcimaDoEstimadoDaAlerta'`
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='ApuracaoIT' -Dcucumber.filter.name='Alerta preserva os artefatos'`

**C23** - Apuração com falha registrada encerra em `processado com erro` ainda que a duração também tenha ultrapassado o estimado - o erro prevalece sobre o alerta (AC 18)
Proof: `mvn -pl processador-starter -am test -Dtest='ClassificacaoStatusTest#erroPrevaleceSobreAlerta'`

**C24** - O `.csv.gz` descomprimido tem separador `;`, uma linha de cabeçalho, e conteúdo idêntico ao resultado da consulta principal - sem subrelatório, imagem ou formatação (AC 19)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='ApuracaoIT' -Dcucumber.filter.name='CSV é o dataset bruto com separador ponto e vírgula'`

**C25** - Com o relógio em 2026-09-20T23:30Z, a data de referência gravada é `2026-09-20` - resolvida em `America/Sao_Paulo`, não em UTC (AC 20)
Proof: `mvn -pl processador-starter -am test -Dtest='DataReferenciaTest#resolvidaNoFusoDeSaoPaulo'`

**C26** - O ponto de entrada da aplicação fixa o timezone default em `America/Sao_Paulo` antes de qualquer leitura (AC 20)
Proof: `mvn -pl processador-poupanca -am test -Dtest='ProcessadorPoupancaApplicationTest#fixaTimezoneNaMontagem'`

**C27** - O job recusa qualquer JobParameter, sai com código 2 e não abre leitura alguma (AC 21)
Proof: `mvn -pl processador-starter -am test -Dtest='JobParametrosTest#qualquerParametroRecusaComExit2'`

**C28** - Cada Execução encerrada emite um registro de log JSON com `siglaProduto`, `codigoRelatorio`, `dataReferencia`, `status`, `duracaoMs` e `correlationId` (AC 22)
Proof: `mvn -pl processador-starter -am test -Dtest='LogEstruturadoTest#registroPorExecucaoEncerrada'`

### S4 - Limites, recusas e encerramento · 12 arquivos · ~34 KB · ~8,5k

**C29** - Dataset com 50.001 linhas encerra aquela Execução em `processado com erro` com motivo contendo `50001` e `50000`, sem gravar objeto algum no bucket (AC 23)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='LimitesIT' -Dcucumber.filter.name='Dataset acima do teto é recusado antes da leitura'`

**C30** - O teto de linhas recusa nas 3 bordas: 49.999 apura, 50.000 apura, 50.001 recusa (AC 23)
Proof: `mvn -pl processador-starter -am test -Dtest='ContagemPreviaTest#bordasDoTetoDeLinhas'`

**C31** - Relatório que atinge o dobro do tempo estimado copiado é abortado e encerrado em `processado com erro` (AC 24)
Proof: `mvn -pl processador-starter -am test -Dtest='LimiteDeTempoTest#dobroDoEstimadoAborta'`

**C32** - Com `POUPANCA-0001` abortado por tempo, `POUPANCA-0002` é apurado e encerra em sucesso na mesma execução do job (AC 24)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='LimitesIT' -Dcucumber.filter.name='Relatório abortado não impede os demais do produto'`

**C33** - Dentro da transação de leitura de um relatório, `SHOW statement_timeout` devolve o dobro do tempo estimado copiado em milissegundos (AC 25)
Proof: `mvn -pl processador-starter -am verify -Dit.test='LimitesIT' -Dcucumber.filter.name='Transação de leitura carrega o statement_timeout do relatório'`

**C34** - Com o par data + código já em `em processamento`, nova Execução é recusada, um evento de auditoria com solicitante, momento e Correlation ID é gravado, e a contagem de `execucao` não muda (AC 26)
Proof: `mvn -pl processador-starter -am test -Dtest='UnicidadeExecucaoTest#parEmProcessamentoRecusaSemCriar'`

**C35** - Com o par já em `processado com sucesso` ou `processado com alerta`, nova Execução é recusada, os 2 artefatos permanecem com o mesmo ETag, e a auditoria é gravada sem criar Execução (AC 27)
Proof: `mvn -pl processador-poupanca -am verify -Dit.test='LimitesIT' -Dcucumber.filter.name='Par já concluído recusa nova execução e preserva os artefatos'`

**C36** - Dois disparos concorrentes do job para a mesma data de referência deixam exatamente 1 Execução vigente por relatório, e o segundo falha no índice único parcial em vez de duplicar (AC 26, AC 27)
Proof: `mvn -pl processador-starter -am test -Dtest='UnicidadeExecucaoTest#disparosConcorrentesDeixamUmaVigente'`

**C37** - Ao fim do job, Execução que ficou com `inicio IS NULL` é encerrada em `processado com erro` (AC 28)
Proof: `mvn -pl processador-starter -am test -Dtest='EncerramentoAnomaloTest#reservadaNuncaIniciadaVaiParaErro'`

**C38** - Ao fim do job, Execução que ficou em `em processamento` com início preenchido é encerrada em `processado com erro` (AC 28)
Proof: `mvn -pl processador-starter -am test -Dtest='EncerramentoAnomaloTest#emProcessamentoPenduradaVaiParaErro'`

**C39** - O job sai com código 0 quando toda Execução do produto está em sucesso ou alerta, e com código 1 quando qualquer uma está em erro (AC 29)
Proof: `mvn -pl processador-starter -am test -Dtest='CodigoDeSaidaTest#zeroQuandoTodasValidasUmQuandoQualquerErro'`

**C40** - Execução em status terminal não muda de status: a tentativa é recusada nos 3 terminais `processado com sucesso`, `processado com alerta` e `processado com erro` (RN-15, RA-67)
Proof: `mvn -pl processador-starter -am test -Dtest='ExecucaoTest#statusTerminalNaoMuda'`

**C41** - A Execução grava as 3 origens previstas - `agendada`, `retentativa` e `reprocessamento forçado` - e recusa valor fora do conjunto (RN-46)
Proof: `mvn -pl processador-starter -am test -Dtest='ExecucaoTest#origensGravaveis'`

### S5 - Modelos de relatório e a convenção de autoria · 4 arquivos · ~12 KB · ~3k

**C42** - Os 2 JRXML do módulo referenciam imagens distintas entre si e font extensions distintas entre si (AC 30, RA-08)
Proof: `mvn -pl processador-poupanca -am test -Dtest='ModelosRelatorioTest#imagensEFontesDistintasEntreOsDois'`

**C43** - Em cada um dos 2 JRXML, o cabeçalho de coluna está na banda `title`, e `pageHeader` e `pageFooter` não contêm elemento de texto de cabeçalho de coluna (AC 31, RA-59)
Proof: `mvn -pl processador-poupanca -am test -Dtest='ModelosRelatorioTest#cabecalhoDeColunaNaBandaTitle'`

**C44** - O `.jrprint` de cada um dos 2 relatórios, exportado para XLSX com `onePagePerSheet(false)` e `removeEmptySpaceBetweenRows(true)`, apresenta o cabeçalho de coluna exatamente 1 vez (AC 32, RF-21, RA-68)
Proof: `mvn -pl processador-poupanca -am test -Dtest='ExportacaoXlsxTest#cabecalhoAparaceExatamenteUmaVezEmCadaRelatorio'`

**C45** - Um `.jrprint` gravado por este módulo, desserializado com as font extensions do módulo no classpath, reproduz a família de fonte declarada no JRXML em vez de uma substituta (AC 33, §12)
Proof: `mvn -pl processador-poupanca -am test -Dtest='ExportacaoXlsxTest#fonteDeclaradaSobreviveAoJrprint'`

## Coverage

| Set (size) | Member -> proof | Unproven |
| --- | --- | --- |
| status da Execução (4) | `em processamento` C16 · `processado com sucesso` C21 · `processado com alerta` C22 · `processado com erro` C23 | - |
| status terminal que não muda (3) | C40, table-driven sobre os 3 terminais | - |
| origem da Execução (3) | C41, table-driven sobre as 3 origens | - |
| código de saída do processo (3) | `0` C39 · `1` C39 · `2` C27 | - |
| recusas de inicialização do catálogo (5) | sigla C10 · código C11 · quatro dígitos duplicados C9 · tempo estimado não positivo C12 · soma acima do teto C13 | - |
| artefatos por Execução concluída (2) | `.jrprint` C19 · `.csv.gz` C24 | - |
| regex da sigla, bordas (4) | C10, table-driven sobre as 4 bordas | - |
| regex do código, bordas (4) | C11, table-driven sobre as 4 bordas | - |
| teto de linhas RNF-06, bordas (3) | 49.999 C30 · 50.000 C30 · 50.001 C29 | - |
| teto da soma RNF-19, bordas (3) | 599 C13 · 600 C13 · 601 C13 | - |
| JRXML do módulo (2) | `POUPANCA-0001` C44 · `POUPANCA-0002` C44 | - |
| serviços do compose saudáveis (2) | `postgres` C4 · `minio` C4 | - |
| atributos editáveis preservados no reinício (3) | nome C7 · descrição C8 · tempo estimado C8 | - |
| caminhos que encerram Execução aberta ao fim do job (2) | início nulo C37 · em processamento C38 | - |
| startup config: timezone `America/Sao_Paulo` (2 assemblies) | ponto de entrada `ProcessadorPoupancaApplication` C26 · montagem de teste C25 | - |

- Claims que nomeiam um valor persistido, um caminho de objeto ou um código de saída - C9, C19,
  C24, C27, C29, C33, C35, C39 - têm proof que atravessa a fronteira: PostgreSQL e MinIO reais via
  Testcontainers, nunca dublê.
- C21, C22, C23, C30, C31, C40 e C41 são decisão pura sobre valores de entrada e têm proof na
  própria camada, além do cenário que os atravessa.
- Nenhum outro check afirma mais que o caso único que o seu proof exercita.
- **A linha de startup config tem 2 membros, que é o argumento para os unificar:** o timezone é
  fixado num único ponto que a montagem de teste também usa, e as duas linhas existem para que uma
  divergência entre elas apareça em vez de ser assumida.

## Test policy

O repositório não tem código: não há convenção a consultar, então nenhuma das duas perguntas -
qual nível prova este código, e quanto do espaço de entrada o proof precisa afirmar - tem resposta
aqui. As linhas abaixo são a régua sob a qual esta fatia é construída.

| Code | Required proofs | Coverage expectation |
| --- | --- | --- |
| Decide e é alcançado atravessando fronteira (PostgreSQL, MinIO, processo) | um na fronteira **e** um na própria camada | o contrato na fronteira; um caso afirmado por linha da tabela de decisão na própria camada |
| Decide e não atravessa fronteira | um na própria camada | um caso afirmado por linha da tabela de decisão |
| Ponto de entrada que não decide | um na fronteira | entrada aceita, cada entrada recusada, cada caminho de erro |
| Instrumentação e repasse | nenhum próprio | coberto pelo proof do consumidor |

Evidence:

- classificação de status (RN-11, RN-12): decide sobre 2 eixos - houve falha, e duração acima do
  estimado - com 4 combinações e 3 resultados possíveis; o erro prevalece. **Decide**, e a precedência
  é o que um caminho felizardo não exercita
- publicação do catálogo (RA-58): decide sobre 5 recusas independentes e sobre quais colunas o
  upsert pode tocar; 6 pontos de ramificação. **Decide**
- contagem prévia (RA-64): decide sobre 1 fronteira numérica, 3 bordas. **Decide**
- unicidade e vigência (RN-16, RN-17, RN-43): decide sobre o status vigente do par, com 4 status de
  entrada e 2 desfechos, mais uma corrida resolvida no índice. **Decide**, e o índice parcial é
  alcançado atravessando fronteira
- encerramento anômalo (RA-14 escopado ao job): decide sobre 2 formas de linha aberta,
  distinguidas por início nulo. **Decide**
- gravação no MinIO e escrita do `.csv.gz`: repassam argumentos para o cliente e para o writer, sem
  condicional decidindo o resultado. **Instrumentação** - cobertas pelo proof do consumidor, exceto
  a **ordem** de RA-11, que é decisão e tem C20
- análogo mais próximo no repositório: **nenhum**. Não há segundo dispatcher, segunda máquina de
  estado nem módulo irmão para citar como precedente, porque não há código. A régua vem da forma do
  código que esta fatia escreve, e é a primeira coisa que o próximo módulo processador vai copiar

Cost: 20 proofs na própria camada, em 14 arquivos de teste, além dos 11 cenários Gherkin na
fronteira. Sem estas linhas, 5 tabelas de decisão ficariam provadas apenas pelo cenário que
por acaso as atravessa - e a precedência de RN-12 sobre RN-11, que é a única regra do PRD marcada
como decisão estruturante (D02), seria a primeira a passar sem ser afirmada.

## Swept

- validation: C10, C11, C12, C13, C27, C30
- failure modes: C20, C23, C29, C31, C37, C38
- idempotency: C7, C8, C15, C34, C35
- authorization: n/a - o módulo processador não expõe rota, porta nem usuário final, e a cadeia de permissão de RN-22 vive no Keycloak e na API, ambos fora de escopo; o acesso do módulo ao seu próprio schema transacional é o invariante de RA-10, provado por ausência de dependência e não por autorização
- concurrency: C36
- data lifecycle: n/a - nenhuma política de expurgo é configurada nesta fatia; a janela de 7 dias de RN-36 e o webhook de RA-21 pertencem à feature de exportação, e RN-51 manda os metadados de Execução nunca serem expurgados, então não há TTL a aplicar aqui
- dependency failure: C17, C20
- state transitions: C16, C18, C40, C41
- observability: C28

## Handoff

Estimativa por `wc -c` dos arquivos que cada slice toca, dividido por 4. O repositório está vazio,
então a contagem é dos arquivos a criar, não de arquivos existentes - a base do número é essa, e é
a única disponível antes da primeira linha.

- S1 = 8,5k (13 arquivos, ~34 KB) - build, migrations, compose, CI
- S2 = 15k acumulado - entra no catálogo, ainda em `processador-starter` e `biblioteca-comum`
- S3 = 32,5k acumulado - entra em `processador-poupanca`, JRXML, MinIO
- S4 = 41k acumulado - limites e encerramento, sem módulo novo
- S5 = 44k acumulado - modelos e a guarda de RA-59

44k contra o budget de 150k: **um builder, sem pergunta.** O corte natural, se ele aparecer, é
depois de S2, onde a superfície muda de `processador-starter` para `processador-poupanca`.

A estimativa é de arquivos criados, e por isso é o número menos confiável deste documento: ela não
mede a iteração de fazer JasperReports, Spring Batch 6 e Testcontainers 2 assentarem juntos pela
primeira vez. Se a compactação chegar antes de S5, o caminho é reler `checks.md` e o diff.
