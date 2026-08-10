# SP-2 — Decisões técnicas · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** entregar os 19 ADRs, o `riscos.md` com 14 riscos vigentes (15 seções, contando o
exemplo resolvido) e as quatro alterações em `arquitetura-inicial.md`, fechando a fase E0 do guia.

**Arquitetura:** não há código. Cinco entregas de documento, agrupadas por **origem da
alternativa**, e não por tema — porque é a origem que decide se um revisor pode rejeitar um lote
e aprovar o vizinho. As 5 reconstruções ficam isoladas numa tarefa própria: são o único conteúdo
inferido, e merecem gate separado.

**Ferramentas:** Markdown, `git`, `grep`/`comm`/`awk` para as conferências. Nenhuma dependência
nova, nenhum script versionado.

**Spec:** [`docs/superpowers/specs/2026-08-10-sp2-decisoes-tecnicas-design.md`](../specs/2026-08-10-sp2-decisoes-tecnicas-design.md)

---

## Restrições globais

Valem para **todas** as tarefas. Copiadas da spec.

- **Idioma:** pt-BR. Identificadores do domínio em pt-BR sem acento; tecnologia em inglês.
- **Identificadores `RA-NN` / `RN-NN` / `RF-NN` / `ADR-NNNN` são permanentes.** Nunca renumerar
  nem reaproveitar.
- **O ADR não repete o `RA`, e o `RA` não repete o ADR.** O `RA` é a norma e vira ponteiro; o ADR
  é o porquê não foi outra coisa.
- **Nenhuma opção listada pode aparecer sem justificativa de rejeição.** Opção sem motivo é
  decoração — dá impressão de deliberação sem registrar nenhuma.
- **SP-2 não cria diretório de módulo nem `pom.xml`.** Nomeia; não constrói. Isso é SP-3.
- **O C4 já está entregue** em `docs/arquitetura/c4-contexto.md` (commit `172e50b`). Nenhuma tarefa
  deste plano o cria ou altera; a Tarefa 5 apenas o marca como existente na §15.
- **Pré-condição:** SP-1 aplicado (SP-1 também altera a §15).
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Template do ADR

Usado nas Tarefas 1, 2 e 3. Não é repetido nas tarefas — é este.

```markdown
# ADR-NNNN — <título>

**Estado:** aceita · **Data:** 2026-08-10 · **Regras:** <RA-NN, RN-NN>

## Contexto
<Por que a decisão foi necessária. Cita RA e RN; não os repete.>

## Opções consideradas
1. <opção>  — rejeitada
2. <opção>  ← escolhida

## Por que não a 1
<Motivo concreto. Toda opção rejeitada tem a sua seção.>

## Consequências
<O que passa a ser verdade. Riscos aceitos entram aqui, com o R-NN.>
```

Nas **5 reconstruções**, a seção *Opções consideradas* abre com a linha, literalmente:

```markdown
> Reconstruída em SP-2; não registrada à época.
```

### Nota sobre o formato deste plano

As entregas são prosa. Reproduzir 19 ADRs por extenso seria escrever a entrega duas vezes. Cada
tarefa traz, por ADR: **título, regras, as opções, o motivo de cada rejeição e a fonte**. Isso é o
conteúdo — o que falta é redigir contexto e consequências a partir dele, que é o trabalho.

---

## Tarefa 1: Os 11 ADRs documentados

Alternativa registrada nas `RA` aposentadas e na tabela D20–D33 do PRD. Lote mais rápido: o
material existe.

**Arquivos:**
- Criar: `docs/adr/0005-autorizacao-hibrida-keycloak-e-schema-de-controle.md`,
  `0009-catalogo-derivado-do-codigo.md`, `0010-execucao-append-only-com-ponteiro-de-vigencia.md`,
  `0011-sem-apuracao-retroativa.md`, `0012-janela-unica-com-retentativa-sem-cancelamento.md`,
  `0013-dois-limites-de-tempo.md`, `0014-dag-com-task-estatica-por-produto.md`,
  `0015-exportacao-sincrona-com-semaforo.md`, `0016-xlsx-continuo-por-convencao-de-autoria.md`,
  `0017-tres-retencoes-e-inativacao-logica.md`, `0018-expurgo-por-ilm-com-callback.md`

**Interfaces:**
- Produz: os identificadores `ADR-0005`, `ADR-0009`–`ADR-0018`, consumidos pelos ponteiros da
  Tarefa 5 e pelas referências cruzadas do `riscos.md` (Tarefa 4).

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "arquivos:  $(ls docs/adr/*.md 2>/dev/null | wc -l)"
for f in docs/adr/*.md; do
  for s in "## Contexto" "## Opções consideradas" "## Consequências"; do
    grep -q "^$s" "$f" || echo "FALTA '$s' em $f"
  done
  grep -qE '^## Por que não' "$f" || echo "FALTA seção 'Por que não' em $f"
done
```

Esperado agora: `arquivos: 0` e nenhuma linha (o `for` não itera). É a falha que a tarefa corrige.

- [ ] **Passo 2: Escrever os 11 ADRs**

Conteúdo por ADR. A opção marcada com `←` é a escolhida.

**ADR-0005 — Autorização híbrida: Keycloak e schema de controle** · `RA-61, RN-22, RN-23, RN-26`
1. Cadeia inteira resolvida no Keycloak — rejeitada
2. Cadeia inteira em tabela própria — rejeitada
3. Híbrida: Perfil como realm role, Role de relatório como client role, Grupo nativo, elo
   Relatório→Role em tabela ←
- *Não a 1:* o Keycloak não conhece o conceito de Relatório. `RA-31` foi escrita assim e teve de
  ser aposentada — a formulação era **impossível**, não apenas inconveniente.
- *Não a 2:* perderia grupos, federação e o console de conta nativos; e o Perfil deixaria de ser
  realm role, o que reduz RN-26 a uma verificação de código em vez de separação de espaços de
  nomes.
- *Consequências:* R-08 — o service account recebe `manage-users` e `manage-clients` porque
  *fine-grained admin permissions* é preview no Keycloak 26.5.2.
- *Fonte:* `RA-31` aposentada, `RA-61`.

**ADR-0009 — Catálogo derivado do código** · `RN-49, RN-50, RA-58, RF-44`
1. CRUD de produto e relatório na aplicação — rejeitada
2. Catálogo publicado pelo módulo ao iniciar ←
- *Não a 1:* um produto **é** um módulo processador (`RA-04`) e um relatório **é** um JRXML
  versionado (`RA-07`). Cadastrar pela aplicação criaria linha de catálogo sem código
  correspondente — um relatório que a listagem promete e que nenhuma apuração produz.
- *Consequências:* a aplicação edita nome, descrição e tempo estimado, e inativa; nunca cria nem
  apaga. Código duplicado dentro do produto impede o módulo de iniciar (RF-44).
- *Fonte:* D30.

**ADR-0010 — Execução append-only com ponteiro de vigência** · `RN-15, RN-46, RN-47, RA-67`
1. Mutar o status da execução na retentativa — rejeitada
2. Inserir linha nova e mover o ponteiro de vigência ←
- *Não a 1:* colide frontalmente com RN-15 (execução em status terminal não muda de status). D28
  registrou a contradição: a retentativa precisaria reabrir o que a regra declara fechado.
- *Consequências:* "vigente" passa a ser ponteiro, não status; o tempo estimado é copiado para
  dentro da Execução (RN-47), de modo que editar o catálogo não reclassifica o passado. RN-15 vira
  propriedade do schema, e não disciplina de código.
- *Fonte:* D28.

**ADR-0011 — Sem apuração retroativa** · `RN-07, RN-54, RA-56, RF-53`
1. Data de referência como parâmetro de entrada — rejeitada
2. Data de referência sempre derivada do dia do disparo ←
- *Não a 1:* só produziria dado correto se **toda** base transacional fosse temporal, o que não é
  garantido. Rodar hoje uma apuração carimbada com data passada gravaria os números de hoje sob o
  rótulo de ontem, e nenhuma métrica do sistema detectaria.
- *Consequências:* nenhuma interface aceita a data — nem aplicação, nem orquestrador, nem
  reprocessamento forçado. A DAG declara `catchup=False` **explicitamente**, porque o padrão do
  Airflow varia entre 2.x e 3.x e a corrupção entraria por omissão.
- *Fonte:* D25.

**ADR-0012 — Janela única de leitura, com retentativa e sem cancelamento** · `RN-13, RN-44, RNF-17`
1. Uma leitura por produto por dia, sem retentativa — rejeitada
2. Cancelamento sob demanda como interruptor — rejeitada
3. Uma leitura **bem-sucedida** por relatório por dia, com retentativa limitada ←
- *Não a 1:* RN-19 exige poder refazer o que falhou. Sem retentativa, um relatório que falhou às
  03h só sairia no dia seguinte.
- *Não a 2:* o cancelamento operava sobre o relatório, mas a unidade de execução é o produto — a
  regra não era implementável. Reverte D06 e elimina o status `cancelado`.
- *Consequências:* relatórios do mesmo produto podem enxergar instantes diferentes da base quando
  um deles vem de retentativa (R-06); o único interruptor passa a ser o tempo (R-07).
- *Fonte:* D20, D21, D22.

**ADR-0013 — Dois limites de tempo com papéis distintos** · `RN-13, RA-57, RF-05`
1. Um único timeout, no orquestrador — rejeitada
2. Limite do relatório dentro do contêiner + limite de segurança na task ←
- *Não a 1:* era `RA-15`, e foi aposentada. O orquestrador só enxerga o produto, mas a regra de
  negócio mede o relatório: um único limite derrubaria os relatórios irmãos junto, contra RF-05.
- *Consequências:* o limite do relatório é verificado **entre chunks** do Spring Batch, o que não
  interrompe uma consulta travada dentro de uma chamada JDBC — por isso **todo statement de leitura
  declara `queryTimeout`**. Sem ele o limite interno não existe e ninguém percebe. O limite de
  segurança é `execution_timeout` da task, e o seu efeito recai em `RA-14`.
- *Fonte:* D23, `RA-15` aposentada, `RA-57`.

**ADR-0014 — DAG com task estática por produto** · `RA-65, RA-54, RA-55`
1. Fábrica de DAGs dinâmica, lendo o catálogo do banco — rejeitada
2. Uma task por produto, estática, espelhando os módulos ←
- *Não a 1:* a lista de produtos é código, porque o produto **é** código (`RA-04`). Uma DAG gerada
  do banco pode referenciar produto sem módulo, e a divergência apareceria em tempo de execução,
  de madrugada — não no PR.
- *Consequências:* adicionar produto é adicionar módulo e task no mesmo PR, e o mono repositório
  garante que os dois não divirjam. A lista de **relatórios** continua sendo dado, lida em tempo de
  execução pela reserva de `RA-54`. As tasks correm em pool de 2 (`RNF-18`).
- *Fonte:* `RA-65`, §14 "Resolvidos nesta revisão".

**ADR-0015 — Exportação síncrona com semáforo, sem fila** · `RN-30, RN-53, RA-60, RF-48`
1. Job assíncrono com polling de status — rejeitada
2. Síncrona com fila de espera — rejeitada
3. Síncrona com semáforo e recusa imediata do excedente ←
- *Não a 1:* introduziria um segundo ciclo de vida de status, competindo com o da Execução (D09) —
  e o usuário passaria a perguntar "ficou pronto?" sobre duas coisas diferentes com o mesmo nome.
- *Não a 2:* a fila exigiria segurar a requisição indefinidamente; RN-30 exige resposta na mesma
  requisição.
- *Consequências:* a requisição excedente é recusada de imediato, com indicação de repetir mais
  tarde. É o que mantém a memória da API sob teto conhecido — ver R-05.
- *Fonte:* `RA-60`, RN-30.

**ADR-0016 — XLSX contínuo por convenção de autoria** · `RN-33, RA-59, RF-21`
1. Configurar o exportador XLSX para ignorar a paginação — rejeitada
2. Repreencher o relatório sem paginação, na exportação — rejeitada
3. Convenção de autoria no JRXML + exclusão de banda por origem de elemento ←
- *Não a 1:* `ignorePagination` é aplicado **no preenchimento**, não na exportação, e
  `pageHeader`/`pageFooter` já estão gravados por página dentro do `.jrprint`. `RA-28` supunha o
  contrário e foi aposentada.
- *Não a 2:* repreencher exige reler a base — fere RN-31 e RN-44.
- *Consequências:* impõe convenção a **todo** JRXML do projeto (cabeçalho de coluna na banda
  `title`) e exige teste por relatório afirmando que o cabeçalho aparece exatamente uma vez
  (RF-21, `RA-68`). Sem o teste, a convenção apodrece no primeiro relatório escrito por quem não
  leu o documento.
- *Fonte:* D33, `RA-28` aposentada, `RA-59`.

**ADR-0017 — Três retenções e inativação lógica** · `RN-36, RN-38, RN-50, RN-51, RA-62`
1. Retenção única para artefato, execução e download — rejeitada
2. Três ciclos de vida independentes ←
- *Não a 1:* a métrica primária tem janela de 30 dias e o artefato dura 7. Uma retenção única
  calcularia a métrica sobre uma série truncada, **sem sinal algum de que isso está acontecendo**.
- *Consequências:* artefato 7 dias; metadados de Execução, nunca; histórico de downloads,
  indefinidamente. E nada do catálogo é apagado — produto e relatório são inativados.
- *Fonte:* D29.

**ADR-0018 — Expurgo por ILM do MinIO, com callback de marcação** · `RN-37, RN-39, RA-20, RA-21, RA-63`
1. Job de expurgo próprio, varrendo o bucket — rejeitada
2. Política de ciclo de vida do bucket + callback marcando o artefato ←
- *Não a 1:* duplicaria uma responsabilidade que o repositório já tem, e a varredura periódica
  competiria por I/O com a janela da coleta.
- *Consequências:* a expiração por ILM emite `s3:ObjectRemoved:Delete` — o MinIO **diverge do S3 da
  AWS** aqui. A assinatura correta é `--event delete`, **não** `--event ilm` como o README de
  lifecycle do MinIO sugere; seguir a documentação produziria um webhook que nunca dispara, sem
  erro algum. A marca é autoritativa quando presente; quando falta, a API deriva o estado por
  `data de referência < hoje − janela`, de modo que uma notificação perdida custa inconsistência
  transitória e não resposta errada. Risco R-10.
- *Fonte:* `RA-20`, `RA-21`, `RA-63`.

- [ ] **Passo 3: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "arquivos:  $(ls docs/adr/*.md | wc -l)   (esperado 11)"
for f in docs/adr/*.md; do
  for s in "## Contexto" "## Opções consideradas" "## Consequências"; do
    grep -q "^$s" "$f" || echo "FALTA '$s' em $f"
  done
  grep -qE '^## Por que não' "$f" || echo "FALTA seção 'Por que não' em $f"
done
```

Esperado: `arquivos: 11` e nenhuma linha `FALTA`.

- [ ] **Passo 4: Conferir que toda opção rejeitada tem a sua seção**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
for f in docs/adr/*.md; do
  rej=$(sed -n '/^## Opções consideradas/,/^## /p' "$f" | grep -c '— rejeitada')
  sec=$(grep -cE '^## Por que não' "$f")
  [ "$rej" -eq "$sec" ] || echo "$f: $rej rejeitadas, $sec seções 'Por que não'"
done
```

Esperado: nenhuma saída. É o critério de aceite 3 — opção sem motivo é decoração.

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/adr/
git commit -m "$(cat <<'EOF'
ADRs das 11 decisões com alternativa registrada

Formaliza as decisões cuja alternativa rejeitada já estava escrita nas
RA aposentadas e na tabela D20-D33 do PRD. Cada ADR guarda o que a RA
não guarda: por que não foi outra coisa.

Três delas registram alternativas que não eram apenas piores, mas
impossíveis: a cadeia inteira no Keycloak, que não conhece Relatório; o
ignorePagination na exportação, que é aplicado no preenchimento; e o
timeout único, que derrubaria os relatórios irmãos junto.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Os 3 ADRs de alternativa parcial

A decisão está registrada; a alternativa, só em parte. Ficam separados da Tarefa 1 porque exigem
mais julgamento e menos transcrição.

**Arquivos:**
- Criar: `docs/adr/0004-docker-compose-local-sem-kubernetes.md`,
  `0006-gherkin-em-toda-camada.md`, `0007-persistir-o-jasperprint-serializado.md`

**Interfaces:**
- Produz: `ADR-0004`, `ADR-0006`, `ADR-0007`, consumidos pela Tarefa 5 e pelo `riscos.md`.

- [ ] **Passo 1: Escrever os 3 ADRs**

**ADR-0004 — Docker Compose local, sem Kubernetes** · `RA-50, RA-51`
1. Kubernetes — rejeitada
2. Docker Compose ←
- *Não a 1:* a primeira versão executa **somente em ambiente local**, numa máquina de 23 GB de RAM,
  4 vCPUs e ~20 GB livres, sem meta de disponibilidade nem de escala horizontal. Kubernetes
  adicionaria uma camada de operação sem resolver problema existente. Declarado fora de escopo.
- *Consequências:* é essa máquina que justifica os limites recalibrados do PRD §10 e o pool de 2 de
  `RA-55`. Deploy em produção e homologação também estão fora de escopo.
- *Fonte:* "Fora de escopo" da arquitetura + `RA-50`. **Parcial:** a rejeição de Kubernetes está
  declarada; o comparativo, não.

**ADR-0006 — Gherkin para todo comportamento observável pelo negócio** · `RA-44` a `RA-49`, `RA-68`
1. JUnit puro em unitário e integração, Gherkin apenas em E2E — rejeitada
2. Gherkin para todo comportamento observável pelo negócio, inclusive a Coleta ←
- *Não a 1:* a Coleta é comportamento de negócio **sem interface**. Sob a opção 1 ela ficaria sem
  cenário legível — justamente a metade do sistema onde as regras são mais densas e onde ninguém
  consegue verificar por inspeção visual se a regra foi cumprida.
- *Consequências:* cenários em `src/test/resources/feature` nos módulos Java e em `e2e/features/`
  nos módulos Angular; JUnit 5 + Cucumber + Testcontainers + Flyway na integração; Newman e `psql`
  no E2E de backend; Playwright no de navegador. E os testes obrigatórios por natureza de risco de
  `RA-68`, que são os que ninguém escreve espontaneamente.
- *Fonte:* `RA-44`. **Parcial:** a decisão está registrada; a alternativa, não.

**ADR-0007 — Persistir o `JasperPrint` serializado** · `RA-16, RA-27, §12`
1. Persistir só o dataset e re-renderizar a cada exportação — rejeitada
2. Persistir o PDF e converter a partir dele — rejeitada
3. Persistir o `JasperPrint` serializado ←
4. Virtualizar o `JasperPrint` na exportação — rejeitada
- *Não a 1:* re-renderizar exige preencher de novo. Se a fonte for a base, fere RN-31; se for o
  dataset, multiplica a latência de exportação e a paginação deixa de ser estável entre formatos,
  quebrando a promessa de PDF e DOCX paginarem igual.
- *Não a 2:* converter PDF para XLSX ou DOCX produz resultado ilegível — o PDF é uma projeção, não
  a fonte.
- *Não a 4:* trocaria heap por disco, e o disco é o recurso mais escasso da máquina alvo.
  Declarado fora de escopo.
- *Consequências:* R-01 a R-05, **todos com premissa em `RA-01`**. As imagens vão embutidas no
  `.jrprint`, mas as fontes não; barcodes viram renderers serializados. O `.jrprint` desserializado
  ocupa múltiplos do tamanho em disco, e é isso que obriga `RNF-05`, `RNF-06` e `RA-60` a existirem
  **juntos**.
- *Fonte:* §12 + "Fora de escopo". **Parcial.**

- [ ] **Passo 2: Rodar as duas conferências da Tarefa 1**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "arquivos:  $(ls docs/adr/*.md | wc -l)   (esperado 14)"
for f in docs/adr/*.md; do
  for s in "## Contexto" "## Opções consideradas" "## Consequências"; do
    grep -q "^$s" "$f" || echo "FALTA '$s' em $f"
  done
  rej=$(sed -n '/^## Opções consideradas/,/^## /p' "$f" | grep -c '— rejeitada')
  sec=$(grep -cE '^## Por que não' "$f")
  [ "$rej" -eq "$sec" ] || echo "$f: $rej rejeitadas, $sec seções 'Por que não'"
done
```

Esperado: `arquivos: 14`, nenhuma linha `FALTA`, nenhum desencontro. Note que `ADR-0007` tem
**três** opções rejeitadas e portanto três seções `## Por que não`.

- [ ] **Passo 3: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/adr/
git commit -m "$(cat <<'EOF'
ADRs das 3 decisões com alternativa parcialmente registrada

Ambiente, estratégia de testes e persistência do JasperPrint. Nos três
a decisão estava escrita e a alternativa não, ou só em parte.

O ADR-0007 é o mais caro do projeto: dele descendem os cinco primeiros
riscos, todos com o mono repositório como premissa, e os três tetos de
memória que só funcionam juntos.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Os 5 ADRs reconstruídos

**Lote isolado de propósito.** É o único conteúdo inferido de SP-2, e o revisor precisa poder
rejeitá-lo sem tocar nos catorze anteriores.

**Arquivos:**
- Criar: `docs/adr/0001-java-maven-spring-e-angular.md`,
  `0002-mono-repositorio-com-versao-unica.md`, `0003-postgresql-e-flyway.md`,
  `0008-csv-fora-do-jasperreports.md`, `0019-nomes-dos-modulos.md`

**Interfaces:**
- Produz: `ADR-0001`, `ADR-0002`, `ADR-0003`, `ADR-0008`, `ADR-0019`. O `ADR-0019` fixa os nomes de
  módulo que a Tarefa 5 grava em `RA-69` e que SP-3 usa para criar os diretórios.

- [ ] **Passo 1: Escrever os 5 ADRs, cada um com o rótulo de reconstrução**

Todos abrem *Opções consideradas* com a linha
`> Reconstruída em SP-2; não registrada à época.`

**ADR-0001 — Java, Maven e Spring no backend; Angular no frontend** · `§11`
1. Java + Maven + Spring ←
2. Outra linguagem, com biblioteca de relatório equivalente — rejeitada
- *Não a 2:* JasperReports é biblioteca Java, e é o motor de renderização que o produto exige — o
  `.jrprint` é um objeto Java serializado. A escolha da linguagem é **consequência** da escolha do
  motor, não uma deliberação independente. Registrar isso importa porque quem ler `RA-01` daqui a
  um ano pode supor que houve comparação de linguagens, e não houve.
- *Consequências:* Spring Web na API, Spring Batch nos processadores, Maven como build. Angular no
  frontend, integrando exclusivamente pelos endpoints da API.

**ADR-0002 — Mono repositório com versão única** · `RA-01, §12`
1. Um repositório por módulo — rejeitada
2. Mono repositório, versão única, dependências compartilhadas ←
- *Não a 1:* os quatro primeiros trade-offs da §12 **dependem** de todos os módulos compartilharem
  a mesma versão do JasperReports e o mesmo classpath de fontes e renderers. Com repositórios
  separados, a API poderia desserializar um `.jrprint` produzido por outra versão — e o sintoma
  seria fonte substituída num PDF, ou `ClassNotFoundException` num barcode, em vez de erro de
  build.
- *Consequências:* R-01 a R-04 declaram `RA-01` como premissa. Se `RA-01` cair, os quatro precisam
  ser reavaliados — e essa frase precisa estar em cada um deles, não só aqui.

**ADR-0003 — PostgreSQL e Flyway; migration aplicada não se altera** · `RA-24`
1. PostgreSQL + Flyway ←
2. PostgreSQL + Liquibase — rejeitada
- *Não a 2:* diferença pequena e sem consequência arquitetural. Flyway foi escolhido por versionar
  **SQL puro**, que mantém a migration legível para quem revisa o schema de controle sem conhecer a
  ferramenta.
- *Consequências:* a regra que importa mais que a ferramenta é **migration já aplicada não se
  altera** — corrigir schema é sempre uma migration nova. Vale para o schema de controle e para os
  transacionais.

**ADR-0008 — CSV fora do JasperReports** · `RN-34, RA-17`
1. Exportador CSV do JasperReports, a partir do `.jrprint` — rejeitada
2. `.csv.gz` gravado pela Coleta, a partir da consulta principal ←
- *Não a 1:* o exportador do Jasper produz o CSV do relatório **renderizado** — com subrelatórios,
  formatação e resquícios de paginação. RN-34 define o CSV como o **dataset bruto**, para quem vai
  reprocessar o dado e não para quem vai lê-lo. São dois artefatos diferentes com o mesmo nome de
  formato, e confundi-los entregaria ao usuário de reprocessamento um arquivo inútil.
- *Consequências:* o `.csv.gz` é irmão do `.jrprint` e nasce na mesma execução; separador `;`, por
  compatibilidade com Excel pt-BR. O JasperReports permanece responsável apenas por PDF, XLSX e
  DOCX.

**ADR-0019 — Nomes dos módulos em pt-BR, sem prefixo** · `RA-69, RA-02` a `RA-06`, `RA-65`
1. pt-BR sem prefixo ←
2. pt-BR com prefixo `sjr-` — rejeitada
3. Inglês técnico — rejeitada
- *Não a 2:* o `groupId` já cuida do namespace. O prefixo repetiria quatro caracteres em cada linha
  de cada `pom` e em cada caminho de arquivo, sem desambiguar nada dentro do repositório.
- *Não a 3:* contraria a regra de fronteira que o glossário de SP-1 fixa — *se o conceito existe
  para o negócio, o nome é pt-BR* — logo no primeiro artefato que a aplica. **Módulo processador** é
  verbete do domínio, não jargão de infraestrutura.
- *Consequências:* `processador-<sigla em minúsculas>` amarra o nome do diretório à Sigla, que é
  imutável (RN-01) — não há espaço para divergência entre módulo, sigla e caminho no MinIO
  (`RA-19`). E `orquestrador/` **não tem `pom.xml`**: é Python dentro de um mono repo Maven, o que
  o `Makefile` e o CI de SP-3 precisam saber, e o `pom` raiz não pode listá-lo como módulo.

- [ ] **Passo 2: Conferir os 19, o rótulo e a numeração sem buraco**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "arquivos:  $(ls docs/adr/*.md | wc -l)   (esperado 19)"
echo "numeracao: $(ls docs/adr/ | grep -oE '^[0-9]{4}' | sort | tr '\n' ' ')"
echo "rotulos:   $(grep -l 'Reconstruída em SP-2; não registrada à época' docs/adr/*.md | wc -l)   (esperado 5)"
for n in 0001 0002 0003 0008 0019; do
  grep -q 'Reconstruída em SP-2' docs/adr/$n-*.md || echo "FALTA rótulo em $n"
done
```

Esperado: `19`; numeração `0001 0002 … 0019` sem buraco; `rotulos: 5`; nenhuma linha `FALTA`.

- [ ] **Passo 3: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/adr/
git commit -m "$(cat <<'EOF'
ADRs das 5 decisões cuja alternativa foi reconstruída

Linguagem, mono repositório, banco, CSV e nomes de módulo: nos cinco a
alternativa nunca foi registrada, e cada um abre declarando isso.

O rótulo não é formalidade. Um ADR que apresenta inferência como
deliberação será citado daqui a um ano como registro de algo que não
houve, e um ADR falso é pior que um ADR ausente.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `docs/riscos.md`

**Arquivos:**
- Criar: `docs/riscos.md`

**Interfaces:**
- Consome: os `ADR-NNNN` das Tarefas 1 a 3, citados no campo *Mitigação*.
- Produz: `R-01`…`R-14`, citados pelas seções *Consequências* dos ADRs e pela Tarefa 5.

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
R=docs/riscos.md
echo "registros:      $(grep -cE '^## R-[0-9]+' $R)"
echo "sem disparo:    $(awk '/^## R-/{if(t&&!d)print t; t=$0; d=0; next} /\*\*Sinal de disparo:\*\*/{d=1} END{if(t&&!d)print t}' $R | wc -l)"
echo "pendencias sem dono: $(awk '/^## R-1[234]/{f=1} f&&/\*\*(Dono|Mitigação):\*\*.*SP-/{c++} END{print c+0}' $R)"
```

Esperado agora: erro `No such file or directory`.

- [ ] **Passo 2: Escrever o cabeçalho e as regras do documento**

```markdown
# Riscos

> Artefato E0 do [`guias/guia-app-web.md`](./guias/guia-app-web.md). Registro único das três
> naturezas: riscos **aceitos**, riscos **abertos** e **pendências de desenho**.

## Como ler

Todo registro tem **sinal de disparo** — o sintoma observável que denuncia que o risco se
materializou. É o campo que não existe em nenhum outro documento do projeto: a §12 da arquitetura
diz *o que aceitamos*, e não *como descobrimos que aconteceu*. Risco aceito sem sintoma observável
é indistinguível de risco esquecido.

**Pendência resolvida não é apagada.** Passa a `Estado: resolvido em SP-N`, com o commit. É o
mesmo padrão de "aposentado" que o PRD usa para `RF` e a arquitetura para `RA` — e é o que impede
este documento de virar uma lista de coisas que já não são verdade.
```

- [ ] **Passo 3: Escrever os 8 riscos aceitos (R-01 a R-08)**

Formato de cada um, exemplificado por R-03:

```markdown
## R-03 — Fonte ausente no classpath da API

- **Natureza:** aceito (§12) · **Estado:** vigente
- **Impacto:** o PDF sai com fonte substituída, ou a exportação estoura — conforme
  `net.sf.jasperreports.awt.ignore.missing.font`
- **Sinal de disparo:** divergência visual entre o PDF exportado e o `.jrprint` de origem, ou
  `JRFontNotFoundException` no log da API
- **Mitigação:** mono repositório com versão única (RA-01, ADR-0002)
- **Se RA-01 cair:** reavaliar — é premissa de R-01 a R-04
```

Conteúdo dos oito:

| # | Impacto | Sinal de disparo | Mitigação |
|---|---|---|---|
| R-01 | `.jrprint` gravado por uma versão do Jasper não desserializa em outra | `InvalidClassException` por `serialVersionUID` ao exportar artefato de dia anterior | Versão única em todo o mono repo (ADR-0002) |
| R-02 | Desserializar objeto Java é execução de código de origem confiável apenas por premissa | Artefato no MinIO cuja origem não seja um módulo do projeto | O `.jrprint` só é escrito pela Coleta, e o bucket não é gravável pela API (ADR-0007) |
| R-03 | O PDF sai com fonte substituída, ou a exportação estoura, conforme `net.sf.jasperreports.awt.ignore.missing.font` | Divergência visual entre o PDF exportado e o `.jrprint` de origem, ou `JRFontNotFoundException` no log da API | Mono repo garante as mesmas *font extensions* no classpath (ADR-0002) |
| R-04 | Barcode e afins viram renderer serializado; sem o jar, a exportação estoura | `ClassNotFoundException` de `BarbecueRendererImpl` no log da API | Mono repo garante o jar no classpath (ADR-0002); `RA-08` obriga ao menos um relatório com renderer, para que o risco seja exercido |
| R-05 | `.jrprint` desserializado ocupa múltiplos do tamanho em disco; a API estoura o heap | `OutOfMemoryError` na API, ou latência de exportação subindo com GC | **Um teto só**: `RNF-05` (25 MB) + `RNF-06` (50.000 linhas) + semáforo de 2 (`RA-60`, ADR-0015). Afrouxar um sozinho quebra o conjunto |
| R-06 | Relatórios do mesmo produto podem enxergar instantes diferentes da base | Execução com origem `retentativa` no mesmo par data+produto de outra com origem `agendada` | Aceito: a alternativa era ficar sem o relatório até o dia seguinte (ADR-0012) |
| R-07 | Não há como interromper uma apuração sob demanda | Execução em `em processamento` que ninguém consegue encerrar antes do limite | O teto de `RN-48` torna "o dobro do tempo estimado" um número conhecido e limitado (ADR-0012, ADR-0013) |
| R-08 | O service account da API tem `manage-users` e `manage-clients`: pode tecnicamente criar um ADMINISTRADOR | Realm role `ADMINISTRADOR` atribuída fora do bootstrap de `RA-32` | Separação de espaços de nomes realm role × client role, mais o código (ADR-0005). `RF-34` exige teste dedicado |

R-01 a R-04 fecham com a linha **`Se RA-01 cair: reavaliar — é premissa de R-01 a R-04`**.

- [ ] **Passo 4: Escrever os 3 riscos abertos (R-09 a R-11)**

| # | Impacto | Sinal de disparo | Como se resolve |
|---|---|---|---|
| R-09 | Os limites do PRD §10 são estimativa, não medição; podem não caber na máquina alvo | Exportação estourando heap ou latência acima de `RNF-07`/`08`/`09` no uso real | Spike de calibração com `k6`. **Mede e não bloqueia**: enquanto não rodar, os `PROVISÓRIO` não são critério de reprovação de PR. Q10 |
| R-10 | `RA-21` foi verificado no branch `master` do MinIO; a tag fixada pelo Compose pode divergir | Webhook de expurgo que nunca dispara, **sem erro algum** — o modo de falha é silencioso | Conferência dentro do ticket que configura o expurgo: assinar `--event delete`, apagar um objeto, observar. ADR-0018 |
| R-11 | A meta de 98% pode ser inalcançável ou frouxa demais | Taxa de apuração limpa colada em 100% ou cronicamente abaixo de 98% no primeiro mês | Revisão após 30 dias de operação. Q11 |

- [ ] **Passo 5: Escrever as 3 pendências (R-12 a R-14) e a resolvida**

| # | Pendência | Dono | Sinal de disparo |
|---|---|---|---|
| R-12 | Arquitetura interna de cada módulo indefinida | **SP-3** | Dois módulos com organização de pacotes divergente no primeiro PR que os toque |
| R-13 | Relatórios de exemplo e modelos de dados indefinidos | **SP-6a** | `RA-08` não verificável: nenhum par com imagens e fontes distintas, nenhum renderer serializado no conjunto |
| R-14 | Modelagem das tabelas do schema de controle indefinida | **SP-6b** | Migration criando coluna com nome divergente do `glossario.md` |

E o exemplo do padrão, já fechado:

```markdown
## R-15 — Nomes dos módulos indefinidos

- **Natureza:** pendência de desenho · **Estado:** **resolvido em SP-2** (ADR-0019, RA-69)
- **Impacto:** cada sessão inventaria um nome de módulo, divergindo de sigla e caminho no MinIO
- **Sinal de disparo:** já não se aplica
- **Resolução:** pt-BR sem prefixo, `processador-<sigla>` amarrado à Sigla imutável
```

- [ ] **Passo 6: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
R=docs/riscos.md
echo "registros:   $(grep -cE '^## R-[0-9]+' $R)   (esperado 15: 14 vigentes + R-15 resolvido)"
echo "sem disparo: $(awk '/^## R-/{if(t&&!d)print t; t=$0; d=0; next} /\*\*Sinal de disparo:\*\*/{d=1} END{if(t&&!d)print t}' $R)"
for n in 12 13 14; do grep -A6 "^## R-$n " $R | grep -q 'SP-' || echo "R-$n sem sub-projeto dono"; done
```

Esperado: `registros: 15`, `sem disparo:` vazio, nenhuma linha sobre dono.

> Note: são **15 seções** para **14 riscos vigentes**. `R-15` é o exemplo do padrão
> "resolvido, não apagado", e por isso conta como seção mas não como risco aberto.

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/riscos.md
git commit -m "$(cat <<'EOF'
Registro de riscos, com o sinal de disparo de cada um

Reúne as três naturezas num documento só: os sete trade-offs aceitos da
§12 mais o do service account, os três abertos aguardando medição e as
três pendências de desenho com o sub-projeto dono.

O campo que não existia em lugar nenhum é o sinal de disparo. A §12 diz
o que aceitamos e não como se descobre que aconteceu; risco aceito sem
sintoma observável é indistinguível de risco esquecido.

R-05 é escrito como um teto só, e não três: os dois limites do PRD e o
semáforo da API compõem um único teto de memória, e separá-los
convidaria a afrouxar um deles sozinho.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: `RA-69`, ponteiros e saneamento

Última porque só agora todos os `ADR-NNNN` existem e podem ser apontados sem quebrar o critério 5.

**Arquivos:**
- Modificar: `docs/arquitetura-inicial.md` — §2 (nova `RA-69`), 18 linhas de `RA` espalhadas,
  §13, §14, §15

**Interfaces:**
- Consome: os 19 `ADR-NNNN` das Tarefas 1 a 3.

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
A=docs/arquitetura-inicial.md
echo "RA com ponteiro ADR: $(grep -cE '^- \*\*RA-[0-9]+\*\*.*ADR-[0-9]{4}' $A)   (esperado 20)"
echo "RA-69:               $(grep -c 'RA-69' $A)"
echo "ADR citado inexistente:"
grep -oE 'ADR-[0-9]{4}' $A | sort -u | while read a; do
  n=${a#ADR-}; ls docs/adr/$n-*.md >/dev/null 2>&1 || echo "  $a não existe"
done
```

Esperado agora: `0` ponteiros, `0` para `RA-69`, e nenhuma linha de ADR inexistente (não há
nenhum citado ainda).

- [ ] **Passo 2: Acrescentar `RA-69` ao fim da §2**

A sequência atual vai de `RA-01` a `RA-68` sem buracos, então `RA-69` é o próximo livre.

```markdown
- **RA-69** — **Nomes dos módulos.** `groupId: br.com.scheduler`. Os módulos são `comum`,
  `processador-starter`, `processador-poupanca`, `processador-cliente`,
  `processador-contacorrente`, `processador-consorcio`, `processador-emprestimo`, `api`,
  `frontend` e `orquestrador`. O nome do diretório do processador é `processador-<sigla em
  minúsculas>`, amarrado à Sigla imutável (RN-01), de modo que módulo, sigla e caminho no MinIO
  (RA-19) não possam divergir. `orquestrador/` **não tem `pom.xml`** — é Python dentro de um mono
  repo Maven, e o `pom` raiz não o lista como módulo. ADR-0019.
```

- [ ] **Passo 3: Acrescentar o ponteiro `ADR-NNNN` nas 18 `RA`**

Uma referência ao fim da linha da `RA`, **sem reescrever o texto existente**:

| `RA` | Ponteiro | | `RA` | Ponteiro |
|---|---|---|---|---|
| RA-01 | ADR-0002 | | RA-50 | ADR-0004 |
| RA-10 | ADR-0012 | | RA-56 | ADR-0011 |
| RA-16 | ADR-0007 | | RA-57 | ADR-0013 |
| RA-17 | ADR-0008 | | RA-58 | ADR-0009 |
| RA-20 | ADR-0018 | | RA-59 | ADR-0016 |
| RA-24 | ADR-0003 | | RA-60 | ADR-0015 |
| RA-26 | ADR-0015 | | RA-61 | ADR-0005 |
| RA-27 | ADR-0007 | | RA-62 | ADR-0017 |
| RA-44 | ADR-0006 | | RA-65 | ADR-0014 |
| RA-67 | ADR-0010 | | | |

São **19 `RA` nesta tabela**, mais a `RA-69` do Passo 2, que já nasce com o seu `ADR-0019`:
**20 linhas com ponteiro** ao fim da tarefa.

Dois ADRs aparecem duas vezes, porque a mesma decisão está registrada em duas normas:
`ADR-0015` (RA-26, exportação síncrona; RA-60, semáforo) e `ADR-0007` (RA-16, os dois arquivos
irmãos; RA-27, o que a exportação lê).

**`ADR-0001` é o único sem `RA` correspondente** — a escolha de linguagem e framework vive na §11
(Tech stack), não numa `RA`. Isso é esperado, e a conferência do Passo 5 não deve acusá-lo.

- [ ] **Passo 4: Atualizar §13, §14 e §15**

**§13** — acrescentar à tabela de rastreabilidade a linha:

```markdown
| RA-69 | RN-01, RN-02 |
```

**§14** — remover `- Definição dos nomes dos módulos.` de *Desenho ainda aberto* e acrescentar a
*Resolvidos nesta revisão*: `nomes dos módulos (RA-69: pt-BR sem prefixo, ADR-0019)`.

**§15** — três estados passam a "Existe":

```markdown
| [`adr/`](./adr/) | Uma decisão estruturante por arquivo | Existe |
| [`arquitetura/c4-contexto.md`](./arquitetura/c4-contexto.md) | Diagramas C4 nível 1 e 2 em Mermaid | Existe |
| [`riscos.md`](./riscos.md) | Riscos técnicos: aceitos, abertos e pendências | Existe |
```

- [ ] **Passo 5: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
A=docs/arquitetura-inicial.md
echo "RA com ponteiro ADR: $(grep -cE '^- \*\*RA-[0-9]+\*\*.*ADR-[0-9]{4}' $A)   (esperado 20)"
echo "RA-69:               $(grep -c 'RA-69' $A)   (esperado >= 2)"
grep -oE 'ADR-[0-9]{4}' $A | sort -u | while read a; do
  n=${a#ADR-}; ls docs/adr/$n-*.md >/dev/null 2>&1 || echo "ADR CITADO INEXISTENTE: $a"
done
echo "nomes dos modulos ainda pendentes: $(grep -c 'Definição dos nomes dos módulos' $A)   (esperado 0)"
```

- [ ] **Passo 6: Conferir os nove critérios de aceite da spec, de uma vez**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
A=docs/arquitetura-inicial.md
echo "1. ADRs:            $(ls docs/adr/*.md | wc -l) (esperado 19)"
echo "   numeracao:       $(ls docs/adr/ | grep -oE '^[0-9]{4}' | sort | tr '\n' ' ')"
echo "2-3. secoes:"
for f in docs/adr/*.md; do
  for s in "## Contexto" "## Opções consideradas" "## Consequências"; do
    grep -q "^$s" "$f" || echo "     FALTA '$s' em $f"
  done
  rej=$(sed -n '/^## Opções consideradas/,/^## /p' "$f" | grep -c '— rejeitada')
  sec=$(grep -cE '^## Por que não' "$f")
  [ "$rej" -eq "$sec" ] || echo "     $f: $rej rejeitadas, $sec justificativas"
done
echo "4. rotulos:         $(grep -l 'Reconstruída em SP-2' docs/adr/*.md | wc -l) (esperado 5)"
echo "5. ponteiros:       $(grep -cE '^- \*\*RA-[0-9]+\*\*.*ADR-[0-9]{4}' $A) (esperado 20)"
echo "6. riscos:          $(grep -cE '^## R-[0-9]+' docs/riscos.md) (esperado 15)"
echo "   sem disparo:     $(awk '/^## R-/{if(t&&!d)c++; t=$0; d=0; next} /\*\*Sinal de disparo:\*\*/{d=1} END{if(t&&!d)c++; print c+0}' docs/riscos.md) (esperado 0)"
echo "7. donos R-12..14:  $(for n in 12 13 14; do grep -A6 "^## R-$n " docs/riscos.md | grep -c 'SP-'; done | paste -sd+ | bc)"
echo "8. RA-69:           $(grep -c 'RA-69' $A)"
echo "9. §15 existentes:"
sed -n '/^## 15\./,$p' $A | grep '| Existe' | grep -oE '\[`[^`]+`\]' | tr -d '[]`' \
  | while read f; do [ -e "docs/$f" ] || echo "     MARCADO EXISTENTE MAS NÃO EXISTE: $f"; done
```

Se qualquer um falhar, corrija antes de commitar.

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/arquitetura-inicial.md
git commit -m "$(cat <<'EOF'
RA-69 com os nomes dos módulos, e ponteiros para os ADRs

Fixa a estrutura de módulos e liga 18 RA aos ADRs que explicam por que
elas não foram outra coisa. A RA continua sendo a norma; o ponteiro é
uma referência ao fim da linha, sem reescrever nada.

O nome do diretório do processador é derivado da Sigla, que é imutável,
de modo que módulo, sigla e caminho no MinIO não possam divergir. E
orquestrador/ fica declarado sem pom.xml, porque o Makefile e o CI de
SP-3 precisam saber disso.

Fecha E0: adr/, c4-contexto.md e riscos.md passam a existir na §15, e
os nomes dos módulos saem dos pendentes da §14.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-2 termina quando os nove critérios do Passo 6 da Tarefa 5 passam e os cinco commits estão no
branch. Com isso E0 fecha: ADRs, C4 e riscos existem.

O próximo sub-projeto é **SP-3 — Fundações do repositório (E1)**, que cria os diretórios que
`RA-69` nomeia, e cujo checkpoint é o do guia: *clone limpo roda com um comando e o CI está verde*.
