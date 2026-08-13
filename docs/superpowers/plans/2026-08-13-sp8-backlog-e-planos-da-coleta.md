# SP-8+ — Backlog de E4 e os planos da Coleta · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** entregar `docs/backlog.md` com os 32 tickets de E4 ordenados por risco, e um documento
com os oito planos da frente de Coleta.

**Arquitetura:** quatro tarefas. Três escrevem o backlog em blocos revisáveis isoladamente; a quarta
escreve os oito planos, abrindo com o bloco de premissas sobre as assinaturas de SP-7.

**Ferramentas:** Markdown, `git`, `grep` para a conferência de cobertura.

**Spec:** [`docs/superpowers/specs/2026-08-13-sp8-loop-de-features-design.md`](../specs/2026-08-13-sp8-loop-de-features-design.md)

---

## Restrições globais

- **O ticket referencia a história; não a duplica.** `user-stories.md` é a issue; o ticket é a
  unidade de PR.
- **Ordenação por risco decrescente**, com o bloco A à frente.
- **Todo RF ativo do PRD aparece em algum ticket** — critério de aceite 3.
- **PR pequeno:** tamanho `G` é sinal de que o ticket deveria ser dois. Só os produtos e as telas
  levam `G`, e por carregarem JRXML e componente visual.
- **Idioma:** pt-BR. **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Nota sobre o formato deste plano

As entregas são documentos. O plano traz **a lista integral dos 32 tickets** com história, RFs,
aceite e dependência — que é o conteúdo que não pode ser inventado na hora — e, para os oito planos,
**o teste-chave de cada um**, que é onde mora o valor. O que falta é redigir.

---

## Tarefa 1: `docs/backlog.md` — blocos A e B

**Arquivos:**
- Criar: `docs/backlog.md`

**Interfaces:**
- Produz: os identificadores `T-01` a `T-13`, referenciados pela Tarefa 4.

- [ ] **Passo 1: Escrever o cabeçalho**

```markdown
# Backlog — E4

> A fila de trabalho da fase E4. Cada ticket é uma unidade de PR: se você não revisa em 15
> minutos, o escopo estava errado.
>
> **Ordenado por risco decrescente**, não por dependência nem por valor percebido. Os seis
> primeiros podem invalidar decisão de arquitetura — é melhor descobrir com 6 tickets feitos do
> que com 25. É a mesma lógica que pôs `R-16` no primeiro degrau de SP-7.

## Como ler

- **História** aponta `user-stories.md`. O ticket não duplica a história.
- **Aceite** é uma frase verificável, herdada da história.
- **Tamanho:** P (uma sessão curta) · M (uma sessão) · G (deveria ser dois, e não é por carregar
  JRXML ou componente visual).
```

- [ ] **Passo 2: Escrever o bloco A — os seis que podem invalidar arquitetura**

| # | Ticket | História | RFs | Risco | Depende | Tam. |
|---|---|---|---|---|---|---|
| T-01 | Publicação do catálogo pelo módulo ao iniciar | HS-10 | RF-44, RF-27 | destrava | SP-7 | M |
| T-02 | Produto CLIENTE, com a *font extension* da fonte C | — | `RA-08` | **`R-03`** | T-01 | G |
| T-03 | Produto CONSORCIO, com o barcode | — | `RA-08` | **`R-04`** | T-01 | G |
| T-04 | Exportação XLSX contínua | HU-02 | RF-21 | `RA-59` | T-02 | M |
| T-05 | Semáforo de exportação | HU-03 | RF-48 | **`R-05`** | SP-7 | M |
| T-06 | Expurgo por ILM e o webhook | HS-12 | RF-56, RF-24 | **`R-10`** | SP-7 | M |

Cada um com o aceite por extenso. Os quatro que carregam risco levam a explicação:

- **T-02:** *"o PDF exportado usa a fonte C e não uma substituta"*. É o único jeito de exercitar
  `R-03` — as fontes A e B vêm no jar do Jasper e estariam no classpath por acidente.
- **T-03:** *"o barcode renderiza e a exportação não lança `ClassNotFoundException`"*. `R-04`.
- **T-04:** *"o cabeçalho de coluna aparece **exatamente uma vez** no XLSX"* (`RF-21`), e o teste é
  **por relatório**, não um só — `RA-59` diz que sem isso a convenção apodrece no primeiro relatório
  escrito por quem não leu o documento.
- **T-06:** *"assinar `--event delete`, apagar um objeto e observar o webhook"*. O README de
  lifecycle do MinIO manda usar `--event ilm`, que **não** cobre expiração — seguir a documentação
  produziria um webhook que nunca dispara, sem erro algum.

- [ ] **Passo 3: Escrever o bloco B — a frente de Coleta**

| # | Ticket | História | RFs | Depende | Tam. |
|---|---|---|---|---|---|
| T-07 | Classificar o desfecho por falha e por duração | HS-03 | RF-03, RF-04 | SP-7 | M |
| T-08 | Abortar o relatório que estourou o dobro | HS-04 | RF-05 | T-07 | M |
| T-09 | Recusar dataset acima do teto, antes de apurar | HS-08 | RF-49 | T-07 | P |
| T-10 | Retentar apenas o que não concluiu | HS-06 | RF-46, RF-09 | T-07 | G |
| T-11 | Recusar reexecução do que já concluiu bem | HS-07 | RF-08 | T-10 | M |
| T-12 | Não deixar execução presa em `em processamento` | HS-05 | RF-06 | T-08 | M |
| T-13 | Medir a apuração limpa | HS-13 | RF-52 | T-10 | M |

- [ ] **Passo 4: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "tickets A+B: $(grep -cE '^\| T-(0[1-9]|1[0-3]) \|' docs/backlog.md)  (esperado 13)"
git add docs/backlog.md
git commit -m "$(cat <<'EOF'
Backlog de E4: blocos A e B

Os seis primeiros tickets são os que podem invalidar decisão de
arquitetura, e vêm à frente por isso: a fonte C que exercita R-03, o
barcode que exercita R-04, o XLSX que testa a convenção de RA-59, o
semáforo que sustenta o teto de memória e o expurgo cuja assinatura de
evento a documentação do MinIO erra.

T-01 não ataca risco algum e mesmo assim abre a fila: sem a publicação
do catálogo, os produtos dependeriam do seed, e ADR-0009 diz que
catálogo vem do código.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `docs/backlog.md` — bloco C

**Arquivos:**
- Modificar: `docs/backlog.md`

- [ ] **Passo 1: Escrever os 19 tickets restantes**

| # | Ticket | História | RFs | Depende | Tam. |
|---|---|---|---|---|---|
| T-14 | Produto CONTACORRENTE | — | `RA-08` | T-01 | G |
| T-15 | Produto EMPRESTIMO | — | `RA-08` | T-01 | G |
| T-16 | Exportação DOCX | HU-02 | RF-19 | T-04 | P |
| T-17 | Exportação CSV a partir do `.csv.gz` | HU-02 | RF-22 | SP-7 | P |
| T-18 | Reprocessamento forçado: API dispara a DAG, com motivo e auditoria | HU-12 | RF-10, RF-11, RF-12 | T-10 | M |
| T-19 | Catálogo: editar nome, descrição e tempo estimado | HU-14 | RF-41, RF-47 | T-01 | M |
| T-20 | Catálogo: inativar produto e relatório, preservando referências | HU-14, HS-11 | RF-50, RF-54 | T-19 | M |
| T-21 | Autocadastro público de RELATOR | HU-04 | RF-29, RF-30 | SP-7 | M |
| T-22 | Troca e recuperação de senha | HU-05 | RF-37 | T-21 | P |
| T-23 | Gerente: criar roles de relatório e vinculá-las | HU-06 | RF-31 | SP-7 | M |
| T-24 | Gerente: grupos, e incluir ou remover usuários | HU-07 | RF-32, RF-33, RF-36 | T-23 | M |
| T-25 | Gerente não cria nem promove a GERENTE ou ADMINISTRADOR | HU-08 | RF-34, RF-18 | T-23 | P |
| T-26 | Revogação em bloco ao remover role ou grupo | HU-10 | RF-43 | T-24 | P |
| T-27 | Remover um RELATOR | HU-09 | RF-35 | T-24 | P |
| T-28 | Histórico de downloads com identificadores congelados | HU-13 | RF-23, RF-51 | SP-7 | M |
| T-29 | Telas do Relator | HU-01, HU-02, HU-03 | RF-13 a RF-16 | SP-5, T-04 | G |
| T-30 | Telas do Gerente e do Administrador | HU-06 a HU-14 | RF-23, RF-31 a RF-41 | T-29 | G |
| T-31 | Observabilidade: métricas, logs e traces | HS-13 | `RA-36` a `RA-40` | T-13 | M |
| T-32 | Segurança (E5) e release (E6) | — | `threat-model`, OWASP, runbook, CHANGELOG | T-30 | M |

Dois aceites merecem cuidado ao redigir:

- **T-25:** *"não consegue promover **nem por manipulação direta da requisição**"* (`RF-34`). O
  aceite precisa dizer isso, senão o teste verifica só a ausência do botão na tela.
- **T-28:** *"o histórico exibe os identificadores **como estavam no momento do download**, mesmo
  após edição de nome ou inativação"* (`RF-51`). Sem essa frase, alguém implementa com `JOIN` e o
  download de 2026 aparece com o nome de 2027.

- [ ] **Passo 2: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "total de tickets: $(grep -cE '^\| T-[0-9]{2} \|' docs/backlog.md)  (esperado 32)"
echo "tamanhos G:       $(grep -cE '^\| T-[0-9]{2} \|.*\| G \|' docs/backlog.md)  (esperado 5)"
git add docs/backlog.md
git commit -m "$(cat <<'EOF'
Backlog de E4: bloco C

Dezenove tickets, do segundo par de produtos às telas, à observabilidade
e ao release. São os mais frágeis do backlog, por estarem mais longe do
que se sabe hoje.

Cinco tickets levam tamanho G, e os cinco carregam JRXML ou componente
visual. Nos demais, G seria sinal de que o ticket deveria ser dois.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Conferência de cobertura de RF

**Arquivos:**
- Modificar: `docs/backlog.md` (acrescenta a matriz ao final)

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
rf_prd()  { grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u; }
rf_feito(){ grep -oE 'RF-[0-9]+' docs/superpowers/specs/2026-08-13-sp7-esqueleto-e-fatia-vertical-design.md | sort -u; }
rf_back() { grep -oE 'RF-[0-9]+' docs/backlog.md | sort -u; }
echo "RF sem ticket e sem SP-7:"
comm -23 <(rf_prd) <(cat <(rf_feito) <(rf_back) | sort -u)
```

Esperado: alguns RFs aparecem — são os que faltam cobrir.

- [ ] **Passo 2: Acrescentar os RFs faltantes aos tickets existentes**

Não crie ticket novo sem necessidade: a maioria dos RFs faltantes pertence a um ticket que já
existe e cujo campo de RFs ficou incompleto. Os 5 RFs aposentados (RF-07, RF-25, RF-26, RF-28,
RF-42) **não** precisam de ticket.

- [ ] **Passo 3: Escrever a matriz ao final do `backlog.md`**

```markdown
## Cobertura

| RF | Onde | |  RF | Onde |
|---|---|---|---|---|
| RF-01 | SP-7 | | RF-29 | T-21 |
| RF-02 | SP-7 | | RF-30 | T-21 |
| ... | | | ... | |
| RF-07 | *aposentado* | | RF-56 | T-06 |
```

- [ ] **Passo 4: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
rf_prd()  { grep -oE '^\| \*\*RF-[0-9]+\*\*' docs/prd.md | grep -oE 'RF-[0-9]+' | sort -u; }
faltando=$(comm -23 <(rf_prd) <(grep -oE 'RF-[0-9]+' docs/backlog.md | sort -u) | tr '\n' ' ')
echo "RF ausentes do backlog: ${faltando:-nenhum}"
echo "(os que aparecerem precisam estar cobertos por SP-7 ou marcados como aposentados)"
git add docs/backlog.md
git commit -m "$(cat <<'EOF'
Matriz de cobertura do backlog

Todo RF ativo tem ticket, está feito em SP-7, ou está marcado como
aposentado. A matriz torna a pergunta "esse requisito tem dono?"
respondível por leitura, em vez de por busca.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Os oito planos da frente de Coleta

**Arquivos:**
- Criar: `docs/superpowers/plans/2026-08-13-e4-frente-de-coleta.md`

- [ ] **Passo 1: Escrever o bloco de premissas**

Abre o documento. É o que torna a revisão localizada quando SP-7 entregar algo diferente:

```markdown
## Premissas sobre SP-7

Os oito planos assumem estas assinaturas. **Se SP-7 entregar diferente, revise o plano indicado
antes de executá-lo** — não adapte na hora.

| Assinatura | Usada por |
|---|---|
| `ApurarRelatorio.apurar(String codigo, LocalDate data) → Execucao` | P2, P3, P4, P5 |
| `PreencherRelatorio.preencher(String codigo, LocalDate data) → JasperPrint` | P3, P4 |
| `RepositorioDeArtefatos.gravar(...) → List<String>` | P2 |
| `DataSourcePaginado` — já verifica o limite a cada avanço | P3 |
| `ExecucaoRepositorio.concluir(long id, String status, Instant fim)` | P2, P5, P7 |
| Schema `controle` com os dois triggers (SP-6b) | P5, P6, P7 |
| DAG `coleta_diaria` com `reserva_do_ciclo` e `apura_poupanca` | P1, P7 |
```

- [ ] **Passo 2: Escrever P1 e P2**

**P1 — T-01 · Publicação do catálogo ao iniciar**

Teste-chave:

```java
@Test
void codigo_de_relatorio_duplicado_impede_o_modulo_de_subir() {
    // RN-03 e RF-44: a violacao impede o produto de iniciar. NAO e validacao
    // de formulario — e validacao de inicializacao. Um modulo que subisse com
    // codigo duplicado publicaria catalogo inconsistente e so falharia na
    // apuracao, de madrugada.
    var contexto = new SpringApplicationBuilder(Aplicacao.class)
        .properties("scheduler.relatorios[0].codigo=POUPANCA-0001",
                    "scheduler.relatorios[1].codigo=POUPANCA-0001");
    assertThatThrownBy(contexto::run)
        .hasMessageContaining("codigo de relatorio duplicado: POUPANCA-0001");
}
```

Mais: a publicação é **idempotente** e **não apaga** — `RA-58` diz que a aplicação guarda apenas o
que é mutável (nome, descrição, tempo estimado) e nunca cria nem apaga linhas de catálogo. Um
`UPSERT` que sobrescrevesse o nome editado desfaria `RF-41` a cada reinício.

**P2 — T-07 · Classificar o desfecho por falha e por duração**

Teste-chave — é o que registra **D02**:

```java
@Test
void o_erro_sempre_prevalece_sobre_o_alerta() {
    // D02, RN-12: execucao com falha termina em 'processado com erro' MESMO
    // tendo ultrapassado o tempo estimado. E a decisao mais facil de perder
    // ao implementar, porque as duas condicoes sao verdadeiras ao mesmo tempo.
    var execucao = apurarComFalhaApos(Duration.ofSeconds(300), estimado(120));
    assertThat(execucao.status()).isEqualTo("processado com erro");
}

@Test
void duracao_acima_do_estimado_sem_falha_termina_em_alerta() {
    // RN-11: o artefato e valido e utilizavel; o alerta sinaliza degradacao
    // de desempenho, nao de conteudo.
    var execucao = apurarComSucessoApos(Duration.ofSeconds(300), estimado(120));
    assertThat(execucao.status()).isEqualTo("processado com alerta");
}

@Test
void a_duracao_e_comparada_com_o_tempo_COPIADO_na_execucao() {
    // RN-47: o tempo estimado vive dentro da execucao. Editar o catalogo
    // depois nao pode reclassificar esta execucao.
    var execucao = apurarComSucessoApos(Duration.ofSeconds(150), estimado(120));
    editarCatalogo("POUPANCA-0001", 600);
    assertThat(recarregar(execucao).status()).isEqualTo("processado com alerta");
}
```

- [ ] **Passo 3: Escrever P3 e P4**

**P3 — T-08 · Abortar o relatório que estourou o dobro**

Teste-chave:

```java
@Test
void o_relatorio_e_abortado_no_dobro_e_os_irmaos_continuam() {
    // RN-13, RF-05: o limite do relatorio e regra de negocio e alimenta a
    // metrica. Os DEMAIS relatorios do mesmo produto continuam — e esta e a
    // parte que se esquece, porque abortar o produto inteiro e mais simples
    // de escrever.
    var execucoes = apurarProduto("POUPANCA", comRelatorioLento("POUPANCA-0001"));

    assertThat(statusDe(execucoes, "POUPANCA-0001")).isEqualTo("processado com erro");
    assertThat(statusDe(execucoes, "POUPANCA-0002")).isEqualTo("processado com sucesso");
}
```

**P4 — T-09 · Recusar dataset acima do teto, antes de apurar**

Teste-chave — e a razão de não usar volume real:

```java
@Test
void dataset_acima_do_teto_e_recusado_ANTES_de_apurar() {
    // RA-64, RN-52: conta as linhas antes. Sem isso, o teto so se
    // manifestaria como falha de memoria na exportacao, dias depois e em
    // outro modulo.
    //
    // O teste injeta o resultado da contagem em vez de materializar 50.000
    // linhas: o seed de SP-6a e medio de proposito, e um seed que estourasse
    // o teto faria toda apuracao do produto falhar.
    var contador = contagemFixa(50_001);
    var execucao = new ApurarRelatorio(..., contador).apurar("POUPANCA-0001", data);

    assertThat(execucao.status()).isEqualTo("processado com erro");
    assertThat(execucao.motivo()).contains("50000");   // motivo explicito
    verify(preencher, never()).preencher(any(), any());  // nao chegou a apurar
}
```

A última linha é a que importa: prova que a recusa aconteceu **antes**, e não depois de renderizar.

- [ ] **Passo 4: Escrever P5 e P6**

**P5 — T-10 · Retentar apenas o que não concluiu**

```java
@Test
void a_retentativa_cria_execucao_nova_e_a_anterior_vira_nao_vigente() {
    // RN-15, RN-46: execucao em status terminal nao muda. A retentativa
    // INSERE e move o ponteiro — nunca reabre.
    var primeira = apurarComFalha("POUPANCA-0001", data);
    var segunda  = retentar("POUPANCA-0001", data);

    assertThat(segunda.id()).isNotEqualTo(primeira.id());
    assertThat(segunda.origem()).isEqualTo("retentativa");
    assertThat(vigenteDe("POUPANCA-0001", data)).isEqualTo(segunda.id());
    assertThat(recarregar(primeira).status()).isEqualTo("processado com erro"); // intacta
}

@Test
void a_retentativa_rele_apenas_o_que_nao_concluiu() {
    // RN-44, D21: uma janela BEM-SUCEDIDA por relatorio por dia. O que
    // concluiu nao e relido — e o preco aceito e que relatorios do mesmo
    // produto podem enxergar instantes diferentes da base (R-06).
    apurarProduto("POUPANCA", comFalhaEm("POUPANCA-0002"));
    var lidos = retentarProduto("POUPANCA");
    assertThat(lidos).containsExactly("POUPANCA-0002");
}
```

**P6 — T-11 · Recusar reexecução do que já concluiu bem**

```java
@Test
void a_recusa_gera_evento_de_auditoria_e_NAO_uma_execucao() {
    // RN-18: uma tentativa recusada nunca aparece como falha de apuracao.
    // Se a recusa criasse uma Execucao, contaminaria a metrica primaria.
    var antes = contarExecucoes("POUPANCA-0001", data);

    assertThatThrownBy(() -> apurar("POUPANCA-0001", data))
        .isInstanceOf(ReexecucaoRecusada.class);

    assertThat(contarExecucoes("POUPANCA-0001", data)).isEqualTo(antes);
    var evento = ultimoEventoDeAuditoria();
    assertThat(evento.tipo()).isEqualTo("reexecucao recusada");
    assertThat(evento.correlationId()).isNotBlank();   // RN-18
}
```

- [ ] **Passo 5: Escrever P7 e P8**

**P7 — T-12 · Não deixar execução presa**

```java
@Test
void o_callback_encerra_ate_a_execucao_que_nunca_chegou_a_iniciar() {
    // RA-14 e RA-68: o caso que ninguem escreve espontaneamente. A reserva
    // cria execucoes com iniciado_em NULO; se o conteiner morre antes de
    // comecar, elas ficam em 'em processamento' para sempre.
    // E o iniciado_em nulo que as distingue.
    reservarCiclo("POUPANCA", data);            // 2 execucoes, inicio nulo
    matarConteinerDoProduto("POUPANCA");
    callbackDeFalha("POUPANCA", data);

    var presas = buscarExecucoes("POUPANCA", data, "em processamento");
    assertThat(presas).isEmpty();
    assertThat(buscarExecucoes("POUPANCA", data, "processado com erro")).hasSize(2);
}
```

**P8 — T-13 · Medir a apuração limpa**

```java
@Test
void a_metrica_conta_apenas_vigentes_de_origem_agendada() {
    // RF-52 e PRD §6: reprocessamentos ficam FORA, e retentativa tem metrica
    // propria. Contar tentativas em vez de vigentes mudaria o numero sem que
    // ninguem percebesse.
    apurarComSucesso("POUPANCA-0001", data, "agendada");
    apurarComSucesso("POUPANCA-0002", data, "reprocessamento forcado");

    assertThat(taxaDeApuracaoLimpa(data)).isEqualTo(1.0);  // so a agendada conta
    assertThat(totalDeParesAvaliados(data)).isEqualTo(1);
}

@Test
void a_metrica_tem_label_de_produto_relatorio_e_origem() {
    // RA-40: sem a label de origem e impossivel separar apuracao agendada de
    // retentativa e de reprocessamento, e as metricas do PRD se contaminam.
    var amostra = registro().find("apuracao_limpa").tags();
    assertThat(amostra).containsKeys("produto", "relatorio", "origem");
}
```

- [ ] **Passo 6: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
D=docs/superpowers/plans/2026-08-13-e4-frente-de-coleta.md
echo "planos:     $(grep -cE '^## P[1-8] — ' $D)  (esperado 8)"
echo "premissas:  $(sed -n '/^| Assinatura | Usada por |/,/^$/p' $D | grep -cE '^\| .+ \| P')  (esperado 7)"
echo "cada plano tem teste-chave: $(grep -c '@Test' $D)  (esperado >= 12)"
git add $D
git commit -m "$(cat <<'EOF'
Os oito planos da frente de Coleta

Abrem com o bloco de premissas sobre as assinaturas de SP-7, e a
instrução é revisar o plano indicado se SP-7 entregar diferente — não
adaptar na hora.

Cada plano traz o teste-chave, que é onde mora o valor. Três merecem
destaque: o de P2 registra D02, que o erro prevalece sobre o alerta
mesmo com as duas condições verdadeiras ao mesmo tempo; o de P4 prova
que a recusa por teto aconteceu antes de renderizar, com um verify de
que o preenchimento nunca foi chamado; e o de P7 cobre a execução que a
reserva criou e que nunca iniciou, distinguível só pelo início nulo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-8+ termina quando os cinco critérios da spec passam e os quatro commits estão no branch.

Com isso, **a decomposição inteira está planejada**: SP-1 a SP-7 com spec e plano, e E4 com fila
ordenada e a frente mais densa preparada.

**O que não está feito:** nada. O repositório segue sem código, e SP-3 continua sendo a
pré-condição dura de SP-5, SP-6a, SP-6b e SP-7.
