# Arquitetura Inicial

## Regras Arquiteturais:
- Cada módulo processador lê exclusivamente do esquema PostgreSQL do seu próprio produto, que representa a base transacional daquele domínio. A Coleta é a única fronteira de leitura: nenhum outro módulo acessa esses esquemas
- O histórico de downloads não são expurgados juntos com os relatórios no MinIO.
- O CSV não passa pelo Jasper Reports. Persistir o dataset bruto em CSV.gz ao lado do .jrprint. O Jasper permanece responsável por PDF, XLSX e DOCX
- O CSV é o dataset da query principal (sem subrelatórios e imagens) com separador `;` (para Excel pt-BR)
- Os usuários do tipo RELATOR irão se cadastrar somente via interface WEB pública
- Ao iniciar o container do KeyCloak, automaticamente irá criar um usuário do tipo ADMINISTRADOR (senha configurada em variável de ambiente)
- A geração e download do relatório deve ser feito pelo módulo de API REST
- Em cada módulo de processamento de relatórios criar dois relatórios de exemplo com imagens e fontes diferentes. Pesquisar e definir como será implementado os dois exemplos de cada módulo baseados na sua descrição
- Formato mensagem de erro no Swagger: horário do erro(formato ISO 8601), descrição do erro, Correlation ID, Botão para copiar formato em JSON
- O código fonte será armazenado em um mono repositório com versão única no GitHub
- Automação do CI com GitHub Actions
- Armazenamento dos dados em um repositório que implementa o padrão S3 (Minio) 
- O módulo API REST retorna status UP ao acessar os endpoint http://localhost:<porta>/actuator/health/liveness e http://localhost:<porta>/actuator/health/readiness
- Módulo API REST executando na porta 8080
- Log, span, trace e métrica devem ser enviados para o OTel Collector
- Correlation ID propagado automaticamente e formado por traceId nos logs via MDC pertindo a pesquisa no Graylog pelo Correlation ID
- Logs estruturados enriquecidos com traceId e spanId do OpenTelemetry, permitindo correlação direta entre logs e traces.
- SDK do OpenTelemetry deve ser desabilitado para que os testes (JUnit/Cucumber/Testcontainers) não dependam de Collector nem gerem telemetria
- Sempre que possível usar as labels nome do produto e código do relatório nas métricas
- Ciclo de vida dos dados no Minio: criar uma variável de ambiente (valor padrão 7 dias) para definir quando os dados salvos devem ser apagados automaticamente
- Gherkin para todo comportamento observável pelo negócio (aceitação e integração, inclusive a Coleta)
- Produção roda Docker Compose em VMs
- Cada Relatório tem o seu próprio JRXML, versionado no repositório e associado ao seu módulo processador
- A Role de Relatório é uma role real do Keycloak e viaja no JWT
- Mailpit para verificação de e-mail e reset de senha do Keycloak
- O Account Console e a página de registro do Keycloak (com tema customizado) serão expostos seletivamente pelo Traefik para troca de senha e cadastro
- Será usado um schema — de controle/aplicação — separado dos schemas transacionais, com escrita pelos processadores e leitura pela API
- Criar uma função de callback no MinIO para atualizar o relatório como expurgado na base de dados
- Toda a aplicação e seus containers devem executar no timezone America/Sao_Paulo 
- A primeira versão irá executar somente em Ambiente Local
- Nos módulos JAVA criar os cenários em Gherkin(`*.feature`) no diretório 
`./<módulo>/src/test/resources/feature`
- Nos módulos Angular criar os cenários em Gherkin(`*.feature`) no `./<módulo>/e2e/features/`

## Módulos backend:
- Biblioteca comum a todos outros módulos
- Stater do Processador com Spring Batch
- API REST 
- Múltiplos módulos processadores segmentados por produto que implementam o Stater do Processador com Spring Batch: Poupança, Cliente, Conta Corrrente, Consorcio, Empréstimo 

## Módulo Frontend:
- Realiza a integração com os endpoints que estão no módulo API REST

## Tech Stack comum:
- Gherkin 
- JWT
- TDD
- BDD 

## Tech Stack sugerida para Backend:
- JAVA
- Spring Web
- Spring Batch
- Jasper Reports
- Apache Airflow
- PostgreSQL
- Flyway 
- Docker Compose
- KeyCloak
- Swagger
- SpringDOC OpenAPI
- MAVEN
- JACOCO
- Mailpit 
- Minio
- Traefik (Ingress e TLS)
- Actuator 
- OpenTelemetry (Micrometer)
- OpenTelemetry SDK
- OTel Collector
- Prometheus
- Grafana
- Graylog
- Log4j2
- Jaeger 
- Cucumber
- Testes de Integração (JUnit 5 + Cucumber + Testcontainers + Flyway)
- Testes de E2E (Newman CLI + psql)
- Bucket Notifications

## Tech Stack sugerida para Frontend:
- TypeScript
- NodeJS
- Angular
- Cucumber
- E2E de navegador (Playwright)

### Protótipação das principais funcionalidades
- drop-down para visualizar os relatórios disponíveis por dd/MM/yyyy -> Nome do produto -> Código do relatório
- Vinculação das roles de relatório aos grupos de usuário
- Vinculação dos usuários aos grupos

## Trade-offs aceitos
- Serialização Java nativa não quebra entre versões do JasperReports (`serialVersionUID`) porque todos os módulos usarão a mesma versão do Jasper.
- O arquivo vem do módulo que está dentro do projeto, logo é confiável desserializar objeto Java de fonte.
- Imagens vão embutidas, mas as fontes não. A API que exporta terão as mesmas 'font extensions' no classpath por ser um projeto mono repositório, senão o PDF sai com substituição de fonte (ou estoura, dependendo de `net.sf.jasperreports.awt.ignore.missing.font`). 
- Barcodes e afins também viram renderers serializados (`BarbecueRendererImpl`), então vão junto — por ser um projeto mono repositório o jar correspondente estará presente na hora de desserializar, senão dá `ClassNotFoundException`.

## Pendentes de definição:
- Cadastramento de novos contêineres do Spring Batch no Apache Airflow.
- Gravação dos metadados de processamento (data hora início, data hora fim, status)
- Gravação dos metadados do relatório: "tempo estimado de execução" em segundos, nome do produto, nome e descrição.
- Revisão da Tech Stack
- Definição dos nomes dos módulos 
- Definição da arquitetura de cada módulo e sua respectiva estrutura
- Definição dos relatorios de exemplo e seus respectivos modelos de dados

## Tickets iniciais do projeto

Tickets que devem ser os primeiros a serem implementados no projeto.

- Prototipação usando somente HTML, CSS e JavaScript das seguintes funcionalidades (descartável)
- Swagger descartável onde depois será substituído pelo SpringDOC OpenAPI
- Módulos compilando com um esqueleto básico e endpoints do Actuator liveness e readiness respondendo UP no módulo API REST
- Criar os cenários em Gherkin
- Criar os arquivos CLAUDE.md e ARCHITECTURE.md dentro do projeto e dentro dos módulos
- Criar as guidelines do projeto

## Fora de escopo
- Kubernetes
- Classificação de dados, mascaramento e criptografia em repouso
- Cache de exportação com o binário exportado
- Deploy em produção/homologação