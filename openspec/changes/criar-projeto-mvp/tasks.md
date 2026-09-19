> **Como executar.** Cada `##` é uma fase mergeável por si só, com CI verde ao fim. Regra do guia que vale em
> todas: **teste antes da implementação**, e toda rota nova sai com teste de autorização na mesma entrega.

## 1. Fase 0 — Documentos de produto e engenharia que faltam

- [ ] 1.1 Escrever `docs/glossario.md` com a linguagem ubíqua: Janela de leitura, Data de referência, Execução vigente, Origem da execução, Catálogo, Inativação, Artefato, Cadeia de permissão — definição única por termo
- [ ] 1.2 Escrever `docs/user-stories.md` derivando de RF-01 a RF-55, cada história com Given/When/Then verificável por teste
- [ ] 1.3 Escrever `docs/riscos.md` com os riscos técnicos abertos e como cada um será resolvido (heap do `.jrprint`, permissões grossas do Keycloak, evento de expurgo do MinIO, três escritores no schema de controle)
- [ ] 1.4 Escrever `docs/arquitetura/c4-contexto.md` com os diagramas C4 nível 1 e 2 em Mermaid
- [ ] 1.5 Escrever os ADRs mínimos em `docs/adr/`: linguagem e framework, banco e migrations, autenticação e autorização, ambiente, monolito modular vs. serviços, estratégia de testes
- [ ] 1.6 Escrever `docs/especificacao.md` do MVP, consumindo as `RA-NN` e fixando as costuras de teste
- [ ] 1.7 Escrever `docs/design/fluxos.md` com os fluxos de entrar, listar, exportar, baixar e administrar acesso, incluindo estados de erro
- [ ] 1.8 Escrever `docs/design/decisoes-ux.md` com o que foi descartado e por quê
- [ ] 1.9 Escrever `docs/design/design-system.md` com tokens, regras de uso, padrões de estado e acessibilidade obrigatória
- [ ] 1.10 Conferir que todo caminho referenciado por documento existe no repositório

## 2. Fase 1 — Fundações do repositório

- [ ] 2.1 Criar o pom raiz com `dependencyManagement` único e `maven-enforcer-plugin` reprovando versão divergente (D-I, RA-01)
- [ ] 2.2 Criar os módulos vazios compilando: `biblioteca-comum`, `processador-starter`, os 5 processadores e `api-rest` (D-A)
- [ ] 2.3 Criar o workspace Angular em `frontend/` e o diretório `orquestrador/` com a DAG esqueleto
- [ ] 2.4 Criar a estrutura de camadas com **um exemplo por camada** em `biblioteca-comum` e em `api-rest` (D-B)
- [ ] 2.5 Escrever `infra/docker-compose.yml` com PostgreSQL, Keycloak, MinIO, Airflow, Traefik, Mailpit, OTel Collector, Graylog, Prometheus, Grafana e Jaeger, com limites de memória por serviço e perfil separado para a pilha de observabilidade (RA-51, RA-50)
- [ ] 2.6 Fixar `TZ=America/Sao_Paulo` em todos os contêineres e `user.timezone` nas JVMs (RA-52)
- [ ] 2.7 Escrever `.env.example` com todas as variáveis e nenhum segredo real, incluindo a senha do ADMINISTRADOR inicial e a janela de retenção
- [ ] 2.8 Escrever os scripts padronizados: `setup`, `dev`, `test`, `lint`, `build`, `migrate`
- [ ] 2.9 Configurar `.editorconfig`, formatter e linter do Java e do TypeScript, com `strict: true` no `tsconfig.json`
- [ ] 2.10 Configurar `.github/workflows/ci.yml` bloqueante: lint, tipos, testes e build (RA-53)
- [ ] 2.11 Configurar pre-commit hook e scanner de segredos no CI
- [ ] 2.12 Escrever `README.md` com a subida em três comandos e `ARCHITECTURE.md` esquelético com os invariantes escritos como proibições
- [ ] 2.13 Escrever teste de arquitetura que reprova `dominio` importando `infraestrutura` e qualquer datasource transacional alcançável a partir da `api-rest` (RA-10, RA-29)
- [ ] 2.14 Verificar o checkpoint de E1: clone limpo sobe com um comando e o CI fica verde

## 3. Fase 2 — Contratos: schema, API e cenários

- [ ] 3.1 Escrever as migrations Flyway do schema de controle: `produto`, `relatorio`, `execucao`, `artefato`, `download`, `evento_auditoria`, `relatorio_role` (D-C)
- [ ] 3.2 Criar o índice parcial único de vigência em `execucao (data_referencia, codigo_relatorio) WHERE vigente` e escrever teste que prova a impossibilidade de duas vigentes (RN-16)
- [ ] 3.3 Criar a trigger que recusa alterar status, início, fim e tempo estimado de execução terminal, e teste que prova a recusa (RN-15, RA-67)
- [ ] 3.4 Criar os `CHECK` do regex da sigla, do código e do tempo estimado > 0 (RN-01, RN-02, RN-04)
- [ ] 3.5 Criar os usuários de banco por escritor — Coleta, orquestrador e API — com `GRANT` mínimo (D-F, RA-23)
- [ ] 3.6 Criar os schemas transacionais de exemplo dos 5 produtos e o seed de desenvolvimento
- [ ] 3.7 Escrever o `openapi.yaml` com o contrato de erro de RA-41 e gerar os tipos consumidos pelo frontend
- [ ] 3.8 Escrever os `.feature` em Gherkin das regras de negócio, em `src/test/resources/feature` por módulo (RA-44, RA-45)
- [ ] 3.9 Configurar JUnit 5, Cucumber, Testcontainers, Flyway nos testes e JaCoCo, com o SDK do OpenTelemetry desabilitado (RA-39, RA-47, RA-49)

## 4. Fase 3 — Coleta: starter, primeiro produto e DAG

- [ ] 4.1 Implementar no `processador-starter` a publicação do catálogo na inicialização, recusando iniciar com código duplicado no produto (RA-58, RF-44)
- [ ] 4.2 Implementar a contagem prévia de linhas e a recusa por volume acima do teto, encerrando em `processado com erro` com motivo explícito (RA-64, RN-52)
- [ ] 4.3 Implementar o `ItemReader` paginado com `queryTimeout` declarado em todo statement de leitura (RA-57)
- [ ] 4.4 Implementar o `CompositeItemWriter` que alimenta o dataset do preenchimento e o `.csv.gz` numa única leitura (D-D, RA-17)
- [ ] 4.5 Implementar a renderização e a gravação do `.jrprint` e do `.csv.gz` no MinIO, no caminho data → sigla → código (RA-16, RA-19)
- [ ] 4.6 Garantir a ordem: artefatos gravados antes do registro de conclusão (RA-11)
- [ ] 4.7 Implementar a classificação de status ao encerrar, com o erro prevalecendo sobre o alerta (RN-11, RN-12)
- [ ] 4.8 Implementar o limite do relatório entre chunks, abortando só aquele relatório (RN-13, RF-05)
- [ ] 4.9 Implementar o `processador-poupanca` ponta a ponta com os dois relatórios de exemplo, sendo `POUPANCA-0001` o do barcode (D-H, RA-08)
- [ ] 4.10 Escrever a DAG com `catchup=False` explícito, agendamento às 03h00 e uma task estática por produto em pool de 2 (RA-55, RA-56, RA-65)
- [ ] 4.11 Implementar a task de reserva do ciclo, gravando uma execução por relatório ativo com início nulo (RA-54, RN-45)
- [ ] 4.12 Configurar `execution_timeout` por task como 2× a soma dos estimados do produto, com folga (RA-57)
- [ ] 4.13 Implementar o callback de falha que encerra como erro toda execução aberta do produto, inclusive as reservadas que nunca iniciaram (RA-14, RA-68)
- [ ] 4.14 Configurar as retentativas da task com a apuração idempotente que relê só o que não concluiu, limitadas a RNF-17 (RN-44, D-E)
- [ ] 4.15 Escrever o teste de aceitação do ciclo completo do produto em Testcontainers, cobrindo reserva, sucesso, alerta, erro e retentativa

## 5. Fase 4 — Demais produtos e relatórios de exemplo

- [ ] 5.1 Implementar `processador-cliente` com os dois relatórios de exemplo e seu schema transacional
- [ ] 5.2 Implementar `processador-conta-corrente` com os dois relatórios de exemplo e seu schema transacional
- [ ] 5.3 Implementar `processador-consorcio` com os dois relatórios de exemplo e seu schema transacional
- [ ] 5.4 Implementar `processador-emprestimo` com os dois relatórios de exemplo e seu schema transacional
- [ ] 5.5 Garantir imagens e fontes diferentes entre os dois relatórios de cada módulo, com as *font extensions* no classpath comum (RA-08)
- [ ] 5.6 Aplicar a convenção de autoria de RA-59 nos dez JRXML: cabeçalho de coluna na banda `title`
- [ ] 5.7 Adicionar as tasks dos quatro produtos na DAG e conferir a execução em ondas de 2 dentro da janela de RNF-04
- [ ] 5.8 Conferir que a soma dos tempos estimados de cada produto respeita o teto de RNF-19 (RN-48)

## 6. Fase 5 — Identidade e autorização

- [ ] 6.1 Escrever o realm do Keycloak como JSON versionado: perfis como realm roles, cliente `relatorios` para client roles, SMTP do Mailpit (D-J, RA-61)
- [ ] 6.2 Criar o ADMINISTRADOR inicial na subida, com senha vinda de variável de ambiente (RA-32)
- [ ] 6.3 Customizar o tema da página de registro e expor seletivamente o Account Console e o registro no Traefik, sem o console administrativo (RA-33, RA-34)
- [ ] 6.4 Implementar o autocadastro criando exclusivamente RELATOR sem grupo, ignorando perfil informado (RN-27, RF-29, RF-30)
- [ ] 6.5 Implementar a validação de JWT na API e o mapeamento de perfil (RA-30)
- [ ] 6.6 Implementar a resolução da cadeia Relatório → Role de relatório → Grupo → Usuário, com acesso pela união dos caminhos (RN-22, RF-33)
- [ ] 6.7 Implementar os endpoints do GERENTE operando exclusivamente sobre client roles do cliente `relatorios`, e o vínculo relatório ↔ role no schema de controle (RA-61)
- [ ] 6.8 Implementar a remoção de usuário conforme a matriz de perfis (RF-35)
- [ ] 6.9 Escrever o teste dedicado de RF-34: o GERENTE não promove ninguém, nem manipulando diretamente a requisição (RA-68)
- [ ] 6.10 Escrever o teste dedicado de RN-24: o ADMINISTRADOR sem grupo algum acessa todos os relatórios (RA-68)
- [ ] 6.11 Escrever o teste de revogação imediata ao remover vínculo, role ou grupo (RF-36, RF-43)
- [ ] 6.12 Verificar o reset de senha por e-mail chegando ao Mailpit (RN-29, RA-35)

## 7. Fase 6 — API: listagem, exportação, downloads e expurgo

- [ ] 7.1 Implementar o contrato de erro com momento em ISO 8601, descrição e Correlation ID, documentado no OpenAPI (RA-41, RF-38)
- [ ] 7.2 Implementar a listagem navegável data → produto → relatório com data em `dd/MM/yyyy`, filtrada pela cadeia de permissão e negando acesso direto fora dela (RF-13 a RF-15)
- [ ] 7.3 Implementar a listagem vazia com mensagem de aguardo para o RELATOR sem grupo (RF-16, RF-55)
- [ ] 7.4 Implementar a exportação síncrona em PDF e DOCX a partir do `.jrprint` (RN-30, RN-32)
- [ ] 7.5 Implementar a exportação XLSX contínua, excluindo as bandas por origem de elemento, com `onePagePerSheet(false)` e `removeEmptySpaceBetweenRows(true)` (RA-59)
- [ ] 7.6 Escrever o teste de cabeçalho único no XLSX **para cada um dos dez relatórios** (RF-21, RA-68)
- [ ] 7.7 Implementar a exportação CSV servida do `.csv.gz`, sem passar pelo motor de relatório (RA-17, RF-22)
- [ ] 7.8 Implementar a recusa de exportação por status vigente diferente de sucesso ou alerta (RN-42, RF-20)
- [ ] 7.9 Implementar o semáforo de exportações com `tryAcquire()` sem espera e recusa imediata (D-G, RN-53, RF-48)
- [ ] 7.10 Implementar o registro de download com cópia dos identificadores e a consulta restrita ao ADMINISTRADOR (RA-66, RF-23, RF-51)
- [ ] 7.11 Configurar a política de ciclo de vida do MinIO com a janela de retenção por variável de ambiente, padrão 7 dias (RA-20, RNF-12)
- [ ] 7.12 Configurar a notificação de expurgo com `--event delete` e conferir o disparo na tag fixada pelo Compose (RA-21)
- [ ] 7.13 Implementar o endpoint autenticado por credencial de serviço que recebe a marca de expurgo, e a derivação do estado expirado quando a marca falta (RA-63)
- [ ] 7.14 Implementar a recusa explícita por retenção, nunca com erro genérico (RN-39, RF-24)
- [ ] 7.15 Implementar o reprocessamento forçado: exclusivo do ADMINISTRADOR, motivo obrigatório, invalidação da vigente, sobrescrita dos artefatos e disparo da DAG pela API (RA-12, RA-13, RF-10 a RF-12)
- [ ] 7.16 Implementar a recusa de nova execução como evento de auditoria, sem criar Execução (RN-18, RF-08)
- [ ] 7.17 Implementar os endpoints de edição do catálogo — nome do produto, nome, descrição e tempo estimado do relatório — recusando a edição que estoura o teto do produto (RF-41, RF-47)
- [ ] 7.18 Implementar a inativação de produto e relatório, recusando produto com relatório ativo (RF-50, RF-54)
- [ ] 7.19 Expor `/actuator/health/liveness` e `/actuator/health/readiness` (RA-43)

## 8. Fase 7 — Frontend

- [ ] 8.1 Implementar os componentes canônicos do design system — botão, input, formulário, tabela, modal — e a regra de lint que proíbe valor fora dos tokens (guia P2)
- [ ] 8.2 Implementar os estados canônicos: carregamento, vazio, erro, sucesso e desabilitado
- [ ] 8.3 Implementar a integração com o Keycloak e as telas de entrar e sair
- [ ] 8.4 Implementar a navegação de listagem por data → produto → relatório
- [ ] 8.5 Implementar a tela de exportação e download nos quatro formatos
- [ ] 8.6 Implementar o componente de erro com momento, descrição, Correlation ID e cópia em JSON (RF-39, RA-42)
- [ ] 8.7 Implementar as telas do GERENTE: roles de relatório, grupos e vínculos
- [ ] 8.8 Implementar as telas do ADMINISTRADOR: catálogo, usuários administrativos, histórico de downloads e reprocessamento forçado
- [ ] 8.9 Verificar contraste AA, foco visível e rótulo em todo input
- [ ] 8.10 Escrever os `.feature` e os testes E2E de navegador em `frontend/e2e/features/` com Playwright (RA-46, RA-48)

## 9. Fase 8 — Observabilidade, E2E e calibração

- [ ] 9.1 Configurar o envio de log, span, trace e métrica ao OTel Collector e a distribuição para Graylog, Prometheus/Grafana e Jaeger (RA-36)
- [ ] 9.2 Configurar os logs estruturados com `traceId` e `spanId` no MDC, com o Correlation ID exibido localizando a ocorrência (RA-37, RA-38, RF-40)
- [ ] 9.3 Instrumentar as métricas do PRD §6 com as labels sigla do produto, código do relatório e origem da execução (RA-40)
- [ ] 9.4 Criar o painel com a taxa de apuração limpa em janela de 30 dias e as cinco métricas secundárias
- [ ] 9.5 Escrever os testes E2E de backend com Newman CLI e psql (RA-48)
- [ ] 9.6 Escrever o script k6 e rodar o spike de calibração: tamanho do `.jrprint` desserializado, latência por formato e teto real de simultaneidade
- [ ] 9.7 Substituir os números `PROVISÓRIO` do PRD §10 pelos medidos e registrar a resposta de Q10
- [ ] 9.8 Escrever o runbook de operação e o `CHANGELOG.md`
- [ ] 9.9 Atualizar `ARCHITECTURE.md` e `CLAUDE.md` com os padrões que se estabeleceram durante a implementação
