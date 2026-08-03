# 05 — Stack: build, runtime e layout do monorepo

Type: research
Status: resolved
Blocked by: —

## Question

Quais versões e qual layout de build sustentam o monorepo?

Levantar com fontes primárias (use context7) e recomendar:

- **Java**: qual LTS. O ambiente tem Temurin 25. Spring Boot e JasperReports suportam? Qual o baseline mínimo.
- **Spring Boot**: versão atual e sua janela de suporte; compatibilidade com Spring Batch 5.x e com a versão de Java escolhida.
- **JasperReports**: versão atual, mudanças de licença/artefato (a migração de `net.sf.jasperreports` para `com.jaspersoft`), e o que isso implica para o trade-off aceito de que `serialVersionUID` não quebra porque todos os módulos usam a mesma versão.
- **Maven multi-módulo**: layout de diretórios, BOM/parent, gestão de versão única para o monorepo, reactor e ordem de build. Maven wrapper (`mvnw`) é preferível a `mvn` direto.
- **JaCoCo**: versão, agregação de cobertura em multi-módulo, gates.
- Como o módulo frontend (Node/Angular) convive no mesmo reactor — plugin frontend-maven, build separado, ou workspace independente.

Registrar as descobertas em `docs/mapa/research/05-build-runtime-monorepo.md`.

## Answer

**Temurin 25 (LTS)** com `maven.compiler.release=25` e runtime `eclipse-temurin:25-jre` (tem manifesto arm64); o Temurin 25 tem binários "at least Sep 2031" e é o LTS corrente. **Spring Boot 4.1.x** é a única geração com suporte OSS vivo (até 2027-07-31) — a 3.5.x expirou em 2026-06-30 e a 4.0.x expira em 2026-12-31; ela exige Spring Framework 7.0.8+ e Maven 3.6.3+.

Duas premissas do ticket estavam erradas: (1) **não existe migração `net.sf.jasperreports` → `com.jaspersoft`** — esse groupId dá 404 no Maven Central e a licença segue LGPL v3; o que a 7.0.0 mudou foi a extração de artefatos opcionais (com renomeação de pacotes) e a quebra de formato de `.jasper`/`.jrxml`/`.jrtx`; (2) **é Spring Batch 6.x, não 5.x** — o que altera a API do Starter do Processador (`@EnableJdbcJobRepository`, `JdbcDefaultBatchConfiguration`, `ChunkOrientedStepBuilder`).

**JasperReports 7.0.7** é piso mínimo obrigatório: a 7.0.6 e anteriores têm o RCE de desserialização **CVE-2026-6009**, e desserializar `.jrprint` é o coração do sistema. O trade-off do `serialVersionUID` está certo pelo motivo errado: `JRConstants.SERIAL_VERSION_UID` é a constante fixa `10200` para todas as versões, então o UID **não** detecta divergência — leitura cruzada falha em silêncio. Daí: fixar a versão do Jasper só no POM raiz (com `maven-enforcer-plugin`) e gravar a versão que gerou cada `.jrprint` nos metadados.

Build: **Maven 3.9.16** (o 4.0.0 ainda é RC) + `mvnw` `type=only-script`; versão única via `${revision}` + `flatten-maven-plugin`; POM raiz herdando de `spring-boot-starter-parent` (traz `pluginManagement` junto). **JaCoCo 0.8.15** com módulo `cobertura/` dedicado ao `report-aggregate` + `check`. Frontend via **frontend-maven-plugin 2.0.2** no reactor com `nodeVersion` fixado (suporta arm64), **Angular 22.1.x** + TypeScript 6.0.x.

Detalhes, fontes primárias e critérios de decisão: [`../research/05-build-runtime-monorepo.md`](../research/05-build-runtime-monorepo.md).
