## Context

O repositório é hoje docs-only. O PRD fixou o comportamento e a `arquitetura-inicial.md` fixou as decisões
estruturantes (`RA-NN`), mas deixou explicitamente em aberto quatro itens de desenho — **nomes dos módulos,
arquitetura interna de cada módulo, relatórios de exemplo e modelagem do schema de controle**. Este documento
fecha esses quatro e registra as decisões de implementação que o código exigiria decidir em silêncio.

Restrições que valem para tudo o que segue:

- **Máquina alvo** (RA-50): 23 GB de RAM, 4 vCPUs, ~20 GB livres em disco, ambiente local, sem meta de
  disponibilidade. Toda a pilha de RA-51 disputa esses recursos com a aplicação.
- **Um único teto de memória**: RNF-05 (artefato), RNF-06 (dataset), RNF-10 (exportações simultâneas) e o
  pool de RNF-18 compõem um conjunto. Afrouxar um sozinho quebra o conjunto.
- **Mono repositório com versão única** (RA-01) é a premissa de que dependem os quatro primeiros trade-offs
  da arquitetura. Nada aqui pode enfraquecê-la.
- **A Coleta é a única fronteira de leitura transacional** (RA-10). É o invariante que não se negocia.

## Goals / Non-Goals

**Goals:**

- Fechar os quatro pendentes de desenho da `arquitetura-inicial.md` §14.
- Definir a modelagem do schema de controle de modo que RN-15 (execução imutável) e RN-16 (uma vigente por
  par) sejam propriedades do schema, não disciplina de código.
- Definir onde vive cada mecanismo de tempo, retentativa e limite, para que RN-13 não vire "um só limite".
- Entregar a estrutura de pastas com **um exemplo por camada**, porque é o que o agente copia na sessão
  seguinte.

**Non-Goals:**

- Kubernetes, deploy em produção ou homologação, escala horizontal.
- Cache de exportação, virtualização do `JasperPrint`, mascaramento e criptografia em repouso.
- Substituir os números `PROVISÓRIO` do PRD §10 — isso é o spike de calibração com k6, que mede e não bloqueia.
- Cancelamento de execução sob demanda (PRD §5, D20).

## Decisions

### D-A. Nomes e layout dos módulos

```
/ (pom raiz, packaging pom, dependencyManagement único)
├── biblioteca-comum/            RA-02 — tipos do domínio compartilhado, contrato de erro, Correlation ID
├── processador-starter/         RA-03 — Spring Batch: leitura paginada, render, gravação, metadados
├── processador-poupanca/        RA-04 — POUPANCA
├── processador-cliente/         RA-04 — CLIENTE
├── processador-conta-corrente/  RA-04 — CONTACORRENTE
├── processador-consorcio/       RA-04 — CONSORCIO
├── processador-emprestimo/      RA-04 — EMPRESTIMO
├── api-rest/                    RA-05 — porta 8080, único módulo que atende o usuário final
├── frontend/                    RA-06 — Angular
├── orquestrador/                DAG do Airflow (Python), fora do reator Maven
└── infra/                       docker-compose, realm do Keycloak, config do OTel, init do MinIO
```

**Alternativa considerada:** um módulo processador único parametrizado por produto. Rejeitada porque
contraria RA-04 — *o módulo processador é o Produto* — e porque um processo único apuraria todos os produtos
no mesmo contêiner, destruindo a unidade que o `execution_timeout` de RA-57 mede.

### D-B. Arquitetura interna dos módulos Java

Três camadas por módulo, com a proibição escrita no `ARCHITECTURE.md` e verificada por teste de arquitetura:

```
dominio/          regras puras — não importa Spring, JDBC, HTTP nem JasperReports
aplicacao/        casos de uso, orquestra dominio + portas
infraestrutura/   adaptadores: JDBC, S3, Jasper, Keycloak, OTel
api/              (só na api-rest) controllers, DTOs, validação de entrada
```

Invariantes: `dominio` não importa nada de `infraestrutura`; nenhum acesso a banco fora de
`infraestrutura/repositorio`; nenhum controller acessa banco diretamente.

**Alternativa considerada:** pacote por feature. Rejeitada porque o invariante que mais importa aqui é
*quem pode falar com o schema transacional*, e ele se enuncia por camada, não por feature.

### D-C. Modelagem do schema de controle

| Tabela | Papel | Ponto crítico |
|---|---|---|
| `produto` | sigla (PK), nome, ativo | Sigla imutável (RN-01) |
| `relatorio` | codigo (PK), sigla (FK), nome, descricao, tempo_estimado_segundos, ativo | `CHECK` do regex de RN-02 e de tempo > 0 (RN-04) |
| `execucao` | id, data_referencia, codigo_relatorio, origem, status, inicio, fim, duracao_ms, tempo_estimado_segundos, vigente, motivo, correlation_id | **Append-only** (RA-67) |
| `artefato` | id, execucao_id, tipo (`jrprint`/`csv`), caminho, tamanho_bytes, expurgado_em | Marca de expurgo de RA-63 |
| `download` | id, usuario, codigo_relatorio, nome_relatorio, sigla_produto, data_referencia, formato, momento | **Cópia** dos identificadores (RA-66) |
| `evento_auditoria` | id, tipo, solicitante, momento, correlation_id, detalhe (jsonb) | Recusa de RN-18 e reprocessamento de RN-21 |
| `relatorio_role` | codigo_relatorio, role_relatorio | Único elo da cadeia que vive em banco (RA-61) |

Duas decisões carregam peso:

1. **Vigência como índice parcial único:** `CREATE UNIQUE INDEX ... ON execucao (data_referencia,
   codigo_relatorio) WHERE vigente`. RN-16 passa a ser impossível de violar por caminho de código.
   *Alternativa:* resolver vigência por `max(id)` em consulta. Rejeitada — deixa a unicidade implícita e uma
   inserção concorrente cria duas vigentes sem que nada reclame.
2. **Imutabilidade por trigger:** um `BEFORE UPDATE` recusa alterar `status`, `inicio`, `fim` e
   `tempo_estimado_segundos` de execução já terminal; só `vigente` é alterável. RN-15 vira propriedade do
   schema. *Alternativa:* confiar na camada de aplicação. Rejeitada — há **três** escritores no schema de
   controle (Coleta, orquestrador e API, RA-23), e uma disciplina que precisa ser lembrada em três lugares
   já falhou.

`status` e `origem` são enums de banco, não texto livre. Flyway é o dono do schema; **nenhum outro
componente cria ou altera estrutura** (RA-24).

### D-D. Uma leitura da base alimenta os dois artefatos

O `ItemReader` paginado lê a consulta principal **uma vez**; um `CompositeItemWriter` alimenta
simultaneamente o acumulador do dataset (que vira `JRDataSource` no preenchimento) e o writer do `.csv.gz`
em streaming.

*Alternativa:* preencher o Jasper com `JRResultSetDataSource` direto e reler a base para o CSV. Rejeitada:
duas leituras contradizem a janela única de RN-44/RA-10 e produziriam PDF e CSV de instantes diferentes do
mesmo dia.

**Preço aceito:** o dataset fica em heap durante a apuração — exatamente o que o teto de RNF-06 orça, e o que
a contagem prévia de RA-64 protege.

### D-E. Onde vive cada mecanismo de tempo e retentativa

| Mecanismo | Onde | Implementação |
|---|---|---|
| Limite do relatório (2× estimado) | Contêiner | `ChunkListener` + `setTerminateOnly()` entre chunks |
| Timeout de consulta | Contêiner | `queryTimeout` declarado em **todo** statement de leitura da Coleta |
| Limite de segurança do produto | Task da DAG | `execution_timeout` = 2× soma dos estimados, com folga |
| Retentativa (RNF-17) | Task da DAG | `retries` da task; a task é idempotente e apura **só** o que não concluiu |
| Encerramento anômalo | Callback de falha da task | Encerra como erro toda execução aberta do produto (RA-14) |

A retentativa vive no orquestrador, e não dentro do contêiner, porque cada tentativa precisa de um
`execution_timeout` próprio: uma retentativa interna consumiria a janela da primeira e o interruptor de
emergência dispararia no meio dela, sem que nada explicasse por quê.

### D-F. Reserva do ciclo escrita pelo orquestrador

A primeira task da DAG grava as execuções reservadas direto no schema de controle (RA-54), com **usuário de
banco próprio**, cujo `GRANT` alcança apenas `execucao` e a leitura do catálogo.

*Alternativa:* a DAG chamar um endpoint da API. Rejeitada por acrescentar uma dependência de disponibilidade
da API ao caminho crítico do ciclo — se a API estiver fora às 03h, nada é reservado e o dia inteiro some do
denominador, que é precisamente o que RN-45 existe para impedir.

### D-G. Semáforo de exportação em memória

O limite de RNF-10 é um `Semaphore` com `tryAcquire()` sem espera, na própria API. Recusa imediata, sem fila
(RN-30, RN-53).

**Validade declarada:** correto enquanto a API for **uma instância** — que é o caso em RA-50. Registrar isso
no `ARCHITECTURE.md` é o que impede alguém de escalar a API e achar que o teto continua valendo.

### D-H. Relatórios de exemplo (RA-08)

Dez relatórios, dois por produto, com imagens e fontes **diferentes entre os dois do mesmo módulo**.
`POUPANCA-0001` é o que carrega o elemento de barcode, exercitando o renderer serializado no classpath da API
— um basta para o conjunto, cinco seriam o mesmo teste repetido.

Todo JRXML segue a convenção de RA-59: cabeçalho de coluna na banda `title`, ornamento descartável em
`pageHeader`/`pageFooter`. Cada um tem teste de cabeçalho único no XLSX (RF-21).

### D-I. Versão única imposta pelo build

`dependencyManagement` no pom raiz e `maven-enforcer-plugin` reprovando versão divergente e dependência
convergente quebrada. A premissa de RA-01 deixa de depender de revisão humana.

### D-J. Identidade declarativa

O realm é **importado de um JSON versionado** na subida do Keycloak: perfis como realm roles, cliente
`relatorios` para as client roles, tema da página de registro, SMTP apontando para o Mailpit. Nada de
configuração manual em console — o ambiente precisa nascer igual em qualquer clone.

## Risks / Trade-offs

- **Heap da exportação** (`.jrprint` desserializado ocupa múltiplos do tamanho em disco) → teto de RNF-05,
  teto de linhas de RNF-06, contagem prévia de RA-64 e semáforo de RNF-10 atuando **juntos**; nenhum deles se
  afrouxa sozinho.
- **A API tem poder técnico de criar um ADMINISTRADOR**, porque *fine-grained admin permissions* é preview no
  Keycloak (RA-61) → separação de espaços de nomes (realm role × client role do cliente `relatorios`) mais
  teste dedicado de RF-34. Risco aceito e declarado, não resolvido.
- **Assinatura do evento de expurgo do MinIO** — a documentação induz a `--event ilm`, que não cobre
  expiração → assinar `--event delete` e conferir na tag fixada pelo Compose, dentro do próprio ticket
  (RA-21); e a API deriva o estado expirado quando a marca falta (RA-63), de modo que a notificação perdida
  custa inconsistência transitória, não resposta errada.
- **Três escritores no schema de controle** (Coleta, orquestrador, API) → Flyway como dono único da estrutura,
  usuário de banco por escritor com `GRANT` mínimo, e as invariantes críticas em trigger e índice, não em
  código.
- **Serialização Java nativa do `JasperPrint`** → sustentada só por RA-01. Se o mono repositório cair, os
  quatro primeiros trade-offs da arquitetura precisam ser reavaliados; o enforcer de D-I é o que dá o sinal.
- **Toda a pilha de RA-51 em 23 GB e 4 vCPUs** → pool de 2 produtos (RNF-18), limites de memória por serviço
  no Compose, e Graylog/Prometheus/Grafana/Jaeger em perfil do Compose que pode ser desligado quando não se
  está observando.
- **Relatórios do mesmo produto podem ver instantes diferentes da base** quando um é apurado em retentativa
  (RN-44, D22) → preço já aceito no PRD; a alternativa era ficar sem o relatório até o dia seguinte.
- **Escopo desta change é maior do que um PR** → `tasks.md` em fases numeradas, cada fase mergeável com CI
  verde por si só.

## Migration Plan

Não há migração: o repositório não tem código nem contrato publicado. A ordem de entrega respeita o
sincronismo do guia (**P0 → P1 → P2 precedem E3**) e cada fase termina com CI verde:

1. **Fase 0** — documentos P0/E0 faltantes (glossário, user stories, ADRs, C4, riscos, especificação, design
   system e fluxos).
2. **Fase 1** — fundações: reator Maven, módulos vazios compilando, Compose, `.env.example`, scripts, CI,
   `ARCHITECTURE.md`.
3. **Fase 2** — contratos: schema de controle com Flyway, OpenAPI, seed, `.feature` das regras.
4. **Fase 3** — Coleta: starter, um produto ponta a ponta, DAG com reserva e callback.
5. **Fase 4** — demais produtos e os dez relatórios de exemplo.
6. **Fase 5** — identidade e autorização: realm importado, autocadastro, cadeia de permissão.
7. **Fase 6** — API: listagem, exportação, downloads, expurgo, reprocessamento — já sobre a autorização
   real, porque toda rota nova exige teste de autorização na sua própria entrega.
8. **Fase 7** — frontend.
9. **Fase 8** — observabilidade, E2E e calibração com k6.

Rollback é por reversão de PR; a única irreversibilidade é a migration aplicada, e migration aplicada não se
altera (RA-24) — corrige-se com migration nova.

## Open Questions

- **Q10 (PRD)** — os limites recalibrados de §10 resistem à medição real? Resolve no spike de calibração com
  k6, na Fase 8. Não bloqueia nenhuma fase anterior.
- **Q11 (PRD)** — a meta de 98% é adequada depois do primeiro mês de operação? Só medível em operação.
- **Modelos de dados dos relatórios de exemplo** — as 10 consultas e os schemas transacionais de exemplo são
  fechados no início da Fase 3, junto com o primeiro produto ponta a ponta.
- **Quais *font extensions*** entram no classpath comum: decidido ao autorar o primeiro par de JRXML com
  fontes diferentes (Fase 3), porque é onde o risco de substituição de fonte aparece pela primeira vez.
