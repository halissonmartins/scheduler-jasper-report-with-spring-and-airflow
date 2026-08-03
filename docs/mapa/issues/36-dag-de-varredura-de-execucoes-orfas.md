# 36 — DAG de varredura de execuções órfãs

Type: grilling
Status: resolved
Blocked by: 04, 19

## Question

Como é a DAG de varredura que o ticket 02 tornou obrigatória?

O ticket 02 decidiu **que** ela existe, **onde** roda (uma DAG do próprio Airflow, não um job na
API REST) e **qual o critério** (`status = 'EM_PROCESSAMENTO' AND inicio < now() - LIMITE_ORFA`,
com `LIMITE_ORFA` global de 6h por padrão). Falta especificar a DAG em si — hoje ela não tem dono
em nenhum ticket: o 19 é o contrato Airflow ↔ container, e a varredura não sobe container algum.

Decidir:

- **Frequência.** De quantos em quantos minutos. Interage com o `LIMITE_ORFA`: rodar a cada hora
  com limite de 6h significa até 7h de atraso na detecção.
- **O que ela escreve.** Além de `status = 'ERRO'` e `fim`, o `detalhe_erro` precisa dizer que a
  origem foi a varredura e há quanto tempo a Execução estava aberta — é o que distingue "morreu de
  verdade" de "foi fechada por limite" na análise posterior.
- **Idempotência e concorrência.** O `WHERE status = 'EM_PROCESSAMENTO'` já cobre a corrida com o
  container e com o callback (ticket 02, primeiro escritor vence). Confirmar que não há caminho em
  que a varredura e o callback fechem a mesma linha com valores diferentes.
- **A varredura fechou algo — alguém fica sabendo?** Toda linha fechada por varredura é um caso em
  que a infraestrutura falhou sem avisar. Isso merece alerta, ou só métrica? Interage com o
  ticket 29.
- **Quem vigia o vigia.** Se a própria DAG de varredura falhar ou for pausada, órfãs se acumulam em
  silêncio. Decidir o sinal — `Deadline Alerts` do Airflow 3.1, métrica de última execução
  bem-sucedida, ou nada.
- **A guarda de configuração.** O ticket 02 exige que o cadastro de Relatório recuse
  `2 × tempo_estimado + margem > LIMITE_ORFA`. Decidir se a varredura também verifica isso em
  tempo de execução e reclama, ou se confia no cadastro (ticket 04).
- **Execuções órfãs pré-existentes.** Na primeira subida com dados já em produção, a varredura
  fecharia tudo de uma vez. Precisa de proteção contra fechamento em massa?

## Notas de research

- **Ticket 13**: a feature de SLA do Airflow 2 **foi removida no 3.0**, substituída por
  *Deadline Alerts* no 3.1 (`DeadlineAlert` com `DeadlineReference.DAGRUN_LOGICAL_DATE` no Task
  SDK). Não vale material antigo sobre `sla_miss_callback`.
- **Ticket 13**: erros dentro de callbacks aparecem no log do *dag processor*, não no log da task
  — um processo de reconciliação que falha em silêncio deixa execuções abertas para sempre. A
  varredura precisa de log próprio e de teste.

## Notas do ticket 24 (tolerância do tempo estimado)

- **A varredura usa `inicio`, não `inicio_processamento`.** O ticket 24 criou a segunda coluna para
  medir desempenho; a varredura mede **abandono**, e uma Execução cujo container nunca chegou a
  começar tem `inicio_processamento` nulo — se ela filtrasse por essa coluna, deixaria de enxergar
  exatamente o caso que existe para cobrir.
- **A varredura passou a competir com o retry.** Como as tentativas reusam a linha e acumulam contra o
  mesmo `inicio`, uma Execução em retentativa pode ficar aberta por até `3 × (2E + 120)` segundos
  legitimamente. O `LIMITE_ORFA` de 6 h está acima disso por construção — a guarda do cadastro
  garante — mas a varredura precisa ser escrita sabendo que "aberta há muito tempo" nem sempre
  significa abandonada.
- **O `on_failure_callback` fechar como `ERRO` virou o caminho principal**, não a exceção: com T5
  removida (ticket 24), o container não grava mais `ERRO`. A varredura cobre agora um conjunto menor
  de casos — worker morto, VM caída, mudança manual de estado — mas continua obrigatória, porque o
  callback não dispara em nenhum deles.

## Notas do ticket 29 (métricas e cardinalidade)

- **O que a varredura fecha é métrica com nome e lugar**: `coleta_execucoes_total` carrega o label
  `origem_encerramento` (`container` | `callback` | `varredura`), e o painel-resumo mostra "Execuções
  fechadas pela varredura hoje". Toda linha nessa contagem é infraestrutura que falhou sem avisar.
- **Ninguém é notificado** (risco aceito no ticket 29) — os alertas ficam no painel. Isso muda a
  sub-pergunta "a varredura fechou algo, alguém fica sabendo?": a resposta é *só quem olhar*. Se este
  ticket achar que a varredura merece tratamento diferente, precisa dizer por quê, porque seria
  exceção à decisão geral.
- **"Quem vigia o vigia" ganhou candidato concreto**: a própria contagem no painel-resumo. Se ela
  ficar em zero por muito tempo **e** houver Execuções antigas em `EM_PROCESSAMENTO`, a varredura
  parou. Nenhum dos dois números isolado revela isso.

## Answer

### O quadro

| | |
|---|---|
| Frequência | a cada **15 minutos** (`*/15 * * * *`) |
| Guarda | **recusa rodar** com `LIMITE_ORFA` incoerente |
| Vigia | métrica `varredura_idade_segundos`, no painel-resumo |

### Frequência: 15 minutos

O custo de rodar não é a restrição — a varredura é um `UPDATE` só. Com `LIMITE_ORFA` de 6 h, a
frequência é **puro atraso de detecção**, e 15 min sobre um limiar de 6 h é desprezível.

Ganho colateral: torna "a varredura parou" perceptível em minutos. De hora em hora, a ausência de
runs demoraria a parecer anômala — e como ninguém é notificado (ticket 29), o silêncio precisa ser
rápido de notar.

### A guarda ataca a causa, não o sintoma

O ticket levantava proteção contra fechamento em massa. Separando os dois cenários que parecem o
mesmo:

- **Varredura pausada e retomada** — as órfãs acumuladas são genuinamente órfãs. Fechá-las todas é
  o comportamento **correto**. Um teto por rodada throttleria comportamento certo.
- **`LIMITE_ORFA` incoerente** — alguém troca 6 h por 6 min e a varredura fecha como `ERRO` toda
  Execução em curso. Aqui a massa é destruição, e `ERRO` é terminal e imutável.

Massa não é o problema; **configuração incoerente** é. E a varredura tem como detectá-la:

```
pior_legitimo := 3 × (2 × max(relatorio.tempo_estimado_segundos) + 120)
se LIMITE_ORFA < pior_legitimo  →  falha a task, não fecha nada
```

Uma DAG vermelha é visível e reversível; uma tabela cheia de `ERRO` terminal não é.

**Isto cobre um buraco que a guarda do ticket 04 não alcança.** Aquela valida o **cadastro** — recusa
um `tempo_estimado` alto demais para o `LIMITE_ORFA` vigente. Esta pega o caminho inverso: alguém
reduz a **variável de ambiente**, que o cadastro não vê e não revalida.

Um teto por rodada foi considerado. Ele é cause-agnostic, mas silencioso: nada distinguiria "muitas
órfãs reais" de "configuração destruindo dados", e o dano viraria contínuo em vez de único.

### Quem vigia o vigia

Métrica `varredura_idade_segundos`, publicada a cada execução bem-sucedida, exibida como linha direta
no painel-resumo. Rodando a cada 15 min, qualquer valor acima disso é anomalia óbvia — sem inferência
e sem cruzar dois números.

O `DeadlineAlert` do Airflow 3.1 foi considerado: é nativo e não exige instrumentação. Mas o aviso
moraria na UI do **Airflow**, criando uma segunda tela a consultar — e sem canal de notificação
(ticket 29), o painel-resumo é justamente o lugar único que existe para responder "algo precisa de
atenção agora?". Fragmentá-lo custaria mais do que a instrumentação poupa.

### Derivado

- **Escreve**: `status = 'ERRO'`, `fim = now()`, e `detalhe_erro` com `origem = 'varredura'` e há
  quanto tempo a Execução estava aberta — é o que distingue "morreu de verdade" de "fechada por
  limite" na análise posterior.
- **Filtra por `inicio`, não `inicio_processamento`** (ticket 24): uma Execução cujo container nunca
  chegou a começar tem a segunda coluna nula, e é exatamente o caso que a varredura cobre.
- **Idempotência resolvida pelo `WHERE status = 'EM_PROCESSAMENTO'`.** Não existe caminho em que
  varredura e callback fechem a mesma linha com valores diferentes: o segundo casa zero linhas, não
  sobrescreve, e incrementa `execucao_encerramento_perdido` (ticket 02).
- **Não notifica ninguém** — sem exceção à decisão do ticket 29. O sinal é a contagem com
  `origem_encerramento = varredura` no painel-resumo.
- **Log próprio e teste**, porque o research 13 mostrou que erro em processo de reconciliação some no
  log do *dag processor* em vez do log da task — e uma reconciliação que falha em silêncio deixa
  Execuções abertas para sempre.
- **Órfãs pré-existentes**: não há teto. Fechar tudo numa retomada é o comportamento correto.

### Esta DAG não é gerada pela fábrica

Ela é **estática**: não tem Relatório associado, não sobe container e não deriva do inventário. A
fábrica de DAGs do ticket 39 não deve tentar incluí-la.

## Notas do ticket 39 (agendamento e fábrica de DAGs)

- **Confirmado que a varredura não sai da fábrica**: ela não está no snapshot que a API materializa, e
  snapshot vazio não deve fazê-la sumir.
- **Ela também não consome o pool de Coletas.** O pool limita containers simultâneos, e a varredura é
  um `UPDATE` — contá-la ali roubaria slot de trabalho que custa caro para trabalho que não custa nada.
