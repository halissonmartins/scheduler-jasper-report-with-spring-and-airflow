# Diagnóstico: um erro na tela é localizável na operação, e a métrica existe de verdade

> Build this with **tlc-implement**.
> Every criterion below becomes a check with a proof, referenced by its number. Nothing under
> `Unresolved` gets settled while building.

## Intent

Quem opera descobre que a apuração falhou quando o usuário reclama. Um erro na tela não carrega nada
que permita encontrar a mesma ocorrência nos registros, então o chamado começa com uma descrição de
memória e termina com alguém varrendo log por horário aproximado. E a métrica primária do `prd.md`
§6 — taxa de apuração limpa ≥ 98% em janela móvel de 30 dias — não existe enquanto não for medida:
métrica de PRD não instrumentada é métrica que não existe, e sem a label de origem a apuração
agendada, a retentativa e o reprocessamento se somam na mesma série e as medições se contaminam. A
fonte não traz tempo médio de diagnóstico nem volume de chamados; o sistema não está em operação.

Quando isto existir, toda mensagem de erro carrega momento, descrição e Correlation ID, esse
identificador é o mesmo `traceId` que localiza a ocorrência nos registros da operação, a tela oferece
a cópia do erro em JSON para anexar em chamado, e as métricas de execução saem rotuladas de modo que
a taxa de apuração limpa possa ser lida sem consulta manual ao banco. A tela é `erro`, e o seu padrão
visual está em aberto: ver `Unresolved` 1.

5 criteria in 2 slices · 1 one-way door · 3 open, of which 1 blocks

## Criteria

### O erro que o usuário vê é o erro que a operação encontra

1. Se a API devolve erro ao usuário, então a resposta inclui o momento do erro em ISO 8601, a descrição e o Correlation ID.
2. Sempre, o Correlation ID é o `traceId` do OpenTelemetry, propagado ao log via MDC, de modo que o identificador exibido ao usuário localize a mesma ocorrência nos registros da operação.
3. Quando a interface exibe uma tela de erro, então ela oferece a cópia do erro em JSON.

### A métrica primária é legível sem consulta manual

4. Sempre, toda métrica de execução é rotulada com sigla do produto, código do relatório e origem da execução.
5. Sempre, a taxa de apuração limpa é computada considerando exclusivamente execuções vigentes de origem `agendada`.

## Out of scope

- As **metas** numéricas do `prd.md` §6 — `≥ 98%`, `≤ 10 retentativas/mês`, `≤ 2 reprocessamentos/mês`, `≤ 1% de exportações com erro`. São alvos de serviço medidos sobre uma distribuição, e nenhuma execução única os satisfaz ou os refuta; esta task entrega a série, não o alvo
- O contador de exportações — é o critério 10 de T5, onde a superfície medida vive
- O envelope de erro em si — é a porta registrada em `Decided` de T2, onde o primeiro handler o fixa; T8 prova e instrumenta, e não o redecide
- Painéis, alertas e regras de retenção da pilha de telemetria — o Graylog, o Prometheus, o Grafana e o Jaeger sobem no Compose e a sua configuração não é declarada em fonte alguma

## Observable

| Surface | Decision | Landing |
| --- | --- | --- |
| tela `erro` | estrutura e o que o leitor faz em seguida | 1, 3 |
| tela `erro` | densidade, posição e padrão visual | Unresolved 1 |
| tela `erro` | estado de carregamento e estado vazio | n/a - a tela de erro é terminal: não carrega nem fica vazia, e existe porque algo já falhou |
| API `todas as rotas /api/v1` | forma do erro e seus códigos | 1 |
| API `todas as rotas /api/v1` | quem pode chamar | existing - entregue por T4 (critérios 10, 12, 13, 14); o envelope de erro é o mesmo para `401` e `403` |
| API `todas as rotas /api/v1` | versionamento | n/a - versão única em mono repositório e nenhum consumidor externo à pilha; prefixo `/api/v1` fixo (RA-01) |
| documento `erro copiado em JSON` | estrutura e o que o leitor faz em seguida | 1, 3 — carrega os três campos e é anexado em chamado |
| coleção `métricas de execução` | critério de agrupamento e nomeação | 4 |
| coleção `métricas de execução` | a exceção que não encaixa | 5 — retentativa e reprocessamento existem na série e ficam **fora** do numerador e do denominador da taxa de apuração limpa |

## Swept

- validation: n/a - T8 não recebe entrada de usuário; o que observa é a saída das rotas que as outras tasks já expõem
- failure modes: 1 — o envelope de erro **é** a resposta a falha, e é a única superfície do sistema que só aparece quando algo deu errado
- idempotency and retry: n/a - T8 não executa operação de escrita de domínio; emitir a mesma telemetria duas vezes duplica um ponto de série e não altera estado
- authorization: existing - entregue por T4; T8 não acrescenta guard e não altera o que cada perfil alcança
- concurrency and ordering: n/a - o Correlation ID é por requisição e nada em T8 é compartilhado entre requisições concorrentes; é justamente por isso que ele serve para separar ocorrências simultâneas no log
- data lifecycle: n/a - T8 não persiste no schema de controle; a retenção de log, trace e métrica é da pilha de telemetria e está fora de escopo
- external-dependency failure: Unresolved 3
- state transitions: n/a - T8 não introduz ciclo de vida; o único do sistema é o da Execução, em T3, e o do Artefato, em T7
- observability: 4, 5 — esta é a dimensão que a task inteira cobre

## Impact

| Front | What changes |
|---|---|
| domínio | termo novo: `Correlation ID` — o identificador exibido ao usuário na mensagem de erro e que localiza a mesma ocorrência nos registros da operação. É **um só**, do começo ao fim da requisição; não é "id do erro", "protocolo" nem "ticket" |
| domínio | termo existente: `Origem da execução` nasceu em T3 e ganhou o terceiro valor em T6. Aqui ela deixa de ser só uma coluna e vira **label de métrica** — o que significa que renomear um dos três valores passa a quebrar painel e alerta, além de dado |
| dado armazenado | nada a migrar e nada a persistir: T8 lê a tabela de Execução que T3 e T6 escrevem, e emite telemetria |
| dependência externa | o OTel Collector passa a receber log, span, trace e métrica, e a distribuí-los para Graylog, Prometheus/Grafana e Jaeger |

## Decided

| Decision | Shape | Alternative rejected |
|---|---|---|
| Conjunto de labels da métrica de execução | `sigla`, `codigo_relatorio` e `origem` em toda métrica de execução | rotular só por relatório — sem `origem`, apuração agendada, retentativa e reprocessamento se somam na mesma série, e as métricas do `prd.md` §6 se contaminam mutuamente: a primária mede entrega e a secundária mede instabilidade, e as duas deixam de ser separáveis. **Esta porta alcança além de T8:** uma vez que painel e alerta se ligam a essas labels, renomear qualquer uma delas quebra consumidores que não aparecem no diff |

## Sources

- `.specs/features/scheduler-jasper-report/plan.md` — fatia S8; os critérios 1 a 5 desta task correspondem aos AC 65 a 69 de lá, sem acréscimo
- `docs/prd.md` — §6 (métrica primária e secundárias, e a exigência de instrumentação), RN-40, RN-41; RF-38, RF-39, RF-40, RF-52
- `docs/arquitetura-inicial.md` — RA-36 a RA-42
- `docs/adr/0004-execucao-append-only-com-ponteiro-de-vigencia.md` — **vinculante** para o critério 5: a métrica conta execuções vigentes agendadas, uma por par por dia, e mede entrega e não tentativa
- `docs/glossario.md` — Correlation ID, Origem da execução, Execução vigente
- **O envelope de erro que o critério 1 prova é decidido em `.tasks/02-catalogo-derivado-do-codigo.md`**, na linha `Envelope de erro da API` de `Decided`. T8 não o redecide; se divergirem, a de T2 vale
- Nenhum design é vinculante: `docs/design/design-system.md` não existe (`Unresolved` 1)

This task is the record of decision. If a linked document diverges, ask before building.

## Unresolved

| # | Kind | Question | Until answered |
|---|---|---|---|
| 1 | blocks | `docs/design/design-system.md`, exigido como P2 pelo guia, não existe | a tela `erro` não tem padrão visual, e o critério 3 não fixa onde a cópia em JSON aparece nem como é acionada. É a tela que todo usuário encontra no pior momento, e é a que nasce sem padrão |
| 2 | open | A meta de 98% da taxa de apuração limpa é adequada depois do primeiro mês de operação (Q11)? | o critério 5 computa a taxa e a meta segue `PROVISÓRIO`. Nada nos critérios depende do número, porque o alvo está fora de escopo por construção |
| 3 | open | O que acontece com uma requisição quando o OTel Collector não responde? | escrito assim: a telemetria é descartada e a requisição segue normalmente; nenhuma falha de Collector vira erro para o usuário. O risco de escrever o contrário é a pilha de observabilidade derrubar o sistema que ela deveria observar |
