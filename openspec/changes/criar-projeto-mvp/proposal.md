## Why

O repositório contém hoje apenas documentação de produto e de arquitetura: não existe código, build, ambiente
local nem CI. O PRD e a `arquitetura-inicial.md` já fixaram o problema (a base transacional não pode ser lida
sob demanda), a solução (apurar uma vez por dia e exportar quantas vezes for preciso) e as decisões
estruturantes — falta construir o sistema que elas descrevem.

Esta change constrói o **MVP completo**: as duas metades do sistema (Coleta agendada e Exportação síncrona),
as fundações de repositório que o guia exige antes da primeira feature, e os artefatos de documentação que o
PRD e a arquitetura já citam como existentes mas que ainda não estão no repositório.

> **Ressalva registrada.** O escopo de uma única change aqui é maior do que um PR consegue entregar. O
> `tasks.md` é organizado em **fases numeradas e independentemente mergeáveis**, para que o `/opsx:apply`
> possa ser executado por etapas sem que o escopo total se perca de vista.

## What Changes

**Fundações (E0/E1 do guia)**
- Mono repositório Maven com versão única (RA-01) e os módulos de RA-02 a RA-06.
- `docker-compose.yml` com as dependências reais de RA-51, `.env.example`, scripts padronizados, CI bloqueante
  em GitHub Actions (RA-53), lint/format e pre-commit.
- Documentação faltante que o guia exige e que os documentos existentes já referenciam:
  `docs/glossario.md`, `docs/user-stories.md`, `docs/especificacao.md`, `docs/adr/`,
  `docs/arquitetura/c4-contexto.md`, `docs/riscos.md`, `docs/design/` (fluxos, decisões UX, design system),
  `ARCHITECTURE.md` e `README.md`.

**Coleta**
- DAG do Airflow com reserva do ciclo (RA-54), uma task estática por produto (RA-65), pool de 2 (RA-55) e
  `catchup=False` (RA-56).
- Starter Spring Batch de apuração e os 5 módulos processadores, cada um com 2 relatórios de exemplo (RA-08).
- Dois limites de tempo com papéis distintos (RA-57), contagem prévia de linhas (RA-64), encerramento de
  execução anômala pelo callback de falha (RA-14), retentativa limitada (RNF-17).
- Schema de controle versionado com Flyway, com Execução **append-only** e ponteiro de vigência (RA-67).

**Exportação**
- API REST com listagem navegável filtrada por permissão, exportação síncrona em PDF, XLSX, DOCX e CSV,
  semáforo de simultaneidade (RA-60) e histórico de downloads com cópia de identificadores (RA-66).
- Convenção de autoria de JRXML para o XLSX contínuo (RA-59), com teste por relatório.

**Identidade e acesso**
- Keycloak com perfis como realm roles e roles de relatório como client roles de um cliente dedicado (RA-61),
  autocadastro público de RELATOR sem grupo padrão (RA-33), Mailpit para reset de senha (RA-35).

**Interface**
- Frontend Angular consumindo exclusivamente a API REST (RA-06), sobre um design system com tokens definidos
  antes da primeira tela.

**Observabilidade**
- OTel Collector distribuindo para Graylog, Prometheus/Grafana e Jaeger; Correlation ID = `traceId` via MDC;
  métricas do PRD §6 rotuladas por sigla, código e origem da execução (RA-40).

Não há **BREAKING**: o repositório não tem código nem contrato publicado.

## Capabilities

### New Capabilities
- `fundacoes-do-repositorio`: mono repo, módulos, build, ambiente local, CI bloqueante e os artefatos de
  documentação exigidos pelo guia — os trilhos que precisam existir antes da primeira feature.
- `catalogo-de-relatorios`: catálogo derivado do código — publicação na inicialização, atributos editáveis,
  inativação, validação de código duplicado e do teto da soma dos tempos estimados (RN-01 a RN-05, RN-48 a RN-50).
- `coleta-agendada`: ciclo diário — reserva, disparo por produto, janela única de leitura, limites de tempo,
  retentativa, recusa por volume de dataset e encerramento anômalo (RN-06 a RN-13, RN-44, RN-45, RN-52, RN-54).
- `metadados-de-execucao`: Execução como registro imutável com origem e vigência; unicidade do par
  *data + relatório*; recusa auditada que não vira falha de apuração (RN-09, RN-15 a RN-19, RN-46, RN-47).
- `reprocessamento-forcado`: solicitação do ADMINISTRADOR com motivo obrigatório, invalidação da execução
  vigente e sobrescrita dos artefatos (RN-20, RN-21).
- `armazenamento-de-artefatos`: par `.jrprint` + `.csv.gz` por execução, caminho por identificadores imutáveis,
  janela de retenção de 7 dias, expurgo automático e marca de expurgo (RN-08, RN-36, RN-37, RN-39).
- `listagem-de-relatorios`: navegação data → produto → relatório, filtrada pela cadeia de permissão do usuário,
  inclusive contra acesso direto (RN-23, RN-28, RF-13 a RF-16).
- `exportacao-de-relatorios`: exportação síncrona em PDF, XLSX, DOCX e CSV a partir do artefato apurado, com
  XLSX contínuo, CSV bruto e limite de simultaneidade (RN-30 a RN-34, RN-42, RN-53).
- `historico-de-downloads`: registro de todo download com cópia dos identificadores, consultável pelo
  ADMINISTRADOR e nunca expurgado (RN-35, RN-38).
- `identidade-e-autocadastro`: entrada e saída da aplicação, autocadastro público exclusivo de RELATOR, troca e
  recuperação de senha (RN-27, RN-28, RN-29).
- `autorizacao-de-acesso`: cadeia Relatório → Role de relatório → Grupo → Usuário em N:N, gestão pelo GERENTE,
  acesso irrestrito do ADMINISTRADOR e impossibilidade estrutural de promoção de perfil (RN-22 a RN-26).
- `observabilidade-e-diagnostico`: contrato de erro com momento, descrição e Correlation ID rastreável; métricas
  do PRD §6 instrumentadas de verdade (RN-40, RN-41, PRD §6).
- `interface-web`: aplicação Angular sobre design system com tokens, estados canônicos e acessibilidade,
  integrada exclusivamente com a API REST (RA-06, guia P2).

### Modified Capabilities
<!-- Nenhuma: openspec/specs/ está vazio; todas as capabilities são novas. -->

## Impact

- **Repositório**: sai de docs-only para mono repo Maven multi-módulo + workspace Angular + DAG Python.
- **Código novo**: biblioteca comum, starter do processador, 5 módulos processadores, API REST, frontend, DAG.
- **Dados**: schema de controle novo (Flyway) e 5 schemas transacionais de exemplo para os produtos.
- **Infraestrutura local**: PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit, OTel Collector, Graylog,
  Prometheus, Grafana e Jaeger no Docker Compose — dentro do orçamento da máquina alvo de RA-50
  (23 GB RAM, 4 vCPUs, ~20 GB de disco).
- **Superfície externa nova**: endpoint autenticado por credencial de serviço que recebe a marca de expurgo do
  MinIO (RA-63).
- **Risco aceito e já declarado**: o service account da API recebe permissões administrativas grossas no
  Keycloak, porque *fine-grained admin permissions* é preview (RA-61).
- **Números `PROVISÓRIO`**: os limites do PRD §10 entram como configuração fixa e são alvo do spike de
  calibração com k6 — não são critério de reprovação de PR enquanto não medidos.
