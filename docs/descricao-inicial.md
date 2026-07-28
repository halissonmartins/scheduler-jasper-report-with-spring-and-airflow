Descrição:
Periodicamente a aplicação irá coletar os dados de vários relatórios de forma agendada e salvar em um repositório (banco de dados nosql ou bucket S3).
Através de uma funcionalidade o usuário com perfil de relator irá solicitar a geração de um desses relatórios, essa aplicação irá recuperar os dados coletados e gerar o relatório em formatos PDF, CSV, XLSX ou DOCX.
É um coletor agendado (ingestão de dados) e um gerador/conversor sob demanda de relatórios.
Possui funcionalidades para realizar: sign in, sign out, sign up, gestão de roles de relatório, gestão de usuários, cadastro de relatórios, visualização dos relatórios disponíveis por dd/MM/yyyy e produto, download dos relatórios.

Fluxo:
Coleta Agendada -> Repositório -> API de Geração sob Demanda em Múltiplos Formatos

Estrutura de armazenamento dos dados dos relatórios:
yyyy-MM-dd -> nome do produto -> código do relatório -> estrutura com os dados não estruturados

Formato do código do relatório:
Nome do produto (máximo de 20 caracteres) + - + código com 4 números
	Exemplos:
	- POUPANCA-0001
	- CLIENTE-0005
	- CONTACORRENTE-1234
	- CONSORCIO-9874
	- EMPRESTIMO-4567

Regras:
- Formatos de exportação: PDF, XLSX, DOCX, CSV.
- Se o tempo de execução ultrapassar o que foi cadastrado no "tempo estimado de execução", o status será "processado com alerta".
- O usuário se cadastra e aguarda um usuário do tipo GERENTE adicionar uma role de relatório.
- O usuário com o tipo GERENTE não pode incluir outro usuário com o tipo GERENTE.
- Por padrão o usuário que fizer o via interface web pública aguardará o vinculo das roles de relatório.
- Somente usuários do tipo RELATOR podem gerar relatórios.
- Ao iniciar o container do KeyCloak, automaticamente irá criar um usuário do tipo ADMINISTRADOR (senha configurada em variável de ambiente).
- Os usuários do tipo RELATOR irão se cadastrar somente via interface WEB pública.
- Todos os tipos de usuários podem trocar a senha.
- A inclusão de um novo relatório no repositório não exige o seu cadastro prévio.
- O usuário relator somente consegue gerar os relatórios cadastrados.
- A geração e download do relatório deve ser feito pelo módulo de API REST.
- O código fonte será armazenado em um mono repositório no GitHub.

Tipos de usuário:
- ADMINISTRADOR: somente efetua o cadastrado/remoção de usuários do tipo GERENTE/ADMINISTRADOR, cadastro/remoção de produtos e cadastro/remoção de relatórios.
- GERENTE: somente cadastra roles do tipo "RELATORIO", vincula roles de relatórios a relatórios, vincula roles de relatórios a usuários do tipo RELATOR e exclusão dos usuários do tipo RELATOR.
- RELATOR: apenas consegue gerar os relatórios em seu usuário tem acesso.

Pendentes de definição:
- Como criar um usuário que tenha permissão de vincular a role GERENTE a outro usuário
- Armazenamento dos dados em:
	- CSV + S3 (LocalStack) 
	- MongoDB (ou um outro banco NoSql)
- Ciclo de vida dos dados:
	- Após 7 dias os dados salvos devem ser apagados automaticamente
- Cadastramento de novos contêineres do Spring Batch no Apache Airflow
- Auditoria/histórico de alterações e downloads
- Ciclo de Vida dos Status (em processamento, processado com sucesso, processado com erro, processado com alerta)
- Usar ou não um banco de dados PostgreSQL
- Gravação dos metadados de processamento (data hora início, data hora fim, status)
- Gravação dos metadados do relatório: "tempo estimado de execução" em segundos, sigla do produto, nome e descrição.
- Definição completa do Tech Stack
- UI de navegação para visualizar os relatórios disponíveis por dd/MM/yyyy

Módulos backend:
- Biblioteca comum a todos outros módulos
- Stater do Processador com Spring Batch
- Múltiplos módulos processadores segmentados por produto (implementam o Stater do Processador com Spring Batch) 
- API REST

Frontend:
- Realiza a integração com os endpoints que estão no módulo API REST

Tech Stack comum:
- Gherkin 
- JWT
- TDD
- BDD

Tech Stack sugerida para Backend:
- JAVA
- Spring Web
- Spring Batch
- Jasper Reports
- Apache Airflow
- Open Telemetry (Micrometer)
- Grafana
- Docker Compose
- KeyCloak
- Swagger
- MAVEN

Tech Stack sugerida para Frontend:
- TypeScript
- NodeJS
- Angular
- Json Server