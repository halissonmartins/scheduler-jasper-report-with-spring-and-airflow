# SP-3 — Fundações do repositório (E1)

> Spec do terceiro sub-projeto. Entrega o mono repositório Maven, o ferramental de qualidade,
> o ambiente local, o CI bloqueante e os documentos de referência. Fecha a fase E1 do
> [`guias/guia-app-web.md`](../../guias/guia-app-web.md), descrita nele como **a fase mais
> importante do eixo de engenharia**.
>
> Data: 2026-08-12 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

O repositório tem dez arquivos, todos documentação, e **nenhuma linha de código**. SP-1 fixou a
linguagem e as histórias; SP-2 fixou as decisões, os riscos e os nomes dos módulos em `RA-69`.
SP-3 constrói os trilhos.

O checkpoint da fase é o do guia: *"clone limpo em máquina nova roda com um comando e o CI está
verde. Só então comece features."*

### 1.1 Pré-condição resolvida durante o desenho

`RA-50` declara *"~20 GB livres em disco"*, e é essa premissa que sustenta os limites do PRD §10.
A máquina tinha **9 GB livres** quando esta spec começou — 36 GB de 45 ocupados, quase tudo em
imagens Docker ociosas (31 imagens, nenhuma em uso; 66 volumes anônimos, nenhum montado).

Foi feita a limpeza, com autorização explícita: `docker image prune -a`, `builder prune`,
`volume prune` e a remoção de dois diretórios de review em `/tmp`. Resultado: **29 GB livres**,
acima do que `RA-50` pressupõe. O registro do que foi removido ficou no scratchpad da sessão.

Isso não é anedota de operação: a pilha de `RA-51` consome ~9,5 GB só em imagens, e sem a limpeza
SP-3 não caberia na máquina.

---

## 2. Objetivo

Entregar as fundações de modo que:

- um clone limpo rode com um comando, sem etapa manual;
- o CI reprove PR que quebre formato, build, segredo ou a duplicação controlada dos `CLAUDE.md`;
- SP-6a, SP-6b e SP-7 encontrem estrutura, convenção e ambiente prontos, sem inventar nenhum dos
  três.

---

## 3. Entregas

### 3.1 Mono repositório Maven — 8 módulos, não 10

`RA-69` nomeia dez diretórios, mas `frontend/` é npm e `orquestrador/` é Python: **nenhum dos dois
entra no reactor**. O `pom` raiz lista oito.

```
scheduler-jasper-report/          packaging pom · groupId br.com.scheduler
├── comum/                        jar
├── processador-starter/          jar
├── processador-poupanca/         jar
├── processador-cliente/          jar
├── processador-contacorrente/    jar
├── processador-consorcio/        jar
├── processador-emprestimo/       jar
├── api/                          jar
├── frontend/                     npm — fora do reactor
└── orquestrador/                 Python — fora do reactor
```

É o `Makefile`, e não o Maven, que amarra `frontend/` e `orquestrador/` ao build.

**Versões, em propriedade única no `pom` raiz:**

| Item | Valor | Origem |
|---|---|---|
| Java `release` | **25** | JDK do ambiente. Spring Boot 4.1 cobre 17–26 |
| Spring Boot | **4.1.0** | via `dependencyManagement`, importando o BOM |
| JasperReports | última estável, em `<jasperreports.version>` | **propriedade única** |
| Maven | 3.9.16 | ambiente; Spring Boot 4.1 exige 3.6.3+ |

A compatibilidade Java 25 ↔ Spring Boot 4.1 foi verificada na documentação oficial, não presumida:
*"requires at least Java 17 and is compatible with versions up to and including Java 26"*.

**BOM importado, não `spring-boot-starter-parent` herdado.** Com oito módulos de três naturezas
(biblioteca, starter Batch, aplicação web), o `parent` imporia plugins a módulos que não os querem
— `comum` não é aplicação Spring Boot e não deve receber o plugin de repackage. O BOM dá
gerenciamento de versão sem herança de build.

**A versão do JasperReports mora num só lugar, e isso não é estilo.** `R-01` a `R-04` do
`riscos.md` têm `RA-01` como premissa declarada: a serialização do `.jrprint` só é segura porque
todos os módulos usam a mesma versão. Uma segunda declaração em qualquer `pom` filho quebra a
premissa silenciosamente, e o sintoma apareceria como `InvalidClassException` na exportação, dias
depois.

### 3.2 Arquitetura interna dos módulos — resolve `R-12`

Pacotes **por camada**, com nomes em **pt-BR**, pela regra de fronteira do glossário: camada de
domínio é conceito do negócio.

```
api/src/main/java/br/com/scheduler/api/
├── dominio/           regras puras — não importa Spring, JDBC nem HTTP
├── aplicacao/         casos de uso
├── infraestrutura/
│   ├── repositorio/   único lugar que toca banco
│   └── artefato/      acesso ao repositório S3
└── web/               rotas e validação de entrada — sem regra de negócio
```

Adaptada à natureza de cada módulo: `comum` é biblioteca e não tem `web/`; os processadores
organizam-se em torno do Spring Batch.

**Alternativa rejeitada:** organização por funcionalidade (*vertical slice*). Mantém junto o que
muda junto, mas faria o invariante *"a API não lê schema transacional"* deixar de ser visível na
estrutura, voltando a depender de disciplina.

### 3.3 Qualidade

| Ferramenta | Papel |
|---|---|
| `.editorconfig` | Indentação e fim de linha |
| **Spotless** + `palantir-java-format` | Formatação Java, verificada no CI. Palantir por usar 4 espaços e 120 colunas — melhor que os 2 espaços do google-java-format para os nomes longos em pt-BR que o glossário impõe |
| `-Xlint:all,-serial,-processing -Werror` | Warning vira erro. As exclusões são deliberadas: `serial` geraria ruído constante nas classes serializáveis do Jasper; `processing` vem dos annotation processors do Spring |
| **gitleaks** | Scanner de segredos, no hook e no CI |
| `tsconfig.json` com `strict: true` | Tipagem estrita no frontend |

**Sem Checkstyle nem PMD.** Spotless resolve formatação e `-Werror` resolve correção. Mais um
analisador antes de existir código é regra que alguém desabilita no primeiro PR apertado — o que o
`CLAUDE.md` proíbe.

**Pre-commit sem dependência nova:** hooks versionados em `.githooks/`, ativados por
`git config core.hooksPath .githooks` dentro do `make setup`. As alternativas usuais — o framework
`pre-commit` (Python) ou `husky` (Node) — obrigariam todo desenvolvedor de backend a instalar o
runtime do outro ecossistema só para commitar.

### 3.4 Ambiente local

**A pilha de `RA-51` são 15 contêineres, não 11:** Graylog arrasta MongoDB e OpenSearch, e o
Airflow são dois processos.

| Perfil | Contêineres | Imagens |
|---|---|---|
| *(padrão)* | postgres · keycloak · minio · mailpit · traefik | ~1,6 GB |
| `orquestracao` | airflow-scheduler · airflow-apiserver | ~2,1 GB |
| `observabilidade` | otel-collector · graylog · mongodb · opensearch · prometheus · grafana · jaeger | ~5,7 GB |

Total: **~9,5 GB** sobre os 29 GB livres.

**Por que perfis:** `RA-39` já determina que o SDK do OpenTelemetry é desabilitado nos testes — o
próprio projeto declara que a observabilidade não participa do ciclo comum de desenvolvimento.
Subir OpenSearch (1,9 GB de imagem, ~2 GB de heap) para escrever um repositório JPA gasta metade
dos 4 vCPUs em algo que ninguém vai olhar, e contenção de CPU é exatamente o que `RA-55` diz que
transforma `processado com alerta` em ruído de ambiente.

**Versões, todas já exercitadas nesta máquina** (extraídas do registro de imagens antes da
limpeza): `postgres:18-alpine`, `keycloak:26.4.1`, `minio:RELEASE.2025-07-23T15-54-02Z`,
`mailpit:v1.23.2`, `traefik:v3.3.4`, `otel-collector-contrib:0.130.0`, `graylog:6.3.6`,
`mongo:8.0.4`, `opensearch:2.18.0`, `prometheus:v3.1.0`, `grafana:11.4.0`, `jaeger:2.2.0`.

**Airflow na linha 3.x.** A tentativa anterior do projeto usou 2.10.5. A escolha pela 3.x é
deliberada: é a linha atual, e `RA-56` já neutraliza a única diferença que a arquitetura menciona
— o padrão de `catchup`, declarado explicitamente de qualquer modo.

**Um PostgreSQL, seis schemas.** `RA-23` pede controle mais cinco transacionais, e não seis
instâncias. O invariante é de **acesso**, não de topologia: um contêiner com seis schemas o
preserva e economiza ~2 GB de RAM.

**`.env.example`** com todas as variáveis e nenhum segredo real: credenciais de postgres, MinIO e
Keycloak; `KEYCLOAK_ADMIN_PASSWORD` (`RA-32`); `RETENCAO_DIAS=7` (`RNF-12`, a única de fato
configurável); e as portas expostas.

### 3.5 `Makefile` e CI

`Makefile` com os alvos do guia — `setup`, `dev`, `test`, `lint`, `build`, `migrate` — mais três
que a decomposição em perfis exige: `dev-full`, `down` e `fmt`.

**CI bloqueante, cinco jobs paralelos:**

| Job | Roda | Falha quando |
|---|---|---|
| `formato` | `mvn spotless:check` | Código fora do formato |
| `build` | `mvn verify` | Compilação, warning-as-error ou teste |
| `segredos` | `gitleaks detect` | Segredo no diff |
| `frontend` | `npm ci && npm run lint && npm run build` | Lint ou build do Angular |
| `claude-md` | Compara o hash do bloco comum dos 5 `CLAUDE.md` de processador | As cópias divergiram |

**O CI não sobe contêiner algum.** Testcontainers chega em SP-7, quando houver o que integrar. Em
SP-3 o CI é rápido de propósito: um CI lento no primeiro dia é um CI que alguém vai querer pular.

### 3.6 Documentos

**`README.md` — três comandos:**

```bash
make setup    # valida ferramentas, copia .env.example → .env, ativa os hooks
make dev      # sobe o núcleo do Compose
make build    # mvn verify + build do frontend
```

**`ARCHITECTURE.md` esquelético:** visão geral, *bird's eye view*, code map por módulo com uma
coluna **"não faz"**, fronteiras e pontos de entrada. Algumas centenas de linhas — o guia alerta
que pedir isto a um agente produz 800 linhas descrevendo cada função, que envelhecem em uma semana.

Os **oito invariantes**, escritos como proibições:

1. `dominio/` não importa `infraestrutura/`, nem Spring, nem JDBC, nem HTTP.
2. Nenhum acesso a banco fora de `infraestrutura/repositorio/`.
3. Nenhuma classe em `web/` contém regra de negócio.
4. **A `api` não acessa schema transacional algum** (`RA-29`).
5. Cada processador lê exclusivamente o schema do seu produto (`RA-10`).
6. A versão do JasperReports é declarada uma única vez (`ADR-0002`).
7. Migration aplicada não se altera (`ADR-0003`).
8. `orquestrador/` não é módulo Maven e não entra no reactor.

**Os 11 `CLAUDE.md`** — raiz mais os dez de `RA-69`:

| Arquivo | Conteúdo próprio |
|---|---|
| raiz | Referências aos 7 documentos · stack · comandos · convenções · regras invioláveis · as 3 diretrizes comportamentais atuais, **preservadas** |
| `comum/` | O que pode e o que não pode entrar na biblioteca compartilhada |
| `processador-starter/` | Contrato do starter · chunk do Spring Batch · `queryTimeout` obrigatório em todo statement |
| 5 × `processador-*/` | Bloco comum entre marcadores `<!-- COMUM:INICIO -->` / `<!-- COMUM:FIM -->`, idêntico nos cinco · mais a seção do produto |
| `api/` | Spring Web · cadeia de permissão · semáforo · nunca schema transacional |
| `frontend/` | Angular · integra só com a API · design system chega em SP-5 |
| `orquestrador/` | Python · `catchup=False` explícito · não tem `pom.xml` |

O raiz **referencia** o `ARCHITECTURE.md` em vez de duplicá-lo.

**Por que 11 e não 1:** decisão desta sessão, com a consequência técnica declarada — Claude Code
não faz herança lateral, então `processador-starter/CLAUDE.md` **não** é lido ao editar
`processador-poupanca/`. Daí as cinco cópias, e daí o job `claude-md` no CI.

---

## 4. Método

Sete passos, nesta ordem — os documentos por último, porque descrevem o que passou a existir:

1. `pom` raiz e os 8 módulos, vazios, compilando.
2. Qualidade: `.editorconfig`, Spotless, flags do compilador, `.githooks/`, `gitleaks`.
3. Ambiente: `docker-compose.yml` com três perfis e `.env.example`.
4. `Makefile`.
5. CI com os cinco jobs.
6. `frontend/` e `orquestrador/` — esqueletos com o seu próprio ferramental.
7. `README.md`, `ARCHITECTURE.md` e os 11 `CLAUDE.md`.

**O passo 1 vem primeiro por causa de `R-16`** (§6): se JasperReports não fechar sobre Spring
Boot 4.1 e Java 25, é melhor descobrir no primeiro commit do que depois de montar CI, Compose e
onze documentos.

**Abordagem escolhida: esqueleto vazio.** Os módulos compilam e não contêm exemplo por camada. A
alternativa considerada — uma fatia fina atravessando as quatro camadas na `api`, mais os
invariantes como teste ArchUnit — foi rejeitada, e **a fatia de referência e o ArchUnit passam
para SP-7**. Isso alinha melhor com o guia, que pede a fatia vertical em E3 e não em E1. O custo
está registrado em §6.

---

## 5. Fronteiras

**Fora de escopo de SP-3:**

- Nenhuma feature de negócio.
- **Nenhuma migration real** — SP-6b. O alvo `make migrate` existe e roda o Flyway sobre um schema
  ainda vazio.
- Nenhum JRXML — SP-6a.
- **Nenhuma fatia de referência e nenhum teste ArchUnit** — SP-7, por decisão desta sessão.
- Nenhum teste com Testcontainers — SP-7.
- Design system e componentes canônicos — SP-5.

---

## 6. Riscos aceitos

- **Invariantes só em prosa até SP-7.** Consequência direta do esqueleto vazio. O guia avisa que
  documento sem implementação de referência não é seguido, e que invariante não escrito é
  invariante violado. Neste intervalo, ele depende de alguém ler o `ARCHITECTURE.md`. Dono: SP-7.
- **Cinco `CLAUDE.md` duplicados.** Mitigado pelo job `claude-md`, mas a duplicação existe e cresce
  a cada convenção nova de processador.
- **`-Werror` pode travar o build** por warning vindo de dependência nova, forçando ajuste da lista
  de exclusões. É o preço de tratar warning como erro, pago cedo de propósito.
- **A pilha completa ocupa ~9,5 GB dos 29 GB livres** — um terço do disco. O perfil padrão mantém o
  uso diário em ~1,6 GB.

### `R-16`, risco novo a acrescentar ao `riscos.md`

> **JasperReports sobre Spring Boot 4.1 e Java 25 é combinação não exercitada.**
>
> - **Natureza:** aberto · **Estado:** vigente
> - **Impacto:** o motor de renderização é a razão de existir do projeto. Se não fechar, a decisão
>   recai sobre `ADR-0001` e sobre a escolha pela linha 4.1. O Jasper carrega dependências antigas
>   (Apache POI, iText, Batik) e usa serialização Java intensamente — área que mudou entre versões
>   da JDK.
> - **Sinal de disparo:** falha de resolução de dependência no `mvn verify`, ou
>   `NoSuchMethodError` / `InaccessibleObjectException` na primeira chamada a `JasperFillManager`.
> - **Mitigação:** o passo 1 do método compila antes de qualquer outra entrega.
> - **Dono:** SP-3.

---

## 7. Critério de aceite

Dez afirmações. O checkpoint do guia é a primeira:

1. **Clone limpo, `make setup && make build`, sem etapa manual.**
2. `mvn verify` compila os 8 módulos com `-Werror`, sem warning.
3. `make dev` sobe o núcleo e os 5 contêineres ficam *healthy*.
4. `make dev-full` sobe os 15 e a máquina sustenta — **medido**, não presumido.
5. `mvn spotless:check` passa.
6. `gitleaks detect` não acusa nada.
7. Os 5 `CLAUDE.md` de processador têm bloco comum de hash idêntico.
8. O CI passa nos cinco jobs.
9. `.env` não está versionado, e **toda variável referenciada no Compose existe no `.env.example`**
   — conferível extraindo `${VAR}` do YAML.
10. `ARCHITECTURE.md` traz o code map dos 10 diretórios e os 8 invariantes.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-69` (nomes), `RA-51` (pilha), `RA-50` (máquina) |
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define E1 e o checkpoint da fase |
| [SP-1](./2026-08-09-sp1-linguagem-e-historias-design.md) | Decomposição; glossário que fixa a regra de idioma |
| [SP-2](./2026-08-10-sp2-decisoes-tecnicas-design.md) | `ADR-0002` (versão única), `ADR-0003` (migration), `R-12` |
