# SP-6a — Catálogo de exemplo · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** desenhar os dez relatórios de `RA-08` — domínios, consultas, tempos e especificação
de JRXML — e entregar o DDL e o seed dos cinco schemas transacionais.

**Arquitetura:** sete tarefas. A primeira levanta o PostgreSQL de trabalho e escreve a matriz; cinco
tarefas de produto, independentes entre si e rejeitáveis isoladamente; a última confere os dez
critérios. **Nenhum arquivo `.jrxml`, nenhuma imagem, nenhum código Java** — SP-6a entrega documento
e SQL.

**Tech stack:** PostgreSQL 18 · Flyway (layout de arquivo apenas; a execução é de SP-7) · Markdown.

**Spec:** [`docs/superpowers/specs/2026-08-12-sp6a-catalogo-de-exemplo-design.md`](../specs/2026-08-12-sp6a-catalogo-de-exemplo-design.md)

---

## Restrições globais

Valem para **todas** as tarefas. Copiadas da spec.

- **Nomes em pt-BR sem acento**, conforme o glossário: `conta_poupanca`, `data_movimento`.
- **Toda tabela é lida por ao menos uma das duas consultas principais do seu produto.** Tabela sem
  leitor não entra — é a trava da modelagem rica. Critério de aceite 6.
- **Soma dos tempos estimados ≤ 600 s por produto** (`RN-48`, `RNF-19`).
- **Cabeçalho de coluna na banda `title`** em toda especificação de JRXML; `pageHeader`/`pageFooter`
  só com ornamento descartável (`RA-59`).
- **O seed usa `INSERT ... SELECT generate_series(...)`**, nunca `INSERT` literal em massa.
- **Migrations em `<módulo>/src/main/resources/db/migration`**, nomeadas `V1__cria_tabelas_<produto>.sql`
  e `V2__seed_<produto>.sql`.
- **Fora de escopo:** `.jrxml`, *font extension*, imagens, schema de controle, código Java.
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Nota sobre o formato deste plano

O **DDL** aparece como tabela de colunas com tipo e chave — é conteúdo real, e escrever o `CREATE
TABLE` a partir dele é transcrição direta. As **consultas principais** aparecem como especificação
precisa: tabelas envolvidas, junções, filtro, agrupamento e colunas de saída. O **seed** aparece
completo para `POUPANCA` e como volumes-alvo para os demais, porque a técnica do `generate_series`
se repete e o que muda é a quantidade.

### Ambiente

As Tarefas 2 a 7 precisam de um PostgreSQL. Se SP-3 já rodou, use `make dev`. Senão:

```bash
docker run -d --name sp6a-pg -e POSTGRES_PASSWORD=sp6a -e POSTGRES_DB=scheduler \
  -p 5433:5432 postgres:18-alpine
export PGPASSWORD=sp6a
psql -h localhost -p 5433 -U postgres -d scheduler -c \
  "CREATE SCHEMA IF NOT EXISTS poupanca; CREATE SCHEMA IF NOT EXISTS cliente;
   CREATE SCHEMA IF NOT EXISTS contacorrente; CREATE SCHEMA IF NOT EXISTS consorcio;
   CREATE SCHEMA IF NOT EXISTS emprestimo;"
```

Ao final de tudo: `docker rm -f sp6a-pg`.

---

## Tarefa 1: `docs/catalogo/README.md` — a matriz

**Arquivos:**
- Criar: `docs/catalogo/README.md`

**Interfaces:**
- Produz: a matriz que as Tarefas 2 a 6 detalham e que a Tarefa 7 confere.

- [ ] **Passo 1: Escrever a matriz**

Conteúdo obrigatório, literal:

```markdown
# Catálogo de exemplo

> Os dez relatórios de `RA-08`. **Estes relatórios são instrumentos de teste vestidos de domínio:**
> a matriz abaixo foi montada a partir dos riscos, e só então cada característica ganhou um domínio
> bancário que a vestisse com naturalidade.

## Matriz de características técnicas

| Código | Fonte | Imagem | Característica | Exercita |
|---|:---:|:---:|---|---|
| `POUPANCA-0001` | A | 1 | Listagem simples, dataset médio | linha de base |
| `POUPANCA-0002` | B | 2 | Agrupamento com quebra de página | torna `RF-21` não-trivial |
| `CLIENTE-0001` | A | 1 | Subrelatório | `RN-34` — CSV sem subrelatório |
| `CLIENTE-0005` | C | 3 | Listagem larga | layout e XLSX |
| `CONTACORRENTE-0001` | B | 2 | O maior dataset do conjunto | `R-05`, `RNF-06`, latência |
| `CONTACORRENTE-1234` | A | 4 | Agrupamento por pacote | — |
| `CONSORCIO-0002` | C | 1 | **Barcode** | **`R-04`** |
| `CONSORCIO-9874` | A | 5 | Listagem simples | — |
| `EMPRESTIMO-0003` | B | 3 | Subrelatório e agrupamento | combinação |
| `EMPRESTIMO-4567` | C | 6 | Listagem simples | — |

Em cada par, fonte **e** imagem diferem (`RA-08`); o conjunto tem exatamente um barcode.

## As três fontes

| | Fonte | Origem |
|---|---|---|
| A | DejaVu Sans | vem em `jasperreports-fonts` |
| B | DejaVu Serif | idem |
| C | empacotada por nós, como *font extension* | **é esta que exercita `R-03`** |

Com A e B o risco fica mascarado: elas já vêm no jar do Jasper e estariam no classpath por acidente.
Só a fonte C prova que o mono repositório garante o classpath compartilhado.

## Tempos estimados

| Produto | Relatório 1 | Relatório 2 | Soma | Teto |
|---|---:|---:|---:|---:|
| POUPANCA | 120 s | 180 s | 300 s | 600 s |
| CLIENTE | 180 s | 120 s | 300 s | 600 s |
| CONTACORRENTE | 300 s | 180 s | 480 s | 600 s |
| CONSORCIO | 180 s | 120 s | 300 s | 600 s |
| EMPRESTIMO | 180 s | 120 s | 300 s | 600 s |

A folga é deliberada: acrescentar um terceiro relatório não deve esbarrar imediatamente em `RF-47`.

## Arquivos

| Produto | Documento |
|---|---|
| POUPANCA | [`poupanca.md`](./poupanca.md) |
| CLIENTE | [`cliente.md`](./cliente.md) |
| CONTACORRENTE | [`contacorrente.md`](./contacorrente.md) |
| CONSORCIO | [`consorcio.md`](./consorcio.md) |
| EMPRESTIMO | [`emprestimo.md`](./emprestimo.md) |
```

- [ ] **Passo 2: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
R=docs/catalogo/README.md
echo "relatorios: $(grep -cE '^\| `[A-Z]+-[0-9]{4}`' $R)  (esperado 10)"
echo "barcodes:   $(grep -cE '^\| `[A-Z]+-[0-9]{4}`.*Barcode' $R)  (esperado 1)"
git add docs/catalogo/README.md
git commit -m "$(cat <<'EOF'
Matriz do catálogo de exemplo

Dez relatórios distribuídos a partir dos riscos que precisam ser
exercitados, e só então vestidos de domínio bancário. A arquitetura já
diz que RA-08 existe para que o ClassNotFoundException do renderer
deixe de ser risco declarado e nunca exercido.

Das três fontes, só a terceira prova alguma coisa: as outras duas vêm
no jar do Jasper e estariam no classpath por acidente.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: POUPANCA

**Arquivos:**
- Criar: `docs/catalogo/poupanca.md`
- Criar: `processador-poupanca/src/main/resources/db/migration/V1__cria_tabelas_poupanca.sql`
- Criar: `processador-poupanca/src/main/resources/db/migration/V2__seed_poupanca.sql`

**Interfaces:**
- Produz: o schema `poupanca` e as consultas de `POUPANCA-0001` e `POUPANCA-0002`, consumidas pelo
  JRXML que SP-7 escreve.

- [ ] **Passo 1: Escrever o DDL — 6 tabelas**

| Tabela | Colunas | Lida por |
|---|---|---|
| `agencia` | `codigo` PK char(4) · `nome` · `municipio` · `uf` char(2) | 0001, 0002 |
| `titular` | `id` PK bigserial · `cpf` char(11) UNIQUE · `nome` · `nascimento` date | 0001 |
| `conta_poupanca` | `numero` PK bigint · `agencia_codigo` FK→agencia · `titular_id` FK→titular · `aberta_em` date · `encerrada_em` date NULL · `ativa` boolean | 0001, 0002 |
| `movimento` | `id` PK bigserial · `conta_numero` FK→conta_poupanca · `data_movimento` date · `tipo` varchar(12) · `valor` numeric(15,2) · `saldo_apos` numeric(15,2) · **`estorno_de` FK→movimento NULL** | 0001 |
| `credito_rendimento` | `id` PK bigserial · `conta_numero` FK · `competencia` date · `base_calculo` numeric(15,2) · `taxa` numeric(8,6) · `valor` numeric(15,2) | 0002 |
| `situacao_conta` | `id` PK bigserial · `conta_numero` FK · `situacao` varchar(12) · `vigente_de` date · `vigente_ate` date NULL | 0002 |

`movimento.estorno_de` é auto-referência: um `LEFT JOIN` da tabela consigo mesma, que é o tipo de
consulta que se degrada sob volume. `POUPANCA-0001` é a linha de base contra a qual os outros nove
serão comparados, então convém que não seja trivial.

Índices: `movimento(data_movimento)`, `credito_rendimento(competencia)`,
`situacao_conta(conta_numero, vigente_de)`.

- [ ] **Passo 2: Escrever as duas consultas principais**

**`POUPANCA-0001` — Movimentação diária de contas de poupança** · 120 s

- Tabelas: `movimento` m · `conta_poupanca` c · `agencia` a · `titular` t · `movimento` e (estorno)
- Junções: `m→c→a`, `c→t`, `LEFT JOIN movimento e ON e.estorno_de = m.id`
- Filtro: `m.data_movimento = :dataReferencia - INTERVAL '1 day'`
  **O intervalo de um dia não é engano:** `RN-07` define a data de referência como o dia do disparo,
  e o ciclo roda de madrugada — o artefato de uma data contém o movimento fechado do dia anterior.
- Ordenação: `a.codigo, c.numero, m.id`
- Saída (8 colunas): agência, conta, titular, data, tipo, valor, saldo após, estornado

**`POUPANCA-0002` — Rendimento creditado por faixa de saldo** · 180 s

- Tabelas: `credito_rendimento` r · `conta_poupanca` c · `agencia` a · `situacao_conta` s
- Junções: `r→c→a`; `s` pela vigência:
  `s.vigente_de <= :dataReferencia AND (s.vigente_ate IS NULL OR s.vigente_ate >= :dataReferencia)`
- Filtro: `date_trunc('month', r.competencia) = date_trunc('month', :dataReferencia)`
- Agrupamento: por agência, **com quebra de página**; dentro dela, por faixa de saldo
  (`CASE` sobre `r.base_calculo`: até 1.000 · 1.000–10.000 · 10.000–50.000 · acima)
- Saída: agência, faixa, quantidade de contas, base total, taxa média, valor creditado

A junção por vigência é onde um erro de intervalo produziria **número errado sem produzir erro** —
motivo pelo qual `situacao_conta` existe.

- [ ] **Passo 3: Escrever a especificação dos dois JRXMLs**

Estrutura obrigatória de cada uma:

```markdown
### POUPANCA-0001 — JRXML

- **Fonte:** A (DejaVu Sans) · **Imagem:** 1 (logo institucional, no `title`)
- **Página:** A4 retrato
- **Parâmetro:** `dataReferencia` (java.time.LocalDate)
- **Bandas:**
  - `title` — nome do relatório, data em `dd/MM/yyyy`, imagem 1, **e o cabeçalho de colunas**
  - `pageHeader` — apenas um filete horizontal (ornamento descartável)
  - `detail` — uma linha por movimento, 8 colunas
  - `pageFooter` — número de página (ornamento descartável)
  - `summary` — total de créditos, débitos e saldo final
- **RA-59:** o cabeçalho de colunas vive no `title` e em nenhum outro lugar. É o que faz o XLSX
  contínuo de `RF-21` funcionar sem repetição.
```

Repita para `POUPANCA-0002`, com: fonte B (DejaVu Serif), imagem 2 (selo de rendimento), A4
**paisagem**, banda `groupHeader` por agência com `isStartNewPage="true"`, e `groupFooter` com
subtotal.

- [ ] **Passo 4: Escrever o seed — este é o padrão para os outros quatro produtos**

```sql
-- V2__seed_poupanca.sql
-- Volumes: 50 agencias, 300 titulares, 500 contas, ~6.000 movimentos.
-- Tecnica: generate_series, nunca INSERT literal em massa.

INSERT INTO poupanca.agencia (codigo, nome, municipio, uf)
SELECT lpad(g::text, 4, '0'),
       'Agencia ' || g,
       (ARRAY['Sao Paulo','Rio de Janeiro','Belo Horizonte','Curitiba','Recife'])[1 + g % 5],
       (ARRAY['SP','RJ','MG','PR','PE'])[1 + g % 5]
FROM generate_series(1, 50) g;

INSERT INTO poupanca.titular (cpf, nome, nascimento)
SELECT lpad(g::text, 11, '0'),
       'Titular ' || g,
       DATE '1960-01-01' + (g * 37 % 20000)
FROM generate_series(1, 300) g;

INSERT INTO poupanca.conta_poupanca (numero, agencia_codigo, titular_id, aberta_em, encerrada_em, ativa)
SELECT 100000 + g,
       lpad((1 + g % 50)::text, 4, '0'),
       1 + g % 300,
       DATE '2020-01-01' + (g * 7 % 2000),
       CASE WHEN g % 25 = 0 THEN DATE '2026-01-15' ELSE NULL END,
       g % 25 <> 0
FROM generate_series(1, 500) g;

-- ~6.000 movimentos, concentrados nos ultimos 10 dias para que a data de
-- referencia do ciclo sempre encontre volume.
INSERT INTO poupanca.movimento (conta_numero, data_movimento, tipo, valor, saldo_apos)
SELECT 100000 + (1 + g % 500),
       DATE '2026-08-11' - (g % 10),
       (ARRAY['CREDITO','DEBITO','RENDIMENTO'])[1 + g % 3],
       round((50 + (g % 5000))::numeric, 2),
       round((1000 + (g % 90000))::numeric, 2)
FROM generate_series(1, 6000) g;

-- 1 em cada 40 movimentos e estorno de outro
UPDATE poupanca.movimento m
SET estorno_de = m.id - 1
WHERE m.id % 40 = 0 AND m.id > 1;

INSERT INTO poupanca.credito_rendimento (conta_numero, competencia, base_calculo, taxa, valor)
SELECT 100000 + (1 + g % 500),
       DATE '2026-08-01',
       round((500 + (g % 60000))::numeric, 2),
       0.005000,
       round(((500 + (g % 60000)) * 0.005)::numeric, 2)
FROM generate_series(1, 1500) g;

INSERT INTO poupanca.situacao_conta (conta_numero, situacao, vigente_de, vigente_ate)
SELECT 100000 + (1 + g % 500),
       (ARRAY['ATIVA','INATIVA','BLOQUEADA'])[1 + g % 3],
       DATE '2026-01-01' + (g % 200),
       CASE WHEN g % 3 = 0 THEN DATE '2026-12-31' ELSE NULL END
FROM generate_series(1, 700) g;
```

- [ ] **Passo 5: Aplicar e validar as duas consultas**

```bash
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f processador-poupanca/src/main/resources/db/migration/V1__cria_tabelas_poupanca.sql
$PSQL -f processador-poupanca/src/main/resources/db/migration/V2__seed_poupanca.sql
$PSQL -c "SELECT count(*) AS movimentos FROM poupanca.movimento;"
$PSQL -c "SELECT count(*) AS estornos FROM poupanca.movimento WHERE estorno_de IS NOT NULL;"
```

Depois rode as duas consultas principais com `:dataReferencia = DATE '2026-08-12'` e confirme que
**ambas retornam linhas**. Consulta que volta vazia com o seed aplicado é defeito de filtro — o mais
provável é o intervalo de um dia da 0001 ou a vigência da 0002.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/catalogo/poupanca.md processador-poupanca/src/main/resources/db/migration/
git commit -m "$(cat <<'EOF'
Domínio, schema e seed de POUPANCA

Seis tabelas, todas lidas por uma das duas consultas. O movimento tem
auto-referência para estorno, de propósito: um LEFT JOIN da tabela
consigo mesma se degrada sob volume, e POUPANCA-0001 é a linha de base
contra a qual os outros nove serão comparados.

A situacao_conta tem vigência, e é onde um erro de intervalo produziria
número errado sem produzir erro.

O filtro da 0001 usa a data de referência menos um dia: RN-07 define a
data como o dia do disparo, e o ciclo roda de madrugada, então o
artefato de um dia contém o movimento fechado do anterior.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: CLIENTE

**Arquivos:**
- Criar: `docs/catalogo/cliente.md`
- Criar: `processador-cliente/src/main/resources/db/migration/V1__cria_tabelas_cliente.sql`
- Criar: `processador-cliente/src/main/resources/db/migration/V2__seed_cliente.sql`

- [ ] **Passo 1: Escrever o DDL — 6 tabelas**

| Tabela | Colunas | Lida por |
|---|---|---|
| `segmento` | `id` PK smallserial · `nome` · `faixa_renda_min` numeric(15,2) · `faixa_renda_max` numeric(15,2) NULL | 0005 |
| `cliente` | `id` PK bigserial · `cpf_cnpj` varchar(14) UNIQUE · `nome` · `tipo` char(2) — PF/PJ · `segmento_id` FK→segmento · `cadastrado_em` date | 0001, 0005 |
| `documento` | `id` PK bigserial · `cliente_id` FK · `tipo` varchar(20) · `numero` varchar(30) · `emitido_em` date · `valido_ate` date NULL · `situacao` varchar(10) — OK/VENCIDO/AUSENTE | 0001 |
| `endereco` | `id` PK bigserial · `cliente_id` FK · `tipo` varchar(12) · `logradouro` · `numero` varchar(10) · `municipio` · `uf` char(2) · `cep` char(8) | **subrelatório de 0001** |
| `relacionamento` | `id` PK bigserial · `cliente_id` FK · `agencia_codigo` char(4) · `gerente_nome` · `iniciado_em` date | 0005 |
| `contato` | `id` PK bigserial · `cliente_id` FK · `tipo` varchar(10) · `valor` · `preferencial` boolean | 0005 |

Índices: `documento(cliente_id, situacao)`, `cliente(segmento_id)`, `contato(cliente_id) WHERE preferencial`.

- [ ] **Passo 2: Escrever as duas consultas principais**

**`CLIENTE-0001` — Cadastro de clientes com pendência documental** · 180 s

- Tabelas: `cliente` c · `documento` d
- Junção: `c→d`
- Filtro: `d.situacao <> 'OK' OR (d.valido_ate IS NOT NULL AND d.valido_ate < :dataReferencia)`
- Ordenação: `c.nome, d.tipo`
- Saída (7 colunas): CPF/CNPJ, nome, tipo, documento, número, situação, vencido em
- **Subrelatório:** endereços do cliente, alimentado por `endereco` filtrado por `cliente_id`. É o
  que exercita `RN-34` — o CSV entrega o dataset da consulta **principal**, sem o subrelatório.

**`CLIENTE-0005` — Distribuição de clientes por segmento e agência** · 120 s

- Tabelas: `cliente` c · `segmento` s · `relacionamento` r · `contato` t
- Junções: `c→s`, `c→r`, `LEFT JOIN contato t ON t.cliente_id = c.id AND t.preferencial`
- Filtro: `c.cadastrado_em <= :dataReferencia`
- Ordenação: `s.nome, r.agencia_codigo, c.nome`
- Saída: **12 colunas** — segmento, faixa mín, faixa máx, agência, gerente, CPF/CNPJ, nome, tipo,
  cadastrado em, relacionamento desde, contato preferencial, tipo de contato
- É a **listagem larga** da matriz: 12 colunas em A4 paisagem é o que estressa o layout e o XLSX.

- [ ] **Passo 3: Especificação dos dois JRXMLs**

`CLIENTE-0001`: fonte **A** (DejaVu Sans), imagem **1**, A4 retrato, banda `detail` com o
subrelatório de endereços embutido. Cabeçalho de colunas no `title`.

`CLIENTE-0005`: fonte **C** (a empacotada por nós), imagem **3**, A4 **paisagem**, sem subrelatório.
Cabeçalho de colunas no `title`. **É o primeiro relatório a usar a fonte C**, e portanto o primeiro
que falha se `ADR-0002` for violado.

- [ ] **Passo 4: Escrever o seed**

Mesma técnica da Tarefa 2 — `INSERT ... SELECT generate_series(...)`, nunca `INSERT` literal.
Volumes-alvo:

| Tabela | Linhas |
|---|---:|
| `segmento` | 8 |
| `cliente` | 1.200 |
| `documento` | 2.400 — **1 em cada 3 com situação diferente de OK**, para que a 0001 tenha volume |
| `endereco` | 1.800 |
| `relacionamento` | 1.200 |
| `contato` | 2.400 — um preferencial por cliente |

- [ ] **Passo 5: Aplicar e validar**

```bash
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f processador-cliente/src/main/resources/db/migration/V1__cria_tabelas_cliente.sql
$PSQL -f processador-cliente/src/main/resources/db/migration/V2__seed_cliente.sql
$PSQL -c "SELECT count(*) FROM cliente.documento WHERE situacao <> 'OK';"
```

Rode as duas consultas com `:dataReferencia = DATE '2026-08-12'` e confirme que ambas retornam
linhas.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/catalogo/cliente.md processador-cliente/src/main/resources/db/migration/
git commit -m "$(cat <<'EOF'
Domínio, schema e seed de CLIENTE

O endereco existe para ser subrelatório, e é assim que a cláusula do
CSV sem subrelatório deixa de ser regra sem teste: o CSV entrega o
dataset da consulta principal, e o endereço não está nele.

A 0005 tem doze colunas de propósito — é a listagem larga da matriz, e
é o que estressa layout e XLSX. É também o primeiro relatório a usar a
fonte C, a única que prova que o classpath é compartilhado.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: CONTACORRENTE

**Arquivos:**
- Criar: `docs/catalogo/contacorrente.md`
- Criar: `processador-contacorrente/src/main/resources/db/migration/V1__cria_tabelas_contacorrente.sql`
- Criar: `processador-contacorrente/src/main/resources/db/migration/V2__seed_contacorrente.sql`

- [ ] **Passo 1: Escrever o DDL — 6 tabelas**

| Tabela | Colunas | Lida por |
|---|---|---|
| `conta_corrente` | `numero` PK bigint · `agencia_codigo` char(4) · `titular_nome` · `aberta_em` date · `limite` numeric(15,2) · `ativa` boolean | 0001, 1234 |
| `lancamento` | `id` PK bigserial · `conta_numero` FK · `data_lancamento` date · `historico` varchar(60) · `valor` numeric(15,2) · `natureza` char(1) — D/C · `documento` varchar(20) | 0001 |
| `saldo_diario` | `conta_numero` FK + `data` date — **PK composta** · `saldo_inicial` numeric(15,2) · `saldo_final` numeric(15,2) | 0001 |
| `pacote_servico` | `id` PK smallserial · `nome` · `mensalidade` numeric(10,2) · `franquia_saques` int · `franquia_ted` int | 1234 |
| `conta_pacote` | `id` PK bigserial · `conta_numero` FK · `pacote_id` FK · `vigente_de` date · `vigente_ate` date NULL | 1234 |
| `tarifa` | `id` PK bigserial · `conta_numero` FK · `pacote_id` FK · `data_cobranca` date · `tipo` varchar(20) · `valor` numeric(10,2) · `isenta` boolean | 1234 |

Índices: `lancamento(data_lancamento)`, `lancamento(conta_numero, data_lancamento)`,
`tarifa(data_cobranca)`, `conta_pacote(conta_numero, vigente_de)`.

- [ ] **Passo 2: Escrever as duas consultas principais**

**`CONTACORRENTE-0001` — Extrato consolidado de conta corrente** · **300 s**

- Tabelas: `lancamento` l · `conta_corrente` c · `saldo_diario` s
- Junções: `l→c`; `s ON s.conta_numero = l.conta_numero AND s.data = l.data_lancamento`
- Filtro: `l.data_lancamento = :dataReferencia - INTERVAL '1 day'`
- Ordenação: `c.agencia_codigo, c.numero, l.id`
- Saída (9 colunas): agência, conta, titular, data, histórico, documento, valor, natureza, saldo final
- **É o maior dataset do conjunto** — o que sustenta `R-05` e a medição de latência de `R-09`.

**`CONTACORRENTE-1234` — Tarifas debitadas por pacote de serviços** · 180 s

- Tabelas: `tarifa` t · `conta_pacote` cp · `pacote_servico` p · `conta_corrente` c
- Junções: `t→c`; `cp` pela vigência
  (`cp.vigente_de <= :dataReferencia AND (cp.vigente_ate IS NULL OR cp.vigente_ate >= :dataReferencia)`);
  `cp→p`
- Filtro: `date_trunc('month', t.data_cobranca) = date_trunc('month', :dataReferencia)`
- Agrupamento: por pacote, com subtotal
- Saída: pacote, mensalidade, agência, conta, titular, tipo de tarifa, valor, isenta

- [ ] **Passo 3: Especificação dos dois JRXMLs**

`CONTACORRENTE-0001`: fonte **B** (DejaVu Serif), imagem **2**, A4 paisagem, listagem contínua sem
agrupamento. Cabeçalho no `title`.

`CONTACORRENTE-1234`: fonte **A** (DejaVu Sans), imagem **4**, A4 retrato, `groupHeader` por pacote
com subtotal no `groupFooter`. Cabeçalho no `title`.

- [ ] **Passo 4: Escrever o seed**

Volumes-alvo — este produto carrega o maior volume do projeto:

| Tabela | Linhas |
|---|---:|
| `conta_corrente` | 400 |
| **`lancamento`** | **20.000** — concentrados nos últimos 10 dias |
| `saldo_diario` | 4.000 — 400 contas × 10 dias |
| `pacote_servico` | 6 |
| `conta_pacote` | 500 |
| `tarifa` | 3.000 |

**20.000 é o maior volume e ainda está abaixo do teto de 50.000 de `RNF-06`.** Isso é deliberado: o
seed não deve estourar o teto sozinho, senão toda apuração do produto falharia. O teste de `RF-49`
injeta um resultado de contagem, e não volume real — ver §6 da spec.

- [ ] **Passo 5: Aplicar e validar**

```bash
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f processador-contacorrente/src/main/resources/db/migration/V1__cria_tabelas_contacorrente.sql
$PSQL -f processador-contacorrente/src/main/resources/db/migration/V2__seed_contacorrente.sql
$PSQL -c "SELECT count(*) AS lancamentos FROM contacorrente.lancamento;"
$PSQL -c "SELECT count(*) AS do_dia FROM contacorrente.lancamento WHERE data_lancamento = DATE '2026-08-11';"
```

O segundo número é o tamanho real do dataset de `CONTACORRENTE-0001` — anote-o, porque é o insumo da
calibração de `R-09`.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/catalogo/contacorrente.md processador-contacorrente/src/main/resources/db/migration/
git commit -m "$(cat <<'EOF'
Domínio, schema e seed de CONTACORRENTE

O lancamento recebe 20.000 linhas e é a maior tabela do projeto, o que
faz de CONTACORRENTE-0001 o maior dataset do conjunto e o insumo da
calibração de R-09.

Vinte mil fica abaixo do teto de 50.000 de propósito: um seed que
estourasse o teto faria toda apuração do produto falhar. RF-49 é
testado injetando o resultado da contagem, não materializando volume.

O conta_pacote tem vigência, então a consulta de tarifas precisa
filtrar a data de referência corretamente para atribuir a tarifa ao
pacote certo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: CONSORCIO — o produto do barcode

**Arquivos:**
- Criar: `docs/catalogo/consorcio.md`
- Criar: `processador-consorcio/src/main/resources/db/migration/V1__cria_tabelas_consorcio.sql`
- Criar: `processador-consorcio/src/main/resources/db/migration/V2__seed_consorcio.sql`

- [ ] **Passo 1: Escrever o DDL — 6 tabelas**

| Tabela | Colunas | Lida por |
|---|---|---|
| `grupo` | `id` PK serial · `codigo` varchar(10) UNIQUE · `bem_tipo` varchar(20) · `prazo_meses` int · `iniciado_em` date | 0002, 9874 |
| `cota` | `id` PK bigserial · `grupo_id` FK · `numero` int · `consorciado_nome` · `cpf` char(11) · `adquirida_em` date · `situacao` varchar(12) | 0002, 9874 |
| `assembleia` | `id` PK bigserial · `grupo_id` FK · `numero` int · `realizada_em` date | 0002 |
| `contemplacao` | `id` PK bigserial · `cota_id` FK · `assembleia_id` FK · `modalidade` varchar(10) — SORTEIO/LANCE · `valor_credito` numeric(15,2) · **`codigo_comprovante` varchar(44)** | 0002 |
| `lance` | `id` PK bigserial · `cota_id` FK · `assembleia_id` FK · `percentual` numeric(5,2) · `tipo` varchar(10) | 0002 |
| `parcela` | `id` PK bigserial · `cota_id` FK · `numero` int · `vencimento` date · `valor` numeric(15,2) · `pago_em` date NULL | 9874 |

**`contemplacao.codigo_comprovante` é o campo do barcode.** 44 caracteres numéricos — o mesmo
comprimento de uma linha digitável de boleto, o que torna o `Code128` realista em largura.

Índices: `contemplacao(assembleia_id)`, `parcela(cota_id, vencimento)`, `cota(grupo_id)`.

- [ ] **Passo 2: Escrever as duas consultas principais**

**`CONSORCIO-0002` — Contemplações por grupo e assembleia** · 180 s

- Tabelas: `contemplacao` ct · `cota` co · `assembleia` a · `grupo` g · `lance` l
- Junções: `ct→co→g`, `ct→a`, `LEFT JOIN lance l ON l.cota_id = co.id AND l.assembleia_id = a.id`
- Filtro: `a.realizada_em <= :dataReferencia`
- Ordenação: `g.codigo, a.numero, co.numero`
- Saída: grupo, bem, assembleia, data, cota, consorciado, modalidade, percentual do lance, valor do
  crédito, **código do comprovante**
- **O barcode renderiza `codigo_comprovante`.** É o único elemento do conjunto que produz renderer
  serializado, e é o que exercita `R-04`.

**`CONSORCIO-9874` — Inadimplência de cotas por prazo decorrido** · 120 s

- Tabelas: `parcela` p · `cota` co · `grupo` g
- Junções: `p→co→g`
- Filtro: `p.pago_em IS NULL AND p.vencimento < :dataReferencia`
- Agrupamento: por faixa de dias em atraso (`CASE` sobre `:dataReferencia - p.vencimento`:
  até 30 · 31–90 · 91–180 · acima de 180)
- Saída: faixa, grupo, cota, consorciado, parcela, vencimento, dias em atraso, valor

- [ ] **Passo 3: Especificação dos dois JRXMLs**

`CONSORCIO-0002`: fonte **C**, imagem **1**, A4 retrato. **Elemento de barcode `Code128` sobre
`codigo_comprovante`, na banda `detail`.** Requer `jasperreports-barbecue` ou
`jasperreports-barcode4j` no classpath do módulo — a escolha entre os dois é de SP-8, mas o JRXML
precisa declarar qual.

> Este é **o** relatório de `RA-08`. Sem ele, `R-04` continua declarado e nunca exercido, porque
> nenhum outro critério do projeto obriga um relatório a ter barcode.

`CONSORCIO-9874`: fonte **A**, imagem **5**, A4 retrato, `groupHeader` por faixa de atraso.

- [ ] **Passo 4: Escrever o seed**

Volumes-alvo:

| Tabela | Linhas |
|---|---:|
| `grupo` | 30 |
| `cota` | 900 |
| `assembleia` | 200 |
| `contemplacao` | 400 |
| `lance` | 600 |
| `parcela` | 9.000 — **1 em cada 4 sem `pago_em`**, para que a 9874 tenha volume |

O `codigo_comprovante` é gerado com `lpad((...)::text, 44, '0')`, produzindo 44 dígitos.

- [ ] **Passo 5: Aplicar e validar**

```bash
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f processador-consorcio/src/main/resources/db/migration/V1__cria_tabelas_consorcio.sql
$PSQL -f processador-consorcio/src/main/resources/db/migration/V2__seed_consorcio.sql
$PSQL -c "SELECT count(*) AS inadimplentes FROM consorcio.parcela WHERE pago_em IS NULL;"
$PSQL -c "SELECT length(codigo_comprovante) AS tamanho, count(*) FROM consorcio.contemplacao GROUP BY 1;"
```

O segundo comando deve devolver **uma única linha, com `tamanho = 44`**. Comprimento variável
quebraria a largura do barcode de forma imprevisível.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/catalogo/consorcio.md processador-consorcio/src/main/resources/db/migration/
git commit -m "$(cat <<'EOF'
Domínio, schema e seed de CONSORCIO, o produto do barcode

A contemplacao carrega codigo_comprovante com 44 dígitos, o mesmo
comprimento de uma linha digitável, e é sobre ele que o Code128
renderiza. Contemplação de consórcio tem comprovante, então o código de
barras tem razão de existir ali — não é elemento posto para satisfazer
critério.

É o único relatório do conjunto que produz renderer serializado, e sem
ele R-04 seguiria declarado e nunca exercido.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: EMPRESTIMO

**Arquivos:**
- Criar: `docs/catalogo/emprestimo.md`
- Criar: `processador-emprestimo/src/main/resources/db/migration/V1__cria_tabelas_emprestimo.sql`
- Criar: `processador-emprestimo/src/main/resources/db/migration/V2__seed_emprestimo.sql`

- [ ] **Passo 1: Escrever o DDL — 6 tabelas**

| Tabela | Colunas | Lida por |
|---|---|---|
| `linha_credito` | `id` PK smallserial · `nome` · `taxa_am` numeric(8,6) · `prazo_max_meses` int · `garantia_exigida` boolean | 0003, 4567 |
| `contrato` | `id` PK bigserial · `linha_id` FK · `cliente_nome` · `cpf` char(11) · `valor` numeric(15,2) · `contratado_em` date · `prazo_meses` int | 0003, 4567 |
| `parcela` | `id` PK bigserial · `contrato_id` FK · `numero` int · `vencimento` date · `valor` numeric(15,2) · `pago_em` date NULL · `dias_atraso` int | 0003 |
| `garantia` | `id` PK bigserial · `contrato_id` FK · `tipo` varchar(20) · `descricao` · `valor_avaliado` numeric(15,2) | **subrelatório de 0003** |
| `liberacao` | `id` PK bigserial · `contrato_id` FK · `data_liberacao` date · `valor` numeric(15,2) · `conta_credito` bigint | 4567 |
| `renegociacao` | `id` PK bigserial · `contrato_origem_id` FK→contrato · `contrato_novo_id` FK→contrato · `data_renegociacao` date · `motivo` varchar(60) | 0003 |

`renegociacao` referencia `contrato` **duas vezes**. Índices: `parcela(contrato_id, vencimento)`,
`liberacao(data_liberacao)`, `garantia(contrato_id)`.

- [ ] **Passo 2: Escrever as duas consultas principais**

**`EMPRESTIMO-0003` — Carteira de empréstimos por faixa de atraso** · 180 s

- Tabelas: `contrato` c · `parcela` p · `linha_credito` l · `renegociacao` r
- Junções: `c→l`, `c→p`, `LEFT JOIN renegociacao r ON r.contrato_origem_id = c.id`
- Filtro: `p.pago_em IS NULL AND p.vencimento < :dataReferencia`
- Agrupamento: por faixa de atraso (até 30 · 31–90 · 91–180 · acima), **com quebra de página**
- Saída: faixa, linha, contrato, cliente, valor, parcela, vencimento, dias em atraso, renegociado
- **Subrelatório:** garantias do contrato, de `garantia` filtrada por `contrato_id`
- É a **combinação** da matriz: subrelatório **e** agrupamento no mesmo relatório

**`EMPRESTIMO-4567` — Liberações do dia por linha de crédito** · 120 s

- Tabelas: `liberacao` lb · `contrato` c · `linha_credito` l
- Junções: `lb→c→l`
- Filtro: `lb.data_liberacao = :dataReferencia - INTERVAL '1 day'`
- Ordenação: `l.nome, lb.id`
- Saída: linha, taxa, contrato, cliente, valor liberado, conta de crédito, data

- [ ] **Passo 3: Especificação dos dois JRXMLs**

`EMPRESTIMO-0003`: fonte **B**, imagem **3**, A4 paisagem, `groupHeader` por faixa com
`isStartNewPage="true"`, e subrelatório de garantias na banda `detail`. Cabeçalho no `title`.

`EMPRESTIMO-4567`: fonte **C**, imagem **6**, A4 retrato, listagem simples. Cabeçalho no `title`.

- [ ] **Passo 4: Escrever o seed**

Volumes-alvo:

| Tabela | Linhas |
|---|---:|
| `linha_credito` | 8 |
| `contrato` | 700 |
| `parcela` | 8.400 — 12 por contrato, **1 em cada 5 sem `pago_em`** |
| `garantia` | 500 |
| `liberacao` | 700 — concentradas nos últimos 10 dias |
| `renegociacao` | 80 |

- [ ] **Passo 5: Aplicar e validar**

```bash
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f processador-emprestimo/src/main/resources/db/migration/V1__cria_tabelas_emprestimo.sql
$PSQL -f processador-emprestimo/src/main/resources/db/migration/V2__seed_emprestimo.sql
$PSQL -c "SELECT count(*) AS em_atraso FROM emprestimo.parcela WHERE pago_em IS NULL AND vencimento < DATE '2026-08-12';"
$PSQL -c "SELECT count(*) AS liberadas FROM emprestimo.liberacao WHERE data_liberacao = DATE '2026-08-11';"
```

Ambos devem ser maiores que zero.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docs/catalogo/emprestimo.md processador-emprestimo/src/main/resources/db/migration/
git commit -m "$(cat <<'EOF'
Domínio, schema e seed de EMPRESTIMO

A 0003 combina subrelatório e agrupamento com quebra de página no mesmo
relatório, que é o caso que nenhum outro do conjunto cobre.

A renegociacao referencia contrato duas vezes, origem e novo, o que dá
à consulta um LEFT JOIN sobre a mesma tabela por caminho diferente do
estorno de POUPANCA.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Verificação consolidada

**Arquivos:** nenhum novo. Esta tarefa confere e corrige.

- [ ] **Passo 1: Conferir os dez critérios de aceite**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
export PGPASSWORD=sp6a
PSQL="psql -h localhost -p 5433 -U postgres -d scheduler -tA"

echo "1. arquivos:      $(ls docs/catalogo/*.md | wc -l)  (esperado 6: README + 5 produtos)"
echo "2. relatorios:    $(grep -hoE '[A-Z]+-[0-9]{4}' docs/catalogo/*.md | sort -u | wc -l)  (esperado 10)"
echo "4. barcodes:      $(grep -licE 'barcode|code128' docs/catalogo/*.md)  (esperado 2: README e consorcio)"
echo "5. subrelatorios: $(grep -licE 'subrelat' docs/catalogo/*.md)  (esperado >= 3)"
echo "3. fonte e imagem distintas em cada par (a exigencia central de RA-08):"
grep -oE '^\| `[A-Z]+-[0-9]{4}` \| [ABC] \| [1-6] \|' docs/catalogo/README.md \
  | sed -E 's/^\| `([A-Z]+)-[0-9]{4}` \| ([ABC]) \| ([1-6]) \|/\1 \2\3/' \
  | awk '{if(p==$1){if(f==$2)print "   PAR IGUAL: " $1; }else{p=$1}; f=$2}'
echo "   (vazio acima = os cinco pares diferem em fonte e imagem)"
echo "8. migrations:    $(ls processador-*/src/main/resources/db/migration/V*.sql 2>/dev/null | wc -l)  (esperado 10)"
echo "9. schemas com tabelas:"
$PSQL -c "SELECT table_schema, count(*) FROM information_schema.tables
          WHERE table_schema IN ('poupanca','cliente','contacorrente','consorcio','emprestimo')
          GROUP BY 1 ORDER BY 1;"
echo "   (esperado 6 tabelas em cada um dos 5 schemas = 30)"
```

- [ ] **Passo 2: Conferir o critério 6 — toda tabela tem leitor**

Este é o mais fácil de violar e o mais caro de descobrir tarde. Para cada tabela criada, o documento
do produto precisa dizer qual relatório a lê:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
export PGPASSWORD=sp6a
for s in poupanca cliente contacorrente consorcio emprestimo; do
  for t in $(psql -h localhost -p 5433 -U postgres -d scheduler -tA \
             -c "SELECT table_name FROM information_schema.tables WHERE table_schema='$s';"); do
    grep -q "\`$t\`" docs/catalogo/$s.md || echo "SEM LEITOR DECLARADO: $s.$t"
  done
done
```

Esperado: nenhuma saída.

- [ ] **Passo 3: Conferir o critério 7 — somas dos tempos**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
grep -A8 '^## Tempos estimados' docs/catalogo/README.md | grep -oE '[0-9]+ s' | paste - - - \
  | awk '{gsub(/ s/,""); if ($1+$2 != $3 || $3 > 600) print "  SOMA ERRADA OU ACIMA DO TETO: " $0}'
echo "(vazio acima = as cinco somas conferem e cabem em 600 s)"
```

- [ ] **Passo 4: Rodar as dez consultas — critério 10**

Execute cada uma das dez consultas principais dos cinco documentos, com
`:dataReferencia = DATE '2026-08-12'`, e confirme que **todas retornam ao menos uma linha**.

Consulta vazia é defeito, e as duas causas prováveis são: o filtro de um dia
(`:dataReferencia - INTERVAL '1 day'`) não encontrar dados porque o seed concentrou o volume em
outras datas; ou a junção por vigência excluir tudo. **Corrija o seed, não a consulta** — a consulta
reflete a regra de negócio, o seed é que precisa acompanhá-la.

- [ ] **Passo 5: Derrubar o PostgreSQL de trabalho e commitar correções**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
docker rm -f sp6a-pg 2>/dev/null || true
git status --short
git add -A docs/catalogo processador-*/src/main/resources/db/migration
git commit -m "$(cat <<'EOF'
Correções da verificação consolidada de SP-6a

Ajustes decorrentes de rodar as dez migrations e as dez consultas
contra um PostgreSQL limpo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)" || echo "nada a corrigir"
```

---

## Definição de pronto

SP-6a termina quando os dez critérios da Tarefa 7 passam e os sete commits estão no branch.

**O que SP-6a entrega para os próximos:** SP-7 encontra o schema de POUPANCA semeado, as duas
consultas escritas e a especificação dos dois JRXMLs — e escreve os `.jrxml`, a *font extension* da
fonte C e as imagens 1 e 2. SP-8+ faz o mesmo para os outros quatro produtos.

**O que continua sem dono até SP-7:** `R-03` segue declarado e não exercido, porque a fonte C é
especificada aqui mas empacotada lá.
