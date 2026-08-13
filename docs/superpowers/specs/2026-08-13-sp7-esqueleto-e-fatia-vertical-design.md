# SP-7 — Esqueleto e fatia vertical (E3)

> Spec do oitavo sub-projeto brainstormado. Entrega os módulos compilando, o `ARCHITECTURE.md`
> preenchido, os 28 arquivos `.feature` e uma fatia vertical que atravessa Coleta, artefato e
> exportação. Fecha a fase E3 do [`guias/guia-app-web.md`](../../guias/guia-app-web.md).
>
> Data: 2026-08-13 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

SP-7 é onde o projeto deixa de ser documento. É também onde chegou o trabalho que outros
sub-projetos adiaram deliberadamente:

| Origem | O que caiu aqui |
|---|---|
| E3 original | Módulos compilando, health check, `ARCHITECTURE.md`, `*.feature`, a fatia vertical |
| SP-3 (esqueleto vazio) | A fatia de referência por camada e os testes ArchUnit |
| SP-6a | Os 2 JRXMLs de POUPANCA e as imagens 1 e 2 |
| SP-6b | Implementar os endpoints que o contrato declara |

**Duas dessas frentes se fundem.** A fatia vertical de negócio **é** a fatia de referência por
camada: se `POUPANCA-0001` atravessa `dominio` → `aplicacao` → `infraestrutura` → `web`, o exemplo
por camada existe. E "os endpoints de SP-6b" se reduz aos **quatro** que a fatia usa.

**Pré-condições:** SP-1, SP-2, SP-3, SP-6a e SP-6b executados. **Não** depende de SP-4 nem SP-5 —
a fatia termina no PDF entregue pela API, sem tela.

---

## 2. Objetivo

Provar, com código rodando, que a costura do sistema fecha: que o Jasper renderiza sobre a stack
escolhida, que o `.jrprint` sobrevive à serialização entre módulos, que os metadados contam a
verdade sobre o artefato, e que a cadeia de permissão filtra de fato.

---

## 3. Entregas

### 3.1 Escopo, com fronteira explícita

**Dentro:**

| Frente | Entrega |
|---|---|
| Esqueleto | 8 módulos compilando · health check em `/actuator/health/liveness` e `/readiness` (`RA-43`) · `ARCHITECTURE.md` com code map real |
| Cenários | Os **28 `.feature`**, com `@pendente` em 24 |
| Recursos Jasper | Imagens 1 e 2 · JRXMLs de `POUPANCA-0001` e `POUPANCA-0002` |
| Coleta | `processador-poupanca` apura **os dois** relatórios ativos → `.jrprint` e `.csv.gz` no MinIO → metadados no controle |
| Exportação | 4 endpoints · leitura do artefato · **PDF** |
| Identidade | Realm, 3 perfis, cliente `relatorios`, API como resource server, cadeia de permissão do Relator |
| Orquestração | DAG com reserva do ciclo (`RA-54`) e a task de POUPANCA |
| Verificação | ArchUnit · Testcontainers por camada · E2E com Newman e `psql` |

**A Coleta apura os dois relatórios, não um.** `RN-06` diz que a apuração executa **todos os
relatórios ativos**; um módulo que apurasse só um estaria implementando outra regra. A restrição da
fatia é na **exportação**, que se limita a `POUPANCA-0001` em PDF. De quebra, `POUPANCA-0002` — com
agrupamento e quebra de página — fica pronto para o teste de XLSX contínuo de SP-8.

**Fora, com dono:**

- Os outros quatro produtos → SP-8.
- XLSX, DOCX e CSV **na exportação** → SP-8. O `.csv.gz` já é *gravado* pela Coleta, porque nasce na
  mesma execução (`RA-16`).
- Retentativa, limites de tempo, reprocessamento forçado, expurgo, callback de falha → SP-8. São os
  **desfechos não-felizes**; a fatia prova o caminho feliz.
- Gestão de roles e grupos pelo Gerente, autocadastro, recuperação de senha → SP-8.
- Telas Angular → SP-8.
- **A *font extension* da fonte C** → SP-8 (ver §3.3).

### 3.2 Os seis degraus da fatia

Construção **de dentro para fora**, cada camada provada antes da seguinte.

| # | Degrau | O que prova | Como se verifica |
|---|---|---|---|
| 1 | Batch lê `poupanca` e preenche o `JasperPrint` | **`R-16`** — Jasper 7.0.8 sobre Spring Boot 4.1 e Java 25 · `queryTimeout` (`RA-57`) | Testcontainers com PostgreSQL: o print tem páginas, o dataset tem linhas |
| 2 | Grava `.jrprint` e `.csv.gz` no MinIO | `R-01`, `R-02` — serialização · caminho imutável (`RA-19`) | Testcontainers com MinIO: os dois objetos em `data/sigla/codigo` |
| 3 | Registra metadados no controle | O schema, os triggers e a **ordem de `RA-11`** | Teste que afirma: quando o status vira terminal, o artefato **já existe** |
| 4 | API lê o artefato e exporta PDF | `R-05` — memória do print desserializado | Teste que exporta e conta as páginas do PDF |
| 5 | Keycloak valida JWT e a cadeia filtra | `RN-23`, `RN-24` | **Testes de autorização** — regra inviolável do `CLAUDE.md` |
| 6 | Airflow orquestra | `RA-54`, `RA-65`, `RA-56` | E2E: dispara a DAG, aguarda, baixa o PDF |

**A ordem é a mitigação, não conveniência.** Com seis sistemas na fatia, montar tudo e testar no fim
deixaria seis suspeitos para qualquer falha. De dentro para fora, o suspeito é sempre o último
degrau. E `R-16`, o risco mais caro do projeto, é atacado no degrau 1 — se não fechar, SP-7 para ali
com uma pergunta clara, e não com seis sistemas meio montados.

**O degrau 3 carrega a verificação mais sutil.** `RA-11` exige que o artefato seja gravado **antes**
dos metadados de conclusão, porque a ordem inversa produziria execução em `processado com sucesso`
sem artefato — *"exatamente o estado que `RN-42` pressupõe impossível"*. Testar isso não é olhar o
resultado final: é afirmar que, no instante em que o status vira terminal, o objeto já está no
bucket.

### 3.3 A fonte C sai de SP-7

Ao cruzar a matriz de SP-6a com esta fatia, apareceu o seguinte: `R-03` — fonte ausente no
classpath — só é exercitado pela **fonte C**, a única empacotada por nós. Mas a matriz atribui a
POUPANCA as fontes **A e B**, que vêm no jar do JasperReports. A fonte C está em `CLIENTE-0005`,
`CONSORCIO-0002` e `EMPRESTIMO-4567`.

SP-7 entregaria a *font extension* sem que nada a exercitasse — ela ficaria no repositório sem uso
até SP-8.

**Decisão: a *font extension* da fonte C move-se para SP-8**, junto de `CLIENTE-0005`, que é o
primeiro relatório a usá-la. SP-7 entrega apenas as imagens 1 e 2 e os dois JRXMLs de POUPANCA.

**Consequência registrada:** ao fim de SP-7, `R-03` continua declarado e não exercido — a situação
de que `RA-08` reclama, agora com dono e prazo.

### 3.4 `ARCHITECTURE.md` e ArchUnit

SP-3 entregou o esqueleto; SP-7 preenche o *code map* com o código que passou a existir.

**Só cinco dos oito invariantes viram teste de arquitetura:**

| # | Invariante | Verificação |
|---|---|---|
| 1 | `dominio/` não importa `infraestrutura/`, Spring, JDBC nem HTTP | **ArchUnit** |
| 2 | Nenhum acesso a banco fora de `infraestrutura/repositorio/` | **ArchUnit** |
| 3 | Nenhuma classe em `web/` contém regra de negócio | **ArchUnit**, na forma verificável: `web` não alcança `repositorio` |
| 4 | **A `api` não acessa schema transacional** | **ArchUnit**: `api` não depende de nenhum módulo processador |
| 5 | Cada processador lê só o seu schema | **ArchUnit**: um processador não importa classes de outro |
| 6 | Versão do Jasper declarada uma vez | `grep` no CI — já em SP-3 |
| 7 | Migration aplicada não se altera | **Revisão de PR; nenhuma ferramenta pega** |
| 8 | `orquestrador/` não é módulo Maven | `grep` no CI — já em SP-3 |

O **7 não tem verificação automática**: alterar uma migration já aplicada passa no lint, no build e
no ArchUnit. Fingir que o ArchUnit cobre os oito seria pior do que registrar que cobre cinco.

### 3.5 Os 28 cenários

Distribuídos por onde o comportamento é verificável:

| Onde | Cenários | Caminho |
|---|---|---|
| `processador-starter` | As 13 histórias de sistema (Coleta) | `src/test/resources/feature/` (`RA-45`) |
| `api` | As histórias de usuário verificáveis por API | `src/test/resources/feature/` |
| `frontend` | As de tela | `e2e/features/` (`RA-46`) |

**Quatro rodam ao fim de SP-7:**

- `coleta.feature` — apurar e gravar os artefatos (HS-02)
- `listagem.feature` — listagem filtrada pela cadeia (HU-01)
- `exportacao.feature` — exportar em PDF (HU-02, restrito ao formato da fatia)
- `acesso-irrestrito.feature` — **o ADMINISTRADOR não passa pela cadeia** (HU-11)

O quarto está aí por exigência explícita: `RA-68` lista o acesso irrestrito do ADMINISTRADOR entre
os testes obrigatórios por natureza de risco, *"porque são os que ninguém escreve espontaneamente"*.
`RN-24` é a única exceção de autorização do sistema, e nasce testada ou não nasce.

Os outros 24 levam `@pendente`, e o CI roda `--tags 'not @pendente'`. Cada etiqueta removida em SP-8
é uma funcionalidade entregue — o trabalho fica visível no próprio repositório.

---

## 4. Método

1. Módulos compilando e health check.
2. **Degrau 1** — Batch preenche o `JasperPrint`. *Se falhar, pare: é `R-16`.*
3. **Degrau 2** — grava no MinIO.
4. **Degrau 3** — registra metadados, na ordem de `RA-11`.
5. **Degrau 4** — API lê e exporta PDF.
6. **Degrau 5** — Keycloak e a cadeia de permissão.
7. **Degrau 6** — Airflow, com a reserva do ciclo.
8. ArchUnit, `ARCHITECTURE.md` preenchido e os 28 `.feature`.
9. E2E com Newman e `psql`.

**Abordagem escolhida: de dentro para fora.** As alternativas: de fora para dentro com stubs (daria
algo demonstrável no primeiro dia, mas deixaria `R-16` para o fim, que é onde não se quer descobrir
que o Jasper não fecha) e por sistema (cada módulo coerente, mas nada atravessa a fronteira até o
fim — e é **na fronteira que as fatias verticais existem para falhar**: `R-01` a `R-04` moram entre
sistemas, não dentro deles).

---

## 5. Riscos aceitos

- **`R-16` é o risco de parada.** Se o Jasper 7.0.8 não fechar com Spring Boot 4.1 e Java 25, SP-7
  para no passo 2, e a decisão volta a `ADR-0001`. Por isso é o primeiro degrau.
- **Seis sistemas numa fatia.** Escolha deliberada; a mitigação é a ordem, que mantém o suspeito no
  último degrau. Não elimina o risco de a integração final revelar algo que nenhum degrau isolado
  mostrou.
- **`R-03` continua não exercido**, com a fonte C movida para SP-8.
- **Um caminho reservado-e-nunca-encerrado.** Sem o callback de falha (`RA-14`), uma execução que a
  reserva criou e que nunca inicie ficaria em `em processamento` para sempre. Na fatia isso não
  ocorre porque não há falha; em SP-8 passa a ocorrer, e é lá que se fecha.
- **O invariante 7 não tem verificação automática.** Só revisão humana pega.

---

## 6. Critério de aceite

1. `mvn verify` passa nos 8 módulos.
2. `/actuator/health/liveness` e `/readiness` respondem `UP`.
3. A Coleta apura os dois relatórios de POUPANCA e grava **quatro objetos** no MinIO.
4. No instante em que o status vira terminal, **o artefato já existe** (`RA-11`).
5. `GET .../exportacao?formato=PDF` devolve PDF válido, com páginas.
6. Relator fora da cadeia recebe **404**; ADMINISTRADOR enxerga tudo sem passar pela cadeia.
7. A DAG dispara e a reserva cria **duas execuções com `iniciado_em` nulo** (`RN-45`).
8. Os cinco testes ArchUnit passam.
9. Existem 28 `.feature`; **4 rodam**, 24 estão `@pendente`.
10. O E2E sobe o Compose, dispara a DAG e baixa o PDF.

---

## 7. Documentos relacionados

| Documento | Papel |
|---|---|
| [SP-3](./2026-08-12-sp3-fundacoes-do-repositorio-design.md) | Os módulos e os oito invariantes que o ArchUnit passa a verificar |
| [SP-6a](./2026-08-12-sp6a-catalogo-de-exemplo-design.md) | O schema `poupanca`, as consultas e a especificação dos JRXMLs |
| [SP-6b](./2026-08-12-sp6b-contratos-internos-design.md) | O schema de controle e os quatro endpoints que a fatia implementa |
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-11`, `RA-19`, `RA-43`, `RA-45`, `RA-54`, `RA-57`, `RA-65`, `RA-68` |
| [`prd.md`](../../prd.md) | `RN-06`, `RN-23`, `RN-24`, `RN-42`, `RN-45` |
