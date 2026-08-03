# 05 — Stack: build, runtime e layout do monorepo

Pesquisa de apoio ao ticket [`05-stack-build-runtime-monorepo.md`](../issues/05-stack-build-runtime-monorepo.md).
Data da coleta: **2026-08-02**. Todas as afirmações abaixo vêm de fonte primária (documentação oficial,
código-fonte do projeto, API de release do fornecedor ou metadados do Maven Central).

Ambiente de referência: Ubuntu 24.04 **ARM64 (aarch64)**, Temurin JDK 25, Maven 3.9.16, Node 24.16.0, Docker 29.5.

> **Duas premissas do ticket estão desatualizadas e foram corrigidas nesta pesquisa:**
> 1. Não existe migração de `net.sf.jasperreports` para `com.jaspersoft` — ver [§3.2](#32-groupid-e-licença--a-premissa-do-ticket-está-errada).
> 2. Spring Boot 4.x não usa Spring Batch 5.x; usa **Spring Batch 6.x** — ver [§2.3](#23-spring-batch-a-linha-5x-saiu-de-cena).

---

## 1. Java: qual LTS

### 1.1 O que é LTS hoje

A API do Eclipse Adoptium responde, hoje, que as releases LTS disponíveis são **8, 11, 17, 21 e 25**, e que
`most_recent_lts` é **25**:

- <https://api.adoptium.net/v3/info/available_releases> → `"available_lts_releases": [8,11,17,21,25]`, `"most_recent_lts": 25`, `"most_recent_feature_release": 26`.

A janela de disponibilidade dos binários Temurin, segundo a página oficial de suporte
(<https://adoptium.net/support/>):

| JDK | Designação | Primeira disponibilidade | Fim de disponibilidade |
|---|---|---|---|
| 21 | LTS | set/2023 | "at least Dec 2029" |
| **25** | **LTS** | **set/2025** | **"at least Sep 2031"** |
| 26 | não-LTS | mar/2026 | set/2026 |

Ou seja: JDK 26 sai de suporte **daqui a ~1 mês**; JDK 25 tem ~5 anos de pista. Não há razão para
considerar 26.

### 1.2 O que o resto da stack aceita

- **Spring Boot 4.1.0**: *"Spring Boot 4.1.0 requires at least Java 17 and is compatible with versions up to
  and including Java 26."* — <https://docs.spring.io/spring-boot/system-requirements.html>
- O próprio build do Spring Boot fixa `BUILD_JAVA_VERSION = 25` e `RUNTIME_JAVA_VERSION = 17`, isto é, o
  projeto é **compilado com JDK 25** e entrega bytecode 17 —
  <https://github.com/spring-projects/spring-boot/blob/main/buildSrc/src/main/java/org/springframework/boot/build/JavaConventions.java>
- **Spring Batch 6.0**: *"Spring Batch 6.0 requires Java 17+ as its minimum Java version."* —
  <https://github.com/spring-projects/spring-batch/wiki/Spring-Batch-6.0-Migration-Guide>
- **JasperReports 7.0.7**: o JAR publicado no Maven Central tem *class file major version 52*, ou seja,
  bytecode **Java 8** (verificado inspecionando `net/sf/jasperreports/engine/JasperPrint.class` dentro de
  <https://repo1.maven.org/maven2/net/sf/jasperreports/jasperreports/7.0.7/jasperreports-7.0.7.jar>).
  O baseline do Jasper não impõe nada.
- **JaCoCo 0.8.15**: *"officially supports Java 26 and experimentally supports Java 27"*; o FAQ declara suporte a
  class files de versão 1.0 a 26 — <https://www.jacoco.org/jacoco/trunk/doc/changes.html> e
  <https://www.jacoco.org/jacoco/trunk/doc/faq.html>
- **Imagem de runtime**: `eclipse-temurin:25-jre` publica manifesto para `linux/arm64` (além de amd64,
  ppc64le, s390x) — consultado em <https://hub.docker.com/v2/repositories/library/eclipse-temurin/tags?name=25-jre>.
  Variantes `25-jre-noble`, `25-jre-alpine-3.23` e `25-jre-ubi10-minimal` também têm arm64.

### 1.3 Trade-off real: `release 17` ou `release 25`?

| | `maven.compiler.release=17` | `maven.compiler.release=25` |
|---|---|---|
| Compila em | qualquer JDK ≥ 17 | apenas JDK ≥ 25 |
| Roda em | qualquer JRE ≥ 17 | apenas JRE ≥ 25 |
| Recursos de linguagem | até Java 17 | *pattern matching* completo, *sequenced collections*, *virtual threads* estáveis, *record patterns* |
| Risco de ferramenta | menor (todo agente/linter suporta) | exige JaCoCo ≥ 0.8.14, Surefire recente |
| Aderência ao ambiente | subutiliza o Temurin 25 instalado | usa exatamente o que está na máquina e na imagem |

**Critério de decisão:** se o backend fosse uma biblioteca publicada para terceiros consumirem, `release 17`
seria obrigatório. Aqui não é: é uma aplicação fechada, o runtime é uma imagem Docker que **nós** pinamos
(`eclipse-temurin:25-jre`) e a produção roda Docker Compose em VMs nossas
(`docs/descricao-inicial.md`, "Regras Arquiteturais"). Não existe consumidor externo do bytecode.
Logo, `release 25`.

---

## 2. Spring Boot e Spring Batch

### 2.1 Versão atual

A API oficial de releases (<https://api.spring.io/projects/spring-boot/releases>) marca
`"version": "4.1.0", "status": "GENERAL_AVAILABILITY", "current": true`.
Linhas ainda vivas no momento da consulta: 3.5.16, 4.0.7 e 4.1.0.

### 2.2 Janela de suporte (fonte: <https://api.spring.io/projects/spring-boot/generations>)

| Geração | Release inicial | Fim do suporte OSS | Fim do suporte comercial |
|---|---|---|---|
| 3.3.x | 2024-05-31 | 2025-06-30 | 2026-06-30 |
| 3.4.x | 2024-11-30 | 2025-12-31 | 2026-12-31 |
| 3.5.x | 2025-05-31 | **2026-06-30 (já expirou)** | 2032-06-30 |
| 4.0.x | 2025-11-30 | **2026-12-31 (expira em ~5 meses)** | 2027-12-31 |
| **4.1.x** | **2026-06-30** | **2027-07-31** | **2028-07-31** |

Leitura: **hoje não existe nenhuma linha 3.x com suporte OSS ativo.** Escolher 3.5.x significaria nascer
fora de suporte gratuito (só a assinatura comercial da Broadcom/Tanzu cobre até 2032). Escolher 4.0.x dá
5 meses de pista. Só 4.1.x oferece uma janela realista para um projeto que começa agora.

Requisitos declarados para 4.1.0 (<https://docs.spring.io/spring-boot/system-requirements.html>):

- *"Spring Framework 7.0.8 or above is also required."*
- Build tools: **Maven 3.6.3 ou posterior**, Gradle 8.14+ / 9.x.
- Containers embarcados: Tomcat 11.0.x e Jetty 12.1.x (Servlet 6.1); *"You can also deploy Spring Boot
  applications to any Servlet 6.1+ compatible container."*

Spring Framework 7.0.x tem fim de suporte OSS em 2027-07-31 —
<https://api.spring.io/projects/spring-framework/generations>.

### 2.3 Spring Batch: a linha 5.x saiu de cena

<https://api.spring.io/projects/spring-batch/releases> aponta **6.0.4 como `current: true`** (5.2.6 ainda
listado, mas não corrente). E o mapeamento geração↔Boot vem de
<https://api.spring.io/projects/spring-batch/generations>:

| Spring Batch | Fim OSS | Spring Boot ligado |
|---|---|---|
| 5.1.x | 2025-06-30 | 3.2.x, 3.3.x |
| 5.2.x | 2026-06-30 (expirou) | 3.4.x, 3.5.x |
| **6.0.x** | **2027-07-31** | **4.0.x, 4.1.x** |

Portanto o ticket precisa ser reescrito: **não é "compatibilidade com Spring Batch 5.x"; é Spring Batch 6.x**.
Isso não é cosmético — o Batch 6 muda a API que os 5 módulos processadores vão usar. Do
[guia oficial de migração](https://github.com/spring-projects/spring-batch/wiki/Spring-Batch-6.0-Migration-Guide):

- `@EnableBatchProcessing(dataSourceRef=…)` → `@EnableBatchProcessing` + **`@EnableJdbcJobRepository(dataSourceRef=…)`**;
- `DefaultBatchConfiguration` → **`JdbcDefaultBatchConfiguration`** para infraestrutura JDBC;
- novo modelo *chunk-oriented*: `StepBuilder.chunk(int, PlatformTransactionManager)` está
  `@Deprecated(since="6.0", forRemoval=true)` (remoção prevista para 7.0) e é substituído por
  `chunk(int)`, que devolve `ChunkOrientedStepBuilder`, com o transaction manager configurado à parte —
  [`StepBuilder.java`](https://github.com/spring-projects/spring-batch/blob/main/spring-batch-core/src/main/java/org/springframework/batch/core/step/builder/StepBuilder.java);
- a implementação legada do v5 continua disponível durante toda a geração 6, mas depreciada.

**Consequência de projeto:** o *Starter do Processador* (ticket 21) deve encapsular a API nova
(`ChunkOrientedStepBuilder`) e **não** expor `chunk(int, tx)` aos 5 módulos de produto, senão a remoção no
Batch 7 vira uma migração em 5 lugares em vez de 1.

### 2.4 Spring **não** integra JasperReports

Não existe pacote `jasperreports` nem em `spring-context-support/src/main/java/org/springframework/ui/`
nem em `spring-webmvc/.../web/servlet/view/` — verificado via API de conteúdo do GitHub nas tags
`v5.1.20.RELEASE`, `v5.2.0.RELEASE`, `v5.3.0`, `v5.3.39` e no branch `main` (Spring Framework 7):
o único subpacote de `org/springframework/ui` é `freemarker`.

Ou seja, `JasperReportsViewResolver` / `org.springframework.ui.jasperreports` **não existem há várias
gerações**. A API REST tem que chamar a API do JasperReports diretamente
(`JRLoader.loadObject`, `JRXlsxExporter`, `JRPdfExporter`, …). Nada de procurar auto-configuração.

### 2.5 Evidência de que Jasper 7 roda com Boot 4

O próprio repositório do JasperReports passou a publicar um *sample* Spring Boot na 7.0.7
(`changes.txt`: *"new OSGi and Spring Boot samples"*). O POM desse sample usa
`spring-boot-dependencies` **4.0.6** importado via BOM, com `source.version`/`target.version` = 17:
<https://github.com/Jaspersoft/jasperreports/blob/7.0.7/demo/samples/springboot/pom.xml>

É a confirmação de primeira mão de que a combinação Jasper 7.0.7 + Spring Boot 4.x é exercitada pelo próprio
fornecedor.

---

## 3. JasperReports

### 3.1 Versão atual

`maven-metadata.xml` de `net.sf.jasperreports:jasperreports` lista até **7.0.7**, `lastUpdated=20260529184441`
— <https://repo1.maven.org/maven2/net/sf/jasperreports/jasperreports/maven-metadata.xml>.
A release correspondente no GitHub é `7.0.7`, publicada em **2026-05-29**
(<https://api.github.com/repos/jaspersoft/jasperreports/releases>). Há uma 7.0.8 já com entrada em
`changes.txt` (*"JasperReports can now run on stock OpenPDF 1.3.43"*), ainda não publicada no Central.

Cronologia recente: 7.0.4 (2026-03-05), 7.0.5 (2026-03-09), 7.0.6 (2026-03-13), 7.0.7 (2026-05-29).

### 3.2 groupId e licença — **a premissa do ticket está errada**

- O POM 7.0.7 publicado declara `<groupId>net.sf.jasperreports</groupId>` e
  `<license><name>GNU Lesser General Public License</name></license>`, com
  `<organization><name>Cloud Software Group, Inc.</name>` —
  <https://repo1.maven.org/maven2/net/sf/jasperreports/jasperreports/7.0.7/jasperreports-7.0.7.pom>
- `https://repo1.maven.org/maven2/com/jaspersoft/` responde **HTTP 404** — o groupId `com.jaspersoft`
  simplesmente **não existe no Maven Central**.
- Existe um diretório legado `com/jaspersoft/jasperreports/` no Artifactory da Jaspersoft
  (<https://jaspersoft.jfrog.io/artifactory/jr-ce-releases/com/jaspersoft/>), com *last modified* de
  **04/Mar/2015**. É resíduo de dez anos atrás, não destino de migração.
- O arquivo `LICENSE` do repositório é a **LGPL v3** literal; o arquivo
  `js-jrlib-ce_7.0.7_license.txt` (o "license bundle" da *Community Edition*) repete a LGPL v3 seguida dos
  *addenda* das dependências de terceiros — <https://github.com/Jaspersoft/jasperreports/blob/master/js-jrlib-ce_7.0.7_license.txt>

**Conclusão:** não há mudança de coordenada nem de licença a acomodar. A LGPL v3 permite uso como
biblioteca linkada sem contaminar o código da aplicação, que é exatamente o nosso caso (não vamos modificar
o Jasper). O que **de fato** mudou na 7.0.0 foi outra coisa (§3.3).

### 3.3 O que a 7.0.0 quebrou (isto sim importa)

Do `changes.txt` e do README (<https://github.com/Jaspersoft/jasperreports/blob/master/changes.txt>,
<https://github.com/Jaspersoft/jasperreports/blob/master/README.md>), JasperReports **7.0.0 (2024-06-17)**:

- trocou Ant por **Maven** como build;
- **quebrou deliberadamente** a compatibilidade retroativa dos `*.jasper` serializados/compilados;
- **quebrou o formato dos `*.jrxml` e `*.jrtx`**: os parsers baseados em Apache Commons Digester foram
  substituídos por serialização de objetos via **Jackson XML**. *"`*.jrxml` and `*.jrtx` files created with
  version 6 or older can no longer be loaded with version 7 or newer of the library alone."* A conversão
  exige **Jaspersoft Studio 7+**;
- extraiu artefatos opcionais do JAR core (migração Jakarta), com **renomeação de pacotes Java** como
  consequência — daí a necessidade de declarar explicitamente `jasperreports-fonts`,
  `jasperreports-chart-themes`, `jasperreports-data-adapters`, `jasperreports-pdf`, etc.;
- subiu JFreeChart para 1.5.4, que **não tem mais gráficos 3D** (Pie 3D / Bar 3D renderizam como 2D).

**Impacto direto no projeto:** os 10 JRXMLs versionados no repositório (regra arquitetural do
`descricao-inicial.md`) precisam nascer no formato 7.x. Qualquer JRXML herdado de um Jasper 6 exige conversão
manual pelo Studio 7 antes de entrar no repositório. Isso é uma tarefa de setup, não um risco recorrente.

### 3.4 Segurança: CVE-2026-6009 estabelece o piso mínimo

`changes.txt` para 7.0.7: *"add deserialization class filter to fix the CVE-2026-6009 security vulnerability"*
e *"introduce URL whitelist filter for controlling repository resources access"*.

Dados da NVD (<https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=CVE-2026-6009>):

> *"Java Deserialisation Vulnerability in Jaspersoft Reports Library leads to Remote Code Execution (RCE),
> potentially allowing code execution on the affected system"*
> Publicado 2026-05-19. Produto **JasperReports Library Community Edition**, versões **≤ 7.0.6 afetadas**.

Isso é decisivo, porque o coração do projeto é **desserializar `.jrprint`** vindo do MinIO. O trade-off aceito
("o arquivo vem do módulo que está dentro do projeto, logo é confiável desserializar") assume que o MinIO nunca
serve um objeto de outra origem — e o CVE mostra o custo caso essa premissa falhe.

Implementação do filtro (código-fonte, útil para o ticket 18):

- `JRLoader` desserializa via `ContextClassLoaderObjectInputStream`, que agora estende
  `FilteredObjectInputStream` e recebe um `DeserializationClassFilter` —
  [`ContextClassLoaderObjectInputStream.java`](https://github.com/Jaspersoft/jasperreports/blob/master/core/src/main/java/net/sf/jasperreports/engine/util/ContextClassLoaderObjectInputStream.java)
- Propriedades de controle, em
  [`DeserializationClassFilter.java`](https://github.com/Jaspersoft/jasperreports/blob/master/core/src/main/java/net/sf/jasperreports/engine/util/DeserializationClassFilter.java):
  - `net.sf.jasperreports.deserialization.class.filter.enabled` — `defaultValue = "true"`, escopo `CONTEXT`;
  - `net.sf.jasperreports.deserialization.class.whitelist.{arbitrary_name}` — prefixo para liberar classes.
- **Atenção operacional:** o filtro vem **ligado por padrão**. Os renderers de barcode
  (`BarbecueRendererImpl` e afins), que o `descricao-inicial.md` diz que "viram renderers serializados", podem
  precisar de entrada explícita na whitelist. Isso tem que virar teste de aceitação, não descoberta em produção.

Bônus relevante para o trade-off de fontes: o mesmo `ContextClassLoaderObjectInputStream` sobrescreve
`resolveObject` para trocar toda `java.awt.Font` desserializada pela fonte resolvida nas *font extensions*
(`FontUtil.resolveDeserializedFont`). Ou seja, o comportamento de substituição de fonte descrito no
`descricao-inicial.md` está codificado exatamente nesse ponto — é ali que o teste do ticket 33 deve mirar.

### 3.5 O trade-off do `serialVersionUID` — está certo pelo motivo errado

O `descricao-inicial.md` registra: *"Serialização Java nativa não quebra entre versões do JasperReports
(`serialVersionUID`) porque todos os módulos usarão a mesma versão do Jasper."*

O código diz o seguinte:

- `JasperPrint implements Serializable` com
  `private static final long serialVersionUID = JRConstants.SERIAL_VERSION_UID;` —
  [`JasperPrint.java`](https://github.com/Jaspersoft/jasperreports/blob/master/core/src/main/java/net/sf/jasperreports/engine/JasperPrint.java)
- E `JRConstants.SERIAL_VERSION_UID` é uma **constante fixa**:
  `public static final long SERIAL_VERSION_UID = 10200;` —
  [`JRConstants.java`](https://github.com/Jaspersoft/jasperreports/blob/master/core/src/main/java/net/sf/jasperreports/engine/JRConstants.java)

Esse `10200` está congelado há anos e vale para **todas** as classes serializáveis da biblioteca. Consequência
contraintuitiva e importante:

> O `serialVersionUID` **não protege nada**. Como ele nunca muda, a JVM **não vai** lançar
> `InvalidClassException` ao ler um `.jrprint` gravado por outra versão do Jasper. Ela vai tentar ler, e o que
> quebra é a **estrutura** (campos removidos, classes renomeadas pela extração de artefatos da 7.0.0) — com
> falha silenciosa, campo nulo ou `ClassNotFoundException` em vez de um erro claro de versão.

Isto **reforça** o trade-off aceito, mas muda a conclusão de "otimização conveniente" para **invariante
obrigatório**, e adiciona duas exigências:

1. A versão do Jasper tem que ser gerenciada em **um único lugar** (propriedade + `dependencyManagement` no
   POM raiz), com `maven-enforcer-plugin` (`requireUpperBoundDeps` / `banDuplicatePomDependencyVersions`)
   garantindo que nenhum módulo a sobrescreva. Sem isso, o "todos usam a mesma versão" é uma promessa verbal.
2. O `.jrprint` deve vir acompanhado da **versão do Jasper que o gerou**, gravada nos metadados de
   processamento (schema de controle, ticket 04). Como o `serialVersionUID` não detecta a divergência, a
   detecção precisa ser explícita e nossa: ao exportar, comparar a versão registrada com a versão em runtime e
   falhar com erro de negócio claro em vez de produzir um PDF corrompido.

---

## 4. Maven multi-módulo

### 4.1 Versão do Maven: 3.9.16, não 4

A página oficial de download (<https://maven.apache.org/download.cgi>) apresenta **3.9.16** como release
estável recomendada (requer JDK 8+), e **4.0.0-rc-5** ainda como *release candidate*, explicitamente não
indicada para produção. O `maven-metadata.xml` de `org.apache.maven:maven-core` confirma
`<release>4.0.0-rc-5</release>` e `3.9.16` como último 3.9.x
(<https://repo1.maven.org/maven2/org/apache/maven/maven-core/maven-metadata.xml>, `lastUpdated=20260713085952`).

O ambiente já tem 3.9.16 — nada a fazer. Spring Boot 4.1 pede apenas 3.6.3+.

### 4.2 Maven Wrapper (`mvnw`)

Fonte: <https://maven.apache.org/wrapper/>

> *"The Maven Wrapper is an easy way to ensure a user of your Maven build has everything necessary to run your
> Maven build."*

- Gerado por `mvn wrapper:wrapper` (opcionalmente `-Dmaven=3.9.16`), plugin
  `org.apache.maven.plugins:maven-wrapper-plugin`, última versão **3.3.4**
  (<https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-wrapper-plugin/maven-metadata.xml>).
- Três tipos de distribuição: **`only-script`** (padrão, nenhum binário no repositório), `bin`
  (adiciona `.mvn/wrapper/maven-wrapper.jar`) e `source` (adiciona `MavenWrapperDownloader.java`).
- Recomendação: **`only-script`** — evita commitar JAR, e o `.mvn/wrapper/maven-wrapper.properties` fixa a
  versão do Maven para todo mundo (dev, CI, container de build).

### 4.3 Reactor e ordem de build

Fonte: <https://maven.apache.org/guides/mini/guide-multiple-modules.html>

> *"The mechanism in Maven that handles multi-module projects is referred to as the reactor. This part of the
> Maven core does the following: collects all the available modules to build; sorts the projects into the
> correct build order; builds the selected projects in order."*

A ordenação honra, nesta prioridade: (1) dependências entre projetos do reactor, (2) declaração de plugin que
seja outro módulo, (3) dependência de plugin, (4) *build extension*, (5) ordem no elemento `<modules>` quando
nenhuma outra regra se aplica.

> **Ressalva crítica:** *"only 'instantiated' references are used — `dependencyManagement` and
> `pluginManagement` elements do not cause a change to the reactor sort order."*

Tradução prática para este projeto: colocar `jasperreports` no `dependencyManagement` do POM raiz **não** cria
aresta de ordenação; a ordem correta emerge sozinha das dependências reais
(`api` → `starter-processador` → `biblioteca-comum`, e cada processador → `starter-processador`).

### 4.4 Versão única para o monorepo (`${revision}`)

Requisito do `descricao-inicial.md`: *"O código fonte será armazenado em um mono repositório com versão única
no GitHub."* O mecanismo canônico é o **CI-Friendly Versions**
(<https://maven.apache.org/maven-ci-friendly.html>):

> *"Starting with Maven 3.5.0-beta-1 you can use the `${revision}`, `${sha1}` and/or `${changelist}` as
> placeholders for the version in your pom file."*

Regras que a documentação impõe:

- **Só** essas três propriedades funcionam; qualquer outro nome *"will not work as expected"*.
- Para instalar/deployar no Maven 3 é **obrigatório** o
  [Flatten Maven Plugin](https://www.mojohaus.org/flatten-maven-plugin/) com
  `flattenMode=resolveCiFriendliesOnly`: *"Otherwise, you will install/deploy artifacts in the repository which
  will not be consumable by Maven."*
- Ao referenciar módulos irmãos, usar **`${project.version}`**, nunca `${revision}`:
  *"If you try to use `${revision}` instead of `${project.version}` your build will fail."*
- No Maven 4 (modelo 4.1.0) o flatten deixa de ser necessário — motivo para revisitar quando o 4 sair de RC.

Precedente de peso: o **próprio JasperReports** usa `${revision}` em seus POMs de sample
(<https://github.com/Jaspersoft/jasperreports/blob/7.0.7/demo/samples/springboot/pom.xml>).

### 4.5 Parent vs BOM importado

Duas formas suportadas oficialmente (<https://docs.spring.io/spring-boot/maven-plugin/using.html>):

| Opção | Como | Ganha | Perde |
|---|---|---|---|
| **A** — herdar de `spring-boot-starter-parent` | POM raiz do monorepo tem `<parent>spring-boot-starter-parent</parent>` | *dependency management* **e** *plugin management* (versões de Surefire, Compiler, etc. já resolvidas), `repackage` pré-configurado, filtro de recursos | o POM raiz "gasta" seu único `<parent>`; nosso POM raiz deixa de poder herdar de outro |
| **B** — importar `spring-boot-dependencies` | `<dependencyManagement>` com `<scope>import</scope>` | POM raiz livre; controle total do `pluginManagement` | *"you can still keep the benefit of the dependency management (**but not the plugin management**)"* — versões de todos os plugins passam a ser nossa responsabilidade |

**Critério de decisão:** a opção A só é ruim quando o POM raiz já precisa herdar de um parent corporativo.
Não é o caso aqui — é um monorepo autocontido. A herança dá de graça o `pluginManagement` (que, sem ela,
vira ~10 versões de plugin para manter à mão) e mantém o alinhamento com as versões que o Spring Boot testa.
**Opção A**, com `<dependencyManagement>` próprio no raiz para o que o Boot não gerencia (JasperReports e
seus artefatos opcionais, MinIO SDK, Cucumber).

Detalhe operacional: o módulo `api` é uma aplicação Boot cujas classes serão consumidas por testes de outros
módulos? Se sim, a documentação manda usar
`<classifier>exec</classifier>` no `spring-boot-maven-plugin` para que o JAR executável não substitua o JAR
de biblioteca — <https://github.com/spring-projects/spring-boot/blob/main/documentation/spring-boot-docs/src/docs/antora/modules/how-to/pages/build.adoc>

### 4.6 Layout de diretórios proposto

```
scheduler-jasper-report/
├── .mvn/wrapper/maven-wrapper.properties   # fixa Maven 3.9.16
├── mvnw, mvnw.cmd                          # type=only-script
├── pom.xml                    # packaging=pom, parent=spring-boot-starter-parent,
│                              # <version>${revision}</version>, flatten-maven-plugin,
│                              # dependencyManagement do que o Boot não cobre, enforcer
├── biblioteca-comum/          # jar — DTOs, erro padronizado, Correlation ID, MDC
├── starter-processador/       # jar — auto-configuração Spring Batch 6 + contrato de Coleta
├── api-rest/                  # jar Boot — porta 8080, actuator, SpringDoc, exportadores Jasper
├── processadores/             # packaging=pom (agregador intermediário)
│   ├── poupanca/  cliente/  conta-corrente/  consorcio/  emprestimo/
├── frontend/                  # jar/pom — Angular via frontend-maven-plugin (§6)
└── cobertura/                 # jar vazio — só jacoco:report-aggregate + jacoco:check (§5)
```

Justificativas: o agregador `processadores/` mantém o `<modules>` do raiz legível quando os 5 produtos
crescerem; `cobertura/` é obrigatório pelo modo de funcionamento do `report-aggregate` (§5.2); a ordem do
reactor sai das dependências reais, sem precisar de ajuste manual (§4.3).

---

## 5. JaCoCo

### 5.1 Versão

Última release: **0.8.15**, de **2026-06-04** (tag `v0.8.15` publicada em 2026-06-05);
`maven-metadata.xml` de `org.jacoco:jacoco-maven-plugin` confirma 0.8.15 como último
(<https://repo1.maven.org/maven2/org/jacoco/jacoco-maven-plugin/maven-metadata.xml>,
`lastUpdated=20260605202919`; <https://api.github.com/repos/jacoco/jacoco/releases>).

Suporte a Java, do changelog oficial (<https://www.jacoco.org/jacoco/trunk/doc/changes.html>):

- **0.8.14** (2025-10-11): *"official support for Java 25 and experimental support for Java 26 class files"*.
- **0.8.15** (2026-06-04): *"officially supports Java 26 and experimentally supports Java 27"*.

FAQ (<https://www.jacoco.org/jacoco/trunk/doc/faq.html>): *"JaCoCo officially supports Java class files from
version 1.0 to 26, with experimental support for versions 27 and 28."*

→ Com `release 25`, **0.8.15** é a escolha; 0.8.14 seria o mínimo absoluto.

### 5.2 Agregação em multi-módulo

Fonte: <https://www.jacoco.org/jacoco/trunk/doc/report-aggregate-mojo.html>

> *"The `report-aggregate` goal generates a comprehensive code coverage report in HTML, XML, and CSV formats by
> aggregating data from multiple projects within a Maven reactor. It collects class and source files, along
> with JaCoCo execution data, from **dependent projects** and optionally the current project."*

O ponto que costuma morder: o goal agrega a partir das **dependências declaradas do módulo onde ele roda**.
Não existe "agrega o reactor inteiro" automático. Por isso o módulo `cobertura/` do §4.6: um JAR sem código
que declara como `<dependency>` todos os módulos que devem entrar no relatório, e é o último do reactor.

Cuidado adicional ao usar o `maven-site-plugin`: a documentação recomenda configurar `<reportSets>` com
`<report>report</report>` para não gerar relatórios agregados redundantes —
<https://www.jacoco.org/jacoco/trunk/doc/maven.html>.

### 5.3 Gates

Fonte: <https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html>

- `jacoco:check` — *"Checks that the code coverage metrics are being met"*; **liga por padrão à fase `verify`**;
  é *thread-safe* (funciona com `-T`).
- `haltOnFailure` (default `true`, propriedade `jacoco.haltOnFailure`).
- `rules` → `element` ∈ {BUNDLE, PACKAGE, CLASS, SOURCEFILE, METHOD}; `counter` ∈ {INSTRUCTION, LINE, BRANCH,
  COMPLEXITY, METHOD, CLASS}; `value` ∈ {TOTALCOUNT, COVEREDCOUNT, MISSEDCOUNT, COVEREDRATIO, MISSEDRATIO}.
  Defaults: `BUNDLE` / `INSTRUCTION` / `COVEREDRATIO`. Ratios aceitam `0.80` ou `80%`.
- Suporta `<excludes>` por regra (ex.: `*Test`).

Desenho sugerido de gate (a calibragem fina é do ticket 30, não deste):

- `jacoco:check` **por módulo** com um piso baixo e uniforme, só para impedir módulo sem teste nenhum;
- `jacoco:check` **no módulo `cobertura/`** com o gate real do projeto, sobre o relatório agregado;
- excluir do denominador o que é gerado/config (`**/config/**`, classes de `@ConfigurationProperties`, DTOs
  puros) via `<excludes>` — senão o número mede boilerplate, não comportamento.

---

## 6. Como o frontend Angular convive com o reactor

### 6.1 Versões atuais

- **Angular 22.1.x** é a corrente (`@angular/core` `dist-tags.latest = 22.1.0`, `@angular/cli` 22.1.2 —
  <https://registry.npmjs.org/@angular/core>, <https://registry.npmjs.org/@angular/cli>).
- Política de suporte (<https://angular.dev/reference/releases>): **major a cada 12 meses** a partir da v22
  (era 6 meses até a v21), 12 meses de *active support* + 12 meses de LTS = 24 meses por major.

| Angular | Status | Lançamento | Fim do *active* | Fim do LTS |
|---|---|---|---|---|
| **22.x** | Active | 2026-06-03 | 2027-06 | 2028-06 |
| 21.x | LTS | 2025-11-19 | 2026-06-03 | 2027-06 |
| 20.x | LTS | 2025-05-28 | 2025-11-19 | 2026-11-28 |

Compatibilidade (<https://angular.dev/reference/versions>, confirmada pelo `engines` no registry):

| Angular | Node.js | TypeScript |
|---|---|---|
| 22.0/22.1 | `^22.22.3 \|\| ^24.15.0 \|\| >=26.0.0` | `>=6.0.0 <6.1.0` |
| 21.x | `^20.19.0 \|\| ^22.12.0 \|\| >=24.0.0` | `>=5.9.0 <6.0.0` |

**O ambiente atende Angular 22 — mas com folga estreita:** Node 24.16.0 ≥ 24.15.0 (margem de um patch) e
TypeScript 6.0.3 ∈ [6.0.0, 6.1.0). Isso é argumento a favor de *pinar* a versão do Node no build em vez de
depender do Node da máquina (§6.2).

Ciclo de vida do Node 24 (<https://github.com/nodejs/Release/blob/main/schedule.json>): LTS desde 2025-10-28,
entra em *maintenance* em **2026-10-20** e termina em **2028-04-30**. Node 26 vira LTS em 2026-10-28.
Node 24 cobre bem o horizonte do projeto; a migração para 26 é uma tarefa de out/2026 em diante.

### 6.2 As três opções

**Opção A — `frontend-maven-plugin` dentro do reactor.**

- Última versão **2.0.2**, publicada em **2026-07-28**
  (<https://repo1.maven.org/maven2/com/github/eirslett/frontend-maven-plugin/maven-metadata.xml>).
- Requisitos declarados no README: *"Maven 3.6 and Java 17"* e *"Maven 4 seems to work fine with this plugin"*
  — <https://github.com/eirslett/frontend-maven-plugin/blob/master/README.md>
- O que faz: *"downloads/installs Node and NPM locally for your project"*, garantindo *"that the version of
  Node and NPM being run is the same in every build environment"* — exatamente o que resolve a folga estreita
  do §6.1. Configura-se `<nodeVersion>v24.16.0</nodeVersion>` no POM e a versão do Node deixa de depender da
  máquina.
- **ARM64 funciona**: o `Platform.java` do plugin mapeia `os.arch == "aarch64"` → `Architecture.arm64` e
  monta o classifier `linux-arm64` para baixar a distribuição correta de nodejs.org —
  [`Platform.java`](https://github.com/eirslett/frontend-maven-plugin/blob/master/frontend-plugin-core/src/main/java/com/github/eirslett/maven/plugins/frontend/lib/Platform.java)
- Aviso do próprio README: *"This plugin does not support already installed Node or npm versions. Use the
  `exec-maven-plugin` instead."* — ele **sempre** baixa. Isso é feature (hermeticidade), não bug, mas custa
  download na primeira build e exige cache de `~/.m2` + `node/` no CI.
- Recomendação do README: *"Try to run all your tasks via npm scripts instead of running bower, grunt, gulp
  etc. directly."* → declarar `npm run build`, `npm run test:ci` no `package.json` e chamar só `npm run` pelo
  plugin.

**Opção B — build separado no CI.** O Angular vira um job próprio do GitHub Actions e uma imagem Nginx/Traefik
independente. Mais rápido e desacoplado, mas **quebra o requisito da fase inicial "Módulos compilando"**, que
só faz sentido como "um comando compila tudo", e abre espaço para o frontend divergir da versão única do
monorepo.

**Opção C — workspace independente (Nx/pnpm) fora do reactor.** Só se paga quando há vários pacotes JS
compartilhando código. Aqui há **um** app Angular. Complexidade sem contrapartida.

### 6.3 Critério de decisão

| Se… | Então |
|---|---|
| a build precisa ser reproduzível por um dev backend sem Node instalado, e `./mvnw clean install` na raiz tem que produzir tudo | **A** |
| o tempo de CI do backend for dominado pelo frontend e as equipes forem separadas | **B** |
| aparecerem 2+ pacotes JS com código compartilhado | **C** |

Para este projeto o requisito da fase inicial decide: **A**, com um profile `-P skip-frontend` (via
`<skip>true</skip>` no plugin) para o loop rápido de quem só mexe no backend. Se em algum momento o tempo de
build virar problema, migrar A→B é barato (o `package.json` e os scripts npm não mudam).

---

## Recomendação

| Item | Escolha | Motivo em uma linha |
|---|---|---|
| **JDK** | **Temurin 25 (LTS)**, `maven.compiler.release=25` | LTS corrente, binários até "at least Sep 2031", já instalado; app fechada com imagem própria não tem motivo para travar em 17 |
| **Imagem de runtime** | `eclipse-temurin:25-jre` (ou `-noble`) | manifesto `linux/arm64` publicado |
| **Spring Boot** | **4.1.x** | única geração com suporte OSS real (até 2027-07-31); 3.5.x já expirou em 2026-06-30 e 4.0.x expira em 2026-12-31 |
| **Spring Framework** | 7.0.8+ | exigido pelo Boot 4.1.0 |
| **Spring Batch** | **6.0.x** (não 5.x) | é a geração ligada ao Boot 4.x; 5.2.x saiu do OSS em 2026-06-30 |
| **JasperReports** | **7.0.7** (`net.sf.jasperreports`, LGPL v3) | 7.0.6 e anteriores têm o RCE de desserialização CVE-2026-6009 — e desserializar `.jrprint` é o coração do sistema |
| **Maven** | **3.9.16** + `mvnw` (`type=only-script`) | 4.0.0 ainda é RC; wrapper fixa a versão sem commitar binário |
| **Versão única** | `${revision}` + `flatten-maven-plugin` (`resolveCiFriendliesOnly`) | mecanismo oficial; obrigatório no Maven 3 para install/deploy consumível |
| **Parent** | POM raiz herda de `spring-boot-starter-parent` | traz `pluginManagement` junto; o import de BOM traria só o dependency management |
| **JaCoCo** | **0.8.15**, módulo `cobertura/` com `report-aggregate` + `check` | 0.8.15 cobre Java 26 oficialmente; `report-aggregate` agrega a partir das dependências do módulo onde roda |
| **Frontend** | `frontend-maven-plugin` **2.0.2** no reactor, `nodeVersion` fixado em v24.16.0, Angular **22.1.x** + TypeScript 6.0.x | preserva "um comando compila tudo" da fase inicial e blinda contra a margem estreita Node 24.15 ↔ 24.16 |

### Correções que o ticket precisa absorver

1. **Não há migração `net.sf.jasperreports` → `com.jaspersoft`.** O groupId `com.jaspersoft` não existe no
   Maven Central (404) e a licença continua LGPL v3. O que mudou na 7.0.0 foi a extração de artefatos opcionais
   (com renomeação de pacotes) e a quebra de formato de `.jasper`/`.jrxml`/`.jrtx`.
2. **É Spring Batch 6.x, não 5.x.** Isso muda a API do Starter do Processador (ticket 21):
   `@EnableJdbcJobRepository`, `JdbcDefaultBatchConfiguration` e o novo `ChunkOrientedStepBuilder`.

### Duas ações que esta pesquisa cria para outros tickets

- **Ticket 18 (desserialização segura):** o filtro `net.sf.jasperreports.deserialization.class.filter.enabled`
  já vem **ligado** na 7.0.7. Os renderers de barcode serializados vão precisar de entrada explícita em
  `net.sf.jasperreports.deserialization.class.whitelist.{nome}`. Isso tem que virar cenário Gherkin, não
  descoberta em produção.
- **Ticket 04 (schema de controle) + trade-off do `serialVersionUID`:** `JRConstants.SERIAL_VERSION_UID` é a
  constante fixa `10200` para **todas** as versões. O `serialVersionUID` **não** detecta divergência de versão
  — a leitura cruzada falha de forma silenciosa ou obscura, não com `InvalidClassException`. Logo: (a) fixar a
  versão do Jasper só no POM raiz e defender isso com `maven-enforcer-plugin`; (b) gravar a versão do Jasper
  nos metadados de cada `.jrprint` e validá-la na exportação.
