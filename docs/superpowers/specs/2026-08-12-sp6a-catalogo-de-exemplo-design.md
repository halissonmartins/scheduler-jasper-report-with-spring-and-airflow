# SP-6a — Catálogo de exemplo (E2)

> Spec do quinto sub-projeto brainstormado. Desenha os dez relatórios de `RA-08`: domínios, modelos
> de dados, consultas principais, tempos estimados e a especificação de cada JRXML. Entrega também
> o DDL e o seed dos cinco schemas transacionais.
>
> Data: 2026-08-12 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

`RA-08` obriga cada módulo processador a trazer dois relatórios de exemplo, com **imagens e fontes
diferentes entre si**, e obriga **ao menos um do conjunto** a carregar um elemento que produz
renderer serializado. A arquitetura diz por que, e a frase é o enquadramento deste sub-projeto:

> *"Sem ela, o quarto risco da seção 12 — `ClassNotFoundException` no renderer — continuaria
> declarado e nunca exercido, porque nenhum outro critério do projeto obriga um relatório a ter
> barcode."*

**Estes relatórios são instrumentos de teste vestidos de domínio.** É o que decide a abordagem
(§4).

### 1.1 Contradição na decomposição, resolvida aqui

A tabela de SP-1 §1 dizia que SP-6a entrega *"os 10 relatórios"*, e que SP-8+ inclui *"os 4
produtos restantes"*. As duas linhas não podem ser verdadeiras ao mesmo tempo.

**Resolução:** SP-6a **desenha os dez e implementa nenhum JRXML**. Entrega documento e SQL. Os
arquivos `.jrxml` nascem em SP-7 (POUPANCA) e SP-8+ (os outros quatro), que passam a ter
especificação pronta em vez de inventarem. Isso mantém E2 no seu papel — contratos antes do código.

---

## 2. Objetivo

Que SP-7 e SP-8+ encontrem, para cada relatório: o schema já criado e semeado, a consulta principal
escrita, o tempo estimado definido e a especificação do JRXML — sem precisar inventar domínio
bancário no meio de uma tarefa de implementação.

---

## 3. Entregas

### 3.1 A matriz de características técnicas

Distribuída a partir dos riscos, e só então vestida de domínio.

| Código | Fonte | Imagem | Característica técnica | Exercita |
|---|:---:|:---:|---|---|
| `POUPANCA-0001` | A | 1 | Listagem simples, dataset médio | linha de base |
| `POUPANCA-0002` | **B** | **2** | **Agrupamento com quebra de página** | torna `RF-21` não-trivial |
| `CLIENTE-0001` | A | 1 | **Subrelatório** | `RN-34` — CSV sem subrelatório |
| `CLIENTE-0005` | **C** | **3** | Listagem larga, muitas colunas | layout e XLSX |
| `CONTACORRENTE-0001` | B | 2 | **O maior dataset do conjunto** | `R-05`, `RNF-06`, latência |
| `CONTACORRENTE-1234` | **A** | **4** | Agrupamento por pacote de serviço | — |
| `CONSORCIO-0002` | C | 1 | **Barcode** | **`R-04`** |
| `CONSORCIO-9874` | **A** | **5** | Listagem simples | — |
| `EMPRESTIMO-0003` | B | 3 | Subrelatório **e** agrupamento | combinação |
| `EMPRESTIMO-4567` | **C** | **6** | Listagem simples | — |

**As duas exigências de `RA-08`, conferidas:** em cada par, fonte e imagem diferem (`A/B`, `A/C`,
`B/A`, `C/A`, `B/C`); e o conjunto tem exatamente um barcode.

**Dois achados ao montar a matriz.** `RN-34` define o CSV como dataset bruto *"sem subrelatórios,
sem imagens e sem formatação"* — se nenhum dos dez tivesse subrelatório, a cláusula nunca seria
exercida. E o teste de XLSX contínuo (`RF-21`) só é significativo sobre um relatório que **de fato
pagina com quebra de grupo**; sobre uma listagem simples, ele passa por acidente.

### 3.2 As três fontes

| | Fonte | Origem |
|---|---|---|
| **A** | DejaVu Sans | vem em `jasperreports-fonts` |
| **B** | DejaVu Serif | idem |
| **C** | **empacotada por nós**, como *font extension* própria | é esta que exercita o risco |

A distinção não é cosmética. `R-03` registra que *"as imagens vão embutidas no `.jrprint`, mas as
fontes não — a API que exporta precisa ter as mesmas font extensions no classpath"*. Com A e B o
risco fica mascarado: elas já vêm no jar do Jasper e estariam presentes por acidente. **Só a fonte C
prova que o mono repositório garante o classpath compartilhado**, e é ela que falha ruidosamente se
`ADR-0002` for violado.

### 3.3 Os cinco domínios — 30 tabelas

Modelagem rica, com uma trava: **toda tabela é lida por ao menos uma das duas consultas principais
do seu produto.** Tabela que nenhuma query alcança não entra. É o que impede a modelagem rica de
virar modelagem decorativa.

Entre parênteses, qual relatório lê cada tabela.

**`poupanca`** — 0001 movimentação diária · 0002 rendimento por faixa de saldo
`agencia` (0001, 0002) · `titular` (0001) · `conta_poupanca` (0001, 0002) · `movimento` (0001, com
auto-referência para estorno) · `credito_rendimento` (0002) · `situacao_conta` (0002, com vigência)

**`cliente`** — 0001 pendência documental · 0005 distribuição por segmento
`cliente` (0001, 0005) · `segmento` (0005) · `documento` (0001) · `endereco` (**subrelatório** de
0001) · `relacionamento` (0005) · `contato` (0005)

**`contacorrente`** — 0001 extrato consolidado · 1234 tarifas por pacote
`conta_corrente` (0001, 1234) · `lancamento` (0001, **a maior tabela do projeto**) · `saldo_diario`
(0001) · `pacote_servico` (1234) · `conta_pacote` (1234, com vigência) · `tarifa` (1234)

**`consorcio`** — 0002 contemplações · 9874 inadimplência
`grupo` (0002, 9874) · `cota` (0002, 9874) · `assembleia` (0002) · `contemplacao` (0002, **onde vive
o barcode**) · `lance` (0002) · `parcela` (9874)

**`emprestimo`** — 0003 carteira por faixa de atraso · 4567 liberações do dia
`linha_credito` (0003, 4567) · `contrato` (0003, 4567) · `parcela` (0003) · `garantia`
(**subrelatório** de 0003) · `renegociacao` (0003) · `liberacao` (4567)

**Três escolhas de modelagem com propósito técnico:**

- **`movimento.estorno_de` é auto-referência.** Um `LEFT JOIN` da tabela consigo mesma é o tipo de
  consulta que se degrada sob volume — e `POUPANCA-0001` é a linha de base contra a qual os outros
  nove serão comparados.
- **`situacao_conta` e `conta_pacote` têm vigência.** É o que obriga as consultas a filtrar a data
  de referência corretamente, e é onde um erro de intervalo produziria número errado **sem produzir
  erro**.
- **O barcode fica em `contemplacao`**, e não solto num rodapé. Contemplação de consórcio tem
  comprovante; o código de barras tem razão de existir ali, o que evita o cheiro de elemento posto
  só para satisfazer critério.

### 3.4 Tempos estimados

Respeitando `RN-48` e `RNF-19` — soma ≤ 10 min por produto:

| Produto | Relatório 1 | Relatório 2 | Soma |
|---|---:|---:|---:|
| POUPANCA | 120 s | 180 s | 300 s |
| CLIENTE | 180 s | 120 s | 300 s |
| CONTACORRENTE | **300 s** | 180 s | 480 s |
| CONSORCIO | 180 s | 120 s | 300 s |
| EMPRESTIMO | 180 s | 120 s | 300 s |

Nenhum produto passa de 480 s contra o teto de 600 s. A folga é deliberada: acrescentar um terceiro
relatório no futuro não deve esbarrar imediatamente em `RF-47`.

### 3.5 DDL e seed

**Flyway em cada módulo processador**, em `src/main/resources/db/migration`:

```
processador-poupanca/src/main/resources/db/migration/
  V1__cria_tabelas_poupanca.sql
  V2__seed_poupanca.sql
```

Coerente com `RA-04` — o módulo **é** o produto — e com `RA-10`: quem lê o schema é quem o
versiona. E o Testcontainers de SP-7 aplica as mesmas migrations, de modo que teste e ambiente local
não divergem.

**O seed usa `INSERT ... SELECT generate_series(...)`**: cerca de 50 linhas de SQL por produto
produzindo milhares de registros, sem engordar o repositório. `lancamento` recebe o maior volume,
para que `CONTACORRENTE-0001` seja de fato o maior dataset.

### 3.6 Especificação dos JRXMLs

Em `docs/catalogo/` — um `README.md` com a matriz, mais **um arquivo por produto** com os seus dois
relatórios. Cinco arquivos gerenciáveis, em vez de um documento de 30 tabelas.

Cada especificação contém o suficiente para que quem escrever o JRXML não invente:

- **Bandas e conteúdo de cada uma**, com `RA-59` aplicada: cabeçalho de coluna na banda `title`;
  `pageHeader`/`pageFooter` apenas com ornamento descartável.
- Colunas do dataset, com tipo e formato de exibição.
- Fonte e imagem, pela matriz de §3.1.
- Elementos especiais: onde entra o subrelatório, o barcode, a quebra de grupo.
- Orientação e tamanho de página; parâmetro de data de referência.

---

## 4. Método

1. `docs/catalogo/README.md` com a matriz.
2. Os cinco arquivos de produto: domínio, DDL comentado, as duas consultas, tempos e especificação
   dos JRXMLs.
3. Migrations `V1__cria_tabelas_<produto>.sql` nos cinco processadores.
4. Migrations `V2__seed_<produto>.sql`, com `generate_series`.
5. Rodar migrations e as dez consultas contra um PostgreSQL limpo.

**Abordagem escolhida: partir dos riscos, nomear depois.** Distribuir primeiro as características
técnicas que precisam ser exercitadas, e só então escolher qual domínio bancário veste cada uma com
naturalidade. Os nomes inventados no protótipo de SP-4 são reaproveitados onde couberem — o
protótipo é descartável e não vincula.

As alternativas consideradas: partir dos nomes de SP-4 (seria o descartável fixando o catálogo — os
nomes foram escolhidos para parecerem plausíveis numa tabela, não para exercitar risco) e modelar o
domínio primeiro (produz o conjunto mais coerente, mas a coerência de domínio não tem relação com o
propósito de `RA-08`, e a cobertura de risco ficaria ao acaso).

---

## 5. Fronteiras

**Fora de escopo de SP-6a:**

- **Os arquivos `.jrxml`** — SP-7 (POUPANCA) e SP-8+ (os outros quatro).
- **A *font extension* da fonte C e as seis imagens** — nascem com os JRXMLs que as consomem. Até
  lá, `R-03` continua declarado e não exercido.
- **O schema de controle** — SP-6b.
- **Qualquer código Java.** SP-6a entrega documento e SQL.

**Dependência nova, que não estava na decomposição:** os critérios de aceite 9 e 10 exigem um
PostgreSQL rodando. SP-6a passa a depender de SP-3, ou de um `docker run postgres:18-alpine` avulso.

---

## 6. Riscos aceitos

- **A modelagem rica não é validada por ninguém do domínio.** São 30 tabelas inventadas —
  plausíveis, não corretas. O custo real não é a invenção: é que cada mudança futura num relatório
  passa a mexer em schema, migration e seed.
- **`RF-49` não é exercitável por volume**, dado o seed médio. **Mitigação:** o teste injeta um
  resultado de contagem acima do teto e verifica que a execução termina em `processado com erro` com
  motivo — `RA-64` conta antes de apurar, então não é preciso materializar 50.000 linhas. Dono:
  SP-7/SP-8.
- **`R-09` medirá em escala reduzida.** `CONTACORRENTE-0001` é o maior dataset do conjunto, mas fica
  na casa dos milhares. A calibração extrapolará, ou o ticket do spike gerará o próprio volume.
- **A fonte C ainda não existe.** É especificada aqui e empacotada em SP-7. Até lá `R-03` segue
  declarado e não exercido — exatamente a situação de que `RA-08` reclama.

---

## 7. Critério de aceite

1. `docs/catalogo/` tem a matriz e cinco arquivos de produto.
2. Os dez relatórios têm domínio, consulta principal, tempo estimado e especificação de JRXML.
3. Em cada par, fonte **e** imagem diferem.
4. Exatamente um relatório do conjunto tem barcode.
5. Ao menos um tem subrelatório, e ao menos um tem agrupamento com quebra.
6. **Toda tabela é lida por ao menos uma consulta principal.**
7. A soma dos tempos estimados de cada produto é ≤ 600 s.
8. Cada processador tem `V1` e `V2` em `src/main/resources/db/migration`.
9. **As dez migrations aplicam sem erro** num PostgreSQL 18 limpo.
10. **As dez consultas principais rodam contra o seed e retornam linhas.**

Os critérios 3 a 7 são conferíveis por leitura da matriz e das tabelas; 9 e 10 são executáveis e
exigem PostgreSQL.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-08` (a exigência), `RA-07`, `RA-10`, `RA-24`, `RA-59`, `RA-64` |
| [`prd.md`](../../prd.md) | `RN-04`, `RN-34`, `RN-48`, `RNF-05`, `RNF-06`, `RNF-19`, `RF-21`, `RF-49` |
| [SP-2](./2026-08-10-sp2-decisoes-tecnicas-design.md) | `R-03`, `R-04`, `R-05`, `R-09` — os riscos que a matriz distribui |
| [SP-3](./2026-08-12-sp3-fundacoes-do-repositorio-design.md) | Os módulos onde as migrations vivem; o PostgreSQL dos critérios 9 e 10 |
| SP-6b | Schema de controle — irmão deste, sem sobreposição |
