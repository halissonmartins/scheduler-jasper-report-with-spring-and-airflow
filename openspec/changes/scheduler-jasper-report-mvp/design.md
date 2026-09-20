## Context

O repositório tem documentação e nenhum código: `docs/prd.md`, `docs/arquitetura-inicial.md`,
`docs/glossario.md` e sete ADRs, todos já passados por uma sessão de grilling cujas reversões estão
registradas (D20–D33 no PRD; RA-15, RA-28 e RA-31 aposentadas na arquitetura). Este design não
reabre essas decisões: ele as traduz em estrutura de código, e o que ele acrescenta é o recorte de
módulos, a modelagem do schema de controle e a ordem de construção.

Três restrições moldam tudo:

1. **A máquina alvo é uma só**, local, com 23 GB de RAM, 4 vCPUs e ~20 GB livres em disco, rodando
   também PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit e toda a pilha de observabilidade.
   Não há escala horizontal para esconder desperdício.
2. **A Coleta é a única fronteira de leitura** das bases transacionais. Esse é o invariante
   fundador; se cair, o sistema não tem razão de existir.
3. **Mono repositório com versão única.** Os quatro primeiros trade-offs aceitos na arquitetura
   dependem disso — persistir `JasperPrint` serializado só é seguro porque todos os módulos
   compartilham a mesma versão do JasperReports e o mesmo classpath de fontes e renderers.

## Goals / Non-Goals

**Goals:**

- Entregar as duas metades do sistema — Coleta agendada e Exportação síncrona — encontrando-se no
  repositório de artefatos, com os cinco produtos e dois relatórios de exemplo cada.
- Tornar **estruturais** os invariantes que hoje são só texto: execução append-only, catálogo
  derivado do código, separação realm role/client role, semáforo de exportação e `queryTimeout`.
- Instrumentar a métrica primária de forma que ela seja calculável sem consulta manual ao banco.
- Deixar o esqueleto navegável por quem chega depois — `ARCHITECTURE.md` com o code map e as
  proibições.

**Non-Goals:**

- Kubernetes, deploy em produção ou homologação, metas de disponibilidade.
- Cancelamento de execução, apuração retroativa, criação de produto/relatório pela aplicação, MFA,
  notificação ativa e cache de exportação — todos já fora de escopo no PRD §5.
- Virtualização do `JasperPrint` na exportação: trocaria heap por disco, e o disco é o recurso mais
  escasso da máquina alvo.
- Otimização de consulta das bases transacionais de exemplo. Os schemas transacionais existem para
  exercitar a Coleta, não para representar um sistema bancário real.

## Decisions

### D-01 — Recorte de módulos Maven

Um mono repo Maven com POM pai de versão única e os módulos:

| Módulo | Papel | Depende de |
|---|---|---|
| `comum` | Tipos do domínio compartilhados, contrato de erro, Correlation ID, enums de status e origem | — |
| `processador-starter` | Spring Batch: leitura paginada, contagem prévia, renderização, gravação de artefato, registro de metadados, limite por relatório | `comum` |
| `produto-poupanca`, `produto-cliente`, `produto-contacorrente`, `produto-consorcio`, `produto-emprestimo` | Um por produto. JRXMLs, consultas, declaração do catálogo | `processador-starter` |
| `api` | REST, exportação, catálogo editável, permissão, auditoria, downloads, endpoint de marca de expurgo | `comum` |
| `frontend` | Angular, consome só a API | — |

**Por que um módulo por produto e não um processador parametrizado:** o módulo processador **é** o
Produto. Um processador genérico lendo configuração transformaria "criar produto" numa operação de
dados, e o catálogo derivado do código deixaria de ser verdade — exatamente o que o ADR 0002
recusa. Alternativa considerada e rejeitada.

**Por que o starter e não herança de classe:** os cinco produtos precisam do mesmo ciclo (contar →
ler → renderizar → gravar → registrar) e diferem apenas na origem do dado e nos JRXMLs.
Auto-configuração dá a eles o ciclo sem que cada um possa reimplementá-lo pela metade.

### D-02 — Schema de controle: tabelas e quem escreve em cada uma

| Tabela | Conteúdo | Escrita por |
|---|---|---|
| `produto` | Sigla (PK), nome, ativo | Coleta (publicação), API (nome, inativação) |
| `relatorio` | Código (PK), sigla, nome, descrição, tempo estimado, ativo | Coleta (publicação), API (atributos, inativação) |
| `execucao` | id, código do relatório, data de referência, início, fim, duração, status, origem, tempo estimado copiado, vigente, motivo | Coleta, orquestrador (reserva e encerramento anômalo) |
| `artefato` | id, execução, tipo (`jrprint`/`csv`), caminho, tamanho, expurgado em | Coleta, API (marca de expurgo) |
| `auditoria` | id, tipo do evento, solicitante, momento, motivo, Correlation ID, execução relacionada | API |
| `download` | id, usuário, formato, momento, **cópias**: código, nome do relatório, sigla, nome do produto, data de referência | API |
| `relatorio_role` | Código do relatório × nome da client role | API |

**Vigência como coluna, não como tabela de ponteiro.** `execucao.vigente` é booleano, com índice
único parcial sobre `(codigo_relatorio, data_referencia) WHERE vigente`. É o que torna "no máximo
uma execução vigente por par" uma propriedade do banco e não uma disciplina de código. Alternativa
considerada: tabela `execucao_vigente` com FK — mais uma escrita a coordenar, mesma garantia.

**Append-only por gatilho.** Um trigger que recusa `UPDATE` de `status` quando o valor anterior é
terminal. Sem isso, "execução imutável" depende de ninguém escrever o `UPDATE` errado — e é
justamente o tipo de erro que aparece meses depois, numa correção apressada. O único `UPDATE`
permitido em `execucao` é o de `vigente`.

### D-03 — Reserva do ciclo e encerramento anômalo vivem no orquestrador

A primeira task da DAG lê o catálogo e insere as execuções reservadas; o callback de falha da task
de produto encerra o que ficou aberto. **Por que no Airflow e não no contêiner:** o contêiner que
morreu não encerra a própria execução — é exatamente o caso que a regra cobre. Quem sobrevive à
morte do contêiner é a task.

A lista de produtos na DAG é **estática**, uma task por módulo. A lista de relatórios é consultada
em tempo de execução, porque relatório é dado do catálogo. Adicionar produto é adicionar módulo e
task no mesmo PR.

### D-04 — Os dois limites de tempo, e o `queryTimeout` que sustenta o interno

O limite do relatório (2× o tempo estimado copiado) é verificado **entre chunks** do Spring Batch.
Uma consulta que trava dentro de uma única chamada JDBC não chega ao fim do chunk e não seria
interrompida — por isso todo statement de leitura da Coleta declara `queryTimeout`. O starter
configura esse valor por padrão e nenhum produto define o seu próprio `JdbcTemplate` sem ele; é
item de revisão de PR.

O limite de segurança é o `execution_timeout` da task, em 2× a soma dos tempos estimados do
produto com folga. Ele não substitui o primeiro: mede coisas diferentes, em níveis diferentes.

### D-05 — XLSX contínuo por convenção de autoria

`ignorePagination` atua no **preenchimento**, e o `.jrprint` já chega paginado à exportação.
Reconstruir o print sem paginação exigiria preencher de novo, lendo a base — o que fere a fronteira
de leitura. Então: cabeçalho de coluna na banda `title` de **todo** JRXML, ornamento descartável em
`pageHeader`/`pageFooter`, e a exportação XLSX exclui essas bandas por origem de elemento.

Isso é uma regra que apodrece em silêncio no primeiro relatório escrito por quem não leu o
documento. A defesa é o teste por relatório afirmando cabeçalho único — e o teste é parte da
definition of done de "adicionar relatório", não um extra.

### D-06 — Marca de expurgo autoritativa, derivação como rede

A notificação de expurgo do MinIO chega a um endpoint da API autenticado por credencial de serviço.
Quando a marca existe, ela manda; quando falta, a API deriva *expirado* por
`data de referência < hoje − janela`. Essa dupla existe porque **não está confirmado** que a
expiração por ILM do MinIO emita evento — é spike aberto. Se não emitir, a derivação já é a resposta
e o endpoint continua servindo para expurgo manual.

### D-07 — Autorização híbrida e o poder que a API tem e não usa

Perfil é realm role; Role de relatório é client role de um cliente dedicado; grupos são nativos; o
elo *Relatório → Role* é tabela, porque é o único que conhece o catálogo.

Restringir o service account da API a gerir um único cliente depende de *fine-grained admin
permissions*, que é preview. Não apoiamos segurança em recurso preview: o service account recebe
permissões grossas. **A API tem tecnicamente poder de criar um ADMINISTRADOR**; o que a impede é o
código e a separação de espaços de nomes. Esse é um risco aceito, declarado aqui e testado em
RA-68.

### D-08 — Ordem de construção

1. Fundações: POM pai, módulos vazios compilando, compose, CI, `ARCHITECTURE.md`, health checks.
2. Contratos: migrations do schema de controle, OpenAPI, seed de desenvolvimento.
3. Fatia vertical de um produto (`POUPANCA`): catálogo publicado → reserva → apuração → artefato →
   exportação PDF. É o menor caminho que atravessa o sistema inteiro.
4. Os quatro testes obrigatórios por natureza de risco, antes das features que eles protegem.
5. Demais formatos, demais produtos, identidade e acesso, histórico, observabilidade.

A fatia vertical vem antes da largura porque é ela que revela se o `.jrprint` serializado sobrevive
ao trajeto entre módulos — o risco técnico mais caro de descobrir tarde.

## Risks / Trade-offs

- **A expiração por ILM do MinIO pode não emitir evento** → o spike roda antes da implementação de
  `artefato-e-retencao`; se não emitir, a derivação aritmética de D-06 é a resposta e o endpoint fica
  restrito a expurgo manual. O desenho não muda.
- **O service account da API pode criar ADMINISTRADOR** → separação de espaços de nomes, endpoints
  do GERENTE restritos ao cliente dedicado, e teste automatizado dedicado. Revisitar quando
  *fine-grained admin permissions* sair de preview.
- **`.jrprint` desserializado ocupa múltiplos do tamanho em disco** → teto de artefato, teto de
  linhas e semáforo de exportação compõem **um único** teto de memória. Afrouxar qualquer um deles
  isoladamente quebra os três.
- **Fontes não vão embutidas no `.jrprint`** → as *font extensions* precisam estar no classpath da
  API; garantido pelo mono repo de versão única. Se o repositório se partir, PDF sai com fonte
  substituída ou estoura.
- **Relatórios do mesmo produto podem ver instantes diferentes da base** quando um vem de
  retentativa → preço aceito por permitir retentativa dentro de janela única; a alternativa era
  ficar sem o relatório até o dia seguinte.
- **Não há como interromper uma apuração sob demanda** → o único interruptor é o tempo, e o teto da
  soma por produto torna "o dobro do tempo estimado" um número limitado e conhecido.
- **Os limites do PRD §10 são provisórios e podem não resistir à medição** → ticket de calibração
  com `k6` substitui os números estimados pelos observados antes de fechar os critérios de aceite
  não-funcionais.
- **Doze capabilities num único change** → é um escopo grande para uma revisão só. A mitigação é a
  ordem de D-08: as tarefas são agrupadas por fatia entregável, e cada grupo é mesclável sozinho.

## Migration Plan

Não há migração: o sistema não existe ainda e não há dado a preservar. O que existe é **ordem de
subida** do ambiente local:

1. `docker compose up` sobe PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit e a pilha de
   observabilidade.
2. O Flyway cria o schema de controle e os schemas transacionais de exemplo; o seed popula as bases
   transacionais.
3. O Keycloak importa o realm com as três realm roles, o cliente dedicado e o ADMINISTRADOR inicial.
4. Os módulos processadores sobem e publicam o catálogo. Código duplicado ou soma acima do teto
   impede a subida — e é aí que se descobre, não no primeiro ciclo.
5. A DAG é publicada com `catchup=False`; o primeiro ciclo roda às 03h00 seguintes ou por disparo
   manual.

Rollback é `docker compose down -v` e subir de novo: o ambiente é descartável por construção.

## Open Questions

- Os limites recalibrados do PRD §10 resistem à medição real com `k6`? Bloqueia o fechamento dos
  critérios de aceite não-funcionais.
- A meta de 98% da métrica primária é adequada depois do primeiro mês de operação?
- Quais são os modelos de dados dos dois relatórios de exemplo de cada produto? Precisam ser
  definidos antes da fatia vertical de `POUPANCA`, e é o que determina se os JRXMLs exercitam de
  fato imagens e fontes diferentes.
- A arquitetura interna de cada módulo (pacotes, fronteiras) será fixada no `ARCHITECTURE.md` do
  módulo durante as fundações, ou herda um padrão único definido no `ARCHITECTURE.md` raiz?
