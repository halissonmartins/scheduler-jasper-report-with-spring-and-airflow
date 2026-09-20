## Why

Hoje não existe lugar algum onde o dado de um relatório esteja apurado, congelado por data e
pronto para entrega: toda solicitação vai direto à base transacional do produto e concorre com a
operação — justamente no fim do mês, quando mais se pede relatório e a base está mais carregada
(`docs/prd.md` §2). Quem opera só descobre que a apuração falhou quando o usuário reclama, e uma
execução travada é indistinguível de uma que ainda está rodando.

Este change traduz o PRD e a arquitetura inicial na especificação executável do MVP: o relatório
passa a ser **lido da base uma vez por dia** e **exportado quantas vezes for preciso**, com
permissão auditável e status observável. O repositório está vazio de código — esta é a primeira
especificação, e ela carrega os invariantes das revisões de grilling já registradas em
`docs/adr/`.

## What Changes

**Coleta (a metade agendada)**

- DAG diária às 03h00 (`America/Sao_Paulo`) com `catchup=False` explícito e **uma task estática por
  produto**, em pool de 2.
- **Reserva do ciclo** antes de qualquer apuração: uma Execução por relatório ativo, com início
  nulo, para que um relatório não apurado apareça como falha em vez de sumir do denominador.
- Cinco módulos processadores Spring Batch — `POUPANCA`, `CLIENTE`, `CONTACORRENTE`, `CONSORCIO`,
  `EMPRESTIMO` — cada um lendo **apenas** o schema transacional do seu produto, com dois relatórios
  de exemplo cada (imagens e fontes diferentes entre si).
- **Dois limites de tempo com papéis distintos**: o do relatório (2× o tempo estimado, verificado
  entre chunks e sustentado por `queryTimeout` em todo statement) e o de segurança do produto
  (`execution_timeout` da task).
- Contagem prévia de linhas que recusa o dataset acima do teto, encerrando como
  `processado com erro` com motivo explícito.
- Encerramento de execução anômala pelo callback de falha da task, inclusive das execuções apenas
  reservadas.

**Execução como registro imutável**

- Quatro status, um só não-terminal. Execução **append-only**: retentativa e reprocessamento
  inserem linha nova e movem o ponteiro de vigência — nenhum caminho do sistema atualiza status
  terminal.
- Tempo estimado **copiado para dentro da Execução** no disparo.
- Recusa de nova execução sobre par já concluído vira **evento de auditoria**, nunca Execução.

**Exportação (a metade sob demanda)**

- API REST síncrona entregando PDF, XLSX, DOCX e CSV a partir do artefato já apurado, **sem jamais
  tocar na base transacional**.
- `.jrprint` e `.csv.gz` como artefatos irmãos; o CSV não passa pelo JasperReports.
- XLSX contínuo como **convenção de autoria do JRXML** (cabeçalho de coluna na banda `title`), com
  teste de cabeçalho único por relatório.
- **Semáforo** de exportações simultâneas que recusa de imediato a requisição excedente — não há
  fila.

**Catálogo derivado do código**

- Produto e Relatório **não são criados nem removidos pela aplicação**: cada módulo anuncia os seus
  ao iniciar. A aplicação edita nome, descrição e tempo estimado, e inativa.
- Código de relatório duplicado dentro do produto **impede o módulo de iniciar**.
- Teto da soma dos tempos estimados por produto validado na edição — é o que torna a janela do
  ciclo uma promessa e não um desejo.

**Identidade e acesso**

- Cadeia `Relatório → Role de relatório → Grupo → Usuário`, com todos os elos N:N e acesso pela
  união dos caminhos.
- Separação **realm role (Perfil) vs. client role (Role de relatório)** no Keycloak, que torna
  estrutural a impossibilidade de o GERENTE promover alguém.
- Autocadastro público apenas de RELATOR, sem grupo padrão e sem moderação.

**Retenção em três ciclos independentes**

- Artefato por 7 dias (configurável); **metadados de Execução, nunca**; histórico de downloads,
  indefinidamente — com cópia dos identificadores do momento do download.

**Fora deste change** (já fora de escopo no PRD §5 e na arquitetura): cancelamento de execução,
apuração retroativa, criação de produto/relatório pela aplicação, MFA, notificação ativa,
Kubernetes, deploy em produção e cache de exportação.

**BREAKING**: nenhum — é a primeira especificação do projeto; não há comportamento publicado a
quebrar.

## Capabilities

### New Capabilities

- `plataforma-local`: ambiente Docker Compose com as dependências reais, timezone único
  `America/Sao_Paulo`, versionamento de schema por Flyway, health checks `liveness`/`readiness` e
  CI bloqueante por PR. É o Sprint 0 do guia — precede qualquer feature.
- `catalogo-derivado`: publicação do catálogo pelos módulos na inicialização, atributos editáveis
  (nome, descrição, tempo estimado), inativação lógica, unicidade do código dentro do produto e
  teto da soma dos tempos estimados.
- `coleta-agendada`: ciclo diário, reserva do ciclo, janela de leitura única por produto,
  retentativa do que não concluiu, paralelismo de 2 produtos, contagem prévia de linhas e
  ausência de qualquer entrada de data de referência.
- `ciclo-de-vida-da-execucao`: os quatro status e suas transições, alerta por degradação, erro
  prevalecendo sobre alerta, os dois limites de tempo, execução append-only com ponteiro de
  vigência e cópia do tempo estimado.
- `reprocessamento-forcado`: solicitação pelo ADMINISTRADOR com motivo obrigatório, invalidação da
  execução anterior, sobrescrita dos artefatos e registro de auditoria.
- `artefato-e-retencao`: gravação do `.jrprint` e do `.csv.gz`, caminho por data → sigla → código,
  expurgo após a janela de retenção, marca de expurgo autoritativa com derivação aritmética como
  rede de segurança, e as três retenções independentes.
- `exportacao`: conversão síncrona para PDF, XLSX, DOCX e CSV a partir do artefato, XLSX contínuo
  por convenção de autoria, CSV como dataset bruto e semáforo de simultaneidade.
- `listagem-de-relatorios`: navegação por data → produto → relatório em `dd/MM/yyyy`, filtrada pela
  cadeia de permissão do usuário, inclusive contra acesso direto.
- `historico-de-downloads`: registro de todo download com cópia dos identificadores do momento,
  consultável pelo ADMINISTRADOR e sobrevivente ao expurgo e à inativação.
- `identidade-e-acesso`: perfis como realm roles, roles de relatório como client roles, grupos,
  autocadastro de RELATOR, troca e recuperação de senha, e o acesso irrestrito do ADMINISTRADOR
  como exceção testada.
- `diagnostico-de-erros`: contrato de erro com momento em ISO 8601, descrição e Correlation ID
  igual ao `traceId`, com cópia estruturada para anexar em chamado.
- `observabilidade-e-metricas`: telemetria via OTel Collector e as métricas do PRD §6
  instrumentadas com labels de sigla, código do relatório e origem da execução.

### Modified Capabilities

Nenhuma. `openspec/specs/` está vazio — todas as capabilities acima são novas.

## Impact

- **Repositório**: mono repo Maven com versão única (biblioteca comum, starter do processador,
  cinco módulos processadores, API REST) e o frontend Angular.
- **Infraestrutura local**: PostgreSQL (schemas transacionais + schema de controle), Keycloak,
  MinIO, Airflow, Traefik, Mailpit, OTel Collector, Graylog, Prometheus, Grafana e Jaeger, numa
  máquina de 23 GB de RAM, 4 vCPUs e ~20 GB livres de disco.
- **Invariantes que atravessam módulos**: só a Coleta lê schema transacional; artefato gravado
  antes dos metadados de conclusão; nenhum `UPDATE` de status terminal; `queryTimeout` em todo
  statement da Coleta; cabeçalho de coluna na banda `title` de todo JRXML.
- **Riscos abertos que este change carrega**: a expiração por ILM do MinIO pode não emitir evento
  (spike), e o service account da API recebe permissões administrativas grossas no Keycloak porque
  *fine-grained admin permissions* é preview.
- **Documentos**: passam a existir `ARCHITECTURE.md`, `docs/user-stories.md`, `docs/riscos.md` e
  `docs/arquitetura/c4-contexto.md`, hoje listados como inexistentes.
