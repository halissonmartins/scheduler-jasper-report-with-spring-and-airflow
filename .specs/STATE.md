# Project state

## Decisions

Decisões de nível de projeto: as que uma feature seguinte tem de obedecer. As portas escopadas a
uma feature só ficam em `plan.md` `## Landing`; as de baixo aparecem nos dois lugares porque
alcançam além dela.

O log de decisões de engenharia do projeto é `docs/arquitetura-inicial.md`, na numeração `RA-NN`.
Este arquivo **não** o substitui: as linhas abaixo resolvem itens que a §14 daquele documento
deixa abertos, e ficam aqui em vez de lá porque `arquitetura-inicial.md` é fonte binding das
features e eu não edito a fonte contra a qual o trabalho é verificado. Dobrá-las na numeração
`RA-NN` é decisão do autor.

| ID | Decision | Rationale | Status | Date |
| --- | --- | --- | --- | --- |
| AD-001 | Os módulos Maven são `scheduler-jasper-report` (parent), `biblioteca-comum`, `processador-starter` e `processador-poupanca`, com groupId `io.github.halissonmartins.scheduler` e nomes em pt-BR | resolve o primeiro item aberto de `arquitetura-inicial.md` §14. RNF-15 fixa pt-BR na interface e nas mensagens, e o glossário do projeto é em pt-BR: código em inglês obrigaria a traduzir o termo do domínio em toda fronteira | active | 2026-09-20 |
| AD-002 | Plataforma fixada em Spring Boot 4.1.1 sobre Java 25, com as versões que o BOM gerencia - Spring Batch 6.0.5, Flyway 12.4.0, Testcontainers 2.0.5, driver PostgreSQL 42.7.13 - e JasperReports 7.0.8 e MinIO 9.0.3 declarados no parent | RA-01 exige versão única em todo o mono repositório, e a §12 apoia quatro trade-offs nessa premissa. Spring Boot 4.x roda em Java 17 até 26. Atenção: Testcontainers 2.x renomeou os artefatos - é `org.testcontainers:testcontainers-minio`, e `org.testcontainers:minio` para na 1.21.4 | active | 2026-09-20 |
| AD-003 | `controle.execucao` é append-only quanto a status terminal, com vigência por índice único parcial `UNIQUE (data_referencia, relatorio_codigo) WHERE vigente`, e a reserva marcada por início nulo | RA-67 e RA-54 juntos: "append-only" significa que nenhum status terminal muda, não que a linha nunca sofra `UPDATE` - a reserva de RA-54 nasce com início nulo e é preenchida depois, e é por esse nulo que RA-14 distingue "nunca começou" de "está rodando" | active | 2026-09-20 |
| AD-004 | O catálogo é publicado por upsert que toca apenas colunas não editáveis pela aplicação; não existe caminho de `DELETE` em `controle.produto` nem em `controle.relatorio`; o que sai do código é inativado | RN-49 e RN-50. Truncate-and-republish apagaria nome, descrição e tempo estimado editados pela aplicação e quebraria as referências de execuções, auditoria e downloads | active | 2026-09-20 |
| AD-005 | O caminho do artefato é `artefatos/<yyyy-MM-dd>/<SIGLA>/<CODIGO>.jrprint` e `.csv.gz`, e usa só identificadores imutáveis | RN-08 e RA-19. O nome do produto é editável, então incluí-lo faria o caminho de um artefato já gravado mudar | active | 2026-09-20 |
| AD-006 | O contêiner de processamento comunica desfecho por código de saída: 0 toda Execução em sucesso ou alerta, 1 qualquer uma em erro, 2 inicialização recusada | o callback de falha de RA-14 é acionado pelo estado da task do Airflow, que vem do código de saída; sem esse contrato o mecanismo de RN-10 não tem gatilho | active | 2026-09-20 |
| AD-007 | O prazo de leitura de RA-57 é aplicado como `SET LOCAL statement_timeout = <2 × tempo estimado copiado × 1000>` na transação do step, e não pela propriedade do reader | verificado no bytecode de `spring-batch-infrastructure:6.0.5`: `JdbcPagingItemReader` expõe apenas `setFetchSize`, e só `AbstractCursorItemReader` tem `setQueryTimeout`. RA-03 fixa leitura paginada, então a propriedade do reader não está disponível onde RA-57 a pede | active | 2026-09-20 |
| AD-008 | Todo JRXML do projeto declara o cabeçalho de coluna na banda `title` e mantém em `pageHeader`/`pageFooter` apenas ornamento descartável, e cada relatório carrega o teste que afirma o cabeçalho único em XLSX | RA-59 declara isto como convenção de autoria, não configuração de exportação, e o item 3 dele exige o teste por relatório. A guarda nasce junto com o primeiro JRXML porque é o primeiro que alguém vai copiar | active | 2026-09-20 |
| AD-009 | Nenhum proof reprova contra número marcado `PROVISÓRIO` no PRD §10 que ainda não foi medido; os valores fixos - 50.000 linhas e 600 s - são comparados porque são os valores escritos e não parametrizáveis | `arquitetura-inicial.md` §14 cita `especificacao.md` §5.5: reprovar PR contra número que ninguém mediu é transformar chute em portão. O documento citado não existe no repositório - questão aberta 2 do plano | active | 2026-09-20 |

## Handoff

**Feature**: coleta-poupanca
**Where**: nenhum check fechado - `plan.md` e `checks.md` escritos e com gate verde, nenhuma linha de código
**In progress**: nada
**Next step**: revisão humana do plano; aprovado, construir S1 (build, migrations, compose, CI) com um builder
**Blockers**: nenhum para construir. Questão 4 do plano bloqueia go-live: nenhuma credencial emitida, e `.env` local ainda não existe
**Uncommitted**: `.specs/` inteiro, `.agents/` (não rastreado desde antes desta sessão)
**Branch**: 00-tlc-spec
