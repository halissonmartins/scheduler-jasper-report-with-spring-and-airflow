# SP-4 — Fluxos e protótipo · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.
>
> ⚠️ **ESTE PLANO PARA NA TAREFA 4.** A Tarefa 5 depende de uma escolha humana que nenhum executor
> pode fazer sozinho. Ver "Gate humano" abaixo.

**Objetivo:** entregar os 5 fluxos escritos, um protótipo navegável descartável com variantes nos
dois pontos ambíguos, e o registro das decisões de UX.

**Arquitetura:** cinco tarefas. As três primeiras produzem artefatos; a quarta publica e **para**;
a quinta só existe depois da escolha do usuário. O protótipo é um único HTML autocontido, sem
backend e sem framework, vivendo fora de `frontend/` por decisão de projeto.

**Tech stack:** Markdown · HTML/CSS/JS puro · Artifact para publicação.

**Spec:** [`docs/superpowers/specs/2026-08-12-sp4-fluxos-e-prototipo-design.md`](../specs/2026-08-12-sp4-fluxos-e-prototipo-design.md)

---

## Gate humano

A Tarefa 4 publica o protótipo e **encerra a execução**. As variantes de navegação (A1) e de espera
(A2) existem para serem comparadas por uma pessoa, e a Tarefa 5 escreve `decisoes-ux.md` a partir
dessa escolha.

**Um executor que escolher a variante sozinho destrói o propósito de P1.** A divergência existe
porque nenhum documento do projeto responde a essas duas perguntas; inventar a resposta e registrá-la
como decisão de UX seria pior do que não ter protótipo — passaria a constar como deliberação algo
que foi um chute.

Se a escolha não estiver disponível, **pare na Tarefa 4 e reporte**.

---

## Restrições globais

Valem para **todas** as tarefas. Copiadas da spec.

- **Idioma:** pt-BR em documento, interface do protótipo e mensagem de commit.
- **Nenhum arquivo do protótipo em `frontend/`.** Ele vive em `docs/design/prototipo/`. Critério de
  aceite 9.
- **O protótipo é fachada:** não autentica, não valida, não trata erro de rede, não persiste estado.
- **Wireframes seguem a regra de baixa fidelidade:** só tons de cinza, borda tracejada, sem ícone,
  sem tipografia de marca, rótulo `WIREFRAME` no canto.
- **Dados falsos usam o catálogo real** — as 5 siglas de `RA-04` e códigos no formato `SIGLA-NNNN`.
  Conteúdo genérico esconderia o problema de layout que as siglas longas causam.
- **Sem design system.** Cor e espaçamento no protótipo são descartáveis; o padrão visual é SP-5.
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Nota sobre o formato deste plano

Os **dados falsos** e o **CSS da regra de baixa fidelidade** aparecem completos e literais: são
curtos e são exatamente o que os critérios 5 e 6 verificam. Os **fluxos** e as **variantes** vêm
como requisito funcional preciso mais a estrutura — o HTML de três navegações completas seria
reproduzir a entrega dentro do plano. O que falta é construir, que é o trabalho.

---

## Tarefa 1: `docs/design/fluxos.md`

**Arquivos:**
- Criar: `docs/design/fluxos.md`

**Interfaces:**
- Produz: os identificadores `F1`–`F5`, referenciados pelo protótipo (Tarefas 2 e 3) e por
  `decisoes-ux.md` (Tarefa 5).

- [ ] **Passo 1: Escrever a conferência e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
F=docs/design/fluxos.md
echo "fluxos:        $(grep -cE '^## F[1-5] — ' $F)"
echo "sem erros:     $(awk '/^## F[1-5] /{if(t&&!e)print t; t=$0; e=0} /^### Estados de erro/{e=1} END{if(t&&!e)print t}' $F | wc -l)"
```

Esperado agora: erro `No such file or directory`.

- [ ] **Passo 2: Criar o cabeçalho**

```markdown
# Fluxos

> Artefato P1 do [`guias/guia-app-web.md`](../guias/guia-app-web.md). Os cinco caminhos principais,
> passo a passo, com os seus estados de erro.

## Como ler

Erro é **ramo do caminho**, não jornada própria: cada fluxo traz os seus estados de erro na própria
seção. Os termos em **negrito** estão definidos no [`glossario.md`](../glossario.md).

| Fluxo | Persona | Fidelidade |
|---|---|---|
| F1 · Baixar um relatório | Relator | Protótipo |
| F2 · Entrar pela primeira vez | Relator | Wireframe |
| F3 · Conceder acesso | Gerente | Só escrito |
| F4 · Refazer uma apuração | Administrador | Wireframe |
| F5 · Diagnosticar um erro relatado | Administrador | Wireframe |

A fidelidade vem da tabela do guia: CRUD administrativo não se prototipa, e as telas de identidade
são o Keycloak com tema (`RA-33`, `RA-34`).
```

- [ ] **Passo 3: Escrever F1 — o fluxo que o protótipo responde**

Estrutura obrigatória de cada fluxo: **Gatilho**, **Caminho**, **Estados de erro**, **Cobre**.

```markdown
## F1 — Baixar um relatório

**Persona:** Relator · **Gatilho:** precisa de um relatório de uma data específica, num formato
específico.

### Caminho

1. Relator autenticado abre a aplicação.
2. Vê as **datas de referência** disponíveis — no máximo 7 (RN-36).
3. Escolhe uma data → vê os **produtos** que a sua **cadeia de permissão** alcança.
4. Escolhe um produto → vê os **relatórios** permitidos, com o estado da **execução vigente**.
5. Escolhe um relatório → escolhe o formato: PDF, XLSX, DOCX ou CSV.
6. **Espera.** p95 de até 25 s para XLSX e DOCX (RNF-08); até 15 s para PDF; até 5 s para CSV.
7. Recebe o arquivo. O **download** é registrado (RN-35).

Os passos 2–4 são a variante de navegação do protótipo; o passo 6 é a variante de espera.

### Estados de erro

| Quando | O que o usuário vê | Regra |
|---|---|---|
| Execução vigente em `em processamento` ou `processado com erro` | O relatório aparece na lista, sem ação de exportar, com o motivo | RF-20, RN-42 |
| Artefato já expurgado | Mensagem explícita de indisponibilidade por retenção — **nunca erro genérico** | RF-24, RN-39 |
| Duas exportações já em curso | Recusa imediata, com indicação de repetir mais tarde. **Não há fila** | RF-48, RN-53 |
| Relatório fora da cadeia de permissão | Não aparece na listagem, e o acesso direto é negado | RF-14, RF-15, RN-23 |

### Cobre
RF-13, RF-14, RF-15, RF-19, RF-20, RF-21, RF-22, RF-24, RF-48
```

- [ ] **Passo 4: Escrever F2 a F5**

Mesma estrutura. Conteúdo obrigatório de cada:

**F2 — Entrar pela primeira vez** · Relator · Gatilho: recebeu o endereço da aplicação e não tem conta.
- Caminho: autocadastro na página do Keycloak (tema customizado) → entra imediatamente → **listagem
  vazia** com a mensagem de que aguarda configuração de permissões → depois de o Gerente vinculá-lo
  a um grupo, a listagem passa a ter conteúdo.
- Estados de erro: *pendente de vínculo* **não é erro** — é estado legítimo e precisa parecer isso.
  Não há fila de aprovação nem grupo padrão.
- Cobre: RF-29, RF-30, RF-16, RF-55.

**F3 — Conceder acesso** · Gerente · Gatilho: um Relator novo precisa enxergar um conjunto de relatórios.
- Caminho, **na ordem**: cria a **role de relatório** → vincula a role aos relatórios → cria ou
  escolhe o **grupo** → vincula a role ao grupo → inclui o usuário no grupo. O acesso passa a valer
  imediatamente.
- Estados de erro: tentativa de criar ou promover a GERENTE/ADMINISTRADOR é negada, **inclusive por
  manipulação direta da requisição** (RF-34) — Perfil é realm role e Role de relatório é client
  role, espaços de nomes distintos (`ADR-0005`).
- Cobre: RF-31, RF-32, RF-33, RF-34, RF-36, RF-43.
- **Sem wireframe, com fluxo escrito.** A ordem das cinco operações precisa estar registrada, ou
  cada tela será desenhada supondo uma ordem diferente.

**F4 — Refazer uma apuração** · Administrador · Gatilho: um relatório saiu com número errado.
- Caminho: localiza o par relatório + data corrente → aciona reprocessamento forçado → **informa o
  motivo, obrigatório** → confirma → a execução anterior passa a não-vigente e os artefatos são
  sobrescritos.
- Estados de erro: motivo ausente rejeita (RF-11); perfil diferente de ADMINISTRADOR não vê a ação
  (RF-12); **data passada não é oferecida** — não há retroatividade (RN-54, `ADR-0011`).
- Cobre: RF-10, RF-11, RF-12.

**F5 — Diagnosticar um erro relatado** · Administrador · Gatilho: um Relator abriu chamado com um
Correlation ID.
- Caminho: recebe o ID do usuário → localiza a ocorrência nos registros da operação → identifica a
  execução ou exportação correspondente → decide entre refazer (F4) ou escalar.
- Estados de erro: ID inexistente ou fora da janela de log — o **artefato** dura 7 dias, mas os
  **metadados de execução nunca são expurgados** (RN-51), então a execução sempre existe mesmo
  quando o arquivo não.
- Cobre: RF-38, RF-39, RF-40.

- [ ] **Passo 5: Rodar a conferência e vê-la passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
F=docs/design/fluxos.md
echo "fluxos:     $(grep -cE '^## F[1-5] — ' $F)  (esperado 5)"
echo "com erros:  $(grep -c '^### Estados de erro' $F)  (esperado 5)"
echo "com cobre:  $(grep -c '^### Cobre' $F)  (esperado 5)"
echo "--- RF de interface ausentes ---"
for rf in RF-13 RF-14 RF-15 RF-16 RF-19 RF-20 RF-21 RF-22 RF-24 RF-29 RF-30 RF-31 RF-32 \
          RF-33 RF-34 RF-36 RF-38 RF-39 RF-40 RF-43 RF-48 RF-55 RF-10 RF-11 RF-12; do
  grep -q "$rf" $F || echo "  FALTA: $rf"
done
```

Esperado: `5`, `5`, `5` e nenhuma linha `FALTA`. É o critério de aceite 2.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/design/fluxos.md
git commit -m "$(cat <<'EOF'
Cinco fluxos principais, com os estados de erro embutidos

Erro entra como ramo do caminho e não como jornada separada: quem lê o
fluxo de baixar um relatório precisa ver, ali, o que acontece quando o
artefato foi expurgado ou quando o limite de simultaneidade recusa.

F3 não ganha wireframe porque é CRUD administrativo e o guia manda ir
direto ao código, mas ganha fluxo escrito: a cadeia de permissão tem
cinco operações em ordem, e sem registrá-la cada tela seria desenhada
supondo uma ordem diferente.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Protótipo — estrutura, dados e as 3 navegações

**Arquivos:**
- Criar: `docs/design/prototipo/prototipo.html`

**Interfaces:**
- Produz: a constante `CATALOGO` e o roteador de variantes, consumidos pela Tarefa 3.

- [ ] **Passo 1: Criar o arquivo com os dados falsos**

Estes dados são literais e não devem ser alterados — os códigos são os exemplos válidos do PRD, e
os nomes são longos de propósito.

```javascript
const HOJE = '2026-08-12';

const DATAS = ['2026-08-12','2026-08-11','2026-08-10','2026-08-09',
               '2026-08-08','2026-08-07','2026-08-06'];

const CATALOGO = [
  { sigla: 'POUPANCA', nome: 'Poupança', relatorios: [
    { codigo: 'POUPANCA-0001', nome: 'Movimentação diária de contas de poupança' },
    { codigo: 'POUPANCA-0002', nome: 'Rendimento creditado por faixa de saldo' } ] },
  { sigla: 'CLIENTE', nome: 'Cliente', relatorios: [
    { codigo: 'CLIENTE-0001', nome: 'Cadastro de clientes com pendência documental' },
    { codigo: 'CLIENTE-0005', nome: 'Distribuição de clientes por segmento e agência' } ] },
  { sigla: 'CONTACORRENTE', nome: 'Conta Corrente', relatorios: [
    { codigo: 'CONTACORRENTE-0001', nome: 'Extrato consolidado de conta corrente' },
    { codigo: 'CONTACORRENTE-1234', nome: 'Tarifas debitadas por pacote de serviços' } ] },
  { sigla: 'CONSORCIO', nome: 'Consórcio', relatorios: [
    { codigo: 'CONSORCIO-0002', nome: 'Contemplações por grupo e assembleia' },
    { codigo: 'CONSORCIO-9874', nome: 'Inadimplência de cotas por prazo decorrido' } ] },
  { sigla: 'EMPRESTIMO', nome: 'Empréstimo', relatorios: [
    { codigo: 'EMPRESTIMO-0003', nome: 'Carteira de empréstimos por faixa de atraso' },
    { codigo: 'EMPRESTIMO-4567', nome: 'Liberações do dia por linha de crédito' } ] },
];

// Estado da execucao vigente por par data+codigo. Ausente = sucesso.
// Exercita RF-20 (sem artefato valido) e RF-24 (expurgado).
const EXCECOES = {
  '2026-08-12|CONSORCIO-9874':     'em processamento',
  '2026-08-12|EMPRESTIMO-4567':    'processado com erro',
  '2026-08-11|CLIENTE-0005':       'processado com alerta',
  '2026-08-06|CONTACORRENTE-1234': 'expurgado',
};

// Relatorios que a cadeia de permissao deste Relator NAO alcanca (RF-14).
const SEM_PERMISSAO = ['POUPANCA-0002', 'CONSORCIO-0002'];
```

**Por que estas exceções:** sem elas o protótipo mostraria só o caminho feliz, e as três navegações
pareceriam equivalentes. Um relatório `em processamento` e outro `expurgado` na mesma tela é
exatamente onde uma tabela plana se sai diferente de um *drill-down*.

- [ ] **Passo 2: Criar o shell com o seletor de variantes**

Uma barra fixa no topo, com dois grupos de botões — navegação (V1/V2/V3) e espera (V1/V2/V3) — e
uma área de conteúdo. Trocar de variante **não** perde o contexto: se o usuário está vendo os
relatórios de `CONTACORRENTE` em 11/08, trocar de V1 para V3 deve mostrar o mesmo recorte na outra
forma. É isso que torna a comparação honesta.

Abaixo da barra, uma linha de contexto declarando o que se está vendo:

```
Relator · vendo 3 de 5 produtos · 2 relatórios fora da sua permissão
```

- [ ] **Passo 3: Construir A1-V1 — drill-down**

Três telas sucessivas com trilha de navegação:
`Datas` → `Produtos de 12/08/2026` → `Relatórios de CONTACORRENTE em 12/08/2026`.
Cada nível é uma lista clicável; voltar é possível pela trilha. Na terceira tela, cada relatório traz
código, nome, e a ação de exportar (ou o motivo de não poder).

- [ ] **Passo 4: Construir A1-V2 — árvore expansível**

Uma página só. As 7 datas listadas; clicar expande os produtos; clicar num produto expande os
relatórios, sem recarregar nem trocar de tela. Múltiplos ramos podem ficar abertos ao mesmo tempo —
é a diferença funcional que importa, porque permite comparar o mesmo relatório em duas datas.

- [ ] **Passo 5: Construir A1-V3 — tabela plana com filtros**

Uma tabela com todas as combinações permitidas: **70 linhas** no total (7 datas × 10 relatórios),
menos as 14 sem permissão (2 relatórios × 7 datas) = **56 linhas**. Colunas: Data, Produto, Código,
Relatório, Estado, Ação. Filtros de data e de produto no topo, e ordenação por coluna.

É aqui que o comprimento de `CONTACORRENTE-1234` mais pesa — a tabela precisa caber sem rolagem
horizontal em 1280px, ou a variante já se autorrefuta.

- [ ] **Passo 6: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
P=docs/design/prototipo/prototipo.html
echo "siglas reais presentes: $(for s in POUPANCA CLIENTE CONTACORRENTE CONSORCIO EMPRESTIMO; do grep -q "$s" $P && echo x; done | wc -l)  (esperado 5)"
echo "codigos SIGLA-NNNN:     $(grep -oE '[A-Z]{1,20}-[0-9]{4}' $P | sort -u | wc -l)  (esperado 10)"
echo "variantes de navegacao: $(grep -coE 'data-variante="nav-v[123]"' $P)  (esperado >= 3)"
echo "autocontido (sem rede): $(grep -cE 'src="http|href="http|@import|fetch\(' $P)  (esperado 0)"
```

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/design/prototipo/prototipo.html
git commit -m "$(cat <<'EOF'
Protótipo: dados do catálogo real e as três navegações

Drill-down, árvore expansível e tabela plana com filtros, todas
percorrendo o F1 inteiro para permitir comparação real.

Os dados usam as siglas e os códigos do PRD, não conteúdo genérico:
CONTACORRENTE-1234 tem 18 caracteres, e é isso que decide se a tabela
plana cabe na tela. Com PROD-0001 as três variantes pareceriam
igualmente viáveis.

Quatro exceções de estado e dois relatórios fora da permissão, porque
um protótipo só do caminho feliz não distingue as variantes.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Protótipo — as 3 esperas, os 4 wireframes e o README

**Arquivos:**
- Modificar: `docs/design/prototipo/prototipo.html`
- Criar: `docs/design/prototipo/README.md`

**Interfaces:**
- Consome: `CATALOGO`, `EXCECOES` e o roteador da Tarefa 2.

- [ ] **Passo 1: Construir A2-V1 — modal bloqueante**

Ao exportar, abre um modal centrado que cobre a tela: nome do relatório, formato, barra de progresso
indeterminada e o texto "Isto pode levar até 25 segundos". Nada mais é clicável. Ao fim, o modal
fecha e o download "acontece" (uma mensagem de sucesso, já que não há arquivo real).

Simule a duração com `setTimeout` de **8 segundos** — longo o suficiente para a espera ser sentida,
curto o suficiente para o usuário testar as três variantes sem tédio. Declare isso na tela.

- [ ] **Passo 2: Construir A2-V2 — progresso na linha**

A linha do relatório na lista ganha um indicador de progresso no lugar do botão. **O resto da
interface continua navegável** — dá para trocar de data, abrir outro produto, e até disparar uma
segunda exportação. Ao fim, a linha volta ao normal com a marca de concluído.

Esta variante deve deixar visível a **recusa por simultaneidade**: ao tentar a terceira exportação
com duas em curso, aparece a recusa imediata de `RF-48`. É a única das três em que esse estado é
alcançável naturalmente, e isso é informação relevante para a escolha.

- [ ] **Passo 3: Construir A2-V3 — aviso prévio com confirmação**

Ao clicar em exportar, aparece primeiro uma confirmação: "Este relatório costuma levar cerca de 20
segundos. Deseja continuar?" com as ações Continuar e Cancelar. Confirmando, mostra o progresso
(pode reusar o tratamento de V1).

- [ ] **Passo 4: Construir os 4 wireframes com a regra de baixa fidelidade**

CSS obrigatório, literal — é o que o critério de aceite 5 verifica:

```css
.wireframe {
  filter: grayscale(1);
  border: 2px dashed #999;
  background: #f4f4f4;
  color: #333;
  font-family: monospace;
  padding: 1.5rem;
  position: relative;
}
.wireframe::before {
  content: "WIREFRAME";
  position: absolute;
  top: .4rem; right: .6rem;
  font-size: .7rem;
  letter-spacing: .1em;
  color: #888;
}
.wireframe * { color: #333 !important; background: transparent !important; }
```

`filter: grayscale(1)` e o `!important` no descendente são cinto e suspensório: mesmo que alguém
acrescente cor depois, ela não aparece. É o que impede o wireframe de virar protótipo por deriva.

Os quatro:

| | Conteúdo obrigatório |
|---|---|
| **W1** Pendente de vínculo | Listagem vazia + mensagem de que aguarda configuração de permissões. **Não pode parecer erro** — é estado legítimo (RF-16) |
| **W2** As três recusas | Expurgado por retenção · fora da permissão · limite de simultaneidade. Os três com momento, descrição e Correlation ID (RF-24, RF-15, RF-48, RN-40) |
| **W3** Erro com Correlation ID | Momento em ISO 8601, descrição, Correlation ID e **ação de copiar o erro em JSON** (RF-38, RF-39, RA-42) |
| **W4** Reprocessamento forçado | Par relatório + data corrente · campo de motivo **obrigatório** · confirmação destrutiva avisando que os artefatos serão sobrescritos (RF-10, RF-11, RN-20) |

- [ ] **Passo 5: Escrever o `README.md` do protótipo**

```markdown
# Protótipo — DESCARTÁVEL

Este protótipo é **código de fachada**. Não autentica, não valida, não trata erro de rede e não
persiste estado. Existe para responder duas perguntas de P1 e para ser jogado fora depois.

## Não promova este código

O guia do projeto adverte: *"código de protótipo gerado por agente é especialmente tentador de
promover, porque já parece funcionar. Não tem validação, autorização, tratamento de erro nem
testes. Promovê-lo é nascer com dívida técnica no dia zero — no único momento em que ela era
evitável."*

O Angular real nasce em SP-5 e SP-7, a partir do design system e dos componentes canônicos. Deste
protótipo aproveita-se **a decisão**, registrada em `../decisoes-ux.md` — não o código.

## O que ele responde

1. Qual das três navegações atende os dois modos de uso do Relator.
2. O que o usuário vê durante a espera de até 25 s da exportação.

## Dados

Falsos, mas com o catálogo real: as 5 siglas de `RA-04` e códigos no formato `SIGLA-NNNN`. Os nomes
são longos de propósito — é o comprimento de `CONTACORRENTE-1234` que decide se a tabela plana cabe
na tela.
```

- [ ] **Passo 6: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
P=docs/design/prototipo/prototipo.html
echo "variantes de espera: $(grep -coE 'data-variante="espera-v[123]"' $P)  (esperado >= 3)"
echo "wireframes:          $(grep -co 'class="wireframe' $P)  (esperado >= 4)"
echo "regra grayscale:     $(grep -c 'grayscale(1)' $P)  (esperado >= 1)"
echo "rotulo WIREFRAME:    $(grep -c 'content: "WIREFRAME"' $P)  (esperado >= 1)"
echo "README declara descarte: $(grep -ci 'descartável\|nao promova\|não promova' docs/design/prototipo/README.md)  (esperado >= 2)"
echo "fora de frontend/:   $(ls frontend/ 2>/dev/null | grep -c prototipo)  (esperado 0)"
```

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/design/prototipo/
git commit -m "$(cat <<'EOF'
Protótipo: as três esperas, os quatro wireframes e o aviso de descarte

Modal bloqueante, progresso na linha com o resto navegável, e aviso
prévio com confirmação. A segunda é a única em que a recusa por
simultaneidade de RF-48 é alcançável naturalmente, e isso é informação
que pesa na escolha.

Os wireframes carregam grayscale e !important nos descendentes: mesmo
que alguém acrescente cor depois, ela não aparece. É o que impede o
wireframe de virar protótipo por deriva, agora que os dois dividem o
mesmo arquivo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Publicar como Artifact — e PARAR

**Arquivos:** nenhum. Esta tarefa publica e encerra.

**Sem commit, e isso é deliberado** — não há arquivo novo. É a única tarefa deste plano que não
termina em `git commit`.

- [ ] **Passo 1: Carregar o skill de design de Artifact**

Antes de publicar, invoque `artifact-design`. É requisito da ferramenta e calibra o quanto de
investimento visual a página merece — aqui, pouco: é protótipo descartável, e polimento seria
contraproducente.

- [ ] **Passo 2: Publicar**

```
Artifact(
  file_path:   "docs/design/prototipo/prototipo.html",
  description: "Protótipo descartável de P1: três navegações, três tratamentos da espera e quatro wireframes.",
  favicon:     "🧭"
)
```

O HTML já é autocontido — sem CDN, sem fonte externa, sem `fetch` — o que satisfaz a CSP dos
Artifacts sem ajuste.

- [ ] **Passo 3: Entregar o link e PARAR**

Reporte ao usuário:

- o link do Artifact;
- que ele deve percorrer o F1 nas três navegações (A1-V1, V2, V3) e escolher uma;
- que deve exportar nas três esperas (A2-V1, V2, V3) e escolher uma;
- que na A2-V2 vale tentar a terceira exportação simultânea, para ver a recusa de `RF-48`.

**Encerre a execução aqui.** A Tarefa 5 precisa das duas escolhas.

> ⚠️ Se você é um executor agêntico e chegou até aqui sem ter as escolhas do usuário: **pare e
> reporte**. Escolher a variante sozinho e registrá-la em `decisoes-ux.md` transformaria um chute em
> deliberação documentada, que é pior do que não ter protótipo nenhum.

---

## Tarefa 5: `docs/design/decisoes-ux.md`

**Bloqueada pela Tarefa 4.** Só execute com as duas escolhas em mãos.

**Arquivos:**
- Criar: `docs/design/decisoes-ux.md`

- [ ] **Passo 1: Escrever as cinco entradas**

Formato de cada uma, igual ao dos ADRs:

```markdown
## DUX-01 — Navegação da listagem

**Escolha:** <variante escolhida pelo usuário>

### Opções consideradas
1. Drill-down em páginas sucessivas
2. Árvore expansível numa página
3. Tabela plana com filtros

### Por que não as outras
<motivo concreto de cada rejeitada, observado no protótipo>

### Consequências
<o que isto impõe a SP-5 e SP-7>
```

Conteúdo obrigatório das cinco:

| # | O que registrar |
|---|---|
| **DUX-01** | A navegação escolhida, o motivo de rejeição das outras duas, e a observação de que a janela de 7 dias cabe inteira na tela — o argumento clássico para hierarquia é volume, e aqui não há volume |
| **DUX-02** | A espera escolhida **e a sua consequência arquitetural**. Se for a V2, registrar que a exportação passa a exigir requisição em segundo plano com entrega do arquivo ao final, e que isso **não fere RN-30** — a regra exige resposta na mesma requisição, não bloqueio da interface |
| **DUX-03** | Por que o CRUD administrativo não foi prototipado: a tabela de fidelidade do guia, aplicada às 10 telas, com o resultado 2 / 4 / 4 |
| **DUX-04** | Por que as telas de identidade são o Keycloak com tema (`RA-33`, `RA-34`), e o que isso limita — o layout do autocadastro e da recuperação de senha não é nosso, e o tema alcança CSS, não estrutura |
| **DUX-05** | Como a listagem comunica o expurgo, dado que o artefato some por volta das **21h do sétimo dia** e não à meia-noite (`RA-20`) |

- [ ] **Passo 2: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
D=docs/design/decisoes-ux.md
echo "entradas DUX:      $(grep -cE '^## DUX-0[1-5] — ' $D)  (esperado 5)"
echo "com rejeicoes:     $(grep -c '^### Por que não' $D)  (esperado 5)"
echo "com consequencias: $(grep -c '^### Consequências' $D)  (esperado 5)"
echo "DUX-02 cita RN-30: $(sed -n '/^## DUX-02/,/^## DUX-03/p' $D | grep -c 'RN-30')  (esperado >= 1)"
```

- [ ] **Passo 3: Conferir os nove critérios de aceite da spec**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
P=docs/design/prototipo/prototipo.html
echo "1. fluxos:        $(grep -cE '^## F[1-5] — ' docs/design/fluxos.md)  (esperado 5)"
echo "2. RF de interface sem fluxo:"
for rf in RF-13 RF-14 RF-15 RF-16 RF-19 RF-20 RF-21 RF-22 RF-24 RF-29 RF-30 RF-31 RF-32 \
          RF-33 RF-34 RF-36 RF-38 RF-39 RF-40 RF-43 RF-48 RF-55 RF-10 RF-11 RF-12; do
  grep -q "$rf" docs/design/fluxos.md || echo "   FALTA: $rf"
done
echo "5. wireframes:    $(grep -co 'class="wireframe' $P)  (esperado >= 4)"
echo "6. siglas reais:  $(for s in POUPANCA CLIENTE CONTACORRENTE CONSORCIO EMPRESTIMO; do grep -q $s $P && echo x; done | wc -l)  (esperado 5)"
echo "6. codigos:       $(grep -oE '[A-Z]{1,20}-[0-9]{4}' $P | sort -u | wc -l)  (esperado 10)"
echo "7. DUX completo:  $(grep -cE '^## DUX-0[1-5] — ' docs/design/decisoes-ux.md)  (esperado 5)"
echo "8. README:        $(grep -ci 'descartável' docs/design/prototipo/README.md)  (esperado >= 1)"
echo "9. fora do front: $(find frontend -name 'prototipo*' 2>/dev/null | wc -l)  (esperado 0)"
```

Os critérios 3 e 4 (as variantes percorrem o F1) são verificados por inspeção no Artifact, na
Tarefa 4.

- [ ] **Passo 4: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/design/decisoes-ux.md
git commit -m "$(cat <<'EOF'
Decisões de UX, com as variantes rejeitadas e seus motivos

Registra a navegação e o tratamento de espera escolhidos no protótipo,
e por que as outras quatro variantes foram descartadas.

DUX-02 registra a consequência arquitetural da espera, e não apenas
qual desenho ganhou: a escolha decide se a aplicação precisa de estado
de navegação durante uma requisição pendente, o que atravessa para
SP-5 e SP-7.

DUX-03 registra o que não foi prototipado e por quê, para que a
ausência de wireframe do CRUD administrativo seja lida como decisão e
não como esquecimento.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-4 termina quando os nove critérios da spec passam e os quatro commits estão no branch — três
antes do gate e um depois.

**O que SP-4 entrega para os próximos:** SP-5 consome a navegação e a espera escolhidas para
desenhar os componentes canônicos; SP-7 consome `fluxos.md` para saber que telas existem e em que
ordem. O código do protótipo **não é consumido por ninguém** — é descartado.
