# Spec: Plataforma de Coleta e Geração de Relatórios — v1

Status: ready-for-agent
Origem: sessão de grilling sobre `docs/descricao-inicial.txt` (2026-07-25)
Decisões vinculantes: `docs/adr/0001` a `docs/adr/0016` · Glossário: `CONTEXT.md`

Onde este spec divergir da descrição inicial, valem os ADRs. A linha 32 da descrição está revogada (ADR-0007).

## Problem Statement

Quem precisa de um relatório de um Produto hoje depende de alguém com acesso ao banco do sistema de origem. Cada pedido é uma extração manual: alguém escreve uma consulta, exporta como der, manda por e-mail. Isso significa que o pedido demora, o formato varia a cada vez, o mesmo relatório sai diferente dependendo de quem extraiu, e a consulta pesada roda no horário em que der — às vezes concorrendo com o sistema transacional.

Pior: ninguém sabe quem acessou o quê. Não há registro de quem pediu, quem extraiu, quais dados saíram, nem para onde foram. Para dados pessoais e financeiros de POUPANCA, CLIENTE, CONTACORRENTE, EMPRESTIMO e CONSORCIO, isso é uma lacuna de controle, não um inconveniente.

E não existe conceito de permissão por relatório: ter acesso ao banco é ter acesso a tudo, ou a nada.

## Solution

Um sistema em duas metades.

A **Coleta** roda sozinha, agendada por Janela de Agendamento, lendo cada Produto no seu próprio sistema de origem em horário controlado e guardando os dados por 7 dias. Ninguém escreve consulta manual, e a carga no sistema de origem acontece quando a operação escolheu.

A **Geração** é sob demanda: o Relator entra, vê quais Relatórios ele pode gerar e para quais datas, escolhe o Formato de Exportação (PDF, CSV, XLSX ou DOCX) e baixa o arquivo na hora. O que ele vê é exatamente o que suas Roles de Relatório permitem — nem mais, nem menos. Todo download fica registrado: quem, o quê, de qual data, em qual formato, quantas linhas, quanto tempo levou.

O Gerente administra as Roles de Relatório, vinculando Relatórios e Relatores a elas. O Administrador cadastra Produtos, Relatórios e os usuários privilegiados. Cada tipo de usuário faz exatamente o que lhe cabe, e nada além.

## User Stories

### Relator

1. Como Relator, quero me cadastrar sozinho pela interface web, para não depender de abrir chamado para ter conta.
2. Como Relator, quero receber um e-mail de verificação ao me cadastrar, para confirmar que a conta é minha.
3. Como Relator recém-cadastrado, quero ver uma mensagem clara de que aguardo liberação de acesso, para saber que o cadastro funcionou e o que falta.
4. Como Relator, quero fazer sign in com usuário e senha, para acessar o sistema.
5. Como Relator, quero fazer sign out, para encerrar minha sessão em um computador compartilhado.
6. Como Relator, quero trocar minha senha, para manter minha conta sob meu controle.
7. Como Relator, quero recuperar minha senha esquecida por e-mail, para não perder acesso ao sistema.
8. Como Relator, quero ver a lista dos Relatórios que posso gerar, para saber a que tenho acesso sem tentativa e erro.
9. Como Relator, quero ver os Relatórios agrupados por Produto, para encontrar o que procuro quando tenho acesso a muitos.
10. Como Relator, quero ver quais Datas de Referência estão disponíveis para um Relatório, para escolher a data certa em vez de adivinhar.
11. Como Relator, quero navegar as datas disponíveis no formato dd/MM/yyyy, para reconhecer a data no formato que uso no dia a dia.
12. Como Relator, quero escolher o Formato de Exportação na hora de gerar, para receber o arquivo no formato que vou usar.
13. Como Relator, quero baixar o arquivo gerado imediatamente após a solicitação, para resolver meu pedido em uma única interação.
14. Como Relator, quero ver uma indicação de que a geração está em andamento, para não achar que a aplicação travou durante uma espera longa.
15. Como Relator, quero receber uma mensagem clara quando o Relatório é grande demais para o formato escolhido, informando o limite e as linhas encontradas, para escolher outro formato em vez de esperar por um erro.
16. Como Relator, quero receber essa recusa imediatamente, e não depois de minutos de espera, para não perder tempo.
17. Como Relator, quero ver apenas Datas de Referência que realmente têm dados coletados, para não pedir geração do que não existe.
18. Como Relator, quero receber uma mensagem explícita quando tento gerar um Relatório a que não tenho acesso, para saber que preciso solicitar permissão ao Gerente.
19. Como Relator, quero que o arquivo baixado tenha um nome previsível contendo Código do Relatório, Data de Referência e formato, para organizar meus downloads.
20. Como Relator, quero ver os dados sempre da última Execução de Coleta bem-sucedida, para nunca receber um arquivo com dados parciais de uma coleta em andamento.

### Gerente

21. Como Gerente, quero criar uma Role de Relatório, para agrupar permissões em vez de conceder acesso relatório por relatório.
22. Como Gerente, quero dar um nome e uma descrição à Role de Relatório, para que outra pessoa entenda para que ela serve.
23. Como Gerente, quero vincular um ou mais Relatórios a uma Role de Relatório, para definir o que aquela role dá acesso.
24. Como Gerente, quero desvincular um Relatório de uma Role de Relatório, para revogar acesso sem destruir a role.
25. Como Gerente, quero vincular uma Role de Relatório a um usuário Relator, para liberar o acesso dele.
26. Como Gerente, quero desvincular uma Role de Relatório de um Relator, para revogar o acesso quando ele muda de função.
27. Como Gerente, quero listar os Relatores cadastrados, incluindo os que ainda aguardam liberação, para saber quem está esperando acesso.
28. Como Gerente, quero ver quais Roles de Relatório um Relator possui, para conferir o acesso antes de conceder mais.
29. Como Gerente, quero ver quais Relatores possuem uma determinada Role de Relatório, para revisar quem tem acesso a um conjunto de Relatórios.
30. Como Gerente, quero excluir um usuário Relator, para encerrar o acesso de quem saiu da organização.
31. Como Gerente, quero ser impedido de criar ou alterar usuários GERENTE e ADMINISTRADOR, para que a separação de responsabilidades seja garantida pelo sistema e não pela disciplina.
32. Como Gerente, quero que a revogação de uma Role de Relatório valha imediatamente, para que um acesso removido não continue funcionando.

### Administrador

33. Como Administrador, quero cadastrar um Produto com seu nome, para que Relatórios possam ser vinculados a ele.
34. Como Administrador, quero remover um Produto, para retirar do sistema uma linha de negócio descontinuada.
35. Como Administrador, quero ser impedido de remover um Produto que ainda tem Relatórios, para não deixar Relatórios órfãos.
36. Como Administrador, quero cadastrar um Relatório informando Código do Relatório, nome, descrição, Tempo Estimado de Execução e Janela de Agendamento, para que ele passe a ser coletado.
37. Como Administrador, quero que o Código do Relatório seja validado no formato nome-9999, para não cadastrar códigos inconsistentes.
38. Como Administrador, quero receber uma recusa quando o nome do Código não corresponde a um Produto cadastrado, para que a hierarquia de armazenamento nunca contenha Produto inexistente.
39. Como Administrador, quero escolher a Janela de Agendamento de uma lista fechada, para não errar uma expressão de agendamento.
40. Como Administrador, quero que o Código do Relatório seja imutável após a criação, para que registros de auditoria antigos continuem verdadeiros.
41. Como Administrador, quero ser impedido de reutilizar um Código de um Relatório excluído, para que a trilha de auditoria nunca aponte para o Relatório errado.
42. Como Administrador, quero alterar nome, descrição, Tempo Estimado de Execução e Janela de Agendamento de um Relatório, para ajustar o cadastro sem recriá-lo.
43. Como Administrador, quero remover um Relatório, para interromper sua coleta.
44. Como Administrador, quero cadastrar outros usuários ADMINISTRADOR e GERENTE, para distribuir a administração.
45. Como Administrador, quero remover usuários ADMINISTRADOR e GERENTE, para revogar acesso privilegiado.
46. Como Administrador, quero que apenas eu (e não o Gerente) possa conceder o tipo GERENTE, para que a escalada de privilégio dependa de mim.
47. Como Administrador, quero trocar minha senha, para rotacionar a credencial inicial recebida na implantação.
48. Como Administrador, quero ver a documentação da API em Swagger, para entender o contrato ao integrar outro sistema.

### Operação

49. Como Operação, quero que cada Relatório cadastrado seja coletado automaticamente na sua Janela de Agendamento, para não depender de disparo manual.
50. Como Operação, quero ver o Status de Processamento de cada Execução de Coleta, para saber o que rodou e o que falhou.
51. Como Operação, quero ver início, fim e duração de cada Execução de Coleta, para identificar degradação antes de virar incidente.
52. Como Operação, quero que uma Execução de Coleta que ultrapasse o Tempo Estimado de Execução seja marcada como processado com alerta, para investigar o Produto que está ficando lento.
53. Como Operação, quero ver a contagem de linhas coletadas por Execução de Coleta, para notar quedas ou explosões de volume.
54. Como Operação, quero repetir uma Execução de Coleta que falhou, para recuperar o dia sem intervenção manual no banco.
55. Como Operação, quero que uma Execução de Coleta repetida não duplique nem corrompa os dados já publicados, para repetir sem medo.
56. Como Operação, quero que uma Execução de Coleta que falhe no meio não afete o que os Relatores estão baixando, para que a falha seja invisível para o usuário.
57. Como Operação, quero que os dados coletados sejam apagados automaticamente após 7 dias, para não administrar crescimento infinito de disco.
58. Como Operação, quero um dashboard com execuções, durações, alertas e falhas, para acompanhar a saúde do pipeline em um lugar.
59. Como Operação, quero métricas da API (latência de geração, erros, recusas por limite), para saber como o sistema se comporta sob uso real.
60. Como Operação, quero que o agendamento continue funcionando quando o PostgreSQL fica momentaneamente indisponível, para que uma instabilidade curta não pare as coletas do dia.
61. Como Operação, quero cadastrar um novo Relatório de um Produto existente sem deploy, para atender pedidos de negócio sem release.
62. Como Operação, quero acessar a interface do Airflow apenas pela rede interna, para que o painel que dispara containers não fique exposto.
63. Como Operação, quero que a configuração do Keycloak seja aplicada por script versionado a cada deploy, para que os ambientes não divirjam.
64. Como Operação, quero subir todo o ambiente com um único comando de Compose, para reproduzir o sistema em uma máquina nova.

### Auditoria

65. Como Auditor, quero consultar quem gerou e baixou cada Relatório, para responder pedidos de auditoria de acesso.
66. Como Auditor, quero ver a Data de Referência, o Formato de Exportação e a contagem de linhas de cada download, para saber exatamente que dado saiu.
67. Como Auditor, quero que os registros de auditoria sobrevivam muito além dos 7 dias dos dados, para investigar acessos antigos.
68. Como Auditor, quero ver o desfecho de cada tentativa de geração, inclusive as recusadas por falta de permissão, para detectar tentativa de acesso indevido.

## Implementation Decisions

### Módulos

Agregador Maven único, versão compartilhada (ADR-0001). Reator: `common` → `processor-starter` → `processor-<produto>` (POUPANCA, CLIENTE, CONTACORRENTE, EMPRESTIMO, CONSORCIO) → `api`. Fora do reator: `frontend/` (Angular), `airflow/` (DAGs e módulo de geração), `deploy/` (Compose, realm do Keycloak, script `kcadm`, configuração do OTel Collector com os pipelines de métricas e traces).

`common` carrega os tipos de domínio compartilhados — `CodigoRelatorio` (com a validação do ADR-0015 encapsulada no próprio tipo, não espalhada em anotações de controller), `DataReferencia`, `StatusProcessamento`, `JanelaAgendamento`, `FormatoExportacao`. Não é depósito de utilitários.

### Interface do processador (ADR-0011)

O starter é profundo: possui o ciclo de vida da Execução de Coleta, a escrita em lote no MongoDB, a troca de ponteiro, o registro de metadados e Status de Processamento incluindo a regra do Tempo Estimado de Execução, a exportação OTLP e as políticas de chunk/retry/skip.

Um módulo de Produto contribui exatamente três coisas: o `DataSource` do seu sistema de origem (somente leitura), a consulta que produz as linhas de um Relatório, e o mapeamento de linha para documento. Nada mais. Um processador não tem acesso à mecânica de ponteiro — ele não pode errá-la.

O starter publica um artefato `test-fixtures` com os passos Cucumber reutilizáveis do seam 2.

### Esquema PostgreSQL

| Tabela | Conteúdo |
|---|---|
| `produto` | nome (natural key), descrição |
| `relatorio` | código (natural key), produto, nome, descrição, tempo estimado de execução, janela de agendamento, ativo |
| `role_relatorio` | nome da role (igual à role do Keycloak), descrição, created_by, created_at |
| `role_relatorio_relatorio` | vínculo N:N role ↔ relatório, com created_by, updated_by, created_at |
| `execucao_coleta` | runId, código do relatório, Data de Referência, início, fim, status, contagem de linhas |
| `publicacao_relatorio` | (Data de Referência, produto, código) → runId corrente. Único por chave; é o ponteiro do ADR-0006 |
| `auditoria_geracao` | usuário, código, Data de Referência, formato, contagem de linhas, início, fim, desfecho |
| tabelas do Spring Batch | JobRepository JDBC (ADR-0003) |

Colunas `created_by`/`updated_by`/`created_at` nas tabelas de vínculo são a mitigação parcial da auditoria de permissões que ficou fora de escopo.

### Esquema MongoDB

Uma coleção de linhas de Relatório. Campos de controle fixos: Data de Referência, produto, código do relatório, runId, sequência, timestamp de criação. Os dados do Relatório vivem em um subdocumento sem esquema fixo — é a razão da escolha do MongoDB (ADR-0002).

Índices: composto em (Data de Referência, produto, código, sequência) para leitura ordenada e determinística e para a contagem prévia; índice TTL de 7 dias sobre o timestamp de criação (ADR-0008).

### Contratos da API

Geração é síncrona e devolve o arquivo no próprio response (ADR-0004). Antes de gerar, a API faz a contagem prévia pelo índice composto e recusa com 4xx explícito o que excede o limite do formato — CSV 500.000, XLSX 100.000, PDF 25.000, DOCX 25.000, constantes versionadas no código.

Superfícies necessárias: catálogo de Relatórios disponíveis ao usuário autenticado (filtrado pelas suas Roles de Relatório); Datas de Referência disponíveis por Relatório; geração/download; CRUD de Produto e Relatório (ADMINISTRADOR); CRUD de Role de Relatório e seus vínculos com Relatórios e Relatores (GERENTE); consulta de Execuções de Coleta (Operação); consulta de auditoria de downloads. Documentação por Swagger/OpenAPI, que é a fonte única do contrato — o cliente Angular é gerado dela.

### Autorização (ADR-0005)

A Role de Relatório é role do Keycloak e chega no JWT; o mapeamento role → Relatórios é resolvido no PostgreSQL a cada requisição (cacheável). O tipo de usuário (ADMINISTRADOR/GERENTE/RELATOR) também é role do realm. A regra "GERENTE não cria GERENTE" é imposta no servidor, não na UI. A enumeração de Relatores nas telas do Gerente usa a Admin API do Keycloak — não há espelho de usuários.

### Keycloak (ADR-0014)

Realm versionado em JSON para o primeiro boot (clients: frontend público com Authorization Code + PKCE, `api` como bearer-only; realm roles; self-registration; verificação de e-mail; reCAPTCHA; força bruta; política de senha; Account Console) e script `kcadm.sh` idempotente para as mudanças posteriores, porque `--import-realm` ignora realm existente. ADMINISTRADOR inicial com senha por variável de ambiente, sem rotação forçada (risco aceito). Troca de senha de qualquer usuário via Account Console.

### Airflow (ADR-0007)

DAGs geradas dinamicamente do Cadastro, uma por (Produto × Janela de Agendamento), cada uma lançando o processador com `DockerOperator`. Obrigatório: cache local da última lista válida de Relatórios com fallback em falha do PostgreSQL, `min_file_process_interval` em ~300s e timeout curto de conexão. Interface não publicada na internet (ADR-0009).

### Observabilidade (decidido na sessão)

Processadores exportam métricas via Micrometer OTLP para um OpenTelemetry Collector sempre ativo, que alimenta Prometheus/Grafana — os containers de Coleta são efêmeros e não podem ser raspados. A API expõe métricas normalmente.

O mesmo argumento da efemeridade vale para logs e traces (ADR-0017): log JSON estruturado com `traceId`/`spanId` no MDC via Micrometer Tracing, e mais dois pipelines no Collector — spans para o Jaeger (Badger, TTL de 7 dias) e logs para o Loki (monolítico, filesystem, retenção de 7 dias). Amostragem integral. Jaeger, Grafana e Prometheus escutam só na rede interna, ao lado do Airflow; Loki não tem UI própria e é lido pelo Grafana, que por isso entra na mesma fronteira. `traceparent` W3C propagado do Angular para a API e do Airflow para dentro do container do processador; o `runId` vai como atributo de span, amarrando o correlator de negócio ao técnico. Atributos de span e campos de log carregam apenas identificadores de domínio — nunca valor de linha de Relatório.

### Frontend

Angular com cliente gerado do OpenAPI, autenticação Authorization Code + PKCE contra o Keycloak. Download por `fetch()` + blob com header `Authorization` (ADR-0004) — os limites de linhas existem em função desse teto de memória. Seletor de data limitado às Datas de Referência disponíveis, no máximo sete (ADR-0008).

### Idioma

Identificadores de domínio em pt-BR, andaime técnico em inglês (ADR-0012). Cenários Gherkin em português (`# language: pt`).

## Testing Decisions

Um bom teste aqui exercita comportamento externo observável e nada mais. Nenhum teste toca reader, writer, mapper ou service isolado; nenhum teste conhece nome de classe interna. Se uma regra das linhas 22–34 da descrição inicial existe, ela tem um cenário nomeado com o vocabulário do `CONTEXT.md`. Refatorar o interior de um módulo não deve quebrar teste algum.

Quatro seams, todos no ponto mais alto do seu runtime:

1. **HTTP na API.** Cenários Cucumber contra a API real, com PostgreSQL, MongoDB e Keycloak em Testcontainers. Cobre catálogo filtrado por Role de Relatório, as recusas por permissão, o CRUD de Cadastros e suas validações (formato do Código, nome inexistente, imutabilidade, proibição de reuso), a regra "GERENTE não cria GERENTE", a geração nos quatro formatos, a recusa por limite com contagem prévia, o nome do arquivo, e o registro de auditoria de cada download.
2. **Lançamento do job de Coleta.** Cenários Cucumber que semeiam um banco de origem em Testcontainer, executam a Coleta pelo starter e verificam as linhas no MongoDB, a troca de ponteiro, o Status de Processamento e a contagem. Cobre explicitamente: repetição de execução não duplica dados; execução que falha no meio não altera o ponteiro nem o que está publicado; execução acima do Tempo Estimado de Execução resulta em processado com alerta. Passos reutilizáveis vindos do `test-fixtures` do starter.
3. **Geração de DAGs (pytest).** Sobre o módulo Python que lê o Cadastro: uma DAG por (Produto × Janela), e — o caso que mais importa — o fallback de cache quando o PostgreSQL está indisponível, que é código que só executa no dia do incidente.
4. **E2E de navegador (Playwright).** Login no Keycloak, catálogo, geração e download real. É o único seam que valida de fato o teto de memória do blob do ADR-0004: um download próximo ao limite de CSV precisa completar no navegador, não apenas no servidor.

Não há prior art no repositório — é greenfield, e este spec estabelece o padrão. O `test-fixtures` do starter passa a ser a referência para os processadores seguintes. Cenários de batch e E2E recebem tags próprias e rodam em etapas separadas de CI; os cenários de API rodam a cada push.

Os valores iniciais dos limites de linhas são conservadores e provisórios: o benchmark k6 (geração com contagens crescentes, medindo tempo de parede, heap e tamanho de resposta) refina cada um para ~60% do orçamento de timeout e ~50% do heap seguro. Esse benchmark é parte do escopo.

## Out of Scope

- **Relatórios com mais de 7 dias.** Sem artefato persistido e com TTL de 7 dias, o sistema não produz histórico. Fechamento de mês, trimestre e pedido de auditoria retroativo estão fora (ADR-0008).
- **Extração completa dos maiores Relatórios.** O teto de memória do navegador limita todos os formatos, inclusive CSV, à casa das centenas de milhares de linhas (ADR-0004).
- **Geração assíncrona**, endpoint de polling, artefato reaproveitável e retomada de download (ADR-0004).
- **Bulkhead de concorrência.** Uma geração grande pode causar OOM na API e derrubar requisições em voo de outros usuários (ADR-0004).
- **MFA e exposição segmentada.** Todas as telas, inclusive administrativas, no ingress público, com roles como única fronteira (ADR-0010).
- **Classificação de dados, mascaramento e criptografia em repouso** (ADR-0016).
- **Rotação obrigatória da senha inicial do ADMINISTRADOR** (ADR-0014).
- **Auditoria de concessão e revogação de permissões.** Mitigada parcialmente por admin events do Keycloak e colunas de autoria nas tabelas de vínculo (decidido na sessão).
- **Kubernetes, deploy sem downtime, réplicas da API** (ADR-0009).
- **Descoberta de Relatórios não cadastrados.** Coleta é dirigida pelo Cadastro; não existe dado de Relatório não cadastrado (ADR-0007).
- **Fontes que não sejam banco relacional de leitura** — sem arquivos de mainframe, sem API de terceiros, sem Kafka.
- **Json Server** — removido do stack; o contrato é o OpenAPI.
- **Cron livre por Relatório.** Apenas Janelas de Agendamento nomeadas (ADR-0007).
- **Métricas de negócio e relatórios sobre uso** além do dashboard operacional.

## Further Notes

Ordem de dependência sugerida, porque quase tudo depende dos dois primeiros: `common` (tipos e validações) → esquema PostgreSQL + `processor-starter` com o seam 2 verde → primeiro `processor-<produto>` → API com catálogo e autorização → geração e download → Keycloak (realm + script) → DAGs → frontend → observabilidade → demais processadores. O benchmark k6 pode rodar assim que a geração existir, e deve rodar antes do primeiro uso real.

Riscos aceitos que este spec implementa deliberadamente, e que não devem ser "corrigidos" sem reabrir o ADR correspondente: OOM por geração grande (0004), teto de blob (0004), exposição pública sem MFA (0010), senha inicial sem rotação (0014), ausência de classificação de dados (0016), Compose sem deploy contínuo (0009), consulta ao PostgreSQL em tempo de parse de DAG (0007).
