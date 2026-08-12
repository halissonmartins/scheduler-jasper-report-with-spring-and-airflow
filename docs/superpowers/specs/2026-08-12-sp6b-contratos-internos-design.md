# SP-6b — Contratos internos (E2)

> Spec do sétimo sub-projeto brainstormado. Entrega o schema de controle com migrations Flyway, o
> `openapi.yaml`, os tipos gerados para o frontend e o seed de desenvolvimento. Fecha, com SP-6a, a
> fase E2 do [`guias/guia-app-web.md`](../../guias/guia-app-web.md).
>
> Data: 2026-08-12 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

E2 existe para fixar as fronteiras onde o agente mais improvisa. O guia é direto sobre o custo de
pular: *"sem schema fixo, cada sessão inventa colunas"*.

**A entrada já está pronta.** O glossário de SP-1 fixou os identificadores canônicos — as tabelas
`produto`, `relatorio`, `execucao`, `artefato`, `download`, `evento_auditoria`, `relatorio_role` e
seus campos — e declarou a fronteira: **SP-6b acrescenta tipos, chaves e restrições; não renomeia
nada.** Precisando de outro nome, a mudança volta ao glossário primeiro.

### 1.1 O que a arquitetura promete que seja propriedade do schema

Três promessas, e é o cumprimento delas que dá trabalho:

- **`RA-67`** — *"nenhum caminho do sistema atualiza o status de uma execução já terminal, o que
  torna `RN-15` uma propriedade do schema e não uma disciplina de código"*.
- **`RN-16`** — no máximo uma execução vigente por par data + relatório.
- **`RA-66`** — o Download guarda **cópia** dos identificadores, para que um histórico que sobrevive
  indefinidamente não exiba o download de 2026 com o nome que o relatório ganhou em 2027.

### 1.2 A tensão do append-only, e como ela se resolve

`RN-46` diz que *"'Vigente' é um **ponteiro**, não um **status**"*, e `RA-67` chama a Execução de
append-only. Mas `RN-45` exige que o ciclo **reserve** a Execução com início ainda não preenchido, e
que a apuração depois registre início, fim e status — o que é `UPDATE`.

Não há contradição, e a leitura precisa é esta: `RN-15` diz *"execução em status **terminal** não
muda mais de status"*, e `RA-67` diz *"nenhum caminho atualiza o status de uma execução **já
terminal**"*. Nenhuma das duas proíbe o `UPDATE` enquanto a execução está `em processamento`.

**Resolução, com dois mecanismos independentes:**

| Invariante | Mecanismo |
|---|---|
| `RN-16` — uma vigente por par | **Chave primária** de `execucao_vigente` |
| `RN-15` — terminal não muda | **Trigger** `BEFORE UPDATE` que rejeita quando `OLD.status` é terminal |

Tirar `vigente` da tabela `execucao` é o que torna o trigger simples: ele protege a linha inteira
quando o status é terminal, sem precisar de uma lista de colunas a excluir — lista que envelheceria
a cada coluna nova.

---

## 2. Objetivo

Que SP-7 e SP-8+ encontrem schema, contrato e tipos prontos — e que nenhuma sessão futura invente
coluna, código de status HTTP ou formato de erro.

---

## 3. Entregas

### 3.1 O schema de controle — oito tabelas

No schema `controle`, com os nomes que o glossário fixou.

| Tabela | Conteúdo | Restrição que carrega |
|---|---|---|
| `produto` | `sigla` PK · `nome` · `ativo` | `sigla ~ '^[A-Z]{1,20}$'` (`RN-01`) |
| `relatorio` | `codigo` PK · `sigla_produto` FK · `nome` · `descricao` · `tempo_estimado_segundos` · `ativo` | `codigo ~ '^[A-Z]{1,20}-\d{4}$'` (`RN-02`) · `tempo_estimado_segundos > 0` (`RN-04`) |
| `execucao` | `id` PK · `data_referencia` · `codigo_relatorio` FK · `status` · `origem` · `tempo_estimado_segundos` · `iniciado_em` · `finalizado_em` | Trigger de imutabilidade terminal |
| `execucao_vigente` | **`(data_referencia, codigo_relatorio)` PK** · `execucao_id` FK | **`RN-16` vira a chave primária** |
| `artefato` | `id` PK · `execucao_id` FK · `caminho` · `tipo` · `tamanho_bytes` · `expurgado` | `tipo IN ('.jrprint', '.csv.gz')` |
| `download` | `id` PK · `usuario` · `codigo_relatorio` · **`nome_relatorio`** · **`sigla_produto`** · `data_referencia` · `formato` · `baixado_em` | Cópias, não junções (`RA-66`) |
| `evento_auditoria` | `id` PK · `tipo` · `solicitante` · `motivo` · `correlation_id` · `ocorrido_em` | — |
| `relatorio_role` | `(codigo_relatorio, nome_role)` PK | Único elo da cadeia que conhece o catálogo (`RA-61`) |

**`status` e `origem` como `varchar` com `CHECK`, não `enum` do PostgreSQL.** O conjunto é fechado
dos dois lados, mas `ALTER TYPE` é migration desconfortável e o `CHECK` dá a mesma garantia. Os
valores são os literais em pt-BR que o PRD usa: `'em processamento'`, `'processado com sucesso'`,
`'processado com alerta'`, `'processado com erro'`; e `'agendada'`, `'retentativa'`,
`'reprocessamento forcado'`.

**Dois triggers:**

- **`execucao_terminal_imutavel`** — `BEFORE UPDATE`, rejeita quando `OLD.status` é terminal
  (`RN-15`, `RA-67`).
- **`execucao_sem_delete`** — `BEFORE DELETE`, rejeita sempre. É o que transforma *"os metadados de
  Execução nunca são expurgados"* (`RN-51`) de promessa em impossibilidade. A métrica primária tem
  janela de 30 dias e o artefato dura 7; sem isso, uma limpeza bem-intencionada truncaria a série
  sem sinal algum.

**`download` guarda cópia E chave.** A FK dá rastreabilidade e é segura porque nada é apagado
(`RN-50`); as colunas copiadas dão a exibição correta. O risco é alguém fazer `JOIN` para mostrar o
nome e obter o **nome atual** — por isso as colunas copiadas levam comentário no próprio DDL
dizendo qual usar para exibir.

### 3.2 O `openapi.yaml`

**Contrato de erro em RFC 9457 (Problem Details)**, com uma extensão, porque é a forma que `RA-41`
já descreve:

```yaml
Erro:                             # application/problem+json
  type, title, status, detail     # RFC 9457
  momento: string(date-time)      # RA-41 — ISO 8601
  correlationId: string           # RA-41, RF-40
```

Usar o padrão em vez de inventar um envelope dá o `content-type` correto e ferramentas que já sabem
lê-lo. `correlationId` é o que torna `F5`, o fluxo de diagnóstico, possível.

**Os códigos de status mapeiam os RFs um a um:**

| Situação | Código | RF |
|---|---|---|
| Exportação bem-sucedida | `200` + `application/pdf` etc. | RF-19 |
| Execução vigente sem artefato válido | **`409`** | RF-20 |
| Artefato expurgado pela retenção | **`410 Gone`** | RF-24 |
| Limite de exportações simultâneas | **`429`** | RF-48 |
| Relatório fora da cadeia de permissão | **`404`**, não `403` | RF-15 |

O `404` é decisão, não descuido: `RN-23` diz que relatório fora da cadeia *"não aparece na listagem
e não é acessível por acesso direto"*. Um `403` confirmaria a existência do relatório a quem não
deveria sequer saber que ele existe.

**A distinção mais fácil de violar no contrato inteiro.** `RF-53` diz que *"nenhuma interface aceita
data de referência como entrada"*, mas a listagem navega por data e a exportação recebe a data no
caminho. Não é contradição — é a diferença entre **consultar** e **mandar apurar**:

```yaml
GET  /api/v1/datas/{data}/produtos                      # filtro — permitido
GET  /api/v1/relatorios/{codigo}/execucoes/{data}/...   # filtro — permitido
POST /api/v1/execucoes/reprocessamentos
  body: { codigoRelatorio, motivo }                     # SEM data — RN-54, RF-53
```

O `openapi.yaml` leva essa explicação como comentário no endpoint de reprocessamento. Sem ela, quem
ler o contrato acrescentará `dataReferencia` ao corpo por simetria com os outros — e a apuração
retroativa que `ADR-0011` proíbe entra por uma linha de YAML.

**Grupos de endpoint**, sob `/api/v1`: listagem e exportação · catálogo · reprocessamento ·
downloads · acesso (roles, grupos, vínculos) · `/interno/expurgo`, autenticado por credencial de
serviço e exposto ao MinIO (`RA-63`).

### 3.3 Tipos gerados

**`openapi-typescript`**, gerando `frontend/src/app/api/tipos.ts`. Só tipos, sem cliente HTTP
gerado: vinte endpoints não justificam um cliente inteiro, e o `HttpClient` do Angular já resolve a
chamada. O que o guia pede é que *"erro de contrato vire erro de compilação"* — e para isso bastam
os tipos.

**Versionados e verificados.** O arquivo é commitado, para que o build não dependa de gerar; e um
job do CI regenera e compara, falhando se divergir do `openapi.yaml`. Versionar sem verificar
deixaria contrato e tipos divergirem em silêncio, que é o pior dos dois mundos.

### 3.4 Seed de desenvolvimento

Cria o catálogo dos 10 relatórios de SP-6a e execuções nas 7 datas, com os mesmos estados que o
protótipo de SP-4 simulou: um `em processamento`, um `processado com erro`, um `processado com
alerta` e um artefato expurgado.

**Fica fora das migrations, e isso não é preciosismo.** `RA-58` diz que o catálogo é publicado pelo
módulo ao iniciar, e `RN-49` que ele é derivado do código. Uma migration de seed rodaria em qualquer
ambiente que aplicasse o Flyway e criaria catálogo sem código correspondente — exatamente o que
`ADR-0009` proíbe. Roda por `make seed-dev`, e a publicação dos processadores é idempotente sobre
ele.

---

## 4. Método

1. Migrations do schema de controle: tabelas, `CHECK`, triggers, índices.
2. `openapi.yaml`.
3. Geração de tipos e o job de deriva no CI.
4. Seed de desenvolvimento.
5. Validação: migrations aplicam, os invariantes resistem a tentativa de violação, o contrato valida,
   os tipos compilam.

**Abordagem escolhida: uma spec, plano em duas metades.** Schema e OpenAPI são o mesmo contrato
visto de dois lados — os DTOs derivam das tabelas —, então uma spec mantém a coerência e o plano
separa em tarefas revisáveis isoladamente. As alternativas: duas specs sequenciais (a segunda
dependeria inteiramente da primeira, e decisões que só aparecem ao desenhar o endpoint voltariam
para mexer no schema já fechado) e adiar a API para SP-7/SP-8 (contrariaria E2, que existe para
fixar o contrato antes do código).

---

## 5. Fronteiras

**Pré-condição:** SP-3 executado, para existirem `api/` e `frontend/`.

**Fora de escopo de SP-6b:**

- **Implementação de endpoint** — SP-7 e SP-8+. Aqui é contrato, não código de negócio.
- **Schemas transacionais** — SP-6a.
- **Autenticação e autorização de fato** — o contrato declara os requisitos de segurança; o Keycloak
  entra em SP-8.
- **Renomear qualquer identificador do glossário.** Precisando, a mudança volta ao glossário
  primeiro.

---

## 6. Riscos aceitos

- **O `JOIN` com `execucao_vigente` aparece em quase toda consulta.** É o preço de tirar a vigência
  da tabela; em troca, `RN-16` deixa de depender de código.
- **O seed de desenvolvimento cria catálogo**, que `ADR-0009` diz vir do código. Mitigado por ficar
  fora das migrations e por ser idempotente — mas alguém pode aplicá-lo onde não devia.
- **Os tipos versionados podem divergir** se o job de deriva for desativado. É a mesma fragilidade
  do job de `CLAUDE.md` em SP-3: a verificação é o que sustenta a decisão.
- **RFC 9457 é menos familiar que um envelope caseiro.** Aceito porque o ganho é o `content-type`
  correto e ferramentas que já entendem o formato.

---

## 7. Critério de aceite

1. Oito tabelas no schema `controle`.
2. **O trigger rejeita `UPDATE` de execução terminal** — testado com SQL que tenta e falha.
3. **O trigger rejeita `DELETE` de execução** — idem.
4. **A PK de `execucao_vigente` impede duas vigentes no mesmo par** — testado com `INSERT` duplicado.
5. `openapi.yaml` valida contra OpenAPI 3.1.
6. Toda resposta de erro referencia o schema `Erro`, com `correlationId`.
7. **O corpo de `POST /execucoes/reprocessamentos` não tem campo de data.**
8. Os tipos gerados compilam no frontend.
9. O job de deriva falha quando `openapi.yaml` muda sem regenerar.
10. O seed cria os 10 relatórios de SP-6a e execuções nas 7 datas, com os quatro status
    representados.

Os itens 2, 3 e 4 são os mais valiosos do conjunto: são testes que **provam que o invariante é do
schema**. Um teste que tenta violar e não consegue vale mais que qualquer afirmação em prosa.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [SP-1](./2026-08-09-sp1-linguagem-e-historias-design.md) | O glossário que fixou os identificadores; a fronteira "acrescenta, não renomeia" |
| [SP-2](./2026-08-10-sp2-decisoes-tecnicas-design.md) | `ADR-0003` (Flyway), `ADR-0009` (catálogo do código), `ADR-0010` (append-only), `ADR-0011` (sem retroatividade) |
| [SP-6a](./2026-08-12-sp6a-catalogo-de-exemplo-design.md) | Os 10 relatórios que o seed materializa |
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-23`, `RA-41`, `RA-58`, `RA-61`, `RA-63`, `RA-66`, `RA-67` |
| [`prd.md`](../../prd.md) | `RN-15`, `RN-16`, `RN-23`, `RN-45`, `RN-46`, `RN-51`, `RN-54`, `RF-15`, `RF-20`, `RF-24`, `RF-48`, `RF-53` |
