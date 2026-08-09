# SP-1 — Linguagem e histórias · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** entregar `docs/glossario.md` e `docs/user-stories.md`, emendar o PRD com o RF-56 e
sanear as referências cruzadas dos documentos existentes, cumprindo a fase P0 do guia.

**Arquitetura:** não há código. São quatro entregas de documento, cada uma com uma conferência
executável antes e depois da escrita. A ordem é deliberada: o RF-56 primeiro (porque o rastreio
da tarefa 3 depende dele), depois o glossário (que fixa os nomes que as histórias usam), depois
as histórias, e por fim o saneamento (que só pode afirmar "Existe" quando os arquivos existirem).

**Ferramentas:** Markdown, `git`, e `grep`/`comm`/`sort` para as conferências. Nenhuma dependência
nova, nenhum script versionado.

**Spec:** [`docs/superpowers/specs/2026-08-09-sp1-linguagem-e-historias-design.md`](../specs/2026-08-09-sp1-linguagem-e-historias-design.md)

---

## Restrições globais

Valem para **todas** as tarefas. Copiadas da spec.

- **Idioma dos documentos:** pt-BR.
- **Identificadores do domínio:** pt-BR **sem acento** (`execucao`, `data_referencia`, `Execucao`).
  Nomes de framework, infraestrutura e padrões técnicos permanecem em inglês.
- **Identificadores `RF-NN` / `RN-NN` / `RA-NN` são permanentes.** Nunca renumerar nem reaproveitar.
  Requisito novo recebe o próximo número livre; descartado é marcado *Aposentado* e permanece listado.
- **Um termo, uma definição.** Sinônimo não ganha verbete — ganha uma linha `ver X`.
- **Nenhuma história contém Given/When/Then.** Os cenários nascem em E3 (SP-7), como `.feature`.
- **SP-1 altera o conteúdo do PRD exatamente uma vez:** o RF-56. Todo o resto é correção de referência.
- **Fronteira com SP-6b:** o glossário fixa o **nome** de tabela, classe e campos de domínio.
  Não fixa tipo, chave, índice nem campo técnico (`id`, `criado_em`, colunas de junção).
- **Commits em pt-BR**, no estilo do repositório (linha de assunto imperativa, sem prefixo `feat:`).

### Nota sobre o formato deste plano

As entregas são documentos de prosa, não código. Reproduzir aqui os 42 verbetes e as 28 histórias
por extenso seria escrever a entrega duas vezes e garantir que as duas cópias divirjam. Em vez
disso, cada tarefa traz: o **template exato** do item, **exemplos completos** de cada variação do
template, a **lista integral** dos itens a produzir com a sua fonte no PRD/arquitetura, e a
**conferência executável** que decide se a tarefa terminou. Isso é o que o executor precisa; o que
falta é redação, que é o trabalho da tarefa.

---

## Tarefa 1: Emenda RF-56 ao PRD

Fecha a lacuna do F05 (expurgo automático sem requisito funcional). Precisa vir primeiro porque a
matriz da tarefa 3 rastreia HS-12 → RF-56.

**Arquivos:**
- Modificar: `docs/prd.md` — tabela de Coleta da §9, após a linha de `RF-53` (hoje linha 438)

**Interfaces:**
- Produz: o identificador `RF-56`, consumido pela matriz da Tarefa 3 (história HS-12).

- [ ] **Passo 1: Conferir que o RF-56 ainda não existe e que o PRD tem 55 RFs**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
grep -c 'RF-56' docs/prd.md
grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u | wc -l
```

Esperado: `0` na primeira linha, `55` na segunda. Se o primeiro não for `0`, pare — alguém já
usou o número e a spec precisa de outro.

- [ ] **Passo 2: Inserir a linha do RF-56**

Na tabela **### Coleta** da §9, imediatamente após a linha do `RF-53`, acrescente:

```markdown
| **RF-56** | Artefato que ultrapassa a janela de retenção é expurgado, e aquela data de referência deixa de aparecer na listagem | RN-36, RN-37 |
```

Não altere mais nada nesta tarefa. Em particular, **não** toque na §13 nem na frase da linha 411
— as duas são da Tarefa 4.

- [ ] **Passo 3: Conferir que o PRD passou a ter 56 RFs, sem quebrar nenhum outro**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u | wc -l
grep -n 'RF-56' docs/prd.md
```

Esperado: `56`, e exatamente uma linha contendo `RF-56`, dentro da tabela de Coleta.

- [ ] **Passo 4: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/prd.md
git commit -m "$(cat <<'EOF'
Acrescenta RF-56: o expurgo do artefato vencido

F05 tinha RN-36 e RN-37 descrevendo a janela de retenção e o expurgo, e
RF-24 recusando a exportação do que já foi expurgado, mas nenhum
requisito afirmava que o expurgo acontece. A funcionalidade que apaga
dado do usuário era a única sem afirmação verificável.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `docs/glossario.md`

Fonte única dos nomes. É o documento que SP-6b lê para nomear tabelas e colunas.

**Arquivos:**
- Criar: `docs/glossario.md`

**Interfaces:**
- Consome: os conceitos de `docs/prd.md` e `docs/arquitetura-inicial.md`.
- Produz: os identificadores canônicos listados no Passo 3, consumidos por SP-6a, SP-6b e SP-7,
  e os nomes de termo usados na prosa das histórias da Tarefa 3.

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
G=docs/glossario.md
echo "verbetes:      $(grep -c '^### ' $G)"
echo "duplicados:    $(grep '^### ' $G | sort | uniq -d | wc -l)"
for c in "Janela de leitura" "Data de referência" "Execução vigente" "Origem da execução" "Catálogo" "Inativação"; do
  grep -q "^### $c\$" $G || echo "FALTA conceito do PRD §7: $c"
done
```

Esperado agora: erro `No such file or directory`. É a falha que a tarefa vai corrigir.

- [ ] **Passo 2: Criar o esqueleto do documento**

```markdown
# Glossário — Scheduler Jasper Report

> Linguagem ubíqua do projeto. **Fonte única dos nomes.** Artefato P0 do
> [`guias/guia-app-web.md`](./guias/guia-app-web.md).
>
> Este documento fixa o **nome** de tabela, classe e campos de domínio. Não fixa tipo, chave,
> índice nem campo técnico (`id`, `criado_em`, colunas de junção) — isso é SP-6b, que
> **acrescenta e não renomeia**. Precisando de outro nome, a mudança volta aqui primeiro.

## Como ler

- **Um termo, uma definição.** Sinônimo não ganha verbete: ganha uma linha `Ver: X`.
- Verbete que vira dado traz o identificador canônico. Verbete conceitual declara que não tem.
- `Regras:` aponta as `RN-NN` do [`prd.md`](./prd.md) e as `RA-NN` da
  [`arquitetura-inicial.md`](./arquitetura-inicial.md) que governam o termo.

## Idioma

Identificadores do **domínio** em pt-BR sem acento: `execucao`, `data_referencia`, `Execucao`,
`tempo_estimado_segundos`. É o que evita a costura de um campo em inglês guardando um literal
pt-BR — e o PRD já impõe literais pt-BR nas siglas (`POUPANCA`), nos códigos (`CLIENTE-0005`) e
nos quatro status (`processado com sucesso`).

Permanecem em **inglês**: nomes de framework, biblioteca e infraestrutura (`Spring Batch`,
`JasperPrint`, `bucket`, `realm role`, `client role`), padrões e siglas consagradas (`JWT`, `S3`,
`ILM`, `MDC`) e a terminologia de teste (`Gherkin`, `feature`, `step definition`).

A fronteira: **se o conceito existe para o negócio, o nome é pt-BR; se existe apenas porque a
tecnologia existe, o nome é o da tecnologia.**
```

- [ ] **Passo 3: Escrever os 42 verbetes, em seis grupos**

Template — variação **A, entidade com dado**:

```markdown
### Execução
Registro imutável de uma tentativa de apuração de um relatório numa data de referência.

- Tabela:  `execucao`
- Classe:  `Execucao`
- Campos:  `data_referencia`, `status`, `origem`, `vigente`, `tempo_estimado_segundos`,
           `iniciado_em`, `finalizado_em`
- Regras:  RN-09, RN-46, RN-47, RN-51, RA-67
- Não confundir com: Ciclo, Janela de leitura
```

Template — variação **B, conceito sem dado**:

```markdown
### Janela de leitura
O intervalo em que um módulo processador lê a base transacional do seu produto, dentro de uma
execução do ciclo. Existe no máximo uma janela bem-sucedida por relatório por dia; uma janela
que falhou não entregou artefato e pode ser reaberta pela retentativa.

- Identificador: não tem — é conceito, não dado persistido.
- Regras:  RN-44, RA-10
- Não confundir com: Ciclo, Janela de retenção
```

Template — variação **C, enumeração de valores**:

```markdown
### Status
Situação de uma Execução. Quatro valores, dos quais apenas o primeiro não é terminal.

- Enum:    `StatusExecucao`
- Campo:   `execucao.status`
- Valores: `em processamento` · `processado com sucesso` · `processado com alerta` ·
           `processado com erro`
- Regras:  RN-11, RN-12, RN-15, RN-42, PRD §8.3
- Não confundir com: Origem da execução
```

Os 42 verbetes, com a fonte de cada um. **A coluna "Identificador" diz qual variação de template
usar**; onde há nome, use exatamente esse nome.

**Grupo 1 — Catálogo**

| Verbete | Identificador | Fonte |
|---|---|---|
| Produto | `produto` / `Produto` · campos `sigla`, `nome`, `ativo` | RN-01, RN-05, RA-04 |
| Sigla | campo `produto.sigla` — regex `^[A-Z]{1,20}$`, imutável | RN-01, RA-19 |
| Relatório | `relatorio` / `Relatorio` · campos `codigo`, `nome`, `descricao`, `tempo_estimado_segundos`, `ativo` | RN-02, RN-04, RA-07 |
| Código do relatório | campo `relatorio.codigo` — regex `^[A-Z]{1,20}-\d{4}$`, imutável | RN-02, RN-03 |
| Tempo estimado | campo `relatorio.tempo_estimado_segundos` — segundos inteiros > 0 | RN-04, RN-47, RN-48 |
| Catálogo | conceito (B) — derivado do código, não criado pela aplicação | RN-49, RN-50, RA-58 |
| Inativação | campo `ativo` — retirada do catálogo visível sem remoção física | RN-05, RN-50, RA-62 |
| Módulo processador | conceito (B) — o módulo **é** o produto | RA-03, RA-04, RA-10 |

**Grupo 2 — Coleta**

| Verbete | Identificador | Fonte |
|---|---|---|
| Coleta | conceito (B) — única fronteira de leitura da base transacional | RN-06, RA-09, RA-10 |
| Ciclo | conceito (B) — uma execução diária da DAG, 03h00 | RNF-03, RNF-20, RA-65 |
| Reserva do ciclo | conceito (B) — primeira task, cria Execução por relatório ativo | RN-45, RA-54 |
| Janela de leitura | conceito (B) — exemplo do template acima | RN-44, RA-10 |
| Data de referência | campo `execucao.data_referencia` — dia do disparo, nunca informada | RN-07, RN-54, RA-19, RA-52 |
| Execução | entidade (A) — exemplo do template acima | RN-09, RN-46, RN-51, RA-67 |
| Execução vigente | campo `execucao.vigente` — **ponteiro, não status** | RN-16, RN-46 |
| Origem da execução | enum (C) `OrigemExecucao` · `agendada`, `retentativa`, `reprocessamento forcado` | RN-46, RA-40 |
| Status | enum (C) — exemplo do template acima | RN-11, RN-12, RN-15, RN-42 |
| Retentativa | valor de `execucao.origem` — relê **apenas** o que não concluiu | RN-44, RNF-17, RF-46 |
| Reprocessamento forçado | valor de `execucao.origem` — exige motivo, sobrescreve artefatos | RN-20, RN-21, RA-12, RA-13 |
| Limite do relatório | conceito (B) — 2× o tempo estimado; regra de negócio | RN-13, RA-57 |
| Limite de segurança do produto | conceito (B) — `execution_timeout` da task; interruptor de emergência | RN-13, RA-57 |

**Grupo 3 — Artefato e retenção**

| Verbete | Identificador | Fonte |
|---|---|---|
| Artefato | `artefato` / `Artefato` · campos `caminho`, `tipo`, `tamanho_bytes`, `expurgado` | RN-08, RA-16, RNF-05 |
| `.jrprint` | valor de `artefato.tipo` — `JasperPrint` serializado; serve PDF, XLSX, DOCX | RA-16, RA-27 |
| `.csv.gz` | valor de `artefato.tipo` — dataset bruto comprimido; serve CSV | RA-16, RA-17 |
| Dataset | conceito (B) — resultado da consulta principal; teto de 50.000 linhas | RN-34, RN-52, RNF-06, RA-64 |
| Repositório de artefatos | conceito (B) — MinIO, padrão S3 | RA-18, RA-19 |
| Janela de retenção | conceito (B) — 7 dias da data de referência, configurável | RN-36, RNF-12, RA-20 |
| Expurgo | campo `artefato.expurgado` — remoção automática por política do bucket | RN-37, RN-39, RA-20, RA-21, RA-63 |

**Grupo 4 — Exportação**

| Verbete | Identificador | Fonte |
|---|---|---|
| Exportação | conceito (B) — síncrona, sem status persistido, nunca lê base transacional | RN-30, RN-31, RA-26 |
| Formato | campo `download.formato` · `PDF`, `XLSX`, `DOCX`, `CSV` | RN-32, RN-33, RN-34 |
| Download | `download` / `Download` · campos `usuario`, `codigo_relatorio`, `nome_relatorio`, `sigla_produto`, `data_referencia`, `formato`, `baixado_em` — **cópia dos identificadores**, não chaves | RN-35, RA-66 |
| Histórico de downloads | conceito (B) — retenção indefinida, independente do artefato | RN-38, RA-22, RA-66 |

**Grupo 5 — Identidade e acesso**

| Verbete | Identificador | Fonte |
|---|---|---|
| Perfil | **realm role** do Keycloak · `ADMINISTRADOR`, `GERENTE`, `RELATOR` — conjunto fechado, em código | PRD §3.2, RN-26, RA-61 |
| Role de relatório | **client role** do cliente `relatorios` — conjunto aberto, criado pelo GERENTE | RN-22, RN-26, RA-61 |
| Grupo | grupo nativo do Keycloak, com client roles mapeadas | RN-22, RA-61 |
| Cadeia de permissão | conceito (B) — Relatório → Role de relatório → Grupo → Usuário, todos N:N, acesso pela união. O elo Relatório→Role é tabela `relatorio_role` no schema de controle | RN-22, RN-23, RN-24, RA-61 |
| Pendente de vínculo | conceito (B) — estado derivado: RELATOR sem grupo. Entra na aplicação, listagem vazia | RN-27, RN-28, RF-16 |
| Autocadastro | conceito (B) — página de registro do Keycloak; cria **exclusivamente** RELATOR | RN-27, RA-33 |

**Grupo 6 — Diagnóstico e dados**

| Verbete | Identificador | Fonte |
|---|---|---|
| Correlation ID | campo `evento_auditoria.correlation_id` — é o `traceId` do OpenTelemetry, propagado por MDC | RN-40, RN-41, RA-37 |
| Evento de auditoria | `evento_auditoria` / `EventoAuditoria` · campos `tipo`, `solicitante`, `motivo`, `correlation_id`, `ocorrido_em` | RN-18, RN-21 |
| Schema de controle | conceito (B) — escrito pela Coleta, pelo orquestrador e pela API | RA-23, RA-25 |
| Schema transacional | conceito (B) — um por produto; **só a Coleta lê** | RA-10, RA-23, RA-29 |

- [ ] **Passo 4: Escrever a seção "Termos que não usamos"**

É a seção que protege as decisões já tomadas — elas estão expressas como *ausência* de algo, e
ausência não se infere de exemplos.

```markdown
## Termos que não usamos

| Termo | Por que não | Use |
|---|---|---|
| Cancelar, cancelamento | Saiu do escopo (PRD §5, D20). O único interruptor é o tempo | Limite do relatório · Limite de segurança do produto |
| Reprocessar (para retentativa) | Retentativa e Reprocessamento forçado são **origens distintas** (RN-46), com regras e métricas próprias | o termo exato dos dois |
| Job, batch job, processamento | Não são termos do domínio | Execução · Ciclo |
| Cadastrar produto, criar relatório | Não existem: o catálogo é derivado do código (RN-49) | publicar catálogo · editar · inativar |
| Excluir, deletar (catálogo) | Nada do catálogo é removido fisicamente (RN-50) | Inativação |
| Data de execução | Ambíguo com Data de referência, que é o dia do disparo (RN-07) | Data de referência · `iniciado_em` |
| Relatório pronto, relatório gerado | Não distinguem execução de artefato | Execução vigente · Artefato |
| Fila de exportação | Não há fila: o excedente é recusado de imediato (RN-53) | Semáforo de exportações |
```

- [ ] **Passo 5: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
G=docs/glossario.md
echo "verbetes:      $(grep -c '^### ' $G)"
echo "duplicados:    $(grep '^### ' $G | sort | uniq -d | wc -l)"
for c in "Janela de leitura" "Data de referência" "Execução vigente" "Origem da execução" "Catálogo" "Inativação"; do
  grep -q "^### $c\$" $G || echo "FALTA conceito do PRD §7: $c"
done
```

Esperado: `verbetes: 42`, `duplicados: 0`, nenhuma linha `FALTA`.

- [ ] **Passo 6: Conferir que todo verbete declara identificador ou a ausência dele**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
awk '/^### /{if(t&&!ok)print "SEM IDENTIFICADOR: " t; t=$0; ok=0; next} \
     /^- (Tabela|Classe|Campo|Campos|Enum|Identificador|Ver):/{ok=1} \
     /^## /{if(t&&!ok)print "SEM IDENTIFICADOR: " t; t=""} \
     END{if(t&&!ok)print "SEM IDENTIFICADOR: " t}' docs/glossario.md
```

Esperado: nenhuma saída. Se algum verbete aparecer, ele viola o critério de aceite 4 — acrescente
a linha `Identificador: não tem — é conceito, não dado persistido.`

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/glossario.md
git commit -m "$(cat <<'EOF'
Glossário: 42 verbetes com identificador canônico

Fixa a linguagem ubíqua e, com ela, o nome de cada tabela, classe e
campo de domínio, para que SP-6b não precise inventá-los. Identificador
do domínio em pt-BR sem acento; nome de tecnologia em inglês, com a
regra de fronteira escrita no próprio documento.

Inclui a seção de termos que não usamos: as decisões do PRD que estão
expressas como ausência de algo e por isso não se inferem de exemplos.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: `docs/user-stories.md`

**Arquivos:**
- Criar: `docs/user-stories.md`

**Interfaces:**
- Consome: `RF-56` (Tarefa 1) e os nomes de termo de `docs/glossario.md` (Tarefa 2).
- Produz: os identificadores `HU-01`…`HU-15` e `HS-01`…`HS-13`, e os nomes de arquivo `.feature`
  da coluna 3 da matriz — consumidos por SP-7, que cria esses arquivos.

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
U=docs/user-stories.md
rf_prd() { grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u; }
rf_us()  { grep -oE 'RF-[0-9]+' $U | sort -u; }
echo "só no PRD:  $(comm -23 <(rf_prd) <(rf_us) | tr '\n' ' ')"
echo "só nas US:  $(comm -13 <(rf_prd) <(rf_us) | tr '\n' ' ')"
echo "histórias:  $(grep -cE '^### H[US]-[0-9]+' $U)"
echo "GWT (deve ser 0): $(grep -icE '^ *(Dado|Quando|Então|Given|When|Then) ' $U)"
```

Esperado agora: erro `No such file or directory` nas duas últimas linhas.

- [ ] **Passo 2: Criar o esqueleto e escrever as 15 histórias de usuário**

Cabeçalho do documento:

```markdown
# User Stories — Scheduler Jasper Report

> Artefato P0 do [`guias/guia-app-web.md`](./guias/guia-app-web.md). Cada história tem um
> critério de aceite que um teste automatizado consegue verificar.
>
> **Os cenários Given/When/Then não vivem aqui.** Eles nascem uma única vez em E3, como arquivos
> `.feature` executáveis, no caminho indicado por cada história. Duas cópias do mesmo cenário
> divergem na primeira semana.
>
> Os termos em **negrito** estão definidos no [`glossario.md`](./glossario.md).

## Como ler

- **HU-NN** — história de usuário: uma das três personas do [`prd.md`](./prd.md) §3.1.
- **HS-NN** — história de sistema: comportamento autônomo, sem persona humana pedindo.
- A matriz ao final rastreia todo requisito funcional até a sua história e ao seu `.feature`.
```

Template da história de usuário:

```markdown
### HU-02 — Baixar o relatório no formato que preciso

Como **Relator**, quero baixar um relatório já apurado em PDF, XLSX, DOCX ou CSV, para usá-lo na
ferramenta certa sem depender de ninguém para converter.

**Aceite:** a mesma requisição devolve o arquivo no formato pedido ou devolve erro; nunca um
status pendente, e apenas para **execução vigente** em `processado com sucesso` ou
`processado com alerta`.

- Cobre:    RF-19, RF-20, RF-21, RF-22
- Cenários: `exportacao.feature`
```

As 15 histórias de usuário, com o que cada uma cobre e o `.feature` de destino:

| ID | Persona | História | Cobre | `.feature` |
|---|---|---|---|---|
| HU-01 | Relator | Encontrar o relatório que preciso | RF-13, RF-14, RF-15, RF-16, RF-55 | `listagem.feature` |
| HU-02 | Relator | Baixar no formato que preciso | RF-19, RF-20, RF-21, RF-22 | `exportacao.feature` |
| HU-03 | Relator | Entender por que não consigo baixar | RF-24, RF-48, RF-38, RF-39 | `exportacao-recusada.feature` |
| HU-04 | Relator | Cadastrar-me sozinho e entrar | RF-29, RF-30 | `autocadastro.feature` |
| HU-05 | Todos | Cuidar da minha senha | RF-37 | `senha.feature` |
| HU-06 | Gerente | Organizar acesso por role de relatório | RF-31 | `roles-de-relatorio.feature` |
| HU-07 | Gerente | Dar e tirar acesso por grupo | RF-32, RF-33, RF-36 | `grupos.feature` |
| HU-08 | Gerente | Não conseguir escalar privilégio | RF-34, RF-18 | `gerente-sem-privilegio.feature` |
| HU-09 | Gerente/Admin | Remover um relator | RF-35 | `remocao-de-usuario.feature` |
| HU-10 | Gerente | Revogar em bloco removendo role ou grupo | RF-43 | `revogacao.feature` |
| HU-11 | Admin | Enxergar e exportar tudo | RF-17 | `acesso-irrestrito.feature` |
| HU-12 | Admin | Refazer uma apuração | RF-10, RF-11, RF-12 | `reprocessamento-forcado.feature` |
| HU-13 | Admin | Auditar downloads | RF-23, RF-51 | `historico-de-downloads.feature` |
| HU-14 | Admin | Ajustar o catálogo | RF-41, RF-47, RF-50 | `catalogo-administravel.feature` |
| HU-15 | Admin | Diagnosticar um erro relatado | RF-40 | `correlation-id.feature` |

Três alertas de redação, porque são os pontos onde a história mente com facilidade:

- **HU-08** cobre RF-18 (o Gerente não exporta) junto com RF-34 (não promove). São a mesma
  história — *o Gerente administra acesso e não consome relatório* — e separá-las produziria uma
  história sem valor de usuário. O aceite precisa afirmar as duas negativas, **inclusive contra
  manipulação direta da requisição** (RF-34).
- **HU-11** é a exceção de autorização do sistema (RN-24) e o PRD exige teste dedicado. O aceite
  deve dizer que o ADMINISTRADOR **não passa pela cadeia de permissão**, e não apenas que ele
  "vê tudo".
- **HU-13** cobre RF-51: o histórico exibe os identificadores **como estavam no momento do
  download**, mesmo após edição de nome ou inativação. O aceite precisa nomear essa propriedade,
  senão o cenário vira um `SELECT` com `JOIN` e o requisito se perde.

- [ ] **Passo 3: Escrever as 13 histórias de sistema**

Template — muda a primeira linha, mantém aceite e rastreio:

```markdown
### HS-01 — Reservar o ciclo antes de qualquer apuração

O sistema deve gravar uma **Execução** por relatório ativo, com início nulo, antes de subir
qualquer contêiner de processamento, para que um relatório que nunca chegue a ser apurado
apareça como falha em vez de desaparecer do denominador da métrica.

**Aceite:** ao fim da primeira task do **Ciclo**, existe exatamente uma Execução por relatório
ativo da **Data de referência**, todas com `iniciado_em` nulo.

- Cobre:    RF-45
- Cenários: `reserva-do-ciclo.feature`
```

| ID | História | Cobre | `.feature` |
|---|---|---|---|
| HS-01 | Reservar o ciclo antes de qualquer apuração | RF-45 | `reserva-do-ciclo.feature` |
| HS-02 | Apurar os relatórios ativos e gravar os artefatos | RF-01, RF-02 | `coleta.feature` |
| HS-03 | Classificar o desfecho por falha e por duração | RF-03, RF-04 | `desfecho-da-execucao.feature` |
| HS-04 | Abortar o relatório que estourou o dobro, sem derrubar os irmãos | RF-05 | `limite-de-tempo.feature` |
| HS-05 | Não deixar execução presa em `em processamento` | RF-06 | `execucao-anomala.feature` |
| HS-06 | Retentar apenas o que não concluiu | RF-46, RF-09 | `retentativa.feature` |
| HS-07 | Recusar reexecução do que já concluiu bem | RF-08 | `unicidade-da-execucao.feature` |
| HS-08 | Recusar dataset acima do teto, antes de apurar | RF-49 | `teto-do-dataset.feature` |
| HS-09 | Nunca aceitar data de referência como entrada | RF-53 | `sem-retroatividade.feature` |
| HS-10 | Publicar o catálogo ao iniciar, ou não iniciar | RF-44, RF-27 | `publicacao-do-catalogo.feature` |
| HS-11 | Preservar o que foi inativado | RF-54 | `inativacao.feature` |
| HS-12 | Expurgar o artefato vencido | RF-56 | `expurgo.feature` |
| HS-13 | Medir a apuração limpa | RF-52 | `metrica-de-apuracao-limpa.feature` |

Dois alertas de redação:

- **HS-03** carrega D02, a decisão mais fácil de perder: **o erro sempre prevalece sobre o
  alerta**. O aceite tem de afirmar o caso combinado — falhou *e* estourou o tempo termina em
  `processado com erro`.
- **HS-07** trata a recusa como **evento de auditoria e não como Execução** (RN-18). O aceite
  precisa dizer que nenhuma Execução nova é criada, senão a tentativa recusada apareceria como
  falha de apuração e contaminaria a métrica.

- [ ] **Passo 4: Escrever a matriz de rastreabilidade**

Uma linha por RF, em ordem numérica, incluindo os aposentados:

```markdown
## Matriz de rastreabilidade

| RF | História | Cenários |
|---|---|---|
| RF-01 | HS-02 | `coleta.feature` |
| ... | | |
| RF-07 | *Aposentado* — cancelamento saiu do escopo | — |
| ... | | |
| RF-56 | HS-12 | `expurgo.feature` |
```

Os cinco aposentados, que entram com o motivo e sem história: **RF-07** (cancelamento saiu do
escopo), **RF-25** e **RF-26** (cadastro de produto e de relatório não existem — catálogo
derivado do código), **RF-28** (substituído por RF-50), **RF-42** (não há remoção de relatório,
há inativação).

- [ ] **Passo 5: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
U=docs/user-stories.md
rf_prd() { grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u; }
rf_us()  { grep -oE 'RF-[0-9]+' $U | sort -u; }
echo "só no PRD:  $(comm -23 <(rf_prd) <(rf_us) | tr '\n' ' ')"
echo "só nas US:  $(comm -13 <(rf_prd) <(rf_us) | tr '\n' ' ')"
echo "histórias:  $(grep -cE '^### H[US]-[0-9]+' $U)"
echo "GWT (deve ser 0): $(grep -icE '^ *(Dado|Quando|Então|Given|When|Then) ' $U)"
```

Esperado: as duas primeiras linhas **vazias** após os dois-pontos, `histórias: 28`, `GWT: 0`.

- [ ] **Passo 6: Conferir que cada RF ativo aparece em exatamente uma linha da matriz**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
sed -n '/## Matriz de rastreabilidade/,$p' docs/user-stories.md \
  | grep -oE '^\| RF-[0-9]+' | grep -oE 'RF-[0-9]+' | sort | uniq -d
```

Esperado: nenhuma saída. Qualquer RF listado aqui está em duas linhas da matriz e viola o
critério de aceite 1.

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/user-stories.md
git commit -m "$(cat <<'EOF'
User stories: 15 de usuário, 13 de sistema e a matriz de rastreio

Cada história traz o aceite em uma frase verificável e aponta o arquivo
.feature que SP-7 vai criar. Os Given/When/Then ficam de fora de
propósito: nascem uma única vez em E3, já executáveis.

O comportamento autônomo da Coleta entra como história de sistema, sem
persona forçada — o Administrador diagnostica e refaz, não opera o
ciclo. A matriz cobre os 56 requisitos, com os 5 aposentados marcados
para que a ausência de história seja visivelmente deliberada.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Saneamento das referências cruzadas

Vem por último porque só agora `glossario.md` e `user-stories.md` existem — antes disso, marcá-los
como "Existe" seria trocar uma referência falsa por outra.

**Arquivos:**
- Modificar: `docs/arquitetura-inicial.md` — tabela da §15
- Modificar: `docs/prd.md` — nota introdutória da §9 (hoje linhas 410-412) e tabela da §13

**Interfaces:**
- Consome: a existência de `docs/glossario.md` e `docs/user-stories.md` (Tarefas 2 e 3).

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

Todo arquivo marcado como "Existe" na §15 da arquitetura tem de existir de verdade:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
sed -n '/^## 15\./,$p' docs/arquitetura-inicial.md | grep '| Existe' \
  | grep -oE '\[`[^`]+`\]' | tr -d '[]`' \
  | while read f; do [ -e "docs/$f" ] || echo "MARCADO COMO EXISTENTE, MAS NÃO EXISTE: $f"; done
grep -c 'especificacao.md' docs/arquitetura-inicial.md
```

Esperado agora: linhas `MARCADO COMO EXISTENTE, MAS NÃO EXISTE:` para `glossario.md`, `adr/` e
`especificacao.md`; e contagem maior que zero na última linha.

- [ ] **Passo 2: Corrigir a §15 da arquitetura**

Três mudanças na tabela:

| Linha | Ação |
|---|---|
| `glossario.md` | Estado passa a **`Existe`** — a Tarefa 2 o entregou |
| `adr/` | Estado passa a **`Não existe — exigido por E0`** |
| `especificacao.md` | **Linha removida por inteiro.** O papel dela passa a ser cumprido pelas specs em `docs/superpowers/specs/`. Manter referência a um documento de outro método é fonte garantida de divergência |

Acrescente à mesma tabela a linha de `user-stories.md`:

```markdown
| [`user-stories.md`](./user-stories.md) | Eixo de produto: histórias com critério de aceite e a matriz RF → história → `.feature` | Existe |
```

Confira também a §14 (**Pendentes de definição**), que cita `especificacao.md §5.5` no bullet da
calibração com `k6`. Substitua essa referência por **PRD §10**, que é onde os `PROVISÓRIO` de
fato vivem. Deixar a citação órfã reintroduz pela porta dos fundos a referência que acabamos de
remover.

- [ ] **Passo 3: Corrigir a nota da §9 do PRD**

O texto atual (linhas 410-412) contradiz a decisão de SP-1 — ele promete Given/When/Then dentro
de `user-stories.md`. Substitua o parágrafo por:

```markdown
Cada requisito é uma afirmação verificável por teste automatizado. A história correspondente e o
seu critério de aceite vivem em [`user-stories.md`](./user-stories.md), que rastreia todo `RF-NN`
até o arquivo `.feature` que o verifica. O detalhamento em Given/When/Then vive nos próprios
arquivos `.feature`, criados em E3.
```

- [ ] **Passo 4: Acrescentar as duas linhas à §13 do PRD**

Na tabela **Documentos relacionados**, acrescente:

```markdown
| [`glossario.md`](./glossario.md) | Linguagem ubíqua. Fonte única dos nomes e dos identificadores | Existe |
| [`user-stories.md`](./user-stories.md) | Histórias com critério de aceite e a matriz RF → história → `.feature` | Existe |
```

- [ ] **Passo 5: Rodar a conferência do Passo 1 e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
sed -n '/^## 15\./,$p' docs/arquitetura-inicial.md | grep '| Existe' \
  | grep -oE '\[`[^`]+`\]' | tr -d '[]`' \
  | while read f; do [ -e "docs/$f" ] || echo "MARCADO COMO EXISTENTE, MAS NÃO EXISTE: $f"; done
echo "menções a especificacao.md: $(grep -c 'especificacao.md' docs/arquitetura-inicial.md)"
echo "GWT prometido no PRD:       $(grep -c 'Given/When/Then pertence' docs/prd.md)"
```

Esperado: nenhuma linha `MARCADO COMO EXISTENTE`, e `0` nas duas contagens.

- [ ] **Passo 6: Conferir os oito critérios de aceite da spec, de uma vez**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
rf_prd() { grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u; }
rf_us()  { grep -oE 'RF-[0-9]+' docs/user-stories.md | sort -u; }
echo "1. RF sem história:  $(comm -23 <(rf_prd) <(rf_us) | tr '\n' ' ')"
echo "2. aposentados:      $(grep -c 'Aposentado' docs/user-stories.md) (esperado >= 5)"
echo "3-4. verbetes:       $(grep -c '^### ' docs/glossario.md) (esperado 42)"
echo "5. termos repetidos: $(grep '^### ' docs/glossario.md | sort | uniq -d | wc -l) (esperado 0)"
echo "6. GWT nas US:       $(grep -icE '^ *(Dado|Quando|Então|Given|When|Then) ' docs/user-stories.md) (esperado 0)"
echo "8. RF total:         $(rf_prd | wc -l) (esperado 56)"
```

O critério 7 é o Passo 5. Se qualquer um falhar, corrija antes de commitar — a tarefa não termina
com um critério vermelho.

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/prd.md docs/arquitetura-inicial.md
git commit -m "$(cat <<'EOF'
Saneia as referências cruzadas entre PRD e arquitetura

A §15 da arquitetura marcava como existentes três documentos ausentes.
Glossário e user stories agora existem e passam a constar; adr/ fica
declarado como pendente de E0; a linha de especificacao.md sai, junto
com a citação órfã na §14, porque o papel dela passou às specs em
docs/superpowers/specs/.

A nota da §9 do PRD prometia Given/When/Then dentro de user-stories.md,
o que contradiz a decisão de manter os cenários apenas nos arquivos
.feature. Reescrita.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-1 termina quando os oito critérios do Passo 6 da Tarefa 4 passam e os quatro commits estão no
branch. O próximo sub-projeto é **SP-2 — Decisões técnicas (E0)**: ADRs, C4 nível 1 e 2, `riscos.md`
e os nomes dos módulos.
