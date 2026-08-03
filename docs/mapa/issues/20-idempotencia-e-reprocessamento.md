# 20 — Idempotência, unicidade e forçar_reprocessamento

Type: grilling
Status: resolved
Blocked by: 02, 03, 04

## Question

Como o sistema se comporta quando o mesmo par (data de referência + código do relatório) é processado de novo?

O documento já decidiu bastante: a combinação é única; uma nova execução para um par já processado com sucesso é rejeitada com "processado com erro", mantendo intactos artefatos e metadados da execução original. A DAG aceita `forcar_reprocessamento`, restrito a ADMINISTRADOR, que invalida a execução anterior, permite nova geração e sobrescreve os artefatos, com registro de solicitante, motivo e Correlation ID.

O que ainda falta decidir:

- **Onde a unicidade é imposta.** Constraint no banco, checagem na aplicação, ou as duas. E o que acontece com duas execuções simultâneas do mesmo par (corrida) — a constraint resolve, mas qual o erro apresentado.
- **"Rejeitada com processado com erro" cria lixo.** Cada tentativa duplicada vira uma linha de execução com erro, poluindo o histórico e possivelmente disparando alerta. Decidir se a rejeição gera registro de execução ou é recusada antes disso.
- **O que "invalidar a execução anterior" significa.** A linha antiga é apagada, marcada como invalidada, ou versionada? Isso muda o modelo do ticket 04 e o histórico de downloads que aponta para ela.
- **Sobrescrever × discriminador de execução.** Se o path ganhar `executionId` (ticket 03), sobrescrever deixa de ser possível e os artefatos antigos ficam órfãos até a retenção. Reconciliar as duas decisões.
- **Retry do Airflow vs reprocessamento.** Um retry automático da mesma task é reprocessamento? Se a execução anterior falhou (não teve sucesso), a regra de unicidade não se aplica — confirmar essa leitura e escrevê-la.
- **Como o ADMINISTRADOR aciona.** Pela UI da aplicação (que chama a API do Airflow) ou direto na UI do Airflow? Se for direto, a restrição por perfil e o registro de motivo não têm como ser impostos.

## Notas de research

- **Ticket 13**: a autorização do `forcar_reprocessamento` deve ficar na **API REST** (Keycloak +
  auditoria), nunca nas permissões do Airflow — caso contrário existem duas fontes de verdade para
  quem pode acionar. Isso responde a sub-pergunta "como o ADMINISTRADOR aciona": pela aplicação,
  não pela UI do Airflow.

## Notas do ticket 02 (ciclo de vida)

- **"A rejeição gera lixo" está resolvido pela ponta de entrada.** Como quem insere a Execução é o
  Airflow numa task anterior ao container (T1), a constraint de unicidade rejeita a duplicata
  **antes** de subir container — a task falha, e não nasce linha de Execução com erro poluindo o
  histórico.
- **A leitura de que unicidade só vale para sucesso está confirmada** e tem uma consequência útil:
  uma Execução fechada como `ERRO` pela varredura não bloqueia nova Execução do mesmo par sem
  `forcar_reprocessamento`. É a recuperação natural do caso em que a varredura fechou uma Execução
  que ainda estava viva.
- **`SEM_DADOS` bloqueia ou não?** Decisão pendente aqui: o par foi processado, mas não produziu
  Artefato. Rodar de novo no mesmo dia é reprocessamento ou tentativa legítima?
- **Retry do Airflow × T1**: se a task `abrir_execucao` já criou a linha, o retry da task de
  processamento reusa a mesma Execução ou abre outra? Interage com o ticket 19.

## Notas do ticket 03 (chave e data)

- **`forcar_reprocessamento` herda a Data de Referência da Execução original.** Sem isso, um
  reprocessamento disparado dias depois receberia data nova, a constraint de unicidade nunca
  dispararia e o acervo ganharia duas entradas para o mesmo fato. Com a herança, "invalidar a
  execução anterior" tem um alvo inequívoco: a Execução do mesmo par.
- **"Sobrescrever os artefatos" está resolvido**, e literalmente. O caminho não tem discriminador de
  execução, então o reprocessamento escreve por cima em
  `{data}/{sigla}/{codigo}/{codigo}.jrprint`. Não sobram órfãos.
- **Consequência de auditoria a registrar**: um registro de Download anterior ao reprocessamento
  passa a apontar para bytes diferentes dos que a pessoa baixou. O SHA-256 por Execução detecta a
  divergência, e este ticket já exige registrar solicitante, motivo e Correlation ID — mas a regra
  precisa estar escrita, porque é uma promessa que o histórico deixa de cumprir.
- **A regra deixa de ser uniforme**: quem lê `data_referencia` não distingue rodada normal de
  reprocesso. O discriminador é a auditoria, não a data.

## Notas do ticket 19 (contrato Airflow ↔ container)

- **A unicidade virou índice parcial**, excluindo `ERRO` — foi o que tornou o retry do Airflow
  possível. Isso confirma por construção a leitura que este ticket já sugeria: uma Execução fracassada
  **não bloqueia** nova tentativa do mesmo par, e `forcar_reprocessamento` só é necessário para
  refazer um par já bem-sucedido.
- **"A rejeição gera lixo" mudou de forma.** Não há mais rejeição virando linha de erro: a duplicata
  é barrada em T1, antes do container. O que acumula agora são as linhas de `ERRO` de tentativas que
  realmente falharam — e isso é histórico legítimo, não lixo. Este ticket precisa dizer se elas têm
  política própria de retenção.
- **Retry × reprocessamento ficam separados**: retry é do Airflow, automático, abre linha nova para um
  par cuja última tentativa foi `ERRO`. Reprocessamento é da API, restrito a ADMINISTRADOR, e existe
  justamente porque o índice parcial **não** deixa passar um par já em `SUCESSO`/`ALERTA`/`SEM_DADOS`.
- **"Invalidar a execução anterior"** agora tem alvo inequívoco: a linha que ocupa o índice parcial
  para aquele par. Decidir aqui o que "invalidar" faz com ela — e note que o terminal é imutável
  (ticket 02), então apagar ou marcar são as opções, reabrir não é.

## Answer

### O índice, na forma final

```sql
CREATE UNIQUE INDEX ON execucao (codigo_relatorio, data_referencia)
  WHERE status NOT IN ('ERRO', 'SEM_DADOS');
```

**Ele é a regra de unicidade inteira** — imposta pelo banco, em T1, antes de gastar container. Não há
checagem duplicada na aplicação. A API consulta o índice apenas para decidir **qual verbo** oferecer
ao ADMINISTRADOR, nunca para autorizar.

Corrida entre dois disparos simultâneos do mesmo par: o índice resolve, e um dos dois falha em
`abrir_execucao`.

### `SEM_DADOS` não bloqueia

Sai do índice junto com `ERRO`. O propósito escrito da regra de unicidade é "mantendo intactos os
artefatos e os metadados da execução original" — e numa Execução `SEM_DADOS` **não há Artefato
algum**, porque o ticket 02 decidiu que ela não grava nada no repositório. Não há o que manter
intacto.

O caso que isso governa é comum em lote: a origem atrasou, a Coleta rodou às 3h e não achou nada, os
dados chegaram às 7h. Sem esta decisão, corrigir isso exigiria `forcar_reprocessamento` com
justificativa formal.

### Os dois verbos de disparo manual

A decisão acima só tem efeito prático se existir disparo manual **não-forçado** — o agendamento
seguinte é para outra Data de Referência, então nada refaria o par sozinho.

| Verbo | Quando é válido | Destrói? | Exige motivo |
|---|---|---|---|
| **refazer** | o par está livre no índice (última tentativa em `ERRO` ou `SEM_DADOS`) | não | não |
| **reprocessar** | há `SUCESSO` ou `ALERTA` ocupando o par | sim | sim |

Os dois restritos a ADMINISTRADOR, os dois auditados. **A API decide qual é válido consultando o
índice** — o usuário não precisa adivinhar, e não existe caminho em que ele destrua algo achando que
está só refazendo.

A autorização fica na API REST, nunca nas permissões do Airflow (research 13), senão existiriam duas
fontes de verdade sobre quem pode acionar.

### `forcar_reprocessamento` apaga a Execução anterior

A linha e suas linhas de `artefato` são removidas; o par fica livre para a nova Execução.

Isso resolve de saída um problema que "marcar como invalidada" teria: como o caminho não tem
discriminador (ticket 03), o reprocessamento **sobrescreve** os objetos no repositório — então as
linhas de `artefato` da Execução antiga passariam a descrever bytes que não existem mais, com
`sha256` mentindo.

*Risco aceito.* Argumentei por marcar como invalidada — coluna `invalidada_em` sem tocar em `status`,
índice parcial ignorando-a, e remoção apenas das linhas de `artefato`. Isso preservaria o registro de
que houve um relatório ali antes, quem o substituiu e por quê. Decisão: apagar.

### O `download` não guarda o `sha256` entregue

*Risco aceito.* Argumentei por gravá-lo: o valor já está calculado e em mãos no momento da entrega, e
uma coluna tornaria o registro autoverificável.

### O efeito combinado dos dois riscos

Registrado junto porque é maior que a soma:

Depois de um reprocessamento, **não sobra forma de verificar o que foi substituído**. A Execução
antiga não existe, o `sha256` dela foi junto, o `execucao_id` do Download virou nulo, e o Download não
guardou o hash do que recebeu. A pergunta "os bytes que essa pessoa baixou ainda são os que estão
lá?" deixa de ser verificável e passa a ser inferida por comparação de datas.

O rastro que resta é a linha de auditoria do reprocessamento — solicitante, motivo, Correlation ID.
Ela responde **quem substituiu e por quê**; nunca **o quê**.

### Derivado, não perguntado

- **O drop-down precisa de regra de desempate.** Um par pode ter várias linhas agora: `ERRO`s,
  `SEM_DADOS`s, e no máximo uma `SUCESSO`/`ALERTA`. A listagem mostra a linha que **ocupa o índice**
  se houver; caso contrário, a `SEM_DADOS` mais recente. Sem essa regra, o mesmo Relatório aparece
  duas vezes na mesma data.
- **As linhas de Execução não têm política de retenção própria.** Dez Relatórios por dia dão ~3.650
  linhas por ano, mais as tentativas falhas — irrelevante para o PostgreSQL, e o documento já exige
  que os metadados sobrevivam aos Artefatos.
- **`download.execucao_id` é `ON DELETE SET NULL`** desde o ticket 04. Deixa de ser precaução
  teórica: o reprocessamento passa a exercitá-lo em produção.
- **Retry do Airflow não é reprocessamento.** Retry é automático, do orquestrador, e abre linha nova
  para um par que o índice deixa passar. Reprocessamento é da API, restrito, destrutivo e auditado.
