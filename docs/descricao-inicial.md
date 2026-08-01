# Scheduler Jasper Report With Spring and Airflow

## Descrição:
Periodicamente a aplicação irá coletar os dados de vários relatórios de forma agendada e salvar no formato JasperPrint em um repositório S3.
Através de uma funcionalidade o usuário com perfil de relator irá solicitar a geração de um desses relatórios, essa aplicação irá recuperar os dados coletados e gerar o relatório em formatos PDF, CSV, XLSX ou DOCX.
É um coletor agendado (ingestão de dados) e um gerador/conversor sob demanda de relatórios.
Possui funcionalidades para realizar: sign in, sign out, sign up, gestão de roles de relatório, gestão de usuários, cadastro de relatórios, visualização dos relatórios disponíveis por dd/MM/yyyy e produto, download dos relatórios.

## Fluxo:
Coleta Agendada -> Geração do JasperPrint serializado -> Repositório -> API de Geração sob Demanda em Múltiplos Formatos

## Estrutura de armazenamento dos dados dos relatórios:
yyyy-MM-dd -> nome do produto -> código do relatório -> estrutura com os dados não estruturados

### Formato do código do relatório:
Nome do produto (máximo de 20 caracteres) + - + código com 4 números
	Exemplos:
	- POUPANCA-0001
	- CLIENTE-0005
	- CONTACORRENTE-1234
	- CONSORCIO-9874
	- EMPRESTIMO-4567

## Regras Negociais:
- Formatos de exportação: PDF, XLSX, DOCX, CSV.
- Ciclo de Vida dos Status (em processamento, processado com sucesso, processado com erro, processado com alerta)
- Se o tempo de execução ultrapassar o que foi cadastrado no "tempo estimado de execução", o status será "processado com alerta".
- O usuário do tipo RELATOR se cadastra e aguarda um usuário do tipo GERENTE o adicionar um grupo de relatório.
- O usuário com o tipo GERENTE não pode incluir outro usuário com o tipo GERENTE.
- Por padrão o usuário que fizer o cadastro via interface web pública aguardará o vinculo a um grupo por um usuário GERENTE.
- Somente usuários do tipo RELATOR podem gerar relatórios cadastrados.
- Ao iniciar o container do KeyCloak, automaticamente irá criar um usuário do tipo ADMINISTRADOR (senha configurada em variável de ambiente).
- Os usuários do tipo RELATOR irão se cadastrar somente via interface WEB pública.
- Todos os tipos de usuários podem trocar a senha.
- A geração e download do relatório deve ser feito pelo módulo de API REST.
- Em cada módulo de processamento de relatórios criar dois relatórios de exemplo com imagens e fontes diferentes. Pesquisar e definir como será implementado os dois exemplos de cada módulo baseados na sua descrição.
- Formato mensagem de erro no Swagger: horário do erro(formato ISO 8601), descrição do erro, Correlation ID, Botão para copiar formato em JSON
- Componente para exibir mensagem de erro no Frontend: horário do erro, descrição do erro, Correlation ID, Botão para copiar formato em JSON
- O CSV não passa pelo Jasper Reports. Persistir o dataset bruto em CSV.gz ao lado do .jrprint. O Jasper permanece responsável por PDF, XLSX e DOCX.
- Modo de concessão de permissão dos usuários aos relatórios: relatório - role de relatório - grupo de usuários - usuário
- Cada módulo processador lê exclusivamente do esquema PostgreSQL do seu próprio produto, que representa a base transacional daquele domínio. A Coleta é a única fronteira de leitura: nenhum outro módulo acessa esses esquemas.
- O histórico de downloads não são expurgados juntos com os relatórios no MinIO.

## Regras Arquiteturais:
- O código fonte será armazenado em um mono repositório com versão única no GitHub.
- Automação do CI com GitHub Actions
- Armazenamento dos dados em um repositório que implementa o padrão S3 (Minio) 
- O módulo API REST retorna status UP ao acessar os endpoint http://localhost:/actuator/health/liveness e http://localhost:/actuator/health/readiness
- Módulo API REST executando na porta 8080
- Log, span, trace e métrica devem ser enviados para o OTel Collector
- Correlation ID propagado automaticamente e formado por traceId nos logs via MDC pertindo a pesquisa no Graylog pelo Correlation ID
- Logs estruturados enriquecidos com traceId e spanId do OpenTelemetry, permitindo correlação direta entre logs e traces.
- SDK do OpenTelemetry é desabilitado para que os testes (JUnit/Cucumber/H2) não dependam de Collector nem gerem telemetria
- Sempre que possível usar as labels nome do produto e código do relatório nas métricas
- Ciclo de vida dos dados no Minio: criar uma variável de ambiente (valor padrão 7 dias) para definir quando os dados salvos devem ser apagados automaticamente
- Gherkin para todo comportamento observável pelo negócio (aceitação e integração, inclusive a Coleta)
- Produção roda Docker Compose em VMs
- Cada Relatório tem o seu próprio JRXML, versionado no repositório e associado ao seu módulo processador
- A Role de Relatório é uma role real do Keycloak e viaja no JWT
- Mailpit para verificação de e-mail e reset de senha do Keycloak
- O Account Console e a página de registro do Keycloak (com tema customizado) serão expostos seletivamente pelo Traefik para troca de senha e cadastro

## Tipos de usuário:
- ADMINISTRADOR: efetua o cadastrado/remoção de usuários do tipo GERENTE/ADMINISTRADOR, cadastro/remoção de produtos, cadastro/remoção de relatórios, visualização do histórico downloads.
- GERENTE: somente cadastra roles do tipo "RELATORIO", vincula roles de relatórios a relatórios, cadastra/remove grupos, vincula roles de relatórios a grupos de usuários do tipo RELATOR, inclui/remove usuários dos grupos e exclusão dos usuários do tipo RELATOR.
- RELATOR: apenas consegue gerar os relatórios em seu usuário tem acesso.

## Pendentes de definição:
- Cadastramento de novos contêineres do Spring Batch no Apache Airflow.
- Gravação dos metadados de processamento (data hora início, data hora fim, status)
- Gravação dos metadados do relatório: "tempo estimado de execução" em segundos, nome do produto, nome e descrição.
- Revisão da Tech Stack
- UI de navegação via drop-down para visualizar os relatórios disponíveis por dd/MM/yyyy
- Definição da biblioteca de coleta de log que será utilizada pelo Spring
- Definição dos nomes dos módulos 
- Definição da arquitetura de cada módulo e sua respectiva estrutura
- Definição dos relatorios de exemplo e seus respectivos modelos de dados

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
- Testes de Integração (JUnit 5 + Cucumber + H2 em modo PostgreSQL)
- Testes de E2E (Newman CLI + psql)
- E2E de navegador (Playwright)

## Tech Stack sugerida para Frontend:
- TypeScript
- NodeJS
- Angular

## Fases iniciais do desenvolvimento

Antes do final cada fase solicitar a revisão e aguardar a aprovação

- Prototipação usando somente HTML, CSS e JavaScript das seguintes funcionalidades (descartável)
- Swagger descartável onde depois será substituído pelo SpringDOC OpenAPI
- Módulos compilando 
- Endpoints do Actuator liveness e readiness respondendo UP no módulo API REST

## Protótipação das principais funcionalidades
- drop-down para visualizar os relatórios disponíveis por dd/MM/yyyy -> Nome do produto -> Código do relatório
- Vinculação das roles de relatório aos grupos de usuário
- Vinculação dos usuários aos grupos

# Trade-offs aceitos
- Serialização Java nativa não quebra entre versões do JasperReports (`serialVersionUID`) porque todos os módulos usarão a mesma versão do Jasper.
- O arquivo vem do módulo que está dentro do projeto, logo é confiável desserializar objeto Java de fonte.
- O conteúdo já está paginado e posicionado. Exportar um `JasperPrint` desenhado para PDF em XLSX/CSV costuma sair feio (o exporter Excel monta grid a partir de coordenadas).
- Imagens vão embutidas, mas as fontes não. A API que exporta terão as mesmas 'font extensions' no classpath por ser um projeto mono repositório, senão o PDF sai com substituição de fonte (ou estoura, dependendo de `net.sf.jasperreports.awt.ignore.missing.font`). 
- Barcodes e afins também viram renderers serializados (`BarbecueRendererImpl`), então vão junto — por ser um projeto mono repositório o jar correspondente estará presente na hora de desserializar, senão dá `ClassNotFoundException`.

# Fora de escopo
- MFA 
- Rotação obrigatória da senha inicial do ADMINISTRADOR
- Kubernetes
- Classificação de dados, mascaramento e criptografia em repouso