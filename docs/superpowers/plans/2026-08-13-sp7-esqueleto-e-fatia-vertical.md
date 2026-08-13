# SP-7 — Esqueleto e fatia vertical · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.
>
> ⚠️ **A Tarefa 2 é um portão.** Se ela falhar, PARE e reporte — é `R-16`, e a decisão volta a
> `ADR-0001`.

**Objetivo:** provar com código rodando que a costura fecha — Jasper renderiza sobre a stack
escolhida, o `.jrprint` sobrevive à serialização entre módulos, os metadados contam a verdade sobre
o artefato, e a cadeia de permissão filtra de fato.

**Arquitetura:** nove tarefas, de dentro para fora. Cada degrau é provado por um teste de integração
próprio antes do seguinte existir, de modo que o suspeito de qualquer falha seja sempre o último
degrau — e não um entre seis sistemas.

**Tech stack:** Java 25 · Spring Boot 4.1.0 · Spring Batch · JasperReports 7.0.8 · PostgreSQL 18 ·
MinIO · Keycloak 26.4.1 · Airflow 3.3.0 · Testcontainers · Cucumber · ArchUnit · Newman.

**Spec:** [`docs/superpowers/specs/2026-08-13-sp7-esqueleto-e-fatia-vertical-design.md`](../specs/2026-08-13-sp7-esqueleto-e-fatia-vertical-design.md)

---

## Pré-condições

**SP-1, SP-2, SP-3, SP-6a e SP-6b executados.** Confira antes de começar:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
test -f pom.xml                                                           || { echo "PARE: SP-3 nao rodou"; exit 1; }
test -f processador-poupanca/src/main/resources/db/migration/V1__cria_tabelas_poupanca.sql \
                                                                          || { echo "PARE: SP-6a nao rodou"; exit 1; }
test -f api/src/main/resources/db/migration/V1__cria_schema_controle.sql  || { echo "PARE: SP-6b nao rodou"; exit 1; }
test -f docs/glossario.md                                                 || { echo "PARE: SP-1 nao rodou"; exit 1; }
echo "pre-condicoes ok"
```

---

## Restrições globais

- **Pacotes por camada, em pt-BR:** `dominio`, `aplicacao`, `infraestrutura`, `web`.
- **`dominio/` não importa Spring, JDBC nem HTTP.** O ArchUnit da Tarefa 8 verifica.
- **Todo statement de leitura da Coleta declara `queryTimeout`** (`RA-57`). Sem ele o limite do
  relatório não existe e ninguém percebe.
- **O artefato é gravado ANTES dos metadados de conclusão** (`RA-11`).
- **Cabeçalho de coluna na banda `title`** de todo JRXML (`RA-59`).
- **Toda rota nova exige teste de autorização** — regra inviolável do `CLAUDE.md`.
- **A `api` não depende de nenhum módulo processador.** É o invariante 4.
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

### A conciliação entre Spring Batch e JasperReports

Spring Batch trabalha em *chunks*; `JasperFillManager.fillReport` puxa o dataset inteiro pelo
`JRDataSource`. Os dois se conciliam com um **adaptador**: um `JRDataSource` que envolve o reader
paginado e avança sob demanda.

É nesse adaptador que o **limite do relatório de `RA-57`** é verificado — a cada avanço, ele compara
o tempo decorrido com o dobro do tempo estimado da execução. É o "entre chunks" que a arquitetura
descreve, no único lugar onde ele de fato existe.

---

## Tarefa 1: Módulos compilando e health check

**Arquivos:**
- Criar: `api/src/main/java/br/com/scheduler/api/Aplicacao.java`
- Criar: `processador-poupanca/src/main/java/br/com/scheduler/processadorpoupanca/Aplicacao.java`
- Modificar: `api/pom.xml`, `api/src/main/resources/application.yml`

**Interfaces:**
- Produz: a aplicação Spring Boot da API na porta 8080, consumida pelas Tarefas 5, 6 e 9.

- [ ] **Passo 1: Escrever o teste que falha**

```java
// api/src/test/java/br/com/scheduler/api/SaudeTest.java
package br.com.scheduler.api;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SaudeTest {

    @LocalServerPort int porta;
    @Autowired TestRestTemplate rest;

    @Test
    void liveness_e_readiness_respondem_UP() {   // RA-43
        assertThat(rest.getForObject("/actuator/health/liveness", String.class)).contains("UP");
        assertThat(rest.getForObject("/actuator/health/readiness", String.class)).contains("UP");
    }
}
```

- [ ] **Passo 2: Rodar e ver falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B -pl api test 2>&1 | tail -20
```

Esperado: falha por não existir classe de aplicação.

- [ ] **Passo 3: Criar as aplicações e o Actuator**

```java
// api/src/main/java/br/com/scheduler/api/Aplicacao.java
package br.com.scheduler.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Aplicacao {
    public static void main(String[] args) {
        SpringApplication.run(Aplicacao.class, args);
    }
}
```

Em `api/pom.xml`, acrescente `spring-boot-starter-web`, `spring-boot-starter-actuator`,
`spring-boot-starter-data-jpa`, `postgresql`, `flyway-core` e `flyway-database-postgresql`.

Em `api/src/main/resources/application.yml`:

```yaml
server:
  port: 8080
spring:
  application:
    name: api
  jackson:
    time-zone: America/Sao_Paulo      # RA-52
  flyway:
    schemas: [controle]
    default-schema: controle
management:
  endpoint:
    health:
      probes:
        enabled: true                 # habilita liveness e readiness — RA-43
  endpoints:
    web:
      exposure:
        include: [health, info]
```

A classe do processador é análoga, com `@SpringBootApplication` e `@EnableBatchProcessing`.

- [ ] **Passo 4: Rodar e ver passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B clean verify 2>&1 | tail -15
```

Esperado: `BUILD SUCCESS` com os 8 módulos.

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add api processador-poupanca
git commit -m "$(cat <<'EOF'
Aplicações da API e do processador, com health check

Liveness e readiness expostos conforme RA-43, e o fuso America/
Sao_Paulo no Jackson, que é onde a data de referência é resolvida.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Degrau 1 — o Batch preenche o `JasperPrint` · PORTÃO DE `R-16`

**Esta é a tarefa mais importante do plano.** Ela responde se o projeto é viável na stack escolhida.

**Arquivos:**
- Criar: `processador-poupanca/src/main/resources/relatorios/POUPANCA-0001.jrxml`
- Criar: `processador-poupanca/src/main/resources/relatorios/POUPANCA-0002.jrxml`
- Criar: `processador-poupanca/src/main/resources/imagens/logo.png`, `selo.png`
- Criar: `processador-starter/src/main/java/br/com/scheduler/processadorstarter/infraestrutura/DataSourcePaginado.java`
- Criar: `processador-starter/src/main/java/br/com/scheduler/processadorstarter/aplicacao/PreencherRelatorio.java`
- Criar: `processador-poupanca/src/test/java/.../PreenchimentoIT.java`

**Interfaces:**
- Produz: `PreencherRelatorio.preencher(String codigo, LocalDate dataReferencia) → JasperPrint`,
  consumido pela Tarefa 3.

- [ ] **Passo 1: Escrever o teste de integração que falha**

```java
// processador-poupanca/src/test/java/br/com/scheduler/processadorpoupanca/PreenchimentoIT.java
package br.com.scheduler.processadorpoupanca;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import net.sf.jasperreports.engine.JasperPrint;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import br.com.scheduler.processadorstarter.aplicacao.PreencherRelatorio;

@SpringBootTest
@Testcontainers
class PreenchimentoIT {

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:18-alpine");

    @DynamicPropertySource
    static void propriedades(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", pg::getJdbcUrl);
        r.add("spring.datasource.username", pg::getUsername);
        r.add("spring.datasource.password", pg::getPassword);
    }

    @Autowired PreencherRelatorio preencher;

    @Test
    void preenche_o_relatorio_de_movimentacao_e_produz_paginas() {
        // O seed de SP-6a concentra movimento nos ultimos 10 dias; a consulta
        // filtra a data de referencia MENOS UM DIA, porque o ciclo roda de
        // madrugada e o artefato de um dia contem o movimento fechado do anterior.
        JasperPrint print = preencher.preencher("POUPANCA-0001", LocalDate.of(2026, 8, 12));

        assertThat(print).isNotNull();
        assertThat(print.getPages()).isNotEmpty();
        assertThat(print.getName()).isEqualTo("POUPANCA-0001");
    }

    @Test
    void o_segundo_relatorio_agrupa_e_quebra_pagina() {
        JasperPrint print = preencher.preencher("POUPANCA-0002", LocalDate.of(2026, 8, 12));
        // Agrupamento por agencia com isStartNewPage: mais de uma pagina
        assertThat(print.getPages().size()).isGreaterThan(1);
    }
}
```

- [ ] **Passo 2: Rodar e ver falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B -pl processador-poupanca verify 2>&1 | tail -25
```

Esperado: falha de compilação — `PreencherRelatorio` não existe.

- [ ] **Passo 3: Escrever os dois JRXMLs**

`POUPANCA-0001.jrxml` — estrutura obrigatória, com `RA-59` aplicada:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jasperReport xmlns="http://jasperreports.sourceforge.net/jasperreports"
              name="POUPANCA-0001" pageWidth="595" pageHeight="842"
              columnWidth="555" leftMargin="20" rightMargin="20"
              topMargin="20" bottomMargin="20">

  <parameter name="dataReferencia" class="java.time.LocalDate"/>

  <field name="agencia"    class="java.lang.String"/>
  <field name="conta"      class="java.lang.Long"/>
  <field name="titular"    class="java.lang.String"/>
  <field name="data"       class="java.sql.Date"/>
  <field name="tipo"       class="java.lang.String"/>
  <field name="valor"      class="java.math.BigDecimal"/>
  <field name="saldoApos"  class="java.math.BigDecimal"/>
  <field name="estornado"  class="java.lang.Boolean"/>

  <!-- RA-59: o cabecalho de colunas vive AQUI, na banda title, renderizada
       uma unica vez. E o que faz o XLSX continuo de RF-21 funcionar sem
       repeticao. NUNCA mover para pageHeader. -->
  <title>
    <band height="90">
      <image><reportElement x="0" y="0" width="80" height="40"/>
        <imageExpression><![CDATA["imagens/logo.png"]]></imageExpression></image>
      <staticText><reportElement x="100" y="10" width="400" height="20"/>
        <textElement><font fontName="DejaVu Sans" size="14" isBold="true"/></textElement>
        <text><![CDATA[Movimentacao diaria de contas de poupanca]]></text></staticText>
      <textField><reportElement x="100" y="32" width="200" height="14"/>
        <textFieldExpression><![CDATA[$P{dataReferencia}]]></textFieldExpression></textField>
      <!-- cabecalho de colunas -->
      <staticText><reportElement x="0"   y="70" width="50"  height="16"/>
        <text><![CDATA[Agencia]]></text></staticText>
      <staticText><reportElement x="55"  y="70" width="70"  height="16"/>
        <text><![CDATA[Conta]]></text></staticText>
      <staticText><reportElement x="130" y="70" width="150" height="16"/>
        <text><![CDATA[Titular]]></text></staticText>
      <staticText><reportElement x="285" y="70" width="60"  height="16"/>
        <text><![CDATA[Data]]></text></staticText>
      <staticText><reportElement x="350" y="70" width="60"  height="16"/>
        <text><![CDATA[Tipo]]></text></staticText>
      <staticText><reportElement x="415" y="70" width="65"  height="16"/>
        <text><![CDATA[Valor]]></text></staticText>
      <staticText><reportElement x="485" y="70" width="70"  height="16"/>
        <text><![CDATA[Saldo apos]]></text></staticText>
    </band>
  </title>

  <!-- RA-59: apenas ornamento descartavel. Nada que o XLSX precise. -->
  <pageHeader><band height="8"/></pageHeader>

  <detail>
    <band height="18">
      <textField><reportElement x="0"   y="0" width="50"  height="16"/>
        <textElement><font fontName="DejaVu Sans" size="8"/></textElement>
        <textFieldExpression><![CDATA[$F{agencia}]]></textFieldExpression></textField>
      <textField><reportElement x="55"  y="0" width="70"  height="16"/>
        <textFieldExpression><![CDATA[$F{conta}]]></textFieldExpression></textField>
      <textField><reportElement x="130" y="0" width="150" height="16"/>
        <textFieldExpression><![CDATA[$F{titular}]]></textFieldExpression></textField>
      <textField pattern="dd/MM/yyyy"><reportElement x="285" y="0" width="60" height="16"/>
        <textFieldExpression><![CDATA[$F{data}]]></textFieldExpression></textField>
      <textField><reportElement x="350" y="0" width="60"  height="16"/>
        <textFieldExpression><![CDATA[$F{tipo}]]></textFieldExpression></textField>
      <textField pattern="#,##0.00"><reportElement x="415" y="0" width="65" height="16"/>
        <textFieldExpression><![CDATA[$F{valor}]]></textFieldExpression></textField>
      <textField pattern="#,##0.00"><reportElement x="485" y="0" width="70" height="16"/>
        <textFieldExpression><![CDATA[$F{saldoApos}]]></textFieldExpression></textField>
    </band>
  </detail>

  <pageFooter>
    <band height="16">
      <textField><reportElement x="480" y="0" width="75" height="14"/>
        <textFieldExpression><![CDATA["Pag. " + $V{PAGE_NUMBER}]]></textFieldExpression></textField>
    </band>
  </pageFooter>
</jasperReport>
```

`POUPANCA-0002.jrxml` segue o mesmo padrão, com três diferenças: `pageWidth="842" pageHeight="595"`
(paisagem), fonte **DejaVu Serif**, imagem `selo.png`, e um grupo por agência:

```xml
  <group name="porAgencia" isStartNewPage="true">
    <groupExpression><![CDATA[$F{agencia}]]></groupExpression>
    <groupHeader><band height="20">...</band></groupHeader>
    <groupFooter><band height="18">... subtotal ...</band></groupFooter>
  </group>
```

As imagens são dois PNG simples e distintos — **imagem 1 e imagem 2 da matriz de SP-6a**. Podem ser
gerados com qualquer ferramenta; o que importa é serem diferentes entre si, que é a exigência de
`RA-08` por par.

- [ ] **Passo 4: Compilar os JRXML no build**

Em `processador-starter/pom.xml`, no `pluginManagement`, e ativado nos processadores:

```xml
<plugin>
  <groupId>net.sf.jasperreports</groupId>
  <artifactId>jasperreports-maven-plugin</artifactId>
  <version>${jasperreports.version}</version>
  <executions>
    <execution>
      <goals><goal>compile-reports</goal></goals>
    </execution>
  </executions>
  <configuration>
    <sourceDirectory>src/main/resources/relatorios</sourceDirectory>
    <outputDirectory>${project.build.outputDirectory}/relatorios</outputDirectory>
  </configuration>
</plugin>
```

Compilar no build, e não em tempo de execução, faz um JRXML inválido reprovar o PR em vez de
falhar às 3h da manhã.

- [ ] **Passo 5: Escrever o adaptador de dataset**

```java
// processador-starter/.../infraestrutura/DataSourcePaginado.java
package br.com.scheduler.processadorstarter.infraestrutura;

import java.time.Duration;
import java.time.Instant;
import java.util.Iterator;
import java.util.Map;
import net.sf.jasperreports.engine.JRException;
import net.sf.jasperreports.engine.JRField;
import net.sf.jasperreports.engine.JRRewindableDataSource;

/**
 * Concilia o chunk do Spring Batch com o JasperFillManager, que puxa o
 * dataset inteiro. Envolve um iterador paginado e avanca sob demanda.
 *
 * E aqui que o limite do relatorio de RA-57 e verificado — o "entre chunks"
 * que a arquitetura descreve, no unico lugar onde ele de fato existe.
 * A verificacao aqui NAO substitui o queryTimeout do statement: uma consulta
 * travada dentro de uma chamada JDBC nao chega a avancar, e so o timeout
 * do driver a interrompe.
 */
public class DataSourcePaginado implements JRRewindableDataSource {

    private final Iterator<Map<String, Object>> paginas;
    private final Instant inicio;
    private final Duration limite;
    private Map<String, Object> atual;

    public DataSourcePaginado(Iterator<Map<String, Object>> paginas, Duration limite) {
        this.paginas = paginas;
        this.limite = limite;
        this.inicio = Instant.now();
    }

    @Override
    public boolean next() throws JRException {
        if (Duration.between(inicio, Instant.now()).compareTo(limite) > 0) {
            throw new JRException(
                "limite do relatorio excedido: " + limite.toSeconds() + "s (RN-13, RA-57)");
        }
        if (!paginas.hasNext()) {
            return false;
        }
        atual = paginas.next();
        return true;
    }

    @Override
    public Object getFieldValue(JRField campo) {
        return atual.get(campo.getName());
    }

    @Override
    public void moveFirst() throws JRException {
        throw new JRException("dataset paginado nao e rebobinavel");
    }
}
```

- [ ] **Passo 6: Escrever o caso de uso de preenchimento**

`PreencherRelatorio` carrega o `.jasper` compilado, monta o `DataSourcePaginado` com um
`JdbcTemplate` paginado — **com `setQueryTimeout` obrigatório** — e chama `JasperFillManager`.

```java
// trecho essencial: o queryTimeout de RA-57
jdbcTemplate.setQueryTimeout((int) limite.toSeconds());
```

Sem esta linha, o limite interno não existe e ninguém percebe — o sistema silenciosamente volta a
ter um só limite de tempo.

- [ ] **Passo 7: Rodar e ver passar — este é o portão**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
mvn -B -pl processador-poupanca verify 2>&1 | tail -30
```

Esperado: os dois testes passam.

> ⚠️ **Se falhar com `NoSuchMethodError`, `InaccessibleObjectException` ou erro de resolução de
> dependência, PARE.** É `R-16` — JasperReports 7.0.8 sobre Spring Boot 4.1 e Java 25 é combinação
> não exercitada. Reporte o erro exato; a decisão volta a `ADR-0001` e à escolha da linha 4.1, e é
> do usuário. **Não contorne baixando a versão do Java nem do Spring Boot por conta própria.**

- [ ] **Passo 8: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add processador-starter processador-poupanca
git commit -m "$(cat <<'EOF'
Degrau 1: o Batch preenche o JasperPrint

Fecha R-16 — JasperReports 7.0.8 sobre Spring Boot 4.1 e Java 25 era
combinação não exercitada, e é o risco mais caro do projeto.

O adaptador concilia o chunk do Spring Batch com o fillReport, que puxa
o dataset inteiro, e é nele que o limite do relatório de RA-57 é
verificado. A verificação não substitui o queryTimeout: uma consulta
travada dentro de uma chamada JDBC não chega a avançar, e só o timeout
do driver a interrompe.

Os JRXML compilam no build. Um template inválido reprova o PR em vez de
falhar às 3h da manhã.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Degrau 2 — gravar no MinIO

**Arquivos:**
- Criar: `processador-starter/.../infraestrutura/RepositorioDeArtefatos.java`
- Criar: `processador-starter/src/test/java/.../GravacaoIT.java`

**Interfaces:**
- Consome: `PreencherRelatorio` (Tarefa 2).
- Produz: `RepositorioDeArtefatos.gravar(LocalDate, String sigla, String codigo, JasperPrint, byte[] csvGz) → List<String> caminhos`.

- [ ] **Passo 1: Escrever o teste que falha**

```java
@Testcontainers
class GravacaoIT {

    @Container
    static MinIOContainer minio = new MinIOContainer("minio/minio:RELEASE.2025-07-23T15-54-02Z");

    @Test
    void grava_os_dois_artefatos_irmaos_no_caminho_imutavel() {
        var caminhos = repositorio.gravar(
            LocalDate.of(2026, 8, 12), "POUPANCA", "POUPANCA-0001", print, csvGz);

        // RA-19: data de referencia -> sigla -> codigo. Usa a SIGLA, nunca o nome:
        // a sigla e imutavel (RN-01) e o nome e editavel, entao o caminho nunca muda.
        assertThat(caminhos).containsExactlyInAnyOrder(
            "2026-08-12/POUPANCA/POUPANCA-0001.jrprint",
            "2026-08-12/POUPANCA/POUPANCA-0001.csv.gz");
    }

    @Test
    void o_jrprint_gravado_desserializa_de_volta() {
        // R-01 e R-02: prova que a serializacao sobrevive a ida e volta
        repositorio.gravar(LocalDate.of(2026,8,12), "POUPANCA", "POUPANCA-0001", print, csvGz);
        JasperPrint lido = repositorio.lerJrprint("2026-08-12/POUPANCA/POUPANCA-0001.jrprint");
        assertThat(lido.getPages()).hasSameSizeAs(print.getPages());
    }
}
```

- [ ] **Passo 2: Rodar e ver falhar** · `mvn -B -pl processador-starter verify`

- [ ] **Passo 3: Implementar o repositório**

Usa o cliente S3 (`software.amazon.awssdk:s3`) apontado para o MinIO. Serializa o `JasperPrint` com
`JRSaver.saveObject` e grava os dois objetos.

**A ordem dentro do método importa:** grava primeiro, e só depois quem chamar registra os metadados.
É `RA-11`, e a Tarefa 4 depende disso.

- [ ] **Passo 4: Rodar e ver passar**

- [ ] **Passo 5: Commit**

```bash
git add processador-starter
git commit -m "$(cat <<'EOF'
Degrau 2: grava os artefatos irmãos no MinIO

O caminho usa a sigla e não o nome do produto: a sigla é imutável e o
nome é editável, de modo que o caminho de um artefato jamais muda.

O segundo teste desserializa o .jrprint de volta e compara as páginas —
é o que prova, e não apenas afirma, que a serialização de R-01 e R-02
sobrevive à ida e volta pelo bucket.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Degrau 3 — metadados, na ordem de `RA-11`

**Arquivos:**
- Criar: `processador-starter/.../infraestrutura/repositorio/ExecucaoRepositorio.java`
- Criar: `processador-starter/.../aplicacao/ApurarRelatorio.java`
- Criar: `processador-starter/src/test/java/.../OrdemDeGravacaoIT.java`

**Interfaces:**
- Consome: Tarefas 2 e 3.
- Produz: `ApurarRelatorio.apurar(String codigo, LocalDate dataReferencia) → Execucao`.

- [ ] **Passo 1: Escrever o teste da ordem — o mais sutil do plano**

```java
@Test
void quando_o_status_vira_terminal_o_artefato_ja_existe() {
    // RA-11: os artefatos sao gravados ANTES dos metadados de conclusao.
    // A ordem inversa produziria uma execucao em 'processado com sucesso'
    // sem artefato correspondente — exatamente o estado que RN-42
    // pressupoe impossivel.
    //
    // Nao basta olhar o resultado final: precisamos observar o INSTANTE em
    // que o status muda. Um espiao no repositorio de artefatos registra se
    // o objeto ja estava la.
    var observado = new ArrayList<Boolean>();
    var repositorioEspiao = new ExecucaoRepositorio(dataSource) {
        @Override
        public void concluir(long execucaoId, String status, Instant fim) {
            observado.add(minio.existe("2026-08-12/POUPANCA/POUPANCA-0001.jrprint"));
            super.concluir(execucaoId, status, fim);
        }
    };

    new ApurarRelatorio(preencher, artefatos, repositorioEspiao)
        .apurar("POUPANCA-0001", LocalDate.of(2026, 8, 12));

    assertThat(observado)
        .as("o artefato precisa existir no bucket antes de o status virar terminal")
        .containsExactly(true);
}

@Test
void a_execucao_recebe_o_tempo_estimado_copiado() {
    // RN-47: o tempo estimado e COPIADO para dentro da execucao no disparo.
    // Alterar o catalogo depois nao pode reclassificar esta execucao.
    var execucao = apurar.apurar("POUPANCA-0001", LocalDate.of(2026, 8, 12));
    assertThat(execucao.tempoEstimadoSegundos()).isEqualTo(120);
}
```

- [ ] **Passo 2: Rodar e ver falhar**

- [ ] **Passo 3: Implementar `ApurarRelatorio`**

A sequência, nesta ordem exata:

```
1. le o tempo estimado do catalogo e COPIA para a execucao (RN-47)
2. marca iniciado_em          -> UPDATE permitido: status ainda e 'em processamento'
3. preenche o JasperPrint      (Tarefa 2)
4. grava os artefatos no MinIO (Tarefa 3)   <- ANTES
5. registra o artefato no controle
6. conclui a execucao: status terminal + finalizado_em   <- DEPOIS (RA-11)
7. move o ponteiro em execucao_vigente
```

O passo 6 é o **único** `UPDATE` que leva a execução a status terminal. Depois dele, o trigger de
SP-6b torna a linha imutável.

- [ ] **Passo 4: Rodar e ver passar**

- [ ] **Passo 5: Commit**

```bash
git add processador-starter
git commit -m "$(cat <<'EOF'
Degrau 3: metadados na ordem que RA-11 exige

O teste não olha o resultado final: um espião observa o instante em que
o status vira terminal e afirma que o artefato já estava no bucket. A
ordem inversa produziria execução em processado com sucesso sem
artefato, que é o estado que RN-42 pressupõe impossível.

O tempo estimado é copiado para dentro da execução no disparo, para que
editar o catálogo depois não reclassifique o passado.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: Degrau 4 — a API exporta PDF

**Arquivos:**
- Criar: `api/.../dominio/`, `.../aplicacao/ExportarRelatorio.java`,
  `.../infraestrutura/artefato/ArtefatoS3.java`, `.../web/ExportacaoController.java`
- Criar: `api/src/test/java/.../ExportacaoIT.java`

**Interfaces:**
- Produz: `GET /api/v1/relatorios/{codigo}/execucoes/{data}/exportacao?formato=PDF`, consumido pelas
  Tarefas 6 e 9.

- [ ] **Passo 1: Escrever o teste**

```java
@Test
void exporta_pdf_com_paginas() {
    var resposta = rest.getForEntity(
        "/api/v1/relatorios/POUPANCA-0001/execucoes/2026-08-12/exportacao?formato=PDF",
        byte[].class);

    assertThat(resposta.getStatusCode().value()).isEqualTo(200);
    assertThat(resposta.getHeaders().getContentType().toString()).isEqualTo("application/pdf");
    // %PDF- e a assinatura do formato
    assertThat(new String(resposta.getBody(), 0, 5)).isEqualTo("%PDF-");
}

@Test
void execucao_sem_artefato_valido_devolve_409() {
    // RF-20, RN-42: so exporta quem esta em sucesso ou alerta
    var resposta = rest.getForEntity(
        "/api/v1/relatorios/POUPANCA-0002/execucoes/2026-08-10/exportacao?formato=PDF",
        String.class);
    assertThat(resposta.getStatusCode().value()).isEqualTo(409);
}

@Test
void artefato_expurgado_devolve_410_e_nao_erro_generico() {
    // RF-24, RN-39: mensagem explicita de indisponibilidade por retencao
    var resposta = rest.getForEntity(
        "/api/v1/relatorios/POUPANCA-0001/execucoes/2026-08-05/exportacao?formato=PDF",
        String.class);
    assertThat(resposta.getStatusCode().value()).isEqualTo(410);
    assertThat(resposta.getBody()).contains("retenção");
}
```

- [ ] **Passo 2: Rodar e ver falhar**

- [ ] **Passo 3: Implementar as quatro camadas**

`web/ExportacaoController` valida a entrada e não contém regra · `aplicacao/ExportarRelatorio`
orquestra · `dominio/` decide se a execução é exportável (`RN-42`) · `infraestrutura/artefato/`
lê do MinIO e desserializa.

**O domínio não importa Spring nem HTTP** — o ArchUnit da Tarefa 8 verifica isso.

- [ ] **Passo 4: Rodar e ver passar**

- [ ] **Passo 5: Commit**

```bash
git add api
git commit -m "$(cat <<'EOF'
Degrau 4: a API lê o artefato e exporta PDF

As quatro camadas com a fatia atravessando todas — é também a fatia de
referência por camada que SP-3 adiou.

Os três testes cobrem os códigos que o contrato de SP-6b declarou: 200
com assinatura de PDF, 409 sem artefato válido e 410 para expurgado,
este último verificando que a mensagem fala de retenção e não é erro
genérico.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: Degrau 5 — Keycloak e a cadeia de permissão

**Arquivos:**
- Criar: `infra/keycloak/realm-scheduler.json`
- Criar: `api/.../infraestrutura/SegurancaConfig.java`
- Criar: `api/.../aplicacao/CadeiaDePermissao.java`
- Criar: `api/src/test/java/.../AutorizacaoIT.java`

- [ ] **Passo 1: Escrever os testes de autorização — regra inviolável**

```java
@Test
void relator_fora_da_cadeia_recebe_404_e_nao_403() {
    // RN-23 + RF-15: relatorio fora da cadeia nao aparece na listagem E nao e
    // acessivel por acesso direto. E 404 de proposito: um 403 confirmaria a
    // existencia do relatorio a quem nao deveria sequer saber que ele existe.
    var resposta = comJwtDe("relator-sem-poupanca").getForEntity(
        "/api/v1/relatorios/POUPANCA-0001/execucoes/2026-08-12/exportacao?formato=PDF",
        String.class);
    assertThat(resposta.getStatusCode().value()).isEqualTo(404);
}

@Test
void administrador_enxerga_tudo_sem_passar_pela_cadeia() {
    // RN-24: unica excecao de autorizacao do sistema. RA-68 a lista entre os
    // testes obrigatorios por natureza de risco, "porque sao os que ninguem
    // escreve espontaneamente".
    var resposta = comJwtDe("admin").getForEntity(
        "/api/v1/datas/2026-08-12/produtos", String.class);
    assertThat(resposta.getStatusCode().value()).isEqualTo(200);
    assertThat(resposta.getBody()).contains("POUPANCA");
}

@Test
void relator_com_a_role_certa_enxerga_o_relatorio() {
    var resposta = comJwtDe("relator-poupanca").getForEntity(
        "/api/v1/datas/2026-08-12/produtos/POUPANCA/relatorios", String.class);
    assertThat(resposta.getBody()).contains("POUPANCA-0001");
}

@Test
void sem_token_recebe_401() {
    assertThat(rest.getForEntity("/api/v1/datas", String.class)
        .getStatusCode().value()).isEqualTo(401);
}
```

- [ ] **Passo 2: Rodar e ver falhar**

- [ ] **Passo 3: Criar o realm mínimo**

`infra/keycloak/realm-scheduler.json`, importado pelo Compose:

- **Realm roles:** `ADMINISTRADOR`, `GERENTE`, `RELATOR` — conjunto fechado, criado na
  inicialização do realm, nunca pela aplicação (`RA-61`).
- **Cliente `relatorios`** com uma client role de exemplo, e o cliente da API como resource server.
- **Usuários de teste:** `admin` (ADMINISTRADOR), `relator-poupanca` (RELATOR + a client role),
  `relator-sem-poupanca` (RELATOR, sem role).
- **Usuário administrativo inicial** com senha por variável de ambiente (`RA-32`).

- [ ] **Passo 4: Implementar a cadeia**

`CadeiaDePermissao` resolve: client roles do JWT → `controle.relatorio_role` → códigos permitidos.
O ADMINISTRADOR **não passa por aqui** — é desvio explícito, com comentário citando `RN-24`.

- [ ] **Passo 5: Rodar e ver passar**

- [ ] **Passo 6: Commit**

```bash
git add infra/keycloak api
git commit -m "$(cat <<'EOF'
Degrau 5: identidade e a cadeia de permissão

Quatro testes de autorização, que a regra inviolável do CLAUDE.md
exige de toda rota nova.

O 404 para relatório fora da cadeia é decisão e está testado: um 403
confirmaria a existência do relatório a quem não deveria saber que ele
existe.

O acesso irrestrito do ADMINISTRADOR tem teste dedicado porque RA-68 o
lista entre os obrigatórios por natureza de risco — são os que ninguém
escreve espontaneamente.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Degrau 6 — Airflow e a reserva do ciclo

**Arquivos:**
- Criar: `orquestrador/dags/coleta_diaria.py`
- Criar: `orquestrador/dags/reserva.py`
- Criar: `orquestrador/tests/test_coleta_diaria.py`

- [ ] **Passo 1: Escrever o teste da DAG**

```python
# orquestrador/tests/test_coleta_diaria.py
from airflow.models import DagBag

def test_a_dag_carrega_sem_erro():
    bag = DagBag(dag_folder="orquestrador/dags", include_examples=False)
    assert bag.import_errors == {}
    assert "coleta_diaria" in bag.dags

def test_catchup_e_falso_explicitamente():
    # RA-56: sem isto, subir a DAG com start_date no passado dispara uma run
    # por dia perdido, cada uma carimbando data de referencia antiga com o dado
    # de hoje — a corrupcao que RN-54 proibe, entrando por omissao.
    # O padrao varia entre Airflow 2.x e 3.x; a declaracao explicita torna a
    # versao irrelevante.
    bag = DagBag(dag_folder="orquestrador/dags", include_examples=False)
    assert bag.dags["coleta_diaria"].catchup is False

def test_a_reserva_vem_antes_das_tasks_de_produto():
    # RN-45, RA-54: nenhum conteiner sobe antes de a reserva existir.
    bag = DagBag(dag_folder="orquestrador/dags", include_examples=False)
    dag = bag.dags["coleta_diaria"]
    reserva = dag.get_task("reserva_do_ciclo")
    poupanca = dag.get_task("apura_poupanca")
    assert poupanca.task_id in [t.task_id for t in reserva.downstream_list]

def test_nenhuma_task_recebe_data_de_referencia_como_parametro():
    # RN-54, RF-53: a data nunca e entrada.
    fonte = open("orquestrador/dags/coleta_diaria.py").read()
    assert "data_referencia=" not in fonte
```

- [ ] **Passo 2: Rodar e ver falhar** · `pytest orquestrador/tests -q`

- [ ] **Passo 3: Escrever a DAG**

```python
# orquestrador/dags/coleta_diaria.py
from datetime import datetime
from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator

from reserva import reservar_ciclo

# RNF-20: 03h00, diario. O agendamento vive aqui, no codigo, e nao em
# configuracao — mudar exige PR e CI, como a task estatica de um produto.
with DAG(
    dag_id="coleta_diaria",
    schedule="0 3 * * *",
    start_date=datetime(2026, 8, 1),
    catchup=False,                    # RA-56 — explicito de proposito
    max_active_runs=1,
    default_args={"retries": 0},
    tags=["coleta"],
) as dag:

    # RA-54: a primeira task grava uma Execucao por relatorio ativo, com
    # inicio nulo. Sem ela, um relatorio que nunca chega a ser apurado
    # desaparece do denominador da metrica em vez de aparecer como falha.
    reserva = PythonOperator(
        task_id="reserva_do_ciclo",
        python_callable=reservar_ciclo,
    )

    # RA-65: uma task por produto, estatica. A lista de produtos e codigo
    # porque o produto E codigo; a lista de relatorios e dado, e por isso a
    # reserva consulta o catalogo em tempo de execucao.
    apura_poupanca = PythonOperator(
        task_id="apura_poupanca",
        python_callable=lambda: __import__("subprocess").check_call(
            ["java", "-jar", "/app/processador-poupanca.jar"]),
        execution_timeout=None,   # SP-8 acrescenta o limite de seguranca (RA-57)
    )

    reserva >> apura_poupanca
```

`reserva.py` conecta no schema de controle e insere uma execução por relatório ativo, com
`iniciado_em` nulo, `status = 'em processamento'` e `origem = 'agendada'`.

- [ ] **Passo 4: Rodar e ver passar**

- [ ] **Passo 5: Commit**

```bash
git add orquestrador
git commit -m "$(cat <<'EOF'
Degrau 6: a DAG com reserva do ciclo

catchup=False é declarado explicitamente e tem teste próprio: o padrão
varia entre Airflow 2.x e 3.x, e sem a declaração a corrupção que RN-54
proíbe entraria por omissão, carimbando data antiga com o dado de hoje.

Um teste lê o fonte da DAG e afirma que nenhuma task recebe data de
referência como parâmetro. É grosseiro, e é o que impede a apuração
retroativa de voltar por uma linha de Python.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: ArchUnit, `ARCHITECTURE.md` e os 28 cenários

**Arquivos:**
- Criar: `api/src/test/java/br/com/scheduler/api/ArquiteturaTest.java`
- Criar: 28 arquivos `.feature`
- Modificar: `ARCHITECTURE.md`

- [ ] **Passo 1: Escrever os cinco testes ArchUnit**

```java
// api/src/test/java/br/com/scheduler/api/ArquiteturaTest.java
package br.com.scheduler.api;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

@AnalyzeClasses(packages = "br.com.scheduler",
                importOptions = ImportOption.DoNotIncludeTests.class)
class ArquiteturaTest {

    @ArchTest
    static final ArchRule dominio_nao_conhece_infraestrutura =
        noClasses().that().resideInAPackage("..dominio..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..infraestrutura..", "org.springframework..",
                                "java.sql..", "jakarta.servlet..")
            .because("o dominio e regra pura: nao conhece HTTP, banco nem framework");

    @ArchTest
    static final ArchRule banco_so_no_repositorio =
        noClasses().that().resideOutsideOfPackage("..infraestrutura.repositorio..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("java.sql..", "javax.sql..")
            .because("nenhum acesso a banco fora de infraestrutura.repositorio");

    @ArchTest
    static final ArchRule web_nao_alcanca_repositorio =
        noClasses().that().resideInAPackage("..web..")
            .should().dependOnClassesThat().resideInAPackage("..infraestrutura.repositorio..")
            .because("web nao contem regra de negocio; passa pela camada de aplicacao");

    @ArchTest
    static final ArchRule api_nao_depende_de_processador =
        noClasses().that().resideInAPackage("br.com.scheduler.api..")
            .should().dependOnClassesThat().resideInAPackage("br.com.scheduler.processador..")
            .because("RA-29: a API nunca acessa schema transacional. Qualquer dependencia "
                   + "para um modulo processador e defeito, nao variacao de desenho");

    @ArchTest
    static final ArchRule processadores_nao_se_conhecem =
        noClasses().that().resideInAPackage("br.com.scheduler.processadorpoupanca..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("br.com.scheduler.processadorcliente..",
                                "br.com.scheduler.processadorcontacorrente..",
                                "br.com.scheduler.processadorconsorcio..",
                                "br.com.scheduler.processadoremprestimo..")
            .because("RA-10: cada processador le exclusivamente o schema do seu produto");
}
```

- [ ] **Passo 2: Rodar e ver passar** — se algum falhar, **o código é que está errado**, não a regra

- [ ] **Passo 3: Criar os 28 `.feature`**

Distribuídos conforme `RA-45` e `RA-46`, com os nomes que a matriz de `user-stories.md` fixou.
**Quatro sem etiqueta**, que rodam:

| Arquivo | Onde | História |
|---|---|---|
| `coleta.feature` | `processador-starter` | HS-02 |
| `listagem.feature` | `api` | HU-01 |
| `exportacao.feature` | `api` | HU-02, só PDF |
| `acesso-irrestrito.feature` | `api` | HU-11 |

Os outros 24 levam `@pendente` na primeira linha:

```gherkin
@pendente
# language: pt
Funcionalidade: Retentativa
  Os passos entram em SP-8. Este arquivo existe para que o trabalho seja
  visivel: cada etiqueta @pendente removida e uma funcionalidade entregue.

  Cenario: relatorio que falhou origina nova execucao de origem retentativa
    Dado uma execucao vigente em "processado com erro"
    Quando a retentativa do ciclo roda
    Entao existe nova execucao com origem "retentativa"
    E a anterior permanece e passa a nao-vigente
```

Configure o Cucumber para `--tags 'not @pendente'`.

- [ ] **Passo 4: Preencher o `ARCHITECTURE.md`**

Substituir o *code map* esquelético pelo real, com os pacotes que passaram a existir. Manter os oito
invariantes e **acrescentar, em cada um, como é verificado** — incluindo a admissão de que o
invariante 7 não tem verificação automática.

- [ ] **Passo 5: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "features:   $(find . -name '*.feature' -not -path './node_modules/*' | wc -l)  (esperado 28)"
echo "pendentes:  $(grep -rl '@pendente' --include='*.feature' . | wc -l)  (esperado 24)"
mvn -B test -Dtest=ArquiteturaTest 2>&1 | grep -E 'Tests run|BUILD'
git add . && git commit -m "$(cat <<'EOF'
ArchUnit, ARCHITECTURE preenchido e os 28 cenários

Cinco dos oito invariantes viram teste de arquitetura. O documento
registra que o sexto e o oitavo são grep no CI e que o sétimo — não
alterar migration aplicada — não tem verificação automática nenhuma.
Fingir cobertura seria pior que admitir a lacuna.

Vinte e quatro cenários nascem com @pendente. Cada etiqueta removida em
SP-8 é uma funcionalidade entregue, e o trabalho fica visível no
próprio repositório.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 9: E2E — a fatia inteira

**Arquivos:**
- Criar: `e2e/colecao-fatia-vertical.json` (Newman)
- Criar: `e2e/verifica-fatia.sh`

- [ ] **Passo 1: Escrever o roteiro E2E**

```bash
#!/usr/bin/env bash
# e2e/verifica-fatia.sh — a fatia inteira, ponta a ponta
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/6] subindo o ambiente"
make dev
make dev-full   # a fatia precisa do Airflow

echo "[2/6] aplicando migrations e seed"
make migrate
make seed-dev

echo "[3/6] disparando a DAG"
docker compose exec -T airflow-scheduler airflow dags trigger coleta_diaria

echo "[4/6] aguardando a apuracao (ate 5 min)"
for i in $(seq 1 60); do
  concluidas=$(psql "$DATABASE_URL" -tA -c \
    "SELECT count(*) FROM controle.execucao
     WHERE status = 'processado com sucesso' AND data_referencia = CURRENT_DATE;")
  [ "$concluidas" -ge 2 ] && break
  sleep 5
done
[ "$concluidas" -ge 2 ] || { echo "FALHOU: apuracao nao concluiu os 2 relatorios"; exit 1; }

echo "[5/6] conferindo a ordem de RA-11 — artefato antes do status terminal"
sem_artefato=$(psql "$DATABASE_URL" -tA -c \
  "SELECT count(*) FROM controle.execucao e
   WHERE e.status IN ('processado com sucesso','processado com alerta')
     AND NOT EXISTS (SELECT 1 FROM controle.artefato a WHERE a.execucao_id = e.id);")
[ "$sem_artefato" = "0" ] || { echo "FALHOU: execucao concluida sem artefato (RA-11, RN-42)"; exit 1; }

echo "[6/6] baixando o PDF"
newman run e2e/colecao-fatia-vertical.json --env-var "base=http://localhost:8080"

echo "FATIA VERTICAL OK"
```

A coleção Newman obtém um token no Keycloak, chama a exportação e verifica que a resposta é `200`,
que o `content-type` é `application/pdf` e que o corpo começa com `%PDF-`.

- [ ] **Passo 2: Rodar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
bash e2e/verifica-fatia.sh
```

- [ ] **Passo 3: Conferir os dez critérios de aceite**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "1.  build:      $(mvn -B -q clean verify >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "2.  health:     $(curl -sf localhost:8080/actuator/health/liveness | grep -c UP)"
echo "3.  objetos no MinIO: $(docker compose exec -T minio mc ls --recursive local/artefatos 2>/dev/null | wc -l)  (esperado 4)"
echo "7.  reserva:    $(psql "$DATABASE_URL" -tA -c "SELECT count(*) FROM controle.execucao WHERE iniciado_em IS NULL;")"
echo "8.  archunit:   $(mvn -B -q test -Dtest=ArquiteturaTest >/dev/null 2>&1 && echo ok || echo FALHOU)"
echo "9.  features:   $(find . -name '*.feature' | wc -l) total, $(grep -rl '@pendente' --include='*.feature' . | wc -l) pendentes"
```

Os critérios 4, 5, 6 e 10 são os passos [5/6] e [6/6] do roteiro.

- [ ] **Passo 4: Commit**

```bash
git add e2e
git commit -m "$(cat <<'EOF'
E2E da fatia vertical, ponta a ponta

Sobe o ambiente, dispara a DAG, aguarda a apuração, confere a ordem de
RA-11 por consulta ao banco e baixa o PDF.

O passo 5 é o que mais importa: uma consulta procura execução concluída
sem artefato correspondente e falha se achar alguma. É o estado que
RN-42 pressupõe impossível, verificado contra o banco real e não contra
um dublê.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-7 termina quando os dez critérios passam e os nove commits estão no branch. Com isso E3 fecha, e
o projeto tem uma fatia vertical funcionando de ponta a ponta.

**O que fica para SP-8:** os quatro produtos restantes · XLSX, DOCX e CSV na exportação · a *font
extension* da fonte C, que exercita `R-03` · os desfechos não-felizes (retentativa, limites de
tempo, callback de falha, reprocessamento, expurgo) · a gestão de acesso pelo Gerente · as telas
Angular · e as 24 etiquetas `@pendente` a remover.
