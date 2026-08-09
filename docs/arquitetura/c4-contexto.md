# C4 — Contexto e Contêineres

> Artefato E0 do [`guias/guia-app-web.md`](../guias/guia-app-web.md). Diagramas em Mermaid,
> versionados: são lidos e atualizados junto com o código.
>
> **Atualize quando um contêiner nascer, morrer ou trocar de responsabilidade** — não a cada
> feature. O detalhamento interno de cada contêiner pertence ao `ARCHITECTURE.md` (E1/E3);
> o *porquê* de cada escolha pertence aos [`adr/`](../adr/).

---

## Nível 1 — Contexto

Quem usa o sistema, e com que mundo ele fala.

```mermaid
flowchart TB
  REL(["<b>Relator</b><br/>Analista de área de negócio"])
  GER(["<b>Gerente</b><br/>Responsável por uma área"])
  ADM(["<b>Administrador</b><br/>Responsável pela plataforma"])

  SIS["<b>Scheduler Jasper Report</b><br/>Apura relatórios uma vez por dia<br/>e os entrega sob demanda em<br/>PDF, XLSX, DOCX ou CSV"]

  TRX[("<b>Bases transacionais dos produtos</b><br/>Poupança · Cliente · Conta Corrente<br/>Consórcio · Empréstimo")]
  SMTP["<b>Servidor de e-mail</b><br/>Mailpit no ambiente local"]

  REL -->|"lista e exporta os relatórios<br/>que sua permissão alcança"| SIS
  GER -->|"administra roles de relatório,<br/>grupos e vínculos"| SIS
  ADM -->|"edita o catálogo, refaz apurações<br/>e audita downloads"| SIS

  SIS -->|"lê numa única janela diária,<br/>nunca sob demanda"| TRX
  SIS -->|"recuperação de senha<br/>e verificação de e-mail"| SMTP

  classDef pessoa fill:#08427b,stroke:#052e56,color:#fff
  classDef sistema fill:#1168bd,stroke:#0b4884,color:#fff
  classDef externo fill:#999,stroke:#6b6b6b,color:#fff
  class REL,GER,ADM pessoa
  class SIS sistema
  class TRX,SMTP externo
```

**O que este nível afirma.** As bases transacionais são **externas** ao sistema: pertencem aos
produtos, e a única seta que chega nelas parte da Coleta. O Gerente não tem seta de exportação —
ele administra acesso e não consome relatório (RN-25).

---

## Nível 2 — Contêineres

O sistema tem duas metades que quase não se tocam: encontram-se apenas no **repositório de
artefatos** e no **schema de controle**. Por isso são dois diagramas, e não um.

### 2a — Coleta

Agendada, diária, 03h00 `America/Sao_Paulo`.

```mermaid
flowchart TB
  AF["<b>Orquestrador</b><br/>Apache Airflow<br/><i>DAG com task estática por produto</i>"]
  PROC["<b>Processador &lt;produto&gt;</b><br/>Spring Batch · ×5, pool de 2<br/><i>o módulo é o produto</i>"]
  CTL[("<b>Schema de controle</b><br/>PostgreSQL")]
  TRX[("<b>Schema transacional<br/>do produto</b><br/>PostgreSQL · ×5")]
  S3[("<b>Repositório de artefatos</b><br/>MinIO · padrão S3")]

  AF -->|"1· reserva uma Execução por<br/>relatório ativo, início nulo"| CTL
  AF -->|"2· dispara, 2 produtos por vez"| PROC
  PROC -->|"3· publica catálogo ao iniciar"| CTL
  PROC -->|"4· lê numa única janela"| TRX
  PROC -->|"5· grava .jrprint e .csv.gz"| S3
  PROC -->|"6· registra metadados<br/><i>depois do artefato</i>"| CTL
  AF -.->|"callback de falha: encerra como<br/>processado com erro o que ficou aberto"| CTL

  classDef cont fill:#438dd5,stroke:#2e6295,color:#fff
  classDef dado fill:#438dd5,stroke:#2e6295,color:#fff
  class AF,PROC cont
  class CTL,TRX,S3 dado
```

A numeração das setas é a cadeia de `RA-09`: nenhuma etapa é pulada e nenhuma inverte a ordem.
A ordem 5 → 6 é `RA-11` — o artefato é gravado **antes** dos metadados de conclusão, porque a
ordem inversa produziria uma execução em `processado com sucesso` sem artefato.

### 2b — Exportação

Sob demanda e síncrona.

```mermaid
flowchart TB
  USR(["<b>Relator · Gerente · Administrador</b>"])
  TRF["<b>Ingress</b><br/>Traefik"]
  FE["<b>Frontend</b><br/>Angular"]
  API["<b>API REST</b><br/>Spring Web · :8080"]
  KC["<b>Identidade</b><br/>Keycloak"]
  MAIL["<b>Mailpit</b>"]
  CTL[("<b>Schema de controle</b><br/>PostgreSQL")]
  S3[("<b>Repositório de artefatos</b><br/>MinIO")]

  USR --> TRF
  TRF --> FE
  TRF -->|"account console e<br/>página de registro, seletivamente"| KC
  FE -->|"JSON sobre HTTPS, com JWT"| API
  API -->|"valida JWT · gere client roles<br/>e grupos do cliente relatorios"| KC
  API -->|"status, permissão, catálogo,<br/>auditoria e downloads"| CTL
  API -->|"lê o artefato apurado"| S3
  S3 -.->|"webhook de expurgo<br/>s3:ObjectRemoved:Delete"| API
  KC -->|"recuperação de senha"| MAIL

  classDef pessoa fill:#08427b,stroke:#052e56,color:#fff
  classDef cont fill:#438dd5,stroke:#2e6295,color:#fff
  class USR pessoa
  class TRF,FE,API,KC,MAIL,CTL,S3 cont
```

**O invariante mais importante do projeto aparece aqui como uma ausência:** não existe seta —
nem caixa — ligando a API a schema transacional algum. Qualquer dependência da API para um
schema transacional é um defeito, não uma variação de desenho (`RA-29`, RN-31).

---

## Telemetria

Não tem diagrama próprio de propósito: a pilha não participa de fluxo de negócio algum, e
desenhá-la ao lado dos contêineres faria dez setas decorativas competirem com as que importam.

Todo contêiner aplicacional — API, os cinco processadores e o orquestrador — emite **log, span,
trace e métrica** para o **OTel Collector**, que distribui para **Graylog** (logs),
**Prometheus/Grafana** (métricas) e **Jaeger** (traces). O `traceId` do OpenTelemetry é o
Correlation ID exibido ao usuário (`RA-37`).

---

## Contêineres, em uma tabela

| Contêiner | Tecnologia | Responsabilidade | Não faz |
|---|---|---|---|
| Frontend | Angular | Interface do usuário final | Não acessa banco, repositório ou orquestrador |
| API REST | Spring Web, `:8080` | Único módulo que atende o usuário; exporta e autoriza | Nunca lê schema transacional |
| Processador `<produto>` | Spring Batch | Apura os relatórios de um produto numa única janela | Não lê o schema de outro produto |
| Orquestrador | Apache Airflow | Reserva o ciclo, dispara os produtos, encerra o que ficou aberto | Não é exposto ao usuário final |
| Schema de controle | PostgreSQL | Catálogo, execuções, artefatos, auditoria, downloads | — |
| Schema transacional | PostgreSQL, ×5 | Base do produto | Lido **apenas** pela Coleta |
| Repositório de artefatos | MinIO | `.jrprint` e `.csv.gz`, com expurgo por ILM | — |
| Identidade | Keycloak | Perfis (realm roles), roles de relatório (client roles), grupos | Não conhece o conceito de Relatório |
| Ingress | Traefik | Borda e TLS; expõe o console do Keycloak seletivamente | — |
| Mailpit | Mailpit | SMTP local | — |
| Telemetria | OTel Collector, Graylog, Prometheus, Grafana, Jaeger | Logs, métricas e traces | — |

---

## Documentos relacionados

| Documento | Papel |
|---|---|
| [`../arquitetura-inicial.md`](../arquitetura-inicial.md) | As decisões `RA-NN` que estes diagramas desenham |
| [`../prd.md`](../prd.md) | As regras `RN-NN` que as setas obedecem |
| [`../adr/`](../adr/) | Por que cada decisão não foi outra coisa |
