# SP-6b — Contratos internos · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** entregar o schema de controle, o `openapi.yaml`, os tipos gerados e o seed de
desenvolvimento, com os invariantes de `RN-15`, `RN-16` e `RN-51` provados por testes que tentam
violá-los e falham.

**Arquitetura:** sete tarefas em duas metades. Três de schema — tabelas, invariantes, seed. Três de
contrato — erro e exportação, resto dos endpoints, tipos. Uma de verificação consolidada.

**Tech stack:** PostgreSQL 18 · Flyway · OpenAPI 3.1 · `openapi-typescript` · `redocly` para
validação.

**Spec:** [`docs/superpowers/specs/2026-08-12-sp6b-contratos-internos-design.md`](../specs/2026-08-12-sp6b-contratos-internos-design.md)

---

## Restrições globais

- **O glossário de SP-1 fixou os nomes.** SP-6b acrescenta tipos, chaves e restrições; **não
  renomeia nada**. Precisando de outro nome, a mudança volta ao glossário primeiro.
- **Nomes em pt-BR sem acento.** Valores de `status` e `origem` são os literais em pt-BR do PRD.
- **`execucao` nunca recebe `DELETE`** e nunca recebe `UPDATE` depois de terminal.
- **Nenhum endpoint de apuração aceita data de referência** (`RN-54`, `RF-53`). Data em caminho de
  consulta é permitida; no corpo de reprocessamento, não.
- **Migrations do controle vivem em `api/src/main/resources/db/migration`** — o schema de controle é
  da API, os transacionais são dos processadores (SP-6a).
- **O seed de desenvolvimento fica fora das migrations.**
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Ambiente

```bash
docker run -d --name sp6b-pg -e POSTGRES_PASSWORD=sp6b -e POSTGRES_DB=scheduler \
  -p 5434:5432 postgres:18-alpine
export PGPASSWORD=sp6b
alias PSQL='psql -h localhost -p 5434 -U postgres -d scheduler -v ON_ERROR_STOP=1'
```

Ao final: `docker rm -f sp6b-pg`.

---

## Tarefa 1: As oito tabelas

**Arquivos:**
- Criar: `api/src/main/resources/db/migration/V1__cria_schema_controle.sql`

**Interfaces:**
- Produz: o schema `controle` com as oito tabelas, consumido pelas Tarefas 2, 3 e por SP-7.

- [ ] **Passo 1: Escrever a verificação e vê-la falhar**

```bash
export PGPASSWORD=sp6b
psql -h localhost -p 5434 -U postgres -d scheduler -tA -c \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='controle';"
```

Esperado agora: `0`.

- [ ] **Passo 2: Escrever a migration**

```sql
-- V1__cria_schema_controle.sql
CREATE SCHEMA IF NOT EXISTS controle;

-- ---------------------------------------------------------------- catalogo
-- RN-49: o catalogo e derivado do codigo. A aplicacao edita nome,
-- descricao e tempo estimado, e inativa. Nunca cria nem apaga.
CREATE TABLE controle.produto (
  sigla   varchar(20) PRIMARY KEY,
  nome    varchar(120) NOT NULL,
  ativo   boolean      NOT NULL DEFAULT true,
  CONSTRAINT ck_produto_sigla CHECK (sigla ~ '^[A-Z]{1,20}$')   -- RN-01
);

CREATE TABLE controle.relatorio (
  codigo                   varchar(25) PRIMARY KEY,
  sigla_produto            varchar(20) NOT NULL REFERENCES controle.produto (sigla),
  nome                     varchar(200) NOT NULL,
  descricao                text,
  tempo_estimado_segundos  integer      NOT NULL,
  ativo                    boolean      NOT NULL DEFAULT true,
  CONSTRAINT ck_relatorio_codigo CHECK (codigo ~ '^[A-Z]{1,20}-[0-9]{4}$'),  -- RN-02
  CONSTRAINT ck_relatorio_tempo  CHECK (tempo_estimado_segundos > 0)         -- RN-04
);

-- ---------------------------------------------------------------- execucao
-- RN-45: a reserva do ciclo insere com iniciado_em nulo.
-- RN-47: o tempo estimado e COPIADO para dentro da execucao, para que
-- editar o catalogo nao reclassifique execucoes passadas.
CREATE TABLE controle.execucao (
  id                       bigserial PRIMARY KEY,
  data_referencia          date        NOT NULL,
  codigo_relatorio         varchar(25) NOT NULL REFERENCES controle.relatorio (codigo),
  status                   varchar(25) NOT NULL,
  origem                   varchar(25) NOT NULL,
  tempo_estimado_segundos  integer     NOT NULL,
  iniciado_em              timestamptz,
  finalizado_em            timestamptz,
  CONSTRAINT ck_execucao_status CHECK (status IN (
    'em processamento', 'processado com sucesso',
    'processado com alerta', 'processado com erro')),
  CONSTRAINT ck_execucao_origem CHECK (origem IN (
    'agendada', 'retentativa', 'reprocessamento forcado')),
  CONSTRAINT ck_execucao_tempo  CHECK (tempo_estimado_segundos > 0)
);

-- RN-16: no maximo uma execucao vigente por par. A chave primaria E a regra.
-- RN-46: "vigente" e um ponteiro, nao um status — por isso mora fora da execucao.
CREATE TABLE controle.execucao_vigente (
  data_referencia   date        NOT NULL,
  codigo_relatorio  varchar(25) NOT NULL REFERENCES controle.relatorio (codigo),
  execucao_id       bigint      NOT NULL REFERENCES controle.execucao (id),
  PRIMARY KEY (data_referencia, codigo_relatorio)
);

-- ---------------------------------------------------------------- artefato
CREATE TABLE controle.artefato (
  id             bigserial PRIMARY KEY,
  execucao_id    bigint      NOT NULL REFERENCES controle.execucao (id),
  caminho        text        NOT NULL,
  tipo           varchar(10) NOT NULL,
  tamanho_bytes  bigint      NOT NULL,
  expurgado      boolean     NOT NULL DEFAULT false,   -- RA-63
  CONSTRAINT ck_artefato_tipo CHECK (tipo IN ('.jrprint', '.csv.gz'))
);

-- ---------------------------------------------------------------- download
-- RA-66: guarda COPIA dos identificadores, nao apenas as chaves. O historico
-- sobrevive indefinidamente (RN-38) e o nome do relatorio e editavel (RF-41):
-- sem a copia, o download de 2026 apareceria com o nome de 2027.
CREATE TABLE controle.download (
  id                bigserial PRIMARY KEY,
  usuario           varchar(120) NOT NULL,
  codigo_relatorio  varchar(25)  NOT NULL REFERENCES controle.relatorio (codigo),
  nome_relatorio    varchar(200) NOT NULL,
  sigla_produto     varchar(20)  NOT NULL,
  data_referencia   date         NOT NULL,
  formato           varchar(5)   NOT NULL,
  baixado_em        timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT ck_download_formato CHECK (formato IN ('PDF', 'XLSX', 'DOCX', 'CSV'))
);

COMMENT ON COLUMN controle.download.nome_relatorio IS
  'COPIA do nome no momento do download. Use ESTA coluna para exibir, nunca um JOIN com relatorio.nome (RA-66).';
COMMENT ON COLUMN controle.download.sigla_produto IS
  'COPIA da sigla no momento do download. Use ESTA coluna para exibir (RA-66).';

-- ---------------------------------------------------------------- auditoria
-- RN-18: a recusa de nova execucao e evento de auditoria, NAO uma Execucao.
-- Uma tentativa recusada nunca pode aparecer como falha de apuracao.
CREATE TABLE controle.evento_auditoria (
  id              bigserial PRIMARY KEY,
  tipo            varchar(40)  NOT NULL,
  solicitante     varchar(120) NOT NULL,
  motivo          text,
  correlation_id  varchar(64)  NOT NULL,
  ocorrido_em     timestamptz  NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------ acesso
-- RA-61: o unico elo da cadeia que precisa conhecer o catalogo. Perfil,
-- role de relatorio e grupo vivem no Keycloak.
CREATE TABLE controle.relatorio_role (
  codigo_relatorio  varchar(25) NOT NULL REFERENCES controle.relatorio (codigo),
  nome_role         varchar(80) NOT NULL,
  PRIMARY KEY (codigo_relatorio, nome_role)
);
```

- [ ] **Passo 3: Aplicar e verificar**

```bash
export PGPASSWORD=sp6b
PSQL="psql -h localhost -p 5434 -U postgres -d scheduler -v ON_ERROR_STOP=1"
$PSQL -f api/src/main/resources/db/migration/V1__cria_schema_controle.sql
$PSQL -tA -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='controle';"
```

Esperado: `8`.

- [ ] **Passo 4: Verificar que os CHECK de fato rejeitam**

```bash
export PGPASSWORD=sp6b
PSQL="psql -h localhost -p 5434 -U postgres -d scheduler"
echo "-- sigla minuscula deve falhar (RN-01)"
$PSQL -c "INSERT INTO controle.produto (sigla, nome) VALUES ('poupanca','x');" 2>&1 | grep -q 'ck_produto_sigla' && echo "  OK rejeitou"
echo "-- codigo fora do padrao deve falhar (RN-02)"
$PSQL -c "INSERT INTO controle.produto (sigla,nome) VALUES ('POUPANCA','Poupanca');" >/dev/null
$PSQL -c "INSERT INTO controle.relatorio (codigo,sigla_produto,nome,tempo_estimado_segundos)
          VALUES ('POUPANCA-1','POUPANCA','x',60);" 2>&1 | grep -q 'ck_relatorio_codigo' && echo "  OK rejeitou"
echo "-- tempo estimado zero deve falhar (RN-04)"
$PSQL -c "INSERT INTO controle.relatorio (codigo,sigla_produto,nome,tempo_estimado_segundos)
          VALUES ('POUPANCA-0001','POUPANCA','x',0);" 2>&1 | grep -q 'ck_relatorio_tempo' && echo "  OK rejeitou"
```

As três devem imprimir `OK rejeitou`.

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add api/src/main/resources/db/migration/V1__cria_schema_controle.sql
git commit -m "$(cat <<'EOF'
Schema de controle: as oito tabelas

Os nomes vêm do glossário de SP-1 e não foram tocados. O que SP-6b
acrescenta são tipos, chaves e restrições.

A vigência mora fora da execução, numa tabela cuja chave primária é o
par data mais relatório — RN-16 deixa de ser regra de código e passa a
ser restrição de chave.

O download guarda cópia dos identificadores com comentário no próprio
DDL dizendo qual coluna usar para exibir. O histórico sobrevive
indefinidamente e o nome do relatório é editável: sem a cópia, um
download de 2026 apareceria com o nome de 2027.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Os invariantes — triggers, índices e os testes que tentam violar

Esta é a tarefa mais valiosa do plano. Cada teste **tenta violar um invariante e falha**.

**Arquivos:**
- Criar: `api/src/main/resources/db/migration/V2__invariantes_execucao.sql`
- Criar: `api/src/test/resources/sql/invariantes.sql`

- [ ] **Passo 1: Escrever os testes de invariante e vê-los passar indevidamente**

```sql
-- api/src/test/resources/sql/invariantes.sql
-- Cada bloco TENTA violar um invariante. O resultado esperado e ERRO.
-- Se algum bloco tiver sucesso, o invariante nao existe.

\set ON_ERROR_STOP off

-- Preparo
INSERT INTO controle.produto (sigla, nome) VALUES ('TESTE','Teste') ON CONFLICT DO NOTHING;
INSERT INTO controle.relatorio (codigo, sigla_produto, nome, tempo_estimado_segundos)
  VALUES ('TESTE-0001','TESTE','Relatorio de teste',60) ON CONFLICT DO NOTHING;
INSERT INTO controle.execucao (data_referencia, codigo_relatorio, status, origem, tempo_estimado_segundos, iniciado_em, finalizado_em)
  VALUES (DATE '2026-08-12','TESTE-0001','processado com sucesso','agendada',60, now(), now());

\echo '=== 1. UPDATE de execucao terminal deve FALHAR (RN-15) ==='
UPDATE controle.execucao SET status = 'processado com erro'
  WHERE codigo_relatorio = 'TESTE-0001' AND data_referencia = DATE '2026-08-12';

\echo '=== 2. DELETE de execucao deve FALHAR (RN-51) ==='
DELETE FROM controle.execucao WHERE codigo_relatorio = 'TESTE-0001';

\echo '=== 3. Segunda vigente no mesmo par deve FALHAR (RN-16) ==='
INSERT INTO controle.execucao (data_referencia, codigo_relatorio, status, origem, tempo_estimado_segundos)
  VALUES (DATE '2026-08-12','TESTE-0001','em processamento','retentativa',60);
INSERT INTO controle.execucao_vigente (data_referencia, codigo_relatorio, execucao_id)
  SELECT DATE '2026-08-12','TESTE-0001', id FROM controle.execucao
  WHERE codigo_relatorio='TESTE-0001' ORDER BY id LIMIT 1;
INSERT INTO controle.execucao_vigente (data_referencia, codigo_relatorio, execucao_id)
  SELECT DATE '2026-08-12','TESTE-0001', id FROM controle.execucao
  WHERE codigo_relatorio='TESTE-0001' ORDER BY id DESC LIMIT 1;

\echo '=== 4. UPDATE de execucao NAO-terminal deve FUNCIONAR (RN-45) ==='
UPDATE controle.execucao SET iniciado_em = now()
  WHERE codigo_relatorio='TESTE-0001' AND status='em processamento';
```

- [ ] **Passo 2: Rodar antes dos triggers — os blocos 1 e 2 vão passar, e isso é a falha**

```bash
export PGPASSWORD=sp6b
psql -h localhost -p 5434 -U postgres -d scheduler -f api/src/test/resources/sql/invariantes.sql 2>&1 | tail -20
```

Esperado agora: os blocos 1 e 2 **executam com sucesso** — prova de que os invariantes ainda não
existem. O bloco 3 já falha (a PK existe desde a Tarefa 1).

- [ ] **Passo 3: Escrever a migration dos invariantes**

```sql
-- V2__invariantes_execucao.sql

-- RN-15 / RA-67: execucao em status terminal nao muda mais.
-- Protege a linha INTEIRA, sem lista de colunas a excluir — a vigencia
-- mora em outra tabela justamente para permitir isso.
-- O UPDATE durante 'em processamento' continua permitido: RN-45 exige que
-- a reserva insira com iniciado_em nulo e a apuracao preencha depois.
CREATE OR REPLACE FUNCTION controle.fn_execucao_terminal_imutavel()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status <> 'em processamento' THEN
    RAISE EXCEPTION
      'execucao % ja esta em status terminal (%) e nao pode ser alterada (RN-15, RA-67)',
      OLD.id, OLD.status
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER execucao_terminal_imutavel
  BEFORE UPDATE ON controle.execucao
  FOR EACH ROW EXECUTE FUNCTION controle.fn_execucao_terminal_imutavel();

-- RN-51: os metadados de Execucao NUNCA sao expurgados. A metrica primaria
-- tem janela de 30 dias e o artefato dura 7; sem isto, uma limpeza
-- bem-intencionada truncaria a serie sem sinal algum.
CREATE OR REPLACE FUNCTION controle.fn_execucao_sem_delete()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION
    'execucao nunca e removida (RN-51). Tentativa sobre o id %', OLD.id
    USING ERRCODE = 'raise_exception';
END $$;

CREATE TRIGGER execucao_sem_delete
  BEFORE DELETE ON controle.execucao
  FOR EACH ROW EXECUTE FUNCTION controle.fn_execucao_sem_delete();

-- Indices de consulta
CREATE INDEX ix_execucao_data      ON controle.execucao (data_referencia);
CREATE INDEX ix_execucao_relatorio ON controle.execucao (codigo_relatorio, data_referencia);
CREATE INDEX ix_execucao_origem    ON controle.execucao (origem, status);  -- metrica primaria, RF-52
CREATE INDEX ix_artefato_execucao  ON controle.artefato (execucao_id);
CREATE INDEX ix_download_data      ON controle.download (baixado_em DESC);
CREATE INDEX ix_auditoria_correl   ON controle.evento_auditoria (correlation_id);
```

- [ ] **Passo 4: Aplicar e rodar os testes de novo — agora 1, 2 e 3 devem falhar**

```bash
export PGPASSWORD=sp6b
PSQL="psql -h localhost -p 5434 -U postgres -d scheduler"
$PSQL -v ON_ERROR_STOP=1 -f api/src/main/resources/db/migration/V2__invariantes_execucao.sql
$PSQL -c "TRUNCATE controle.execucao_vigente;" -c "DELETE FROM controle.artefato;" >/dev/null
$PSQL -f api/src/test/resources/sql/invariantes.sql 2>&1 \
  | grep -E '^(===|ERROR|UPDATE|DELETE|INSERT)' | head -20
```

Esperado, nesta ordem:

| Bloco | Resultado esperado |
|---|---|
| 1 — UPDATE terminal | `ERROR: execucao ... ja esta em status terminal` |
| 2 — DELETE | `ERROR: execucao nunca e removida` |
| 3 — segunda vigente | `ERROR: duplicate key value violates unique constraint` |
| 4 — UPDATE não-terminal | `UPDATE 1` — **este precisa funcionar** |

**Se o bloco 4 falhar, o trigger está errado.** Ele não pode impedir a apuração de preencher
`iniciado_em` numa execução que ainda está `em processamento` — isso quebraria `RN-45`.

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add api/src/main/resources/db/migration/V2__invariantes_execucao.sql \
        api/src/test/resources/sql/invariantes.sql
git commit -m "$(cat <<'EOF'
Invariantes da execução como propriedade do schema

Dois triggers e um teste que tenta violar cada regra e falha. Um teste
que tenta e não consegue vale mais que qualquer afirmação em prosa.

O trigger de imutabilidade protege a linha inteira quando o status é
terminal, e permite UPDATE enquanto está em processamento — porque
RN-45 exige que a reserva insira com início nulo e a apuração preencha
depois. O quarto bloco do teste existe para provar que essa permissão
continua valendo.

O trigger de DELETE transforma "metadados nunca são expurgados" de
promessa em impossibilidade.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Seed de desenvolvimento

**Arquivos:**
- Criar: `api/src/main/resources/seed/seed-dev.sql`
- Modificar: `Makefile` (alvo `seed-dev`)

- [ ] **Passo 1: Escrever o seed**

Fica **fora** de `db/migration` de propósito: uma migration de seed rodaria em qualquer ambiente que
aplicasse o Flyway e criaria catálogo sem código correspondente — o que `ADR-0009` proíbe.

Conteúdo obrigatório, coerente com SP-6a e com o protótipo de SP-4:

| O que | Volume |
|---|---|
| `produto` | 5 — POUPANCA, CLIENTE, CONTACORRENTE, CONSORCIO, EMPRESTIMO |
| `relatorio` | 10, com os códigos e tempos de SP-6a |
| `execucao` | 70 — 10 relatórios × 7 datas (06/08 a 12/08 de 2026) |
| `execucao_vigente` | 70 ponteiros |
| `artefato` | 2 por execução concluída (`.jrprint` e `.csv.gz`) |
| `download` | ~20, com as cópias preenchidas |

**As quatro exceções, iguais às do protótipo de SP-4:**

```sql
-- Estes quatro casos existem para que a interface seja desenvolvida contra
-- os estados reais, e nao so contra o caminho feliz.
UPDATE ... -- nao: as execucoes ja nascem com o status certo no INSERT
-- 2026-08-12 CONSORCIO-9874    -> 'em processamento'   (RF-20: sem artefato)
-- 2026-08-12 EMPRESTIMO-4567   -> 'processado com erro'(RF-20: sem artefato)
-- 2026-08-11 CLIENTE-0005      -> 'processado com alerta'
-- 2026-08-06 CONTACORRENTE-1234-> artefato.expurgado = true  (RF-24)
```

Use `INSERT ... SELECT` sobre `generate_series` para as 70 execuções, com `CASE` para atribuir os
quatro casos especiais.

O seed termina com `ON CONFLICT DO NOTHING` no catálogo, para ser idempotente e conviver com a
publicação dos processadores (`RA-58`).

- [ ] **Passo 2: Acrescentar o alvo ao `Makefile`**

```makefile
seed-dev: ## Popula o schema de controle com dados de desenvolvimento
	@psql "$${DATABASE_URL:-postgres://scheduler:scheduler@localhost:5432/scheduler}" \
	  -v ON_ERROR_STOP=1 -f api/src/main/resources/seed/seed-dev.sql
	@echo "seed de desenvolvimento aplicado"
```

- [ ] **Passo 3: Verificar**

```bash
export PGPASSWORD=sp6b
PSQL="psql -h localhost -p 5434 -U postgres -d scheduler -tA"
psql -h localhost -p 5434 -U postgres -d scheduler -v ON_ERROR_STOP=1 \
  -f api/src/main/resources/seed/seed-dev.sql
echo "produtos:   $($PSQL -c 'SELECT count(*) FROM controle.produto;')  (esperado 5)"
echo "relatorios: $($PSQL -c 'SELECT count(*) FROM controle.relatorio;')  (esperado 10)"
echo "execucoes:  $($PSQL -c 'SELECT count(*) FROM controle.execucao;')  (esperado >= 70)"
echo "vigentes:   $($PSQL -c 'SELECT count(*) FROM controle.execucao_vigente;')  (esperado 70)"
echo "status distintos:"; $PSQL -c "SELECT status, count(*) FROM controle.execucao GROUP BY 1 ORDER BY 1;"
echo "expurgados: $($PSQL -c 'SELECT count(*) FROM controle.artefato WHERE expurgado;')  (esperado >= 1)"
```

Os quatro status precisam aparecer. Se algum faltar, a interface de SP-7 seria desenvolvida sem
nunca ver aquele estado.

- [ ] **Passo 4: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add api/src/main/resources/seed/seed-dev.sql Makefile
git commit -m "$(cat <<'EOF'
Seed de desenvolvimento, fora das migrations

Cria os dez relatórios de SP-6a e setenta execuções nas sete datas, com
os quatro status representados e um artefato expurgado — os mesmos
casos que o protótipo de SP-4 simulou.

Fica fora de db/migration de propósito: uma migration de seed rodaria
em qualquer ambiente que aplicasse o Flyway e criaria catálogo sem
código correspondente, que é o que ADR-0009 proíbe. Roda por make
seed-dev e é idempotente, para conviver com a publicação dos
processadores.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `openapi.yaml` — erro, listagem e exportação

**Arquivos:**
- Criar: `docs/api/openapi.yaml`

**Interfaces:**
- Produz: o schema `Erro` e os endpoints de listagem e exportação, consumidos pela Tarefa 5 e pela
  geração de tipos da Tarefa 6.

- [ ] **Passo 1: Escrever o cabeçalho e o contrato de erro**

```yaml
openapi: 3.1.0
info:
  title: Scheduler Jasper Report
  version: 1.0.0
  description: |
    Apura relatórios uma vez por dia e os entrega sob demanda.

    **Data de referência nunca é entrada de apuração** (RN-54, RF-53). Ela aparece
    em caminho de consulta, como filtro — nunca no corpo de um endpoint que manda apurar.
servers:
  - url: /api/v1

components:
  schemas:
    Erro:
      # RFC 9457 Problem Details, com a extensao que RA-41 exige.
      type: object
      required: [type, title, status, momento, correlationId]
      properties:
        type:          { type: string, format: uri }
        title:         { type: string }
        status:        { type: integer }
        detail:        { type: string }
        momento:       { type: string, format: date-time }   # RA-41 — ISO 8601
        correlationId: { type: string }                      # RA-41, RF-40

  responses:
    Erro409:
      description: Execução vigente sem artefato válido (RF-20, RN-42)
      content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
    Erro410:
      description: Artefato expurgado pela janela de retenção (RF-24, RN-39)
      content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
    Erro429:
      description: Limite de exportações simultâneas atingido; repita mais tarde (RF-48, RN-53)
      content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
    Erro404:
      description: |
        Não encontrado — inclusive quando o relatório existe mas está fora da cadeia
        de permissão do usuário. É 404 e não 403 de propósito: RN-23 diz que o
        relatório fora da cadeia não é acessível por acesso direto, e um 403
        confirmaria a existência a quem não deveria saber que ele existe.
      content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
```

- [ ] **Passo 2: Escrever os endpoints de listagem e exportação**

```yaml
paths:
  /datas:
    get:
      summary: Datas de referência com artefato disponível
      description: No máximo 7, pela janela de retenção de RN-36.
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items: { type: string, format: date }

  /datas/{data}/produtos:
    get:
      summary: Produtos que a cadeia de permissão do usuário alcança nesta data
      parameters:
        - { name: data, in: path, required: true, schema: { type: string, format: date } }
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  required: [sigla, nome]
                  properties:
                    sigla: { type: string }
                    nome:  { type: string }

  /datas/{data}/produtos/{sigla}/relatorios:
    get:
      summary: Relatórios permitidos do produto nesta data
      parameters:
        - { name: data,  in: path, required: true, schema: { type: string, format: date } }
        - { name: sigla, in: path, required: true, schema: { type: string } }
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  required: [codigo, nome, status, exportavel]
                  properties:
                    codigo:     { type: string }
                    nome:       { type: string }
                    status:
                      type: string
                      enum: ['em processamento', 'processado com sucesso',
                             'processado com alerta', 'processado com erro']
                    exportavel: { type: boolean }   # RN-42
        '404': { $ref: '#/components/responses/Erro404' }

  /relatorios/{codigo}/execucoes/{data}/exportacao:
    get:
      summary: Exporta o relatório no formato pedido — síncrono
      description: |
        RN-30: devolve o arquivo ou o erro na mesma requisição. Não há status
        persistido e não há fila.
      parameters:
        - { name: codigo,  in: path,  required: true, schema: { type: string } }
        - { name: data,    in: path,  required: true, schema: { type: string, format: date } }
        - name: formato
          in: query
          required: true
          schema: { type: string, enum: [PDF, XLSX, DOCX, CSV] }
      responses:
        '200':
          description: O arquivo exportado
          content:
            application/pdf: { schema: { type: string, format: binary } }
            application/vnd.openxmlformats-officedocument.spreadsheetml.sheet:
              { schema: { type: string, format: binary } }
            application/vnd.openxmlformats-officedocument.wordprocessingml.document:
              { schema: { type: string, format: binary } }
            text/csv: { schema: { type: string, format: binary } }
        '404': { $ref: '#/components/responses/Erro404' }
        '409': { $ref: '#/components/responses/Erro409' }
        '410': { $ref: '#/components/responses/Erro410' }
        '429': { $ref: '#/components/responses/Erro429' }
```

- [ ] **Passo 3: Validar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
npx -y @redocly/cli@latest lint docs/api/openapi.yaml
git add docs/api/openapi.yaml
git commit -m "$(cat <<'EOF'
OpenAPI: contrato de erro e os endpoints de exportação

O erro segue RFC 9457 com a extensão que RA-41 exige — momento em ISO
8601 e Correlation ID. Usar o padrão dá o content-type correto e
ferramentas que já sabem lê-lo.

Os códigos mapeiam os RFs um a um: 409 sem artefato válido, 410
expurgado, 429 simultaneidade. O 404 para relatório sem permissão está
documentado com o motivo — um 403 confirmaria a existência do
relatório a quem não deveria saber que ele existe.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: `openapi.yaml` — catálogo, reprocessamento, downloads, acesso e interno

**Arquivos:**
- Modificar: `docs/api/openapi.yaml`

- [ ] **Passo 1: Acrescentar catálogo e reprocessamento**

```yaml
  /produtos:
    get: { summary: Lista os produtos, responses: { '200': { description: ok } } }

  /produtos/{sigla}:
    patch:
      summary: Edita o nome do produto (RF-41)
      description: Sigla é imutável (RN-01) e por isso não aparece no corpo.
      requestBody:
        content:
          application/json:
            schema:
              type: object
              required: [nome]
              properties: { nome: { type: string } }
      responses:
        '200': { description: ok }
        '404': { $ref: '#/components/responses/Erro404' }

  /produtos/{sigla}/inativacao:
    post:
      summary: Inativa o produto (RF-50)
      responses:
        '200': { description: ok }
        '409':
          description: Recusado — o produto ainda tem relatório ativo (RN-05, RF-50)
          content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }

  /relatorios/{codigo}:
    patch:
      summary: Edita nome, descrição e tempo estimado (RF-41)
      description: Código é imutável (RN-02) e por isso não aparece no corpo.
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                nome:                   { type: string }
                descricao:              { type: string }
                tempoEstimadoSegundos:  { type: integer, minimum: 1 }
      responses:
        '200': { description: ok }
        '409':
          description: Recusado — a soma dos tempos do produto passaria do teto (RN-48, RF-47)
          content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }

  /execucoes/reprocessamentos:
    post:
      summary: Solicita reprocessamento forçado (RF-10)
      description: |
        **NÃO recebe data de referência** (RN-54, RF-53). O reprocessamento vale
        sempre para a data corrente. Não acrescente `dataReferencia` a este corpo
        por simetria com os endpoints de consulta: apuração retroativa só produziria
        dado correto se toda base transacional fosse temporal, o que não é garantido.
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [codigoRelatorio, motivo]
              properties:
                codigoRelatorio: { type: string }
                motivo:          { type: string, minLength: 10 }   # RF-11
      responses:
        '202': { description: Aceito; a apuração foi disparada }
        '400':
          description: Motivo ausente ou curto demais (RF-11)
          content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
        '403':
          description: Perfil diferente de ADMINISTRADOR (RF-12)
          content: { application/problem+json: { schema: { $ref: '#/components/schemas/Erro' } } }
```

- [ ] **Passo 2: Acrescentar downloads, acesso e o endpoint interno**

```yaml
  /downloads:
    get:
      summary: Histórico de downloads (RF-23), exclusivo do ADMINISTRADOR
      description: |
        Devolve os identificadores COMO ESTAVAM no momento do download (RF-51, RA-66).
        Não são resolvidos por junção com o catálogo atual.
      parameters:
        - { name: pagina,  in: query, schema: { type: integer, minimum: 0, default: 0 } }
        - { name: tamanho, in: query, schema: { type: integer, minimum: 1, maximum: 200, default: 50 } }
      responses:
        '200': { description: ok }

  /roles-de-relatorio:
    get:  { summary: Lista as roles de relatório (RF-31), responses: { '200': { description: ok } } }
    post: { summary: Cria uma role de relatório (RF-31), responses: { '201': { description: ok } } }

  /roles-de-relatorio/{nome}/relatorios:
    put:
      summary: Vincula a role aos relatórios (RF-31)
      responses: { '200': { description: ok } }

  /grupos:
    get:  { summary: Lista os grupos (RF-32), responses: { '200': { description: ok } } }
    post: { summary: Cria um grupo (RF-32), responses: { '201': { description: ok } } }

  /grupos/{nome}/roles:
    put: { summary: Vincula roles de relatório ao grupo (RF-31), responses: { '200': { description: ok } } }

  /grupos/{nome}/usuarios:
    put:
      summary: Inclui e remove usuários do grupo (RF-32, RF-36)
      description: |
        Opera **apenas** sobre client roles do cliente `relatorios` e sobre grupos.
        Perfil é realm role e está em outro espaço de nomes — o GERENTE não o alcança
        por este endpoint nem por manipulação direta (RF-34, ADR-0005).
      responses: { '200': { description: ok } }

  /interno/expurgo:
    post:
      summary: Recebe a marca de expurgo do MinIO (RA-63)
      description: |
        Autenticado por credencial de serviço, não por JWT de usuário. É superfície
        nova e declarada como tal. A marca é autoritativa quando presente; quando
        falta, a API deriva o estado pela comparação da data de referência com a
        janela de retenção — uma notificação perdida custa inconsistência transitória,
        não resposta errada.
      responses: { '204': { description: Marcado } }
```

- [ ] **Passo 3: Validar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
npx -y @redocly/cli@latest lint docs/api/openapi.yaml
echo "endpoints: $(grep -cE '^  /' docs/api/openapi.yaml)"
echo "corpo de reprocessamento tem data? $(sed -n '/reprocessamentos:/,/^  \//p' docs/api/openapi.yaml | grep -ci 'dataReferencia')  (esperado 0 fora do comentario)"
git add docs/api/openapi.yaml
git commit -m "$(cat <<'EOF'
OpenAPI: catálogo, reprocessamento, downloads, acesso e expurgo

O endpoint de reprocessamento leva escrito por que não tem campo de
data, e não apenas a ausência dele. Sem a explicação, o próximo a ler o
contrato acrescentaria dataReferencia por simetria com os endpoints de
consulta, e a apuração retroativa entraria por uma linha de YAML.

O endpoint de grupos declara que opera apenas sobre client roles: o
perfil é realm role e está em outro espaço de nomes, que é o que torna
RF-34 estrutural e não uma verificação a lembrar.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: Tipos gerados e o job de deriva

**Arquivos:**
- Modificar: `frontend/package.json`, `.github/workflows/ci.yml`
- Criar: `frontend/src/app/api/tipos.ts`

- [ ] **Passo 1: Instalar e gerar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npm install -D openapi-typescript
npx openapi-typescript ../docs/api/openapi.yaml -o src/app/api/tipos.ts
```

- [ ] **Passo 2: Acrescentar o script**

Em `frontend/package.json`, no bloco `scripts`:

```json
"gerar-tipos": "openapi-typescript ../docs/api/openapi.yaml -o src/app/api/tipos.ts"
```

- [ ] **Passo 3: Acrescentar o job de deriva ao CI**

Em `.github/workflows/ci.yml`, um job novo:

```yaml
  tipos-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: {node-version: '24', cache: npm, cache-dependency-path: frontend/package-lock.json}
      - run: npm ci
        working-directory: frontend
      - name: Os tipos gerados precisam estar em dia com o openapi.yaml
        run: |
          cd frontend
          npm run gerar-tipos
          if ! git diff --quiet src/app/api/tipos.ts; then
            echo "ERRO: src/app/api/tipos.ts esta desatualizado."
            echo "Rode 'npm run gerar-tipos' no diretorio frontend e commite o resultado."
            git diff src/app/api/tipos.ts | head -40
            exit 1
          fi
          echo "tipos em dia com o contrato"
```

Versionar sem verificar deixaria contrato e tipos divergirem em silêncio — que é pior que não
versionar.

- [ ] **Passo 4: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npm run gerar-tipos
git diff --quiet src/app/api/tipos.ts && echo "tipos em dia: ok"
npx tsc --noEmit -p tsconfig.json && echo "tipos compilam: ok"
```

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/package.json frontend/package-lock.json frontend/src/app/api/tipos.ts \
        .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
Tipos gerados do contrato, com verificação de deriva no CI

Só tipos, sem cliente HTTP gerado: vinte endpoints não justificam um
cliente inteiro, e o que o guia pede é que erro de contrato vire erro
de compilação.

Ficam versionados para o build não depender de gerar, e um job
regenera e compara. Versionar sem verificar deixaria contrato e tipos
divergirem em silêncio, que é pior que não versionar.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Verificação consolidada

- [ ] **Passo 1: Conferir os dez critérios**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
export PGPASSWORD=sp6b
PSQL="psql -h localhost -p 5434 -U postgres -d scheduler -tA"

echo "1.  tabelas:        $($PSQL -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='controle';")  (esperado 8)"
echo "2-4. invariantes:"
psql -h localhost -p 5434 -U postgres -d scheduler -f api/src/test/resources/sql/invariantes.sql 2>&1 \
  | grep -cE '^ERROR' | xargs -I{} echo "     {} violacoes rejeitadas  (esperado 3)"
echo "5.  openapi valido: $(npx -y @redocly/cli@latest lint docs/api/openapi.yaml >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "6.  erros com id:   $(grep -c "schemas/Erro" docs/api/openapi.yaml)  (esperado >= 8)"
echo "7.  reproc sem data: $(sed -n '/reprocessamentos:/,/^  \/downloads/p' docs/api/openapi.yaml | grep -c 'dataReferencia:')  (esperado 0)"
echo "8.  tipos compilam: $(cd frontend && npx tsc --noEmit -p tsconfig.json >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "9.  job de deriva:  $(grep -c 'tipos-api' .github/workflows/ci.yml)  (esperado 1)"
echo "10. seed:           $($PSQL -c 'SELECT count(DISTINCT status) FROM controle.execucao;')  status distintos (esperado 4)"
```

- [ ] **Passo 2: Derrubar o PostgreSQL e commitar correções**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
docker rm -f sp6b-pg 2>/dev/null || true
git status --short
git add -A api docs/api frontend .github Makefile
git commit -m "Correções da verificação consolidada de SP-6b

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" || echo "nada a corrigir"
```

---

## Definição de pronto

SP-6b termina quando os dez critérios passam e os sete commits estão no branch. Com isso E2 fecha,
junto com SP-6a.

**O que fica para SP-7:** implementar os endpoints que este contrato declara, e as entidades JPA
sobre as tabelas que este schema cria. Nenhum dos dois inventa nome — o glossário fixou, SP-6b
tipou.
