# 02 — Ciclo de vida da Execução: estados, precedência e reconciliação

Type: grilling
Status: resolved
Blocked by: 01

## Question

Qual é a máquina de estados completa de uma Execução?

O documento define quatro estados (em processamento, processado com sucesso, processado com erro, processado com alerta) e já resolveu a precedência básica: alerta prevalece sobre erro quando estoura o tempo estimado; ao atingir o dobro (margem de 100%), timeout duro e "processado com erro", que prevalece sobre o alerta.

O que falta decidir:

- **Estados ausentes.** Não existe "cancelado", "não executado" (sem dados de origem), nem "expirado" (artefatos expurgados pela retenção mas metadados vivos). Uma execução sem nenhuma linha na origem é sucesso, alerta ou um estado próprio? Sem "expirado", a UI não distingue um relatório que nunca existiu de um que foi expurgado.
- **Quando o alerta é avaliado.** Só no encerramento, ou uma execução ainda em curso além do tempo estimado já muda de estado? Isso muda o que a UI mostra durante a execução.
- **Reconciliação.** O documento já decidiu que a tabela de metadados é a fonte da verdade e que o Airflow atualiza para "processado com erro" via callback de falha da task. Falta: e se o próprio Airflow morrer? Existe um job de varredura para execuções órfãs em "em processamento"? Qual o limite de tempo antes de considerar órfã?
- **Transições legais.** Escrever a tabela de transições permitidas e quem pode dispará-las (o container, o Airflow, o operador).

## Notas de research

- **Ticket 13 — furo confirmado**: a documentação do Airflow diz que callbacks só disparam em
  mudança de estado por execução **em worker**. Eles **não** cobrem queda de VM nem marcação
  manual na UI. A descrição inicial assume que o `on_failure_callback` basta para fechar execuções
  órfãs — **não basta**. Este ticket precisa decidir o job de varredura, não só o callback.

## Answer

### Estados

Cinco valores, num campo único `status`. `EM_PROCESSAMENTO` é o inicial e o único não-terminal;
`SUCESSO`, `ALERTA`, `SEM_DADOS` e `ERRO` são terminais e **imutáveis**.

**Precedência no encerramento**, da maior para a menor:

```
1. ERRO       timeout duro no dobro do estimado, ou falha fatal
2. SEM_DADOS  completou, zero linhas na origem
3. ALERTA     completou com dados, passou do tempo estimado
4. SUCESSO    completou com dados, dentro do tempo estimado
```

A fronteira entre `ALERTA` e `ERRO` é **ter completado**, não a duração. A regra da descrição
inicial ("o alerta prevalece sobre o erro, inclusive quando a execução também tiver registrado
falhas") passa a se ler como falhas **de item** — o skip/fault tolerance do Spring Batch — numa
Execução que terminou. Falha de job é `ERRO` em qualquer duração. Isso dá a invariante que sustenta
o drop-down.

### Invariantes

```
SUCESSO   => Artefato existe, com conteúdo
ALERTA    => Artefato existe, com conteúdo
SEM_DADOS => nenhum Artefato gravado
ERRO      => nenhum Artefato íntegro
```

`SEM_DADOS` não grava nada no repositório: a Coleta detecta zero linhas, registra os metadados e
encerra sem fazer o fill. Isso evita de saída o `.jrprint` de zero páginas — confirmado no
`JRVerticalFiller.fillReport()`, cujo ramo para datasource vazio é `case NO_PAGES: default:` e
**não chama `addPage()` nenhuma vez**. Um print de zero páginas nunca circula pelo sistema, então
não chega a exporter algum nem à desserialização do ticket 18.

`SEM_DADOS` aparece no drop-down, marcada, **sem download**. A API recusa a exportação com o código
`EXECUCAO_SEM_DADOS` (catálogo do ticket 26). Esconder recriaria o defeito que este ticket abre
reclamando: o relator não distinguiria "ainda não coletou" de "coletou e não tinha nada".

### Materializado × derivado

A regra que emergiu: **materializa-se o que é conhecido no encerramento, deriva-se o que depende
do relógio.**

| Fato | Como |
|---|---|
| `status`, `linhas_processadas`, `inicio`, `fim` | materializado |
| `atrasada` | derivado — `status = 'EM_PROCESSAMENTO' AND now() > inicio + tempo_estimado` |
| `expirado` | derivado — `now() > data_expurgo_prevista` |

Por isso **`ALERTA` só é avaliado no encerramento**: se uma Execução em curso já virasse `ALERTA`,
o mesmo valor passaria a significar duas coisas ("está lenta agora" × "foi lenta"), e a varredura
perderia de vista justamente as linhas lentas, que são as que ela precisa enxergar.

E por isso **"expirado" não é status**: materializá-lo exigiria sobrescrever `SUCESSO` depois de 7
dias, apagando o desfecho da rodada — a taxa de sucesso histórica por Relatório iria a zero toda
semana. O expurgo do MinIO é lifecycle assíncrono sem callback (research 10), então o banco ficaria
atrasado em relação à realidade de qualquer jeito. O ticket 27 herda o 404 semântico.

**Não existe `CANCELADO`.** Nenhuma tela, endpoint ou Perfil do documento tem essa capacidade, e um
estado sem transição de entrada é peso morto. Intervenção manual na UI do Airflow é, do ponto de
vista do schema de controle, indistinguível de uma VM que caiu — nos dois casos a linha fica órfã e
quem fecha é a varredura. Cancelamento sob demanda foi para **Out of scope** do mapa.

### Transições

| # | De | Para | Quem | Quando |
|---|---|---|---|---|
| T1 | — | `EM_PROCESSAMENTO` | Airflow, task `abrir_execucao` | antes de subir o container |
| T2 | `EM_PROCESSAMENTO` | `SUCESSO` | container | completou, linhas > 0, dentro do estimado |
| T3 | `EM_PROCESSAMENTO` | `ALERTA` | container | completou, linhas > 0, passou do estimado |
| T4 | `EM_PROCESSAMENTO` | `SEM_DADOS` | container | completou, linhas = 0, qualquer duração |
| ~~T5~~ | ~~`EM_PROCESSAMENTO`~~ | ~~`ERRO`~~ | ~~container~~ | **removida pelo ticket 24** — ver adendo |
| T6 | `EM_PROCESSAMENTO` | `ERRO` | Airflow, `on_failure_callback` | task falhou e a linha continua aberta |
| T7 | `EM_PROCESSAMENTO` | `ERRO` | Airflow, DAG de varredura | `inicio < now() - LIMITE_ORFA` |

Nenhuma transição parte de estado terminal. **A API REST não dispara transição alguma** — ela só lê
o schema de controle, o que preserva a regra arquitetural da descrição inicial.

**Quem cria a linha é o Airflow**, numa task anterior ao `DockerOperator`. Assim toda tentativa
existe na fonte da verdade, inclusive a que nunca subiu (erro de pull, OOM no startup): sem isso, o
callback teria de ser upsert reconstruindo `data_referencia` e `codigo_relatorio` a partir do
`dag_run.conf`, e a varredura não enxerga o que não existe. De quebra, a constraint de unicidade
(data + código) rejeita a duplicata em T1, **antes** de gastar container — o que responde à
reclamação do ticket 20 de que a rejeição gera lixo. Não há acoplamento novo: o Airflow já precisa
de credencial e conhecimento do schema para o callback (research 13, §6.2).

### Reconciliação

A varredura é **uma DAG do próprio Airflow**, agendada. Isso concentra toda escrita de
reconciliação num lugar só — callback e varredura — e dispensa lock distribuído, já que o Airflow
garante instância única por DAG run. Se o Airflow inteiro cai, nenhuma Coleta nova começa: o
estoque de órfãs fica limitado e é liquidado na volta, e nesse intervalo a UI já mostra "atrasada"
pela derivação acima.

O limite é **`LIMITE_ORFA`, constante global, default 6 horas**.

**Primeiro escritor vence.** Toda escrita terminal (T2–T7) leva `AND status = 'EM_PROCESSAMENTO'`.
Casar zero linhas significa que outro já encerrou: registra log e incrementa
`execucao_encerramento_perdido` — o problema fica visível em vez de silencioso — e não sobrescreve.
Estados terminais seguem imutáveis.

O que torna o limite global seguro é a **guarda no cadastro de Relatório**: recusar
`2 × tempo_estimado + margem > LIMITE_ORFA`. Sem ela, um Relatório lento faria a varredura fechar
Execução viva como `ERRO` enquanto o container ainda escrevia `SUCESSO`. Vale notar a recuperação
natural desse caso: como a linha fica `ERRO` e não `SUCESSO`, a unicidade do ticket 20 não bloqueia
— uma nova Execução do mesmo par é permitida sem `forcar_reprocessamento`.

### Riscos aceitos

1. **Status em campo único.** Argumentei por dois eixos (`status` de desfecho + `excedeu_tempo_estimado`),
   porque colapsar os dois exige a regra de precedência e faz `ALERTA` calar sobre a existência de
   Artefato. Decisão: campo único. O risco está contido pela invariante de que `ALERTA` só ocorre em
   Execução completada — quem quiser separar os eixos depois faz por migração, sem quebrar consumidor.
2. **`SEM_DADOS` no enum.** Argumentei por `SUCESSO` com `linhas_processadas = 0`, porque um valor
   novo reintroduz precedência (lento **e** vazio) e mais um ramo em todo `switch`. Decisão: estado
   próprio. A precedência foi resolvida acima (`SEM_DADOS` › `ALERTA`), e `linhas_processadas`
   continua sendo gravado de qualquer forma.
3. **`LIMITE_ORFA` global.** Argumentei por limite derivado (`2 × tempo_estimado + margem`), porque
   um limite global precisa ser maior que o dobro do estimado do Relatório mais lento e, sendo,
   deixa os rápidos órfãos por horas. Decisão: global. Contido pela guarda no cadastro; **sem a
   guarda, a decisão é insegura.**

## Adendo do ticket 24 (tolerância do tempo estimado)

Duas correções a este ticket, feitas ao decidir os números dos timeouts:

**1. A transição T5 foi removida.** O ticket 24 decidiu que, no retry automático, a linha é **reusada**
— o container sai com código ≠ 0 e deixa a Execução aberta, e quem fecha como `ERRO` é o
`on_failure_callback`, uma única vez, quando os retries se esgotam (o Airflow usa `on_retry_callback`
durante as tentativas). Logo:

- **O container grava apenas `SUCESSO`, `ALERTA` e `SEM_DADOS`** (T2, T3, T4).
- **`ERRO` vem só do callback (T6) e da varredura (T7).**

Efeito colateral bom: a janela de ~10 s entre SIGTERM e SIGKILL, que o research 13 apontava como toda
a folga para o container gravar `ERRO`, **deixa de importar** — o callback roda no worker do Airflow,
fora do container.

**2. A duração avaliada é `fim − inicio_processamento`, não `fim − inicio`.** O `inicio` é gravado em
T1, antes de o container subir; medir por ele colocaria pull de imagem e partida da JVM dentro da
janela de `ALERTA` e do timeout duro. Isso acrescenta a coluna `inicio_processamento`, gravada pelo
container.

**A varredura de órfãs continua usando `inicio`** — ela mede abandono, não desempenho.

**A guarda do cadastro passa a contar as tentativas**: `3 × (2 × tempo_estimado + 120) ≤ LIMITE_ORFA`,
porque as retentativas reusam a linha e portanto acumulam contra o mesmo `inicio`.
