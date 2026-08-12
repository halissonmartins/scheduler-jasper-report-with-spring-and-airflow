# SP-3 — Fundações do repositório · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.

**Objetivo:** entregar o mono repositório Maven, o ferramental de qualidade, o ambiente local, o CI
bloqueante e os documentos de referência, de modo que um clone limpo rode com um comando e o CI
fique verde.

**Arquitetura:** sete tarefas, na ordem do método da spec. A primeira compila os oito módulos
vazios com JasperReports no classpath — é o teste de `R-16`, e vem antes de tudo porque, se a
combinação Jasper 7 + Spring Boot 4.1 + Java 25 não fechar, todo o resto seria trabalho perdido.
Cada tarefa termina com uma verificação executável e um commit.

**Tech stack:** Java 25 · Maven 3.9.16 · Spring Boot 4.1.0 · JasperReports 7.0.8 ·
Spotless 3.9.0 · Docker Compose v5.1.4 · Angular CLI 22.1.3 · Airflow 3.3.0 · GitHub Actions.

**Spec:** [`docs/superpowers/specs/2026-08-12-sp3-fundacoes-do-repositorio-design.md`](../specs/2026-08-12-sp3-fundacoes-do-repositorio-design.md)

---

## Restrições globais

Valem para **todas** as tarefas. Valores copiados da spec e verificados na fonte.

- **`groupId`: `br.com.scheduler`** · **`version`: `0.1.0-SNAPSHOT`** em todos os módulos.
- **Java `release` 25**; Spring Boot 4.1.0 cobre 17–26 (documentação oficial).
- **A versão do JasperReports é declarada UMA vez**, na propriedade `<jasperreports.version>` do
  `pom` raiz. Segunda declaração em qualquer `pom` filho **quebra `ADR-0002`** e o sintoma seria
  `InvalidClassException` na exportação, dias depois.
- **BOM importado, nunca `spring-boot-starter-parent` herdado.**
- **8 módulos no reactor.** `frontend/` e `orquestrador/` **não** entram — são npm e Python.
- **Nenhuma feature, nenhuma migration real, nenhum JRXML, nenhum ArchUnit, nenhum Testcontainers.**
  Esqueleto vazio; a fatia de referência é de SP-7.
- **Pacotes por camada, em pt-BR:** `dominio`, `aplicacao`, `infraestrutura`, `web`.
- **Idioma:** pt-BR em documento, comentário e mensagem de commit.
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### Nota sobre os artefatos do JasperReports

O Jasper 7 é modularizado. Verificado no Maven Central, em 7.0.8, existem: `jasperreports` (core),
`jasperreports-pdf`, `jasperreports-fonts`, `jasperreports-excel-poi`, `jasperreports-fastexcel`,
`jasperreports-barbecue`, `jasperreports-barcode4j`.

**Não existe `jasperreports-docx` nem `jasperreports-xlsx`.** O POI chega via
`jasperreports-excel-poi`. Localizar o artefato do exportador DOCX é trabalho de SP-8, quando a
exportação for implementada — SP-3 declara apenas o core e o `-pdf`, o mínimo para provar que a
combinação resolve.

### Nota sobre o formato deste plano

Arquivo de configuração — `pom`, Compose, `Makefile`, CI, hooks — aparece **completo e literal**:
é conteúdo que o executor copia. Já `README.md`, `ARCHITECTURE.md` e os 11 `CLAUDE.md` são prosa,
e reproduzi-los por extenso seria escrever a entrega duas vezes. Para esses, a Tarefa 7 traz a
**estrutura obrigatória**, o **conteúdo de cada seção em forma de tópicos** e um **exemplo completo
de cada variação**. O que falta é redigir, que é o trabalho da tarefa.

---

## Tarefa 1: `pom` raiz, 8 módulos vazios e o teste de `R-16`

Primeira porque é o teste da premissa mais cara do projeto.

**Arquivos:**
- Criar: `pom.xml`, e `pom.xml` em `comum/`, `processador-starter/`, `processador-poupanca/`,
  `processador-cliente/`, `processador-contacorrente/`, `processador-consorcio/`,
  `processador-emprestimo/`, `api/`
- Criar: os diretórios de pacote de cada módulo

**Interfaces:**
- Produz: as propriedades `${jasperreports.version}` e `${java.version}` do `pom` raiz, e as
  coordenadas `br.com.scheduler:<módulo>:0.1.0-SNAPSHOT`, consumidas por todas as tarefas seguintes
  e por SP-6a, SP-6b e SP-7.

- [ ] **Passo 1: Escrever a verificação e vê-la falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -q -B verify 2>&1 | tail -5
```

Esperado agora: erro de que não há `pom.xml`. É a falha que a tarefa corrige.

- [ ] **Passo 2: Criar o `pom.xml` raiz**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>br.com.scheduler</groupId>
  <artifactId>scheduler-jasper-report</artifactId>
  <version>0.1.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <name>Scheduler Jasper Report</name>

  <modules>
    <module>comum</module>
    <module>processador-starter</module>
    <module>processador-poupanca</module>
    <module>processador-cliente</module>
    <module>processador-contacorrente</module>
    <module>processador-consorcio</module>
    <module>processador-emprestimo</module>
    <module>api</module>
  </modules>

  <properties>
    <maven.compiler.release>25</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <spring-boot.version>4.1.0</spring-boot.version>
    <!-- ADR-0002: declarada UMA vez. Nao repetir em pom filho. -->
    <jasperreports.version>7.0.8</jasperreports.version>
    <spotless.version>3.9.0</spotless.version>
  </properties>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-dependencies</artifactId>
        <version>${spring-boot.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
      <dependency>
        <groupId>net.sf.jasperreports</groupId>
        <artifactId>jasperreports</artifactId>
        <version>${jasperreports.version}</version>
      </dependency>
      <dependency>
        <groupId>net.sf.jasperreports</groupId>
        <artifactId>jasperreports-pdf</artifactId>
        <version>${jasperreports.version}</version>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <build>
    <pluginManagement>
      <plugins>
        <plugin>
          <groupId>org.apache.maven.plugins</groupId>
          <artifactId>maven-compiler-plugin</artifactId>
          <configuration>
            <compilerArgs>
              <arg>-Xlint:all,-serial,-processing</arg>
              <arg>-Werror</arg>
            </compilerArgs>
          </configuration>
        </plugin>
      </plugins>
    </pluginManagement>
  </build>
</project>
```

- [ ] **Passo 3: Criar os 8 `pom.xml` de módulo**

Todos seguem este molde. Substitua `<artifactId>` pelo nome do módulo e ajuste as dependências
conforme a tabela abaixo.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>br.com.scheduler</groupId>
    <artifactId>scheduler-jasper-report</artifactId>
    <version>0.1.0-SNAPSHOT</version>
  </parent>
  <artifactId>comum</artifactId>
  <packaging>jar</packaging>
</project>
```

Dependências por módulo — **sem `<version>` em nenhuma**, o `dependencyManagement` resolve:

| Módulo | Dependências |
|---|---|
| `comum` | nenhuma nesta fase |
| `processador-starter` | `net.sf.jasperreports:jasperreports` · `br.com.scheduler:comum` |
| `processador-*` (5×) | `br.com.scheduler:processador-starter` |
| `api` | `net.sf.jasperreports:jasperreports` · `net.sf.jasperreports:jasperreports-pdf` · `br.com.scheduler:comum` |

A dependência interna se declara assim:

```xml
<dependency>
  <groupId>br.com.scheduler</groupId>
  <artifactId>comum</artifactId>
  <version>${project.version}</version>
</dependency>
```

- [ ] **Passo 4: Criar a estrutura de pacotes**

Java não compila diretório vazio, e o Git não versiona diretório vazio. Crie a árvore com um
`.gitkeep` em cada folha:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
for m in comum processador-starter processador-poupanca processador-cliente \
         processador-contacorrente processador-consorcio processador-emprestimo api; do
  pkg=$(echo $m | tr -d '-')
  for c in dominio aplicacao infraestrutura/repositorio; do
    mkdir -p "$m/src/main/java/br/com/scheduler/$pkg/$c"
    touch "$m/src/main/java/br/com/scheduler/$pkg/$c/.gitkeep"
  done
  mkdir -p "$m/src/test/resources/feature"
  touch "$m/src/test/resources/feature/.gitkeep"
done
# web/ e infraestrutura/artefato/ so na api
mkdir -p api/src/main/java/br/com/scheduler/api/web api/src/main/java/br/com/scheduler/api/infraestrutura/artefato
touch api/src/main/java/br/com/scheduler/api/web/.gitkeep
touch api/src/main/java/br/com/scheduler/api/infraestrutura/artefato/.gitkeep
```

`src/test/resources/feature` vem de `RA-45`, que fixa esse caminho para os `.feature` dos módulos
Java. Criar agora evita que SP-7 invente outro.

- [ ] **Passo 5: Rodar o build — este é o teste de `R-16`**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B clean verify 2>&1 | tail -25
```

Esperado: `BUILD SUCCESS`, com os 8 módulos em `Reactor Summary`.

**Se falhar, PARE e reporte** — não contorne. Uma falha aqui é o risco `R-16` se materializando, e
a decisão sobre ela recai sobre `ADR-0001` e sobre a escolha da linha 4.1. Os sintomas previstos
são falha de resolução de dependência, `NoSuchMethodError` ou `InaccessibleObjectException`.

- [ ] **Passo 6: Confirmar que a versão do Jasper aparece uma única vez**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "declaracoes da versao: $(grep -rc 'jasperreports.version>7' --include=pom.xml . | grep -v ':0' | wc -l)  (esperado 1)"
echo "versao hardcoded em filho: $(grep -rn '<version>7\.0\.8' --include=pom.xml . | wc -l)  (esperado 0)"
echo "modulos no reactor: $(mvn -B -q help:evaluate -Dexpression=project.modules -DforceStdout 2>/dev/null | grep -c '<string>')  (esperado 8)"
```

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add pom.xml */pom.xml */src
git commit -m "$(cat <<'EOF'
Mono repositório Maven com os oito módulos de RA-69

Estrutura de pacotes por camada em pt-BR, com dominio, aplicacao e
infraestrutura em cada módulo. Frontend e orquestrador ficam fora do
reactor: são npm e Python, e é o Makefile que os amarra ao build.

A versão do JasperReports é declarada uma única vez, no pom raiz. É
onde o ADR-0002 deixa de ser promessa: uma segunda declaração
quebraria a premissa da serialização do .jrprint e o sintoma só
apareceria na exportação, dias depois.

Este commit também exercita R-16 — Jasper 7.0.8 sobre Spring Boot 4.1
e Java 25 é combinação não testada, e compilar vem antes de tudo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Qualidade — formato, lint, hooks e segredos

**Arquivos:**
- Criar: `.editorconfig`, `.githooks/pre-commit`, `.gitleaks.toml`
- Modificar: `pom.xml` (plugin Spotless)

**Interfaces:**
- Consome: o `pom.xml` raiz da Tarefa 1.
- Produz: os alvos `spotless:check` e `spotless:apply`, e o hook `pre-commit`, consumidos pelo
  `Makefile` (Tarefa 4) e pelo CI (Tarefa 5).

- [ ] **Passo 1: Criar o `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space

[*.java]
indent_size = 4
max_line_length = 120

[*.{xml,yml,yaml,json}]
indent_size = 2

[*.{ts,html,scss}]
indent_size = 2

[Makefile]
indent_style = tab
```

- [ ] **Passo 2: Acrescentar o Spotless ao `pom.xml` raiz**

Dentro de `<build>`, ao lado de `<pluginManagement>`, acrescente um bloco `<plugins>`:

```xml
<plugins>
  <plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>${spotless.version}</version>
    <configuration>
      <java>
        <palantirJavaFormat/>
        <removeUnusedImports/>
        <importOrder>
          <order>java,javax,jakarta,org,com,br,</order>
        </importOrder>
        <trimTrailingWhitespace/>
        <endWithNewline/>
      </java>
      <pom>
        <sortPom>
          <expandEmptyElements>false</expandEmptyElements>
        </sortPom>
      </pom>
    </configuration>
    <executions>
      <execution>
        <goals><goal>check</goal></goals>
        <phase>verify</phase>
      </execution>
    </executions>
  </plugin>
</plugins>
```

`palantirJavaFormat` é a escolha da spec: 4 espaços e 120 colunas, contra os 2 espaços do
google-java-format — melhor para os nomes longos em pt-BR que o glossário impõe.

- [ ] **Passo 3: Criar o hook de pre-commit**

`.githooks/pre-commit`, com permissão de execução:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[pre-commit] formatando o Java em stage..."
if git diff --cached --name-only --diff-filter=ACM | grep -q '\.java$'; then
  mvn -q -B spotless:apply
  git diff --cached --name-only --diff-filter=ACM | grep '\.java$' | xargs -r git add
fi

echo "[pre-commit] procurando segredos..."
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect --staged --no-banner --redact
else
  echo "[pre-commit] AVISO: gitleaks nao instalado; o CI continua verificando."
fi

echo "[pre-commit] ok"
```

```bash
chmod +x .githooks/pre-commit
```

O hook **formata e re-adiciona** em vez de reprovar: reprovar por formatação é hostil quando a
correção é automática. Segredo, ao contrário, aborta o commit — daí `gitleaks protect`, que falha
com código diferente de zero.

- [ ] **Passo 4: Criar o `.gitleaks.toml`**

```toml
title = "Scheduler Jasper Report"

[extend]
useDefault = true

[[rules]]
id = "senha-em-env"
description = "Senha literal fora do .env.example"
regex = '''(?i)(senha|password|passwd)\s*[:=]\s*['"]?[^\s'"$#]{8,}'''
path = '''.*'''

[[rules.allowlist]]
paths = ['''\.env\.example$''', '''docs/.*\.md$''']
```

A allowlist cobre `.env.example` (onde os valores são propositalmente falsos) e a documentação
(onde há exemplos). Sem ela, o scanner reprovaria os próprios artefatos que a spec manda escrever.

- [ ] **Passo 5: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B spotless:apply -q && echo "spotless:apply ok"
mvn -B spotless:check -q && echo "spotless:check ok"
test -x .githooks/pre-commit && echo "hook executavel ok"
command -v gitleaks >/dev/null && gitleaks detect --no-banner --redact -s . && echo "gitleaks ok" \
  || echo "gitleaks nao instalado localmente; sera verificado no CI"
```

Esperado: as três primeiras linhas de `ok`.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add .editorconfig .githooks .gitleaks.toml pom.xml
git commit -m "$(cat <<'EOF'
Formatação, lint e varredura de segredos

Spotless com palantir-java-format, escolhido por usar 4 espaços e 120
colunas: os identificadores em pt-BR que o glossário impõe não cabem
nos 2 espaços do google-java-format.

Sem Checkstyle nem PMD. O -Werror do compilador já trata warning como
erro, e mais um analisador antes de existir código é regra que alguém
desabilita no primeiro PR apertado.

O hook formata e re-adiciona em vez de reprovar, porque reprovar por
formatação é hostil quando a correção é automática. Segredo aborta.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Ambiente local — Compose com três perfis

**Arquivos:**
- Criar: `docker-compose.yml`, `.env.example`, `infra/postgres/init-schemas.sql`

**Interfaces:**
- Produz: os serviços e perfis consumidos pelos alvos `dev`, `dev-full` e `down` do `Makefile`
  (Tarefa 4), e as variáveis que o `.env` materializa.

- [ ] **Passo 1: Criar o `.env.example`**

```bash
# Copie para .env e ajuste. NUNCA versione o .env.

# PostgreSQL
POSTGRES_USER=scheduler
POSTGRES_PASSWORD=troque-em-desenvolvimento
POSTGRES_DB=scheduler
POSTGRES_PORT=5432

# Keycloak — RA-32: o ADMINISTRADOR inicial nasce desta senha
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=troque-em-desenvolvimento
KEYCLOAK_PORT=8081

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=troque-em-desenvolvimento
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001

# Mailpit
MAILPIT_SMTP_PORT=1025
MAILPIT_UI_PORT=8025

# Traefik
TRAEFIK_HTTP_PORT=80
TRAEFIK_DASHBOARD_PORT=8090

# Retencao dos artefatos — RNF-12, RN-36. A unica de fato configuravel.
RETENCAO_DIAS=7

# Observabilidade (perfil observabilidade)
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
JAEGER_UI_PORT=16686
GRAYLOG_PORT=9002
GRAYLOG_PASSWORD_SECRET=troque-por-16-caracteres-ou-mais
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

# Orquestracao (perfil orquestracao)
AIRFLOW_PORT=8082
AIRFLOW_ADMIN_PASSWORD=troque-em-desenvolvimento
```

`OPENSEARCH_JAVA_OPTS` com 512 MB é deliberado: o padrão do OpenSearch pede muito mais, e a
máquina tem 4 vCPUs disputados por toda a pilha.

- [ ] **Passo 2: Criar `infra/postgres/init-schemas.sql`**

`RA-23` pede seis schemas, não seis instâncias. O invariante é de acesso, não de topologia.

```sql
-- RA-23: um schema de controle e cinco transacionais, num unico PostgreSQL.
-- O invariante "so a Coleta le o transacional" e de acesso, nao de topologia.
CREATE SCHEMA IF NOT EXISTS controle;
CREATE SCHEMA IF NOT EXISTS poupanca;
CREATE SCHEMA IF NOT EXISTS cliente;
CREATE SCHEMA IF NOT EXISTS contacorrente;
CREATE SCHEMA IF NOT EXISTS consorcio;
CREATE SCHEMA IF NOT EXISTS emprestimo;
```

- [ ] **Passo 3: Criar o `docker-compose.yml` — perfil padrão**

Sem `profiles:`, o serviço sobe sempre. Estes cinco são o núcleo.

```yaml
services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      TZ: America/Sao_Paulo
    ports: ["${POSTGRES_PORT}:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./infra/postgres/init-schemas.sql:/docker-entrypoint-initdb.d/10-schemas.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10

  keycloak:
    image: quay.io/keycloak/keycloak:26.4.1
    command: ["start-dev"]
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: ${KEYCLOAK_ADMIN}
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB}
      KC_DB_USERNAME: ${POSTGRES_USER}
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD}
      KC_HEALTH_ENABLED: "true"
      TZ: America/Sao_Paulo
    ports: ["${KEYCLOAK_PORT}:8080"]
    depends_on:
      postgres: {condition: service_healthy}
    healthcheck:
      test: ["CMD-SHELL", "exec 3<>/dev/tcp/127.0.0.1/9000 && echo -e 'GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && cat <&3 | grep -q '200 OK'"]
      interval: 15s
      timeout: 5s
      retries: 20

  minio:
    image: minio/minio:RELEASE.2025-07-23T15-54-02Z
    command: ["server", "/data", "--console-address", ":9001"]
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      TZ: America/Sao_Paulo
    ports:
      - "${MINIO_PORT}:9000"
      - "${MINIO_CONSOLE_PORT}:9001"
    volumes: [miniodata:/data]
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 10

  mailpit:
    image: axllent/mailpit:v1.23.2
    environment:
      TZ: America/Sao_Paulo
    ports:
      - "${MAILPIT_SMTP_PORT}:1025"
      - "${MAILPIT_UI_PORT}:8025"
    healthcheck:
      test: ["CMD", "/mailpit", "readyz"]
      interval: 10s
      timeout: 5s
      retries: 10

  traefik:
    image: traefik:v3.3.4
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--api.dashboard=true"
      - "--api.insecure=true"
    environment:
      TZ: America/Sao_Paulo
    ports:
      - "${TRAEFIK_HTTP_PORT}:80"
      - "${TRAEFIK_DASHBOARD_PORT}:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

volumes:
  pgdata:
  miniodata:
```

`TZ: America/Sao_Paulo` em todo serviço vem de `RA-52`, e não é decoração: é o fuso em que a Data
de referência é resolvida (RN-07).

- [ ] **Passo 4: Acrescentar o perfil `orquestracao`**

```yaml
  airflow-scheduler:
    image: apache/airflow:3.3.0
    profiles: ["orquestracao"]
    command: ["scheduler"]
    environment: &airflow-env
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      AIRFLOW__CORE__LOAD_EXAMPLES: "false"
      AIRFLOW__CORE__DEFAULT_TIMEZONE: America/Sao_Paulo
      TZ: America/Sao_Paulo
    volumes: ["./orquestrador/dags:/opt/airflow/dags"]
    depends_on:
      postgres: {condition: service_healthy}

  airflow-apiserver:
    image: apache/airflow:3.3.0
    profiles: ["orquestracao"]
    command: ["api-server"]
    environment: *airflow-env
    ports: ["${AIRFLOW_PORT}:8080"]
    volumes: ["./orquestrador/dags:/opt/airflow/dags"]
    depends_on:
      postgres: {condition: service_healthy}
```

`AIRFLOW__CORE__LOAD_EXAMPLES: "false"` evita dezenas de DAGs de exemplo poluindo a interface e
concorrendo por CPU. `api-server` é o comando do Airflow 3.x — na linha 2.x chamava-se `webserver`.

- [ ] **Passo 5: Acrescentar o perfil `observabilidade`**

```yaml
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.130.0
    profiles: ["observabilidade"]
    command: ["--config=/etc/otel/config.yaml"]
    volumes: ["./infra/otel/config.yaml:/etc/otel/config.yaml:ro"]
    environment: {TZ: America/Sao_Paulo}

  prometheus:
    image: prom/prometheus:v3.1.0
    profiles: ["observabilidade"]
    ports: ["${PROMETHEUS_PORT}:9090"]
    volumes: ["./infra/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro"]
    environment: {TZ: America/Sao_Paulo}

  grafana:
    image: grafana/grafana:11.4.0
    profiles: ["observabilidade"]
    ports: ["${GRAFANA_PORT}:3000"]
    environment: {TZ: America/Sao_Paulo}

  jaeger:
    image: jaegertracing/jaeger:2.2.0
    profiles: ["observabilidade"]
    ports: ["${JAEGER_UI_PORT}:16686"]
    environment: {TZ: America/Sao_Paulo}

  mongodb:
    image: mongo:8.0.4
    profiles: ["observabilidade"]
    volumes: [mongodata:/data/db]
    environment: {TZ: America/Sao_Paulo}

  opensearch:
    image: opensearchproject/opensearch:2.18.0
    profiles: ["observabilidade"]
    environment:
      discovery.type: single-node
      plugins.security.disabled: "true"
      OPENSEARCH_JAVA_OPTS: ${OPENSEARCH_JAVA_OPTS}
      TZ: America/Sao_Paulo
    volumes: [opensearchdata:/usr/share/opensearch/data]

  graylog:
    image: graylog/graylog:6.3.6
    profiles: ["observabilidade"]
    environment:
      GRAYLOG_PASSWORD_SECRET: ${GRAYLOG_PASSWORD_SECRET}
      GRAYLOG_MONGODB_URI: mongodb://mongodb:27017/graylog
      GRAYLOG_ELASTICSEARCH_HOSTS: http://opensearch:9200
      GRAYLOG_HTTP_BIND_ADDRESS: 0.0.0.0:9000
      TZ: America/Sao_Paulo
    ports: ["${GRAYLOG_PORT}:9000"]
    depends_on: [mongodb, opensearch]
```

Acrescente `mongodata:` e `opensearchdata:` ao bloco `volumes:` do fim do arquivo.

**Graylog não sobe sozinho** — MongoDB e OpenSearch são requisito dele, e é por isso que a pilha
são 14 contêineres e não 11.

- [ ] **Passo 6: Criar as configurações mínimas de OTel e Prometheus**

`infra/otel/config.yaml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc: {endpoint: 0.0.0.0:4317}
      http: {endpoint: 0.0.0.0:4318}
exporters:
  debug: {verbosity: basic}
service:
  pipelines:
    traces:  {receivers: [otlp], exporters: [debug]}
    metrics: {receivers: [otlp], exporters: [debug]}
    logs:    {receivers: [otlp], exporters: [debug]}
```

`infra/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
```

São configurações **mínimas e deliberadas**: o roteamento real para Graylog, Prometheus e Jaeger é
trabalho de SP-8, quando houver telemetria a rotear. Aqui só precisam subir sem erro.

- [ ] **Passo 7: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
cp -n .env.example .env
docker compose config -q && echo "compose valido"
echo "servicos padrao:        $(docker compose config --services | wc -l)  (esperado 5)"
echo "com orquestracao:       $(docker compose --profile orquestracao config --services | wc -l)  (esperado 7)"
echo "com tudo:               $(docker compose --profile orquestracao --profile observabilidade config --services | wc -l)  (esperado 14)"
echo "--- toda variavel do compose existe no .env.example? ---"
grep -oE '\$\{[A-Z_]+' docker-compose.yml | tr -d '${' | sort -u \
  | while read v; do grep -q "^$v=" .env.example || echo "  FALTA no .env.example: $v"; done
```

Esperado: `compose valido`, as três contagens, e nenhuma linha `FALTA`. São 14 serviços, não 15,
porque `airflow-scheduler` e `airflow-apiserver` contam separado e o Compose não conta o `postgres`
duas vezes.

- [ ] **Passo 8: Subir o núcleo e conferir a saúde**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
docker compose up -d
sleep 60
docker compose ps --format 'table {{.Service}}\t{{.Status}}'
echo "saudaveis: $(docker compose ps --format '{{.Status}}' | grep -c healthy)  (esperado 4)"
```

Esperado: `postgres`, `keycloak`, `minio` e `mailpit` como `healthy`. O `traefik` não declara
healthcheck e aparece apenas como `Up` — é a única exceção, e é intencional: a imagem não traz
`curl` nem `wget`.

- [ ] **Passo 9: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add docker-compose.yml .env.example infra/
git commit -m "$(cat <<'EOF'
Ambiente local em Docker Compose, com três perfis

O núcleo sobe por padrão e custa 1,6 GB; orquestração e observabilidade
são opcionais e somam 7,8 GB. Perfis não são conveniência: RA-39 já
determina que o SDK do OpenTelemetry fica desabilitado nos testes, ou
seja, o próprio projeto declara que a observabilidade não participa do
ciclo comum de desenvolvimento.

Graylog arrasta MongoDB e OpenSearch, e é por isso que a pilha são 15
contêineres e não os 11 que RA-51 lista.

Um PostgreSQL com seis schemas, não seis instâncias: o invariante de
RA-23 é de acesso, não de topologia, e a economia é de ~2 GB de RAM.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `Makefile`

**Arquivos:**
- Criar: `Makefile`

**Interfaces:**
- Consome: os `pom` da Tarefa 1, o Spotless e os hooks da Tarefa 2, o Compose da Tarefa 3.
- Produz: os alvos `setup`, `dev`, `dev-full`, `down`, `test`, `lint`, `fmt`, `build`, `migrate`,
  invocados pelo `README.md` (Tarefa 7) e pelo CI (Tarefa 5).

- [ ] **Passo 1: Criar o `Makefile`**

```makefile
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help setup dev dev-full down test lint fmt build migrate

help: ## Lista os alvos disponiveis
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

setup: ## Valida ferramentas, cria o .env e ativa os hooks
	@command -v java  >/dev/null || { echo "ERRO: java nao encontrado"; exit 1; }
	@command -v mvn   >/dev/null || { echo "ERRO: mvn nao encontrado"; exit 1; }
	@command -v docker>/dev/null || { echo "ERRO: docker nao encontrado"; exit 1; }
	@command -v node  >/dev/null || { echo "ERRO: node nao encontrado"; exit 1; }
	@test -f .env || cp .env.example .env
	@git config core.hooksPath .githooks
	@echo "setup concluido. Proximo: make dev"

dev: ## Sobe o nucleo do ambiente local
	docker compose up -d

dev-full: ## Sobe o ambiente completo, com orquestracao e observabilidade
	docker compose --profile orquestracao --profile observabilidade up -d

down: ## Derruba o ambiente, preservando os volumes
	docker compose --profile orquestracao --profile observabilidade down

test: ## Roda os testes de todos os modulos
	mvn -B test

lint: ## Verifica formatacao e segredos
	mvn -B spotless:check
	@command -v gitleaks >/dev/null && gitleaks detect --no-banner --redact -s . \
	  || echo "gitleaks nao instalado; verificado no CI"

fmt: ## Aplica a formatacao
	mvn -B spotless:apply

build: ## Compila o backend e o frontend
	mvn -B clean verify
	@test -f frontend/package.json && cd frontend && npm ci && npm run build || true

migrate: ## Aplica as migrations no schema de controle
	mvn -B -pl api flyway:migrate
```

`build` usa `|| true` no frontend porque, até SP-5, `frontend/` tem apenas o esqueleto. O alvo
`migrate` existe e roda sobre um schema vazio — a primeira migration é de SP-6b.

- [ ] **Passo 2: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
make help
echo "alvos declarados: $(grep -cE '^[a-z-]+:.*## ' Makefile)  (esperado 10)"
make lint && echo "lint ok"
```

- [ ] **Passo 3: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add Makefile
git commit -m "$(cat <<'EOF'
Makefile com os alvos do guia, mais os que os perfis exigem

setup, dev, test, lint, build e migrate vêm do guia; dev-full, down e
fmt existem porque o Compose tem três perfis.

É o Makefile, e não o Maven, que amarra frontend e orquestrador ao
build: os dois estão fora do reactor por não serem projetos Maven.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: CI bloqueante

**Arquivos:**
- Criar: `.github/workflows/ci.yml`

**Interfaces:**
- Consome: os alvos do `Makefile` (Tarefa 4) e a configuração da Tarefa 2.

- [ ] **Passo 1: Criar o workflow**

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  formato:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: {distribution: temurin, java-version: '25', cache: maven}
      - run: mvn -B spotless:check

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: {distribution: temurin, java-version: '25', cache: maven}
      - run: mvn -B clean verify

  segredos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: {fetch-depth: 0}
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: {node-version: '24', cache: npm, cache-dependency-path: frontend/package-lock.json}
      - run: npm ci
        working-directory: frontend
      - run: npm run lint
        working-directory: frontend
      - run: npm run build
        working-directory: frontend

  claude-md:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Bloco comum dos CLAUDE.md de processador deve ser identico
        run: |
          hashes=$(for f in processador-poupanca processador-cliente processador-contacorrente \
                            processador-consorcio processador-emprestimo; do
            sed -n '/<!-- COMUM:INICIO -->/,/<!-- COMUM:FIM -->/p' "$f/CLAUDE.md" | sha256sum | cut -d' ' -f1
          done | sort -u | wc -l)
          if [ "$hashes" -ne 1 ]; then
            echo "ERRO: o bloco comum divergiu entre os CLAUDE.md de processador."
            echo "Corrija copiando o bloco de processador-poupanca para os demais."
            exit 1
          fi
          echo "os cinco blocos comuns sao identicos"
```

`fetch-depth: 0` no job de segredos não é detalhe: o `gitleaks` precisa do histórico para varrer o
diff, e com o clone raso padrão ele não veria nada e passaria em falso.

- [ ] **Passo 2: Verificar a sintaxe localmente**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); \
print('jobs:', list(d['jobs'].keys())); print('total:', len(d['jobs']))"
```

Esperado: os cinco jobs — `formato`, `build`, `segredos`, `frontend`, `claude-md`.

- [ ] **Passo 3: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add .github/
git commit -m "$(cat <<'EOF'
CI bloqueante com cinco jobs paralelos

Formato, build, segredos, frontend e a conferência de que o bloco
comum dos cinco CLAUDE.md de processador não divergiu.

O último job é a mitigação da decisão de manter onze CLAUDE.md: como
Claude Code não faz herança lateral, os cinco processadores carregam
cópias do mesmo bloco, e sem verificação elas divergiriam em uma
semana sem ninguém perceber.

O CI não sobe contêiner algum. Testcontainers chega em SP-7, quando
houver o que integrar; um CI lento no primeiro dia é um CI que alguém
vai querer pular.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: Esqueletos de `frontend/` e `orquestrador/`

Os dois diretórios de `RA-69` que ficam fora do reactor Maven.

**Arquivos:**
- Criar: `frontend/` (projeto Angular), `orquestrador/dags/.gitkeep`,
  `orquestrador/requirements.txt`

**Interfaces:**
- Produz: `frontend/package.json` com os scripts `lint` e `build`, consumidos pelo job `frontend`
  do CI (Tarefa 5) e pelo alvo `build` do `Makefile`.

- [ ] **Passo 1: Gerar o projeto Angular**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
npx -y @angular/cli@22.1.3 new frontend \
  --directory=frontend --routing --style=scss --ssr=false \
  --package-manager=npm --skip-git --skip-install=false
```

- [ ] **Passo 2: Confirmar `strict: true` e acrescentar o script de lint**

O Angular CLI já gera `strict: true` no `tsconfig.json` — confirme, não presuma:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
grep -E '"strict"|"noImplicitOverride"|"strictTemplates"' tsconfig.json
```

Se `"strict": true` não aparecer, acrescente-o em `compilerOptions`. Depois adicione o lint:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx -y ng add @angular-eslint/schematics --skip-confirmation
```

Isso cria o script `lint` em `package.json`, que o CI invoca.

- [ ] **Passo 3: Criar o esqueleto do orquestrador**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mkdir -p orquestrador/dags
touch orquestrador/dags/.gitkeep
cat > orquestrador/requirements.txt <<'EOF'
# Dependencias do orquestrador. A imagem apache/airflow:3.3.0 ja traz o Airflow.
# As DAGs deste projeto nascem em SP-7.
apache-airflow==3.3.0
EOF
```

`orquestrador/` **não recebe `pom.xml`** — `RA-69` e o invariante 8 do `ARCHITECTURE.md`.

- [ ] **Passo 4: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
test ! -f orquestrador/pom.xml && echo "orquestrador sem pom: ok"
test ! -f frontend/pom.xml && echo "frontend sem pom: ok"
grep -q '"strict": true' frontend/tsconfig.json && echo "tsconfig strict: ok"
cd frontend && npm run lint --silent && npm run build --silent && echo "frontend build: ok"
```

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend orquestrador
git commit -m "$(cat <<'EOF'
Esqueletos do frontend Angular e do orquestrador

Os dois diretórios de RA-69 que ficam fora do reactor Maven, cada um
com o seu próprio ferramental. O orquestrador não recebe pom.xml, e
isso é invariante declarado, não omissão.

Angular com strict true, conferido e não presumido, e o script de lint
que o job do CI invoca.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: `README.md`, `ARCHITECTURE.md` e os 11 `CLAUDE.md`

Última porque descreve o que passou a existir.

**Arquivos:**
- Criar: `README.md`, `ARCHITECTURE.md`, e `CLAUDE.md` em `comum/`, `processador-starter/`,
  nos 5 `processador-*/`, `api/`, `frontend/`, `orquestrador/`
- Modificar: `CLAUDE.md` da raiz

- [ ] **Passo 1: Escrever o `README.md`**

Estrutura obrigatória, com os três comandos em destaque:

````markdown
# Scheduler Jasper Report

Apura relatórios uma vez por dia e os entrega, sob demanda, em PDF, XLSX, DOCX ou CSV.

## Rodando em três comandos

```bash
make setup    # valida ferramentas, cria o .env e ativa os hooks
make dev      # sobe o núcleo do ambiente local
make build    # compila backend e frontend
```

## Requisitos

Java 25 · Maven 3.9+ · Docker com Compose v2+ · Node 24+

## Ambiente local

| Perfil | Comando | Custo em disco |
|---|---|---|
| Núcleo | `make dev` | ~1,6 GB |
| Completo | `make dev-full` | ~9,5 GB |

| Serviço | URL |
|---|---|
| Keycloak | http://localhost:8081 |
| MinIO (console) | http://localhost:9001 |
| Mailpit | http://localhost:8025 |
| Traefik (dashboard) | http://localhost:8090 |

## Documentação

| Documento | Papel |
|---|---|
| `ARCHITECTURE.md` | Onde mexer para fazer X, e o que não se atravessa |
| `docs/prd.md` | O que o sistema faz e por quê |
| `docs/glossario.md` | Fonte única dos nomes |
| `docs/adr/` | Por que cada decisão não foi outra coisa |
````

- [ ] **Passo 2: Escrever o `ARCHITECTURE.md`**

Algumas centenas de linhas, não milhares. Cinco seções obrigatórias: **Visão geral**,
**Bird's eye view**, **Code map**, **Invariantes** e **Pontos de entrada**.

O code map cobre os 10 diretórios, com uma coluna **"não faz"** — é ela que carrega o valor:

```markdown
| Diretório | Faz | NÃO faz |
|---|---|---|
| `comum/` | Tipos e utilitários compartilhados | Não conhece Spring Batch nem Spring Web |
| `processador-starter/` | Leitura paginada, renderização, gravação de artefato e metadados | Não conhece produto algum |
| `processador-<produto>/` | Declara os relatórios do seu produto e lê o seu schema | Não lê o schema de outro produto |
| `api/` | Exporta, autoriza e administra o catálogo | **Nunca acessa schema transacional** |
| `frontend/` | Interface do usuário final | Não acessa banco, repositório ou orquestrador |
| `orquestrador/` | Reserva o ciclo, dispara os produtos, encerra o que ficou aberto | Não é módulo Maven; não é exposto ao usuário |
```

E os **oito invariantes**, escritos como proibições:

```markdown
## Invariantes arquiteturais

1. `dominio/` não importa `infraestrutura/`, nem Spring, nem JDBC, nem HTTP.
2. Nenhum acesso a banco fora de `infraestrutura/repositorio/`.
3. Nenhuma classe em `web/` contém regra de negócio.
4. **A `api` não acessa schema transacional algum** — RA-29, RN-31.
5. Cada processador lê exclusivamente o schema do seu próprio produto — RA-10.
6. A versão do JasperReports é declarada uma única vez, no `pom` raiz — ADR-0002.
7. Migration aplicada não se altera — ADR-0003.
8. `orquestrador/` não é módulo Maven e não entra no reactor.

> Até SP-7 estes invariantes vivem **apenas neste documento**. Os testes ArchUnit que os
> tornam executáveis chegam com a fatia de referência. Neste intervalo, o invariante
> depende de alguém ter lido isto.
```

- [ ] **Passo 3: Reescrever o `CLAUDE.md` da raiz**

**Preserve integralmente as três diretrizes comportamentais atuais** ("Pense antes de fazer",
"Simplicidade em Primeiro Lugar", "Execução Orientada a Objetivos") e a seção de Referências,
acrescentando a elas: `docs/glossario.md`, `docs/user-stories.md`, `docs/adr/`,
`docs/arquitetura/c4-contexto.md`, `docs/riscos.md`.

Acrescente as seções técnicas:

```markdown
## Stack
Java 25 · Maven 3.9 · Spring Boot 4.1.0 · Spring Batch · JasperReports 7.0.8
Angular 22 · PostgreSQL 18 · MinIO · Keycloak 26 · Airflow 3.3 · Docker Compose

## Comandos
- Instalar: `make setup`
- Rodar:    `make dev`   (completo: `make dev-full`)
- Testar:   `make test`
- Lint:     `make lint`
- Formatar: `make fmt`

## Onde as coisas ficam
Leia `ARCHITECTURE.md` antes de criar arquivo novo. Não duplique aqui o que está lá.

## Convenções
- Pacotes por camada, em pt-BR: `dominio`, `aplicacao`, `infraestrutura`, `web`.
- Identificador de domínio em pt-BR sem acento; tecnologia em inglês (ver `docs/glossario.md`).
- Cenários Gherkin em `<módulo>/src/test/resources/feature` (RA-45).
- Commits em pt-BR, assunto imperativo, sem prefixo `feat:`.

## Regras invioláveis
- Nunca commitar segredo.
- Nunca alterar migration já aplicada.
- Nunca desabilitar regra de lint ou teste para fazer o build passar.
- Nunca declarar a versão do JasperReports fora do `pom` raiz (ADR-0002).
- Toda mudança de schema exige migration.
- Toda rota nova exige teste de autorização.
```

- [ ] **Passo 4: Escrever os 5 `CLAUDE.md` de módulo com conteúdo próprio**

`comum/`, `processador-starter/`, `api/`, `frontend/`, `orquestrador/`. Cada um curto, com **apenas
o que mais ninguém tem** — nada que já esteja na raiz.

Conteúdo de cada um:

| Arquivo | Tópicos obrigatórios |
|---|---|
| `comum/` | O que pode entrar: tipo compartilhado, contrato de erro, utilitário sem estado · O que **não** pode: dependência de Spring Batch, Spring Web ou JasperReports · Todo módulo depende deste, então dependência acrescentada aqui pesa em oito |
| `processador-starter/` | Concentra leitura paginada, renderização, gravação de artefato e metadados (`RA-03`) · Não conhece produto algum · Chunk do Spring Batch · **`queryTimeout` obrigatório** (`RA-57`) · O limite do relatório é verificado entre chunks |
| `api/` | *(exemplo completo abaixo)* |
| `frontend/` | Integra **exclusivamente** com os endpoints da API (`RA-06`) · Não acessa banco, MinIO nem Airflow · Angular com `strict` · Design system chega em SP-5; até lá, não inventar token de cor ou espaçamento · Cenários em `e2e/features/` (`RA-46`) |
| `orquestrador/` | Python, não Java — **não tem `pom.xml`** · Uma task estática por produto (`RA-65`) · `catchup=False` explícito (`RA-56`) · Não recebe data de referência como parâmetro (`RN-54`) · Não é exposto ao usuário final (`RA-13`) |

Exemplo completo, `api/CLAUDE.md`:

```markdown
# API REST

Único módulo que atende o usuário final. Porta 8080.

## Invariante deste módulo
**Nunca acessa schema transacional.** Lê o artefato no MinIO e o schema de controle.
Qualquer dependência para um schema de produto é defeito, não variação — RA-29, RN-31.

## Convenções
- Toda rota nova exige teste de autorização, inclusive contra acesso direto (RF-15).
- Exportação é síncrona e devolve o arquivo ou erro na mesma requisição (RN-30).
- O semáforo de exportações recusa o excedente de imediato; não há fila (RA-60).
- Todo erro devolve momento, descrição e Correlation ID (RA-41).
```

- [ ] **Passo 5: Escrever os 5 `CLAUDE.md` de processador, com o bloco comum**

Os cinco arquivos têm **o mesmo bloco entre os marcadores**, byte a byte. Escreva
`processador-poupanca/CLAUDE.md` primeiro e copie o bloco para os outros quatro.

```markdown
# Processador POUPANCA

<!-- COMUM:INICIO -->
## Convenções de todo processador

- O módulo **é** o produto (RA-04). Não existe produto sem módulo.
- Lê **exclusivamente** o schema do seu próprio produto (RA-10). Ler outro é defeito.
- Uma única janela de leitura por execução (RN-44, ADR-0012).
- **Todo statement de leitura declara `queryTimeout`** (RA-57). Sem ele, o limite do
  relatório não existe: a verificação entre chunks não interrompe uma chamada JDBC travada.
- Conta as linhas antes de apurar e recusa dataset acima de RNF-06 (RA-64, RN-52).
- Grava o artefato **antes** dos metadados de conclusão (RA-11).
- Publica o seu catálogo ao iniciar; código de relatório duplicado impede o módulo de
  subir (RA-58, RF-44).
- Cabeçalho de coluna na banda `title` do JRXML, nunca em `pageHeader` (RA-59, RN-33).
<!-- COMUM:FIM -->

## Deste produto
- Sigla: `POUPANCA` · Schema: `poupanca`
- Relatórios: definidos em SP-6a.
```

O CI compara o hash deste bloco nos cinco arquivos. Divergiu, build vermelho.

- [ ] **Passo 6: Verificar tudo**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "CLAUDE.md no total: $(find . -name CLAUDE.md -not -path './node_modules/*' -not -path './frontend/node_modules/*' | wc -l)  (esperado 11)"
echo "--- bloco comum identico nos cinco? ---"
for f in processador-poupanca processador-cliente processador-contacorrente \
         processador-consorcio processador-emprestimo; do
  sed -n '/<!-- COMUM:INICIO -->/,/<!-- COMUM:FIM -->/p' "$f/CLAUDE.md" | sha256sum | cut -d' ' -f1
done | sort -u | wc -l | xargs -I{} echo "  hashes distintos: {}  (esperado 1)"
echo "--- invariantes no ARCHITECTURE.md ---"
grep -cE '^[1-8]\. ' ARCHITECTURE.md | xargs -I{} echo "  {}  (esperado 8)"
echo "--- diretrizes preservadas no CLAUDE.md raiz ---"
for d in "Pense antes de fazer" "Simplicidade em Primeiro Lugar" "Execução Orientada a Objetivos"; do
  grep -q "$d" CLAUDE.md || echo "  PERDIDA: $d"
done
```

Esperado: `11`, `hashes distintos: 1`, `8`, e nenhuma linha `PERDIDA`.

- [ ] **Passo 7: Testar o critério 1 — clone limpo, sem etapa manual**

Este é **o checkpoint do guia**, e não pode ser verificado no diretório de trabalho: aqui já
existem `.env`, `~/.m2` quente e hooks ativos. Precisa de um clone de verdade.

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
rm -rf /tmp/sp3-clone-limpo
git clone -q . /tmp/sp3-clone-limpo
cd /tmp/sp3-clone-limpo
make setup && make build && echo "CRITERIO 1: OK — clone limpo roda sem etapa manual"
```

Esperado: `make setup` cria o `.env` a partir do `.env.example`, ativa os hooks e não pede nada;
`make build` termina em `BUILD SUCCESS`.

**Se `make setup` pedir qualquer intervenção manual, o critério falhou** — corrija o `Makefile`,
não o procedimento. Limpe depois com `rm -rf /tmp/sp3-clone-limpo`.

- [ ] **Passo 8: Conferir os demais critérios de aceite da spec**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "2. build:        $(mvn -B -q clean verify >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "3. nucleo up:    $(docker compose up -d >/dev/null 2>&1; sleep 45; docker compose ps --format '{{.Status}}' | grep -c healthy) healthy (esperado 4)"
echo "5. spotless:     $(mvn -B -q spotless:check >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "7. claude-md:    $(for f in processador-{poupanca,cliente,contacorrente,consorcio,emprestimo}; do sed -n '/COMUM:INICIO/,/COMUM:FIM/p' $f/CLAUDE.md | sha256sum; done | sort -u | wc -l) hash (esperado 1)"
echo "9. .env ignorado: $(git check-ignore -q .env && echo ok || echo FALHOU)"
grep -oE '\$\{[A-Z_]+' docker-compose.yml | tr -d '${' | sort -u \
  | while read v; do grep -q "^$v=" .env.example || echo "   FALTA: $v"; done
echo "10. code map:    $(grep -c '^| \`' ARCHITECTURE.md) linhas"
```

O critério 4 (`make dev-full` com os 14 contêineres) é **medição**, e roda à parte:

```bash
make dev-full && sleep 120
docker compose --profile orquestracao --profile observabilidade ps --format 'table {{.Service}}\t{{.Status}}'
free -g | head -2
```

Se a máquina não sustentar, **reporte o número em vez de contornar** — a spec prevê que este
critério pode falhar, e a decisão sobre o perfil `observabilidade` é do usuário.

- [ ] **Passo 9: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add README.md ARCHITECTURE.md CLAUDE.md */CLAUDE.md
git commit -m "$(cat <<'EOF'
README, ARCHITECTURE e os onze CLAUDE.md

O ARCHITECTURE traz o code map com uma coluna "não faz" e os oito
invariantes escritos como proibições — que é a forma que um agente não
consegue inferir a partir de exemplos, e por isso viola quando não está
escrito.

Onze CLAUDE.md porque Claude Code não faz herança lateral: o arquivo do
processador-starter não é lido ao editar processador-poupanca. Daí as
cinco cópias do bloco comum, e daí o job que compara os hashes.

As três diretrizes comportamentais do CLAUDE.md original ficam
preservadas, agora ao lado do conteúdo técnico que o guia pede.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-3 termina quando os dez critérios da spec passam e os sete commits estão no branch. Com isso E1
fecha e o checkpoint do guia é atendido: *clone limpo roda com um comando e o CI está verde*.

**Duas coisas que este plano deliberadamente não faz e que o próximo sub-projeto assume:**

- A fatia de referência e os testes ArchUnit — **SP-7**. Até lá os invariantes vivem só em prosa.
- A primeira migration — **SP-6b**. `make migrate` existe e roda sobre um schema vazio.

O próximo sub-projeto na ordem da decomposição é **SP-4 — Fluxos e protótipo (P1)**, que não
depende de SP-3 e pode correr em paralelo.
