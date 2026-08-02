Segue a análise dos comportamentos especificados, organizada por eixo, com destaque para conflitos, ambiguidades e lacunas que provavelmente vão aparecer na implementação.

## 1. Coleta agendada e ciclo de vida do status

O comportamento central é: Airflow dispara um container Spring Batch → o módulo lê o schema transacional do seu produto → produz `.jrprint` + `.csv.gz` → grava no MinIO → registra metadados.

Pontos não resolvidos:

- **Precedência entre status.** Se a execução estoura o "tempo estimado" *e* falha, o resultado é "erro" ou "alerta"? A regra atual descreve os dois estados como se fossem mutuamente exclusivos. Falta também definir se "alerta" é avaliado só no encerramento (o mais provável) ou se uma execução ainda em curso além do estimado já muda de estado.
- **Estados ausentes.** Não existe "cancelado", "não executado" (sem dados de origem), "expirado" nem timeout duro. Um job travado fica em "em processamento" indefinidamente e a UI não tem como distinguir isso de um job saudável e demorado.
- **Fonte da verdade do estado.** Airflow tem estados próprios de DAG/task; a tabela de metadados tem os dela. Divergem quando o container morre por OOM ou o pod/VM é reiniciado. É preciso decidir quem reconcilia — o mais barato é o Airflow atualizar via callback de falha, ou um job de varredura que marca execuções órfãs.
- **Idempotência e reexecução.** Se a DAG reprocessar o mesmo relatório na mesma data, o objeto é sobrescrito, versionado, ou rejeitado? Isso está acoplado à chave do S3 (ver item 4) e hoje não há nada no path que distinga execuções.
- **Tolerância do "tempo estimado".** Sem uma margem (ex.: +20%) ou média móvel, o alerta vira ruído constante já na primeira variação de carga.

## 2. Geração sob demanda e exportação

- **Síncrono vs. assíncrono não está definido.** "Download do relatório" sugere request/response, mas desserializar um `JasperPrint` grande e exportar DOCX/XLSX é operação de segundos a minutos e com alto custo de heap. Com N relatores concorrentes, a API REST vira o gargalo e o ponto de OOM. Falta: limite de páginas/linhas, timeout de exportação, e provavelmente um fluxo assíncrono (202 + polling de status + link).
- **Conflito real entre o `.jrprint` único e o XLSX.** O trade-off já reconhece que exportar um print paginado para Excel sai ruim. Só que a mitigação usual (`isIgnorePagination`) atua no *fill*, não no *export* — ou seja, exigiria um segundo preenchimento, o que contradiz a decisão de fazer o fill uma única vez no batch. Uma saída coerente com a arquitetura é a coleta gravar **dois** prints (paginado para PDF/DOCX, não paginado para XLSX), ao custo de armazenamento.
- **Divergência PDF × CSV.** Como o CSV não passa pelo Jasper, ele não terá campos calculados, grupos, subtotais nem formatação definidos no JRXML. O mesmo relatório vai apresentar números e colunas diferentes conforme o formato, e isso será reportado como bug. É preciso declarar a regra: o CSV é o *dataset* da query principal (sem subrelatórios), e o PDF é a *visão formatada*.
- **Detalhes do CSV não especificados:** separador (`;` para Excel pt-BR vs `,` do padrão), encoding e BOM, quoting, formato de data e decimal, cabeçalho técnico ou rotulado.
- **Cache de exportação.** Dois usuários pedindo o mesmo PDF hoje geram duas exportações completas. Cachear o binário exportado (com a mesma retenção) é barato e reduz muito a carga.

## 3. Identidade, autorização e cadastro

Este é o eixo com o maior risco de segurança do documento.

- **GERENTE gerenciando roles do Keycloak.** "Cadastra roles do tipo RELATORIO" implica chamar a Admin API do Keycloak. Se a aplicação repassar essa capacidade sem mediação, um GERENTE pode criar ou atribuir roles fora do domínio de relatórios — escalonamento de privilégio direto. A aplicação precisa intermediar, com service account de escopo mínimo, e validar namespace obrigatório (ex.: só roles com prefixo `REL_`).
- **Escopo do GERENTE não existe.** A regra impede que ele crie outro GERENTE, mas nada limita *quais* grupos e quais RELATORes ele administra. Na prática todo GERENTE é global e pode excluir qualquer RELATOR do sistema.
- **Cadeia relatório → role → grupo → usuário vs. JWT.** Se as roles viajam no token, (a) revogar acesso só surte efeito no próximo refresh — é preciso declarar a janela aceitável e o TTL; (b) um relator em muitos grupos infla o token, com risco de estourar limites de header no Traefik. Vale decidir se a autorização fina é feita pela claim ou por consulta ao banco no momento da geração.
- **Estado "pendente de vínculo" não está modelado.** O RELATOR se cadastra e espera. O que ele vê ao logar? Não há tela, mensagem nem notificação ao GERENTE descritas. Também falta: verificação de e-mail é obrigatória antes do login? Há restrição de domínio de e-mail? Registro público sem nenhum filtro é vetor de abuso.
- **ADMINISTRADOR não pode gerar relatórios.** Consequência da regra "somente RELATOR gera": ninguém com perfil administrativo consegue validar um relatório recém-cadastrado. É preciso permitir acúmulo de perfis ou prever um usuário técnico de verificação.
- **Account Console exposto "seletivamente".** Roteamento por path no Traefik é granularidade grossa; a forma correta de restringir a troca de senha é desabilitar as demais features no realm, não filtrar rotas.
- **Sign-out.** Não há menção a back-channel logout nem invalidação de sessão do Keycloak — logout só no frontend deixa a sessão viva.

## 4. Armazenamento, chaveamento e retenção

- **O código do relatório carece de formato normativo.** Os exemplos mostram `CONTACORRENTE-1234` para um produto chamado "Conta Corrente" e `POUPANCA` sem cedilha — ou seja, há uma normalização implícita (maiúsculas, sem acento, sem espaço) que não está escrita. Sugestão de regra explícita: `^[A-Z]{1,20}-\d{4}$`. Consequências: teto de 9.999 relatórios por produto; e é preciso dizer se a sequência é única por produto ou global.
- **Renomear produto quebra o histórico.** O nome do produto é parte do código *e* do path do S3. Se o código é imutável (recomendado), renomear o produto cria inconsistência entre o rótulo exibido e a chave armazenada.
- **Redundância e ausência de discriminador.** O path `yyyy-MM-dd/produto/código` repete o produto (já contido no código) e não comporta duas execuções no mesmo dia. Falta um `executionId` no final do path.
- **Data de referência × data de execução.** Não está dito se `yyyy-MM-dd` é o dia em que o job rodou ou o dia de competência dos dados (tipicamente D-1). Nem qual fuso — uma coleta às 23h em UTC cai no dia seguinte. Isso muda o que o relator enxerga no drop-down.
- **Retenção de 7 dias × histórico preservado.** Combinação correta em intenção, mas cria links quebrados: o histórico apontará para objetos que não existem mais. Falta o comportamento de "download de item expirado" (404 semântico com mensagem específica, não erro genérico). Também não está dito se o expurgo é feito pela aplicação ou por *lifecycle policy* nativa do MinIO — a variável de ambiente sugere aplicação, mas o lifecycle é mais confiável. Em qualquer caso, `.jrprint` e `.csv.gz` precisam expirar juntos.
- **Desserialização Java a partir do MinIO.** O trade-off diz "o arquivo vem do módulo que está dentro do projeto, logo é confiável" — mas o arquivo vem do *bucket*, não do módulo. Se alguém escreve no bucket, é execução remota de código na API REST. Como criptografia em repouso está fora de escopo, vale ao menos: credenciais separadas (processadores só escrevem, API só lê), hash do objeto gravado nos metadados e conferido na leitura, e `ObjectInputFilter` (JEP 290) com allowlist de `net.sf.jasperreports.*`.

## 5. Observabilidade e tratamento de erro

- **Correlation ID = traceId, com SDK desabilitado nos testes.** Sem SDK não há trace ativo, logo o MDC fica vazio e qualquer cenário Gherkin que valide o correlation ID na mensagem de erro falha. É preciso um fallback: aceitar `traceparent` recebido ou gerar um ID próprio quando não houver span.
- **Trace no batch.** Um job disparado pelo Airflow não tem requisição HTTP de origem. Para correlacionar DAG run ↔ execução Spring Batch ↔ logs no Graylog, o Airflow precisa injetar o `traceparent` como variável de ambiente do container.
- **"Botão para copiar em JSON" no Swagger.** Botão é elemento de interface e não pertence ao contrato da API. Separe: no OpenAPI, o *schema* do erro (timestamp ISO-8601, código, descrição, correlationId — RFC 7807 é o candidato natural); no frontend, a affordance de cópia.
- **Readiness.** Não está definido se readiness reflete dependências (PostgreSQL, MinIO, Keycloak). Se refletir, uma indisponibilidade do MinIO tira todas as instâncias do balanceamento — pode ser desejado ou catastrófico. Liveness, essa sim, nunca deve depender de recurso externo.
- **Cardinalidade de métricas.** Usar produto + código como labels é adequado (dezenas de séries), mas incluir data ou usuário nas mesmas métricas explodiria a cardinalidade no Prometheus.

## 6. Testes

O ponto mais frágil é **H2 em modo PostgreSQL com Flyway**. "Dados não estruturados" sugere `jsonb`; migrações com `jsonb`, tipos específicos, `ON CONFLICT` ou funções nativas simplesmente não rodam no H2, e a divergência aparece tarde. Testcontainers com a mesma imagem do PostgreSQL de produção elimina a classe inteira de problema.

Além disso, os dois relatórios de exemplo por módulo com fontes diferentes só provam o ponto se houver um teste que **falhe** na substituição de fonte — ou seja, `net.sf.jasperreports.awt.ignore.missing.font=false` no ambiente de teste. Caso contrário, a fonte é silenciosamente trocada e o risco descrito no trade-off passa despercebido.

## 7. A lacuna estrutural mais importante

A regra "cada módulo lê exclusivamente do schema do seu produto; a Coleta é a única fronteira de leitura" entra em conflito direto com dois requisitos: o Spring Batch precisa do seu `JobRepository`, e a API REST precisa **ler** os metadados de execução (status, início, fim, tempo estimado, produto, descrição) que os processadores **escrevem**.

Isso implica um terceiro schema — de controle/aplicação — separado dos schemas transacionais, com escrita pelos processadores e leitura pela API. Ele não aparece em "Módulos backend" nem em "Pendentes de definição", mas é pré-requisito de praticamente todo o resto: sem ele, não há listagem de relatórios disponíveis, não há status e não há histórico de downloads.
