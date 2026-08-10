# SP-2 — Decisões técnicas (E0)

> Spec do segundo sub-projeto. Entrega `docs/adr/` (19 ADRs), `docs/riscos.md` e os nomes dos
> módulos; registra o `docs/arquitetura/c4-contexto.md` já entregue. Fecha a fase E0 do
> [`guias/guia-app-web.md`](../../guias/guia-app-web.md).
>
> Data: 2026-08-10 · Branch: `00-super-powers` · Decomposição em
> [`2026-08-09-sp1-linguagem-e-historias-design.md`](./2026-08-09-sp1-linguagem-e-historias-design.md) §1

---

## 1. Contexto

`arquitetura-inicial.md` contém **68 decisões `RA-NN`** argumentadas, três delas já aposentadas e
substituídas. Elas dizem o que vale. O que elas quase nunca dizem é **o que foi rejeitado e por
quê** — e é essa informação que se perde primeiro, porque nunca esteve escrita.

E0 pede três artefatos que não existem: os ADRs, o C4 e o registro de riscos.

### 1.1 A divisão entre ADR e `RA-NN`

Sem uma regra explícita, ADR e `RA` viram duas descrições da mesma decisão, que divergem na
primeira revisão. A divisão adotada:

| Artefato | Papel | Ciclo de vida |
|---|---|---|
| **`RA-NN`** | A **norma**: o que vale hoje. Vira ponteiro para o ADR | Editável; aposentada quando substituída |
| **ADR** | O **porquê não foi outra coisa**: opções consideradas, motivo da rejeição, consequências | Imutável; supersedido, nunca editado |

O `RA` não repete o ADR e o ADR não repete o `RA`.

### 1.2 Critério para uma decisão virar ADR

Os **seis mínimos** que o guia exige (linguagem/framework, banco/migrations, autenticação/
autorização, ambiente, monolito vs. serviços, estratégia de testes) são obrigatórios, mesmo
quando a decisão foi imposta e não escolhida — nesse caso o ADR é curto e registra a imposição.

Somam-se a eles **todos os casos em que houve alternativa real rejeitada e a rejeição não é
óbvia**. Aplicado ao projeto, dá 19.

Ficou de fora, deliberadamente: observabilidade via OTel Collector (`RA-36`). Existe alternativa
— instrumentar cada backend diretamente — mas a rejeição é óbvia, e um ADR cerimonial dilui os
que importam.

---

## 2. Objetivo

Fechar E0, de modo que:

- SP-3 saiba como os módulos se chamam antes de criar diretório algum;
- a pergunta *"por que não fizemos de outro jeito?"* tenha resposta escrita nas 19 decisões que
  custam caro se erradas;
- todo risco aceito tenha um **sinal de disparo** — o sintoma observável que denuncia que ele se
  materializou.

---

## 3. Entregas

### 3.1 `docs/adr/` — 19 ADRs

| # | ADR | Origem da alternativa |
|---|---|---|
| 0001 | Java, Maven e Spring no backend; Angular no frontend | 🔨 reconstrução |
| 0002 | Mono repositório com versão única | 🔨 reconstrução |
| 0003 | PostgreSQL e Flyway; migration aplicada não se altera | 🔨 reconstrução |
| 0004 | Docker Compose local, sem Kubernetes | ◐ parcial |
| 0005 | Autorização híbrida: Keycloak e schema de controle | ✅ `RA-31` aposentada |
| 0006 | Gherkin em toda camada; JUnit, Cucumber, Testcontainers, Newman, Playwright | ◐ parcial |
| 0007 | Persistir o `JasperPrint` serializado | ◐ parcial (§12 + fora de escopo) |
| 0008 | CSV fora do JasperReports | 🔨 reconstrução |
| 0009 | Catálogo derivado do código | ✅ D30 |
| 0010 | Execução append-only com ponteiro de vigência | ✅ D28 |
| 0011 | Sem apuração retroativa | ✅ D25 |
| 0012 | Janela única de leitura, com retentativa e sem cancelamento | ✅ D20, D21, D22 |
| 0013 | Dois limites de tempo com papéis distintos | ✅ D23 + `RA-15` aposentada |
| 0014 | DAG com task estática por produto | ✅ `RA-65`, §14 |
| 0015 | Exportação síncrona com semáforo, sem fila | ✅ `RA-60`, RN-30 |
| 0016 | XLSX contínuo por convenção de autoria | ✅ D33 + `RA-28` aposentada |
| 0017 | Três retenções e inativação lógica | ✅ D29 |
| 0018 | Expurgo por ILM do MinIO, com callback de marcação | ✅ `RA-20`, `RA-21` |
| 0019 | Nomes dos módulos em pt-BR, sem prefixo | 🔨 reconstrução (decidida em SP-2) |

**11 documentadas · 3 parciais · 5 reconstruções.**

**Formato:**

```markdown
# ADR-0005 — Autorização híbrida: Keycloak e schema de controle

**Estado:** aceita · **Data:** 2026-08-10 · **Regras:** RA-61, RN-22, RN-23, RN-26

## Contexto
[Por que a decisão foi necessária. Cita RA e RN; não os repete.]

## Opções consideradas
1. Cadeia inteira resolvida no Keycloak  — rejeitada
2. Cadeia inteira em tabela própria      — rejeitada
3. Híbrida: perfil e grupo no Keycloak, elo Relatório→Role em tabela  ← escolhida

## Por que não a 1
O Keycloak não conhece o conceito de Relatório. `RA-31` foi escrita assim e teve
de ser aposentada: a formulação era impossível, não apenas inconveniente.

## Por que não a 2
[...]

## Consequências
Inclui o risco aceito: o service account recebe `manage-users` e `manage-clients`
porque *fine-grained admin permissions* é preview no Keycloak 26.5.2. A API tem
poder técnico de criar um ADMINISTRADOR; o que a impede é o nosso código e a
separação de espaços de nomes. Ver R-08.
```

O bloco **Consequências** é obrigatório e alimenta o `riscos.md` de §3.2.

**Rótulo das reconstruções.** Os ADRs `0001`, `0002`, `0003`, `0008` e `0019` tratam decisões cuja
alternativa nunca foi registrada. Cada um abre a seção *Opções consideradas* com:

> `> Reconstruída em SP-2; não registrada à época.`

O ADR nunca apresenta reconstrução como se fosse deliberação histórica. Um ADR falso é pior que
um ADR ausente: será citado daqui a um ano como registro de algo que não houve.

### 3.2 `docs/riscos.md` — 14 registros

Três naturezas num registro único: **aceitos**, **abertos** e **pendências de desenho**.

**Formato:**

```markdown
## R-03 — Fonte ausente no classpath da API

- **Natureza:** aceito (§12) · **Estado:** vigente
- **Impacto:** o PDF sai com fonte substituída, ou a exportação estoura —
  conforme `net.sf.jasperreports.awt.ignore.missing.font`
- **Sinal de disparo:** divergência visual entre o PDF exportado e o `.jrprint`
  de origem, ou `JRFontNotFoundException` no log da API
- **Mitigação:** mono repositório com versão única (RA-01, ADR-0002)
- **Se RA-01 cair:** reavaliar — é premissa de R-01 a R-04
```

O campo **sinal de disparo** é o que hoje não existe em lugar nenhum. A §12 diz *"aceitamos X"*;
não diz como se descobre que X aconteceu. Risco aceito sem sintoma observável é indistinguível de
risco esquecido.

| # | Risco | Natureza |
|---|---|---|
| R-01 | Serialização Java do `JasperPrint` quebra entre versões do Jasper | aceito §12 |
| R-02 | Desserializar objeto Java de origem externa | aceito §12 |
| R-03 | Fonte ausente no classpath da API | aceito §12 |
| R-04 | `ClassNotFoundException` em renderer serializado (barcode) | aceito §12 |
| R-05 | `.jrprint` desserializado ocupa múltiplos do tamanho em disco | aceito §12 |
| R-06 | Relatórios do mesmo produto veem instantes diferentes da base | aceito §12 |
| R-07 | Não há como interromper uma apuração sob demanda | aceito §12 |
| R-08 | O service account do Keycloak pode tecnicamente criar um ADMINISTRADOR | aceito `RA-61` |
| R-09 | Os limites de PRD §10 podem não resistir à medição | aberto — spike `k6` (Q10) |
| R-10 | `RA-21` pode se comportar diferente na tag de imagem que o Compose fixar | aberto — conferência |
| R-11 | A meta de 98% pode ser inadequada | aberto — após 1 mês (Q11) |
| R-12 | Arquitetura interna de cada módulo indefinida | pendência → **SP-3** |
| R-13 | Relatórios de exemplo e modelos de dados indefinidos | pendência → **SP-6a** |
| R-14 | Modelagem das tabelas do schema de controle indefinida | pendência → **SP-6b** |

**Três decisões embutidas:**

1. **R-01 a R-04 declaram a premissa `RA-01` em bloco próprio.** Hoje isso é uma frase solta da
   §12 que some se alguém ler um trade-off isolado.
2. **R-05 é um teto só, não três.** `RNF-05` (25 MB), `RNF-06` (50.000 linhas) e `RA-60` (semáforo
   de 2) compõem um único teto de memória; afrouxar qualquer um sozinho o quebra. Três registros
   separados convidariam exatamente esse erro.
3. **Trava contra apodrecimento.** `R-12` a `R-14` nomeiam o sub-projeto dono, e pendência
   resolvida é **marcada como resolvida com o sub-projeto que a resolveu, nunca apagada** — o
   mesmo padrão de "aposentado" que o projeto já usa para `RF` e `RA`. Os nomes dos módulos, que
   eram a quarta pendência da §14, entram já como **resolvidos em SP-2**, servindo de exemplo.

### 3.3 Nomes dos módulos

`groupId: br.com.scheduler`

```
scheduler-jasper-report/          pom raiz, packaging pom
├── comum/                        biblioteca comum          RA-02
├── processador-starter/          starter Spring Batch      RA-03
├── processador-poupanca/         POUPANCA                  RA-04
├── processador-cliente/          CLIENTE
├── processador-contacorrente/    CONTACORRENTE
├── processador-consorcio/        CONSORCIO
├── processador-emprestimo/       EMPRESTIMO
├── api/                          API REST, :8080           RA-05
├── frontend/                     Angular                   RA-06
└── orquestrador/                 DAGs Airflow, sem pom     RA-65
```

Esquema: **pt-BR, sem prefixo**. O `groupId` cuida do namespace, então o `artifactId` fica curto —
e ele aparece em toda linha de build e todo caminho de arquivo. Coerente com a regra de fronteira
do glossário de SP-1: *se o conceito existe para o negócio, o nome é pt-BR*; **Módulo processador**
é verbete do domínio.

**Duas consequências que fazem disto decisão, e não convenção:**

- **`processador-<sigla em minúsculas>` amarra o diretório à Sigla**, que é imutável (RN-01). Um
  produto novo é um diretório cujo nome já está determinado — sem espaço para escolha, e portanto
  sem espaço para divergência entre módulo, sigla e caminho do artefato no MinIO (`RA-19`).
- **`orquestrador/` não tem `pom.xml`.** É Python dentro de um mono repo Maven. O `Makefile` e o
  CI de SP-3 precisam saber disso, e o `pom` raiz não pode listá-lo como módulo.

### 3.4 Alterações em `arquitetura-inicial.md`

| # | Mudança |
|---|---|
| 1 | **`RA-69` nova**, fixando a estrutura de §3.3 e apontando ADR-0019. Próximo livre: a sequência vai de 01 a 68, sem buracos |
| 2 | **Ponteiro `ADR-NNNN`** nas 18 `RA` que ganharam ADR — uma referência por linha, sem reescrever a `RA` |
| 3 | **§14** — "Definição dos nomes dos módulos" sai de *Pendentes* e entra em *Resolvidos nesta revisão* |
| 4 | **§15** — `adr/`, `c4-contexto.md` e `riscos.md` passam a "Existe" |

### 3.5 `docs/arquitetura/c4-contexto.md` — entregue

Já commitado em `172e50b`, antes desta spec. Registrado aqui como feito, não como a fazer.

**Recorte adotado:** nível 1 com as 3 personas, o sistema e dois externos; nível 2 em **dois
diagramas** — Coleta e Exportação — porque as duas metades do sistema encontram-se apenas no
repositório de artefatos e no schema de controle. O recorte faz o invariante central aparecer como
**ausência**: não há caixa nem seta ligando a API a schema transacional algum (`RA-29`, RN-31).

A telemetria fica como nota, sem diagrama: não participa de fluxo de negócio, e dez setas
decorativas competiriam com as que importam.

---

## 4. Método

1. Escrever os 19 ADRs em três lotes por origem: as 11 documentadas, as 3 parciais, as 5
   reconstruções (`0001`, `0002`, `0003`, `0008`, `0019`).
2. Acrescentar `RA-69` e os ponteiros `ADR-NNNN` nas 18 `RA`.
3. Escrever `riscos.md` com os 14 registros.
4. Atualizar §14 e §15.

**Abordagem escolhida: recuperação, com reconstrução marcada.** Derivar dos registros existentes
onde eles existem — as `RA` aposentadas e a tabela D20–D33 do PRD, que tem a coluna *"o que estava
ambíguo ou errado"* — e, onde não houver registro, escrever a alternativa reconstruída sob rótulo
explícito. As alternativas consideradas e rejeitadas: escrever apenas o documentado (deixaria 5
ADRs ocos, quatro deles entre os mínimos do guia) e abrir uma sessão de decisão por ADR (fidelidade
máxima, cinco rodadas de pergunta antes de escrever qualquer coisa).

---

## 5. Fronteiras

**Pré-condição:** SP-1 aplicado. SP-1 também altera a §15 e marca `adr/` como *"Não existe —
exigido por E0"*; SP-2 muda para "Existe". Não há conflito porque são sequenciais, mas SP-2 rodando
antes deixaria a §15 errada.

**Fora de escopo de SP-2:**

- Arquitetura interna de cada módulo → SP-3 (`ARCHITECTURE.md`).
- **Nenhum `pom.xml`, nenhum diretório.** SP-2 *nomeia* os módulos; SP-3 os cria. Mesma fronteira
  que SP-1 tem com SP-6b: quem nomeia não constrói.
- Modelagem de tabelas → SP-6b. Relatórios de exemplo e modelos de dados → SP-6a.
- **Rodar os spikes.** `riscos.md` registra `R-09` e `R-10`; executá-los é outro trabalho, e a §14
  já declara que eles medem e não bloqueiam.

---

## 6. Riscos aceitos

- **As 5 reconstruções podem não corresponder à deliberação real.** Mitigado pelo rótulo, que
  preserva a distinção entre registro e inferência.
- **`riscos.md` inclui pendências de desenho e vai envelhecer** a cada sub-projeto concluído.
  Mitigado pela trava do "resolvido, não apagado", mas é manutenção recorrente e foi escolha
  deliberada.
- **19 ADRs escritos de uma vez perdem o que torna o ADR fiel.** O gênero existe para capturar a
  decisão no momento em que é tomada, com a incerteza ainda viva. Escritos em bloco, meses depois,
  herdam a nitidez retrospectiva: as opções rejeitadas parecerão mais obviamente ruins do que
  pareciam na hora. É inerente a formalizar decisão já tomada, não tem mitigação, e o registro
  existe para que um leitor futuro desconte isso.

---

## 7. Critério de aceite

Nove afirmações. SP-2 está pronto quando todas forem verdadeiras:

1. Existem 19 arquivos em `docs/adr/`, numerados `0001`–`0019` sem buraco.
2. Todo ADR tem as quatro seções: Contexto, Opções consideradas, Por que não a rejeitada,
   Consequências.
3. **Nenhuma opção listada aparece sem justificativa de rejeição.** Opção sem motivo é decoração:
   dá a impressão de deliberação sem registrar nenhuma.
4. Os 5 ADRs de reconstrução carregam o rótulo `Reconstruída em SP-2; não registrada à época`.
5. As 18 `RA` com ADR apontam para ele, e nenhuma `RA` aponta para ADR inexistente.
6. `riscos.md` tem 14 registros, **todos com sinal de disparo preenchido**.
7. `R-12` a `R-14` nomeiam o sub-projeto dono.
8. `RA-69` existe, e a §14 não lista mais os nomes dos módulos como pendentes.
9. A §15 lista `adr/`, `c4-contexto.md` e `riscos.md` como existentes — e os três existem.

Os itens 1, 5, 6 e 9 são conferíveis por comparação de texto. Como em SP-1, nenhum script é
versionado agora: **SP-3 transforma essas conferências em gate de CI**.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | As 68 `RA` que os ADRs explicam e que SP-2 altera |
| [`prd.md`](../../prd.md) | A tabela D20–D33, matéria-prima das alternativas rejeitadas |
| [`arquitetura/c4-contexto.md`](../../arquitetura/c4-contexto.md) | Entrega de SP-2 já commitada |
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define E0 e os seis ADRs mínimos |
| [SP-1](./2026-08-09-sp1-linguagem-e-historias-design.md) | Decomposição do projeto e pré-condição de SP-2 |
