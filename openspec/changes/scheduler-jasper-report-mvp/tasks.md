## 1. Fundações do repositório

- [ ] 1.1 Criar o POM pai do mono repo com versão única, `maven.compiler.release` para Java 25 e o
      gerenciamento de dependências (Spring Boot, Spring Batch, JasperReports, OpenTelemetry)
- [ ] 1.2 Criar o módulo `comum` compilando vazio, com os enums de status e de origem da execução
- [ ] 1.3 Criar o módulo `processador-starter` compilando vazio, dependente de `comum`
- [ ] 1.4 Criar os cinco módulos de produto compilando vazios, dependentes do starter
- [ ] 1.5 Criar o módulo `api` compilando vazio, com Spring Web e Actuator, respondendo `UP` em
      `liveness` e `readiness` na porta 8080
- [ ] 1.6 Criar o projeto Angular do frontend compilando, sem nenhuma chamada a backend
- [ ] 1.7 Adicionar `.editorconfig`, formatter e linter para Java e TypeScript, com `tsconfig` em
      modo estrito
- [ ] 1.8 Configurar o timezone `America/Sao_Paulo` em todos os módulos e imagens
- [ ] 1.9 Escrever o `docker-compose.yml` com PostgreSQL, Keycloak, MinIO, Airflow, Traefik,
      Mailpit, OTel Collector, Graylog, Prometheus, Grafana e Jaeger
- [ ] 1.10 Escrever o `.env.example` com todas as variáveis e nenhum segredo real
- [ ] 1.11 Escrever o `README.md` com a execução em três comandos
- [ ] 1.12 Criar os scripts padronizados `setup`, `dev`, `test`, `lint`, `build` e `migrate`
- [ ] 1.13 Configurar o workflow de CI no GitHub Actions — lint, tipos, testes e build — bloqueante
      por PR
- [ ] 1.14 Configurar pre-commit hook e scanner de segredos, com `.gitignore` cobrindo artefatos de
      build
- [ ] 1.15 Escrever o `ARCHITECTURE.md` raiz com bird's eye view, code map e a lista de invariantes
      como proibições
- [ ] 1.16 Escrever o `CLAUDE.md` de cada módulo carregando os invariantes que lhe dizem respeito
- [ ] 1.17 Escrever `docs/arquitetura/c4-contexto.md` com os diagramas C4 nível 1 e 2 em Mermaid
- [ ] 1.18 Escrever `docs/riscos.md` com os riscos abertos e o encaminhamento de cada um
- [ ] 1.19 Escrever `docs/user-stories.md` derivando as histórias das capabilities deste change,
      com critério de aceite em Given/When/Then
- [ ] 1.20 Verificar em clone limpo que o ambiente sobe e o CI fica verde

## 2. Contratos: schema de controle

- [ ] 2.1 Escrever a migration Flyway das tabelas `produto` e `relatorio`, com sigla e código como
      chaves naturais
- [ ] 2.2 Escrever a migration da tabela `execucao` com data de referência, início, fim, duração,
      status, origem, tempo estimado copiado e `vigente`
- [ ] 2.3 Criar o índice único parcial de `(codigo_relatorio, data_referencia) WHERE vigente`
- [ ] 2.4 Criar o gatilho que recusa `UPDATE` de status quando o valor anterior é terminal
- [ ] 2.5 Escrever a migration da tabela `artefato` com tipo, caminho, tamanho e marca de expurgo
- [ ] 2.6 Escrever a migration das tabelas `auditoria` e `download`, com as colunas de cópia dos
      identificadores
- [ ] 2.7 Escrever a migration da tabela `relatorio_role`
- [ ] 2.8 Escrever as migrations dos schemas transacionais dos cinco produtos
- [ ] 2.9 Escrever o seed de desenvolvimento das bases transacionais, com volume suficiente para
      exercitar paginação
- [ ] 2.10 Escrever teste de integração com Testcontainers que aplica todas as migrations em banco
      vazio
- [ ] 2.11 Escrever teste que afirma a recusa de `UPDATE` de status terminal pelo gatilho
- [ ] 2.12 Escrever teste que afirma a violação do índice único ao tentar duas execuções vigentes
      do mesmo par

## 3. Contratos: API e domínio comum

- [ ] 3.1 Modelar no `comum` os tipos de domínio — sigla, código do relatório, data de referência,
      status, origem — com validação de formato
- [ ] 3.2 Implementar no `comum` o contrato de erro com momento em ISO 8601, descrição e
      Correlation ID
- [ ] 3.3 Configurar o SpringDoc OpenAPI na API e publicar o contrato dos endpoints previstos
- [ ] 3.4 Gerar os tipos do frontend a partir do OpenAPI
- [ ] 3.5 Escrever cenários `.feature` de validação dos formatos de sigla e de código

## 4. Catálogo derivado do código

- [ ] 4.1 Escrever os cenários `.feature` de `catalogo-derivado`, todos falhando
- [ ] 4.2 Implementar no starter a declaração de produto e relatórios por um produto
- [ ] 4.3 Implementar a publicação do catálogo no schema de controle na inicialização, preservando
      os atributos já editados pela aplicação
- [ ] 4.4 Implementar a recusa de inicialização com código de relatório duplicado dentro do produto
- [ ] 4.5 Implementar a recusa de inicialização com tempo estimado ausente, zero ou negativo
- [ ] 4.6 Implementar a validação do teto da soma dos tempos estimados na inicialização
- [ ] 4.7 Implementar na API a edição do nome do produto, restrita ao ADMINISTRADOR
- [ ] 4.8 Implementar na API a edição de nome, descrição e tempo estimado do relatório
- [ ] 4.9 Implementar a recusa da edição de tempo estimado que estoure o teto do produto
- [ ] 4.10 Implementar a inativação de relatório e a inativação de produto condicionada à ausência
      de relatório ativo
- [ ] 4.11 Verificar que os cenários de `catalogo-derivado` passam

## 5. Starter do processador

- [ ] 5.1 Escrever os cenários `.feature` de apuração, contagem prévia e limites de tempo
- [ ] 5.2 Implementar no starter o `JdbcTemplate` padrão com `queryTimeout` obrigatório, sem
      caminho que permita a um produto criar o seu próprio sem ele
- [ ] 5.3 Implementar a contagem prévia de linhas e a recusa do dataset acima do teto, encerrando
      como `processado com erro` com motivo explícito
- [ ] 5.4 Implementar a leitura paginada por chunks do Spring Batch
- [ ] 5.5 Implementar a verificação do limite do relatório entre chunks, com aborto ao atingir o
      dobro do tempo estimado copiado
- [ ] 5.6 Garantir que o aborto de um relatório não interrompe os demais do mesmo produto
- [ ] 5.7 Implementar a renderização do `JasperPrint` e a gravação do `.jrprint`
- [ ] 5.8 Implementar a gravação do `.csv.gz` a partir do dataset da consulta principal, com
      separador `;`, sem passar pelo motor de relatório
- [ ] 5.9 Implementar o registro dos metadados de conclusão **depois** da gravação dos artefatos
- [ ] 5.10 Implementar a classificação de alerta por duração acima do tempo estimado copiado, com
      erro prevalecendo sobre alerta
- [ ] 5.11 Verificar que os cenários do starter passam

## 6. Orquestração no Airflow

- [ ] 6.1 Escrever os cenários de reserva do ciclo, encerramento anômalo e ausência de catchup
- [ ] 6.2 Criar a DAG diária às 03h00 em `America/Sao_Paulo` com `catchup=False` explícito
- [ ] 6.3 Implementar a task de reserva do ciclo, criando uma execução por relatório ativo com
      início nulo
- [ ] 6.4 Criar uma task estática por produto, espelhando os módulos
- [ ] 6.5 Configurar o pool de 2 para as tasks de produto
- [ ] 6.6 Configurar o `execution_timeout` de cada task como 2× a soma dos tempos estimados do
      produto, com folga
- [ ] 6.7 Implementar o callback de falha que encerra como `processado com erro` todas as execuções
      abertas do produto, inclusive as reservadas de início nulo
- [ ] 6.8 Implementar o parâmetro `forcar_reprocessamento` da DAG, sem qualquer parâmetro de data
      de referência
- [ ] 6.9 Verificar que nenhuma execução permanece em `em processamento` 30 minutos após o fim do
      ciclo, em teste que derruba o contêiner no meio da apuração

## 7. Fatia vertical de POUPANCA

- [ ] 7.1 Definir e documentar os modelos de dados dos dois relatórios de exemplo de `POUPANCA`
- [ ] 7.2 Escrever os dois JRXMLs com cabeçalho de coluna na banda `title` e ornamento descartável
      em `pageHeader`/`pageFooter`, usando imagens e fontes diferentes entre si
- [ ] 7.3 Implementar as consultas e a declaração do catálogo do módulo `POUPANCA`
- [ ] 7.4 Rodar o ciclo ponta a ponta: catálogo publicado → reserva → apuração → artefatos no
      repositório → metadados registrados
- [ ] 7.5 Exportar o par apurado em PDF pela API e confirmar que o `.jrprint` atravessa a fronteira
      entre módulos sem erro de desserialização, de fonte ou de renderer

## 8. Retentativa, unicidade e vigência

- [ ] 8.1 Escrever os cenários de retentativa, recusa por par concluído e reexecução de par em erro
- [ ] 8.2 Implementar a retentativa que relê apenas os relatórios que não concluíram, com teto de 2
      por relatório no ciclo
- [ ] 8.3 Implementar a criação de execução nova na retentativa, movendo o ponteiro de vigência e
      preservando a anterior como não-vigente
- [ ] 8.4 Implementar a cópia do tempo estimado para dentro da execução no momento do disparo
- [ ] 8.5 Implementar a recusa de nova execução de par em sucesso ou alerta, como evento de
      auditoria e sem criar execução
- [ ] 8.6 Implementar a recusa de nova execução de par em `em processamento`
- [ ] 8.7 Implementar a aceitação de nova execução de par em `processado com erro`
- [ ] 8.8 Verificar que a edição do tempo estimado não reclassifica execução passada

## 9. Artefato e retenção

- [ ] 9.1 Rodar o spike do evento de expiração por ILM do MinIO e registrar o resultado em
      `docs/riscos.md`
- [ ] 9.2 Escrever os cenários de caminho de artefato, expurgo e recusa por retenção
- [ ] 9.3 Implementar o caminho `data de referência → sigla → código` na gravação dos artefatos
- [ ] 9.4 Configurar a política de ciclo de vida do bucket com a janela de retenção por variável de
      ambiente, com padrão de 7 dias
- [ ] 9.5 Implementar o endpoint da API que recebe a marca de expurgo, autenticado por credencial
      de serviço
- [ ] 9.6 Implementar a derivação aritmética de *expirado* para quando a marca faltar
- [ ] 9.7 Implementar a recusa de exportação de artefato expurgado com mensagem explícita de
      indisponibilidade por retenção
- [ ] 9.8 Verificar que o nome do produto editado não altera o caminho de artefato algum
- [ ] 9.9 Verificar que metadados de execução e histórico de downloads sobrevivem ao expurgo

## 10. Exportação

- [ ] 10.1 Escrever os cenários de `exportacao`, incluindo o de cabeçalho único no XLSX
- [ ] 10.2 Implementar a exportação síncrona em PDF a partir do `.jrprint`
- [ ] 10.3 Implementar a exportação em DOCX preservando a paginação
- [ ] 10.4 Implementar a exportação em XLSX excluindo `pageHeader`/`pageFooter` por origem de
      elemento, sem paginação por planilha e sem espaço vazio entre linhas
- [ ] 10.5 Implementar a entrega do CSV a partir do `.csv.gz`, sem passar pelo motor de relatório
- [ ] 10.6 Implementar a recusa de exportação quando a execução vigente não estiver em sucesso ou
      alerta
- [ ] 10.7 Implementar o semáforo de 2 exportações simultâneas, com recusa imediata da excedente e
      indicação de repetir mais tarde
- [ ] 10.8 Escrever o teste de cabeçalho único no XLSX para **cada** relatório existente
- [ ] 10.9 Verificar que nenhuma exportação abre conexão com schema transacional de produto

## 11. Identidade e acesso

- [ ] 11.1 Escrever os cenários de `identidade-e-acesso`, incluindo os dois obrigatórios por risco
- [ ] 11.2 Preparar o realm do Keycloak com as três realm roles, o cliente dedicado de roles de
      relatório e o ADMINISTRADOR inicial por variável de ambiente
- [ ] 11.3 Customizar o tema da página de registro pública e expor seletivamente pelo Traefik o
      registro e o console de conta, mantendo o console administrativo fora
- [ ] 11.4 Configurar o Mailpit para verificação e reset de senha
- [ ] 11.5 Implementar a autenticação por JWT entre frontend e API
- [ ] 11.6 Implementar os endpoints do GERENTE para criar, remover e vincular roles de relatório,
      restritos ao cliente dedicado
- [ ] 11.7 Implementar a tabela de vínculo *Relatório → Role de relatório* e seus endpoints
- [ ] 11.8 Implementar a gestão de grupos e a inclusão e remoção de usuários
- [ ] 11.9 Implementar a gestão de usuários administrativos pelo ADMINISTRADOR e a remoção de
      RELATOR por ADMINISTRADOR e GERENTE
- [ ] 11.10 Implementar a resolução da cadeia de permissão pela união dos caminhos
- [ ] 11.11 Escrever o teste dedicado que afirma que o GERENTE não promove ninguém, nem por
      manipulação direta da requisição
- [ ] 11.12 Escrever o teste dedicado do acesso irrestrito do ADMINISTRADOR, que não passa pela
      cadeia
- [ ] 11.13 Verificar que o autocadastro cria apenas RELATOR pendente de vínculo, sem grupo padrão

## 12. Listagem e consulta

- [ ] 12.1 Escrever os cenários de `listagem-de-relatorios`
- [ ] 12.2 Implementar a listagem navegável por data → produto → relatório, com data em
      `dd/MM/yyyy`
- [ ] 12.3 Implementar a filtragem da listagem pela cadeia de permissão do usuário
- [ ] 12.4 Implementar a negação de acesso direto a relatório fora da cadeia
- [ ] 12.5 Implementar a listagem vazia com mensagem de aguardo para o RELATOR pendente de vínculo
- [ ] 12.6 Implementar a recusa de exportação para o perfil GERENTE
- [ ] 12.7 Verificar que itens inativados somem da listagem e continuam referenciáveis

## 13. Reprocessamento forçado

- [ ] 13.1 Escrever os cenários de `reprocessamento-forcado`
- [ ] 13.2 Implementar o endpoint de solicitação restrito ao ADMINISTRADOR, com motivo obrigatório
- [ ] 13.3 Implementar o registro de auditoria com solicitante, motivo, momento e Correlation ID
- [ ] 13.4 Implementar o acionamento da DAG pela API com `forcar_reprocessamento`
- [ ] 13.5 Implementar a invalidação da execução anterior e a sobrescrita dos artefatos
- [ ] 13.6 Verificar que perfis diferentes de ADMINISTRADOR são recusados e que nenhuma execução é
      criada

## 14. Histórico de downloads

- [ ] 14.1 Escrever os cenários de `historico-de-downloads`
- [ ] 14.2 Implementar o registro de download com cópia de código, nome do relatório, sigla, nome
      do produto, data de referência, formato, usuário e momento
- [ ] 14.3 Implementar a consulta do histórico restrita ao ADMINISTRADOR
- [ ] 14.4 Verificar que o histórico sobrevive ao expurgo do artefato e à inativação do relatório,
      exibindo os identificadores do momento do download

## 15. Diagnóstico e observabilidade

- [ ] 15.1 Configurar o envio de log, span, trace e métrica ao OTel Collector e a sua distribuição
- [ ] 15.2 Implementar a propagação do Correlation ID pelo `traceId` no MDC, com logs estruturados
- [ ] 15.3 Implementar o contrato de erro em todos os endpoints, documentado no OpenAPI
- [ ] 15.4 Implementar na interface a exibição do erro e a cópia em JSON estruturado
- [ ] 15.5 Instrumentar as métricas com as labels sigla, código do relatório e origem da execução
- [ ] 15.6 Instrumentar a métrica primária de taxa de apuração limpa, contando apenas execuções
      vigentes de origem `agendada`
- [ ] 15.7 Instrumentar as cinco métricas secundárias do PRD
- [ ] 15.8 Criar o painel do Grafana com a métrica primária e as secundárias
- [ ] 15.9 Desabilitar o SDK do OpenTelemetry nos testes
- [ ] 15.10 Verificar que o Correlation ID exibido ao usuário localiza a ocorrência no agregador de
      logs

## 16. Demais produtos

- [ ] 16.1 Definir os modelos de dados e escrever os dois JRXMLs de `CLIENTE`, com o teste de
      cabeçalho único
- [ ] 16.2 Definir os modelos de dados e escrever os dois JRXMLs de `CONTACORRENTE`, com o teste de
      cabeçalho único
- [ ] 16.3 Definir os modelos de dados e escrever os dois JRXMLs de `CONSORCIO`, com o teste de
      cabeçalho único
- [ ] 16.4 Definir os modelos de dados e escrever os dois JRXMLs de `EMPRESTIMO`, com o teste de
      cabeçalho único
- [ ] 16.5 Adicionar as tasks estáticas dos quatro produtos à DAG
- [ ] 16.6 Verificar um ciclo completo com os cinco produtos em ondas de 2, concluindo dentro da
      janela de 60 minutos

## 17. Frontend

- [ ] 17.1 Escrever `docs/design/fluxos.md` com os fluxos principais e seus estados de erro
- [ ] 17.2 Escrever `docs/design/design-system.md` com tokens, regras, padrões de estado e
      acessibilidade
- [ ] 17.3 Implementar os componentes canônicos de referência — botão, input, formulário, tabela,
      modal e os estados de carregamento, vazio, erro e sucesso
- [ ] 17.4 Implementar a tela de entrada e a de autocadastro, integradas ao provedor de identidade
- [ ] 17.5 Implementar a listagem navegável por data → produto → relatório e o download nos quatro
      formatos
- [ ] 17.6 Implementar as telas de administração do catálogo e de reprocessamento forçado
- [ ] 17.7 Implementar as telas do GERENTE para roles de relatório e grupos
- [ ] 17.8 Implementar a tela de histórico de downloads
- [ ] 17.9 Implementar a tela de erro com os três campos e a cópia em JSON

## 18. Verificação final

- [ ] 18.1 Escrever os testes E2E de backend com Newman e `psql` dos fluxos críticos
- [ ] 18.2 Escrever os testes E2E de navegador com Playwright dos fluxos críticos
- [ ] 18.3 Configurar o JaCoCo e publicar a cobertura no CI
- [ ] 18.4 Rodar a calibração com `k6` — tamanho real do `.jrprint` desserializado, latência de
      exportação por formato e teto real de simultaneidade
- [ ] 18.5 Substituir os valores `PROVISÓRIO` do PRD §10 pelos números medidos, ou registrar em
      `docs/riscos.md` por que permanecem provisórios
- [ ] 18.6 Atualizar `ARCHITECTURE.md` e os `CLAUDE.md` de módulo com o que o código revelou
- [ ] 18.7 Escrever o `CHANGELOG.md` e o runbook de operação com rollback e restauração
- [ ] 18.8 Verificar, em clone limpo, que o ambiente sobe, o ciclo roda e uma exportação é entregue
