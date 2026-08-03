# 24 — Tolerância do tempo estimado e o ruído de alerta

Type: grilling
Status: resolved
Blocked by: 02

## Question

Qual a margem antes de uma execução virar "processado com alerta"?

O documento define: passou do tempo estimado cadastrado → alerta; atingiu o dobro (margem de 100%) → timeout duro e "processado com erro".

A análise comportamental aponta que sem margem no primeiro limiar o alerta vira ruído constante já na primeira variação de carga — uma execução estimada em 60s que leva 61s dispara alerta.

Decidir:

- **Margem no limiar de alerta.** Tolerância fixa (ex.: +20%), média móvel das últimas N execuções, ou alerta imediato ao ultrapassar o estimado (como está hoje). Se for percentual, qual.
- **De onde vem o "tempo estimado".** Cadastrado à mão por um ADMINISTRADOR (o documento sugere isso, ticket 04) ou recalculado automaticamente a partir do histórico? Se é manual, ele envelhece e desalinha.
- **Primeira execução.** Um relatório recém-cadastrado sem histórico — o estimado inicial é obrigatório? O que acontece se for zero ou nulo.
- **O timeout duro na prática.** Quem conta o tempo (o container, o Airflow, ou os dois) e como o container é interrompido de forma que ainda consiga gravar "processado com erro" antes de morrer. Interage com o ticket 19.
- **Artefatos parciais.** Se o timeout duro corta no meio da escrita no MinIO, o que fica lá? Precisa de escrita atômica ou de limpeza.
- **O alerta notifica alguém?** Ou só muda o status na tabela e nas métricas.

## Notas de research

- **Ticket 13**: o `on_kill` do DockerOperator chama `cli.stop()` sem parâmetro `t`, então o
  daemon dá **~10 segundos** entre SIGTERM e SIGKILL, e isso **não é configurável pelo operador**.
  Essa é toda a janela que o container tem para gravar "processado com erro" antes de morrer.
  Ordem recomendada: timeout interno do container **menor** que o `execution_timeout` do Airflow,
  para que o container se mate antes e tenha tempo de registrar.

## Notas do ticket 02 (ciclo de vida)

- **O alerta só é avaliado no encerramento.** Nada vira `ALERTA` em voo — a UI deriva "atrasada" de
  `status = 'EM_PROCESSAMENTO' AND now() > inicio + tempo_estimado` sem escrever. Então a decisão
  de margem aqui é sobre o **rótulo final**, não sobre um estado intermediário.
- **A margem e o piso são deste ticket, e agora têm um consumidor a mais**: a guarda no cadastro de
  Relatório, que recusa `2 × tempo_estimado + margem > LIMITE_ORFA` (`LIMITE_ORFA` global, default
  6h). Ou seja, a margem escolhida aqui limita o `tempo_estimado` máximo cadastrável.
- **A ordem completa dos timeouts** ficou com três degraus, não dois:
  `timeout interno do container` < `execution_timeout do Airflow` < `LIMITE_ORFA`. Se o terceiro
  degrau cair abaixo do primeiro, a varredura fecha Execução viva.
- **Artefatos parciais**: a invariante `ERRO ⇒ nenhum Artefato íntegro` é do ticket 02, mas quem a
  garante é este ticket — decidir escrita atômica ou limpeza.
- **Zero linhas não é caso de tempo.** Uma Execução vazia é `SEM_DADOS`, que prevalece sobre
  `ALERTA` mesmo que tenha estourado o estimado. A duração continua visível em início/fim.

## Notas do ticket 19 (contrato Airflow ↔ container)

- **Os três degraus estão fixados como ordem**, faltam os números:
  `timeout interno do container < execution_timeout do Airflow < LIMITE_ORFA`. Este ticket define a
  margem do primeiro e, por consequência, o `execution_timeout` que a fábrica de DAGs vai gerar.
- **O timeout interno é do Starter** (ticket 21), não do Airflow. Ele existe porque a janela entre
  SIGTERM e SIGKILL é de ~10 s e não é configurável: contar com o Airflow para matar é apostar em
  conseguir gravar `ERRO` dentro desses 10 s.
- **`execution_timeout` é por task**, e a granularidade ficou por Relatório — então a precisão por
  Relatório que este ticket precisa está disponível, sem soma nem aproximação.
- **O retry mudou o cálculo.** Com índice único parcial, o Airflow **pode** retentar. Uma Coleta que
  estoure o timeout e seja retentada consome o tempo N vezes — o `execution_timeout` multiplicado pelo
  número de tentativas precisa continuar cabendo abaixo do `LIMITE_ORFA`, ou a varredura fecha uma
  Execução que ainda está sendo retentada.

## Notas do ticket 21 (contrato do Starter)

- **O tempo estimado é dado de cadastro**, em `relatorio.tempo_estimado_segundos`, sob o
  ADMINISTRADOR. O bean do módulo expõe apenas um valor **sugerido**, publicado com o inventário, que
  a tela de cadastro oferece pré-preenchido. Isso responde a sub-pergunta "de onde vem" e resolve o
  caso do Relatório recém-criado, que não tem histórico nem palpite.
- **Consequência para a escolha entre fixo e recalculado**: como a verdade é dado e não código,
  recalcular a partir do histórico passa a ser possível sem tocar em deploy — a decisão fica
  genuinamente aberta neste ticket, e não constrangida pela arquitetura.
- **Ambientes com volumes diferentes têm estimativas diferentes**, por construção. Uma estimativa
  vinda do código forçaria produção e homologação a compartilhar o mesmo número; com cadastro, cada
  ambiente tem o seu — mas também cada ambiente precisa que alguém o defina.
- **O timeout interno do container é do Starter**, e ele deriva do tempo estimado cadastrado que
  chega por variável de ambiente — não de constante compilada.

## Answer

### A tabela

Sendo `E` o tempo estimado cadastrado, em segundos:

| | |
|---|---|
| `ALERTA` | duração de trabalho > `E × 1,20` |
| Timeout duro interno | `E × 2` — o container se mata |
| `execution_timeout` do Airflow | `E × 2 + 120 s` |
| Tentativas | **3** (2 retries) |
| `LIMITE_ORFA` | 6 h, global |
| Guarda no cadastro | `3 × (2E + 120) ≤ 21600` → **`E ≤ 3540 s` (~59 min)** |

`E` é **obrigatório**, maior que zero, sugerido pelo bean do módulo (ticket 21) e confirmado pelo
ADMINISTRADOR. Os 120 s de folga cobrem pull da imagem, partida da JVM e subida do contexto Spring.

### Limiar fixo, não adaptativo

`ALERTA` sai de uma margem percentual fixa sobre o valor cadastrado, não de média móvel do histórico.

O que decidiu foi o comportamento diante de **degradação gradual**. Um Relatório que fica mais lento
conforme a base cresce faz um limiar adaptativo subir junto — e ele **nunca alerta**. O sinal que
existe justamente para avisar de degradação é o primeiro a sumir. Com limiar fixo, o alerta fica cada
vez mais frequente até alguém decidir se ajusta o cadastro ou investiga a consulta.

### A duração medida é a do trabalho

**Correção ao ticket 02**: a duração avaliada é `fim − inicio_processamento`, não `fim − inicio`.

O `inicio` é gravado pelo Airflow em T1, **antes** de o container subir. Medir por ele colocaria pull
de imagem e partida da JVM dentro da janela: num Relatório estimado em 60 s, uma partida de 15 s
estoura sozinha a margem de 20% e dispara `ALERTA` em toda execução — o ruído que este ticket existe
para evitar, entrando por outra porta. E com timeout duro em `2 × E`, um Relatório de 5 s seria morto
antes de a JVM terminar de subir.

Com `inicio_processamento` próprio, gravado pelo container, o tempo estimado passa a significar **uma
coisa só**: quanto os dados deste Relatório demoram. A margem volta a ser sobre variação de carga, e a
sugestão do bean fica honesta — o módulo conhece a própria consulta, não o tempo de pull do cluster.

A **varredura de órfãs continua usando `inicio`**, porque ela mede abandono, não desempenho.

### Retry: a linha é reusada, e T5 desaparece

**Correção ao ticket 19**, que afirmou que "cada tentativa abre a própria Execução". Mecanicamente
isso não acontece: `abrir_execucao` e o `DockerOperator` são tasks separadas, e o Airflow retenta
apenas a que falhou.

O desenho fica:

```
abrir_execucao          -> abre 1 linha em EM_PROCESSAMENTO
DockerOperator(retries=2)
  tentativa 1: exit != 0, linha continua aberta
  tentativa 2: exit != 0, linha continua aberta
  tentativa 3: exit != 0, linha continua aberta
  -> retries esgotados
  -> on_failure_callback fecha como ERRO, uma vez
```

**Correção ao ticket 02: a transição T5 deixa de existir.** O container **nunca grava `ERRO`** — ele
sai com código ≠ 0 e deixa a linha aberta. Passa a gravar apenas `SUCESSO`, `ALERTA` e `SEM_DADOS`.
`ERRO` vem só do callback (T6) e da varredura (T7).

E isso **dissolve uma preocupação inteira**: o research 13 alertava que a janela de ~10 s entre
SIGTERM e SIGKILL era toda a folga para o container gravar `ERRO` antes de morrer. Como ele não grava
mais, a janela deixa de importar — o callback roda no worker do Airflow, fora do container.

A ordem dos três degraus continua valendo, por outro motivo: o timeout interno garante saída limpa
com exit code próprio e log completo em vez de SIGKILL, e o `LIMITE_ORFA` acima do total garante que
a varredura não dispare no meio de uma retentativa.

**Correção ao ticket 19, exit codes**: onde estava "`ERRO` gravado pelo próprio container → 5", passa
a ser "falha do job → 5, **sem** gravar terminal".

**O índice único parcial continua útil**, mas serve ao `refazer` manual do ticket 20, não ao retry
automático.

### Tentativas e o teto de tempo estimado

Como as tentativas reusam a linha, elas **acumulam** contra o `LIMITE_ORFA`. A guarda que o ticket 02
escreveu como `2 × tempo_estimado + margem > LIMITE_ORFA` precisa contar as tentativas, senão a
varredura fecha uma Coleta que ainda está sendo retentada.

Três tentativas dão folga para lote noturno não assistido — soluço de rede até o MinIO,
indisponibilidade breve do banco, reinicialização de VM — ao custo de um teto de ~59 minutos de tempo
estimado, muito acima de qualquer Relatório plausível aqui.

### Artefatos parciais: resolvidos por uma restrição anterior

O research 10 decidiu que **nenhuma credencial da aplicação tem `s3:DeleteObject`** — o expurgo é
lifecycle nativo. Então "subir em streaming e limpar na falha" **não existe como opção**.

Fica: escrever os dois Artefatos em disco local durante a Coleta, subir ao repositório só depois do
fill completo, e gravar as linhas de `artefato` mais o status terminal apenas quando os dois uploads
terminarem. Um upload interrompido no meio deixa objeto órfão **sem metadado** — invisível ao sistema,
recolhido pela retenção. A invariante `ERRO ⇒ nenhum Artefato íntegro` do ticket 02 fica honrada,
entendendo "íntegro" como "registrado, com hash conferível".

### O alerta não notifica

`ALERTA` é sinal operacional, não evento de negócio: vive na coluna de status, na métrica por Código
de Relatório (ticket 29) e no log com Correlation ID. Quem transforma isso em aviso é o **Grafana**,
que já está na stack para esse papel e permite ajustar o limiar do aviso — "cinco dias seguidos" em
vez de "uma vez" — sem deploy.

Notificar pela aplicação exigiria dar à API REST um remetente próprio, que é exatamente a
infraestrutura que o ticket 16 recusou.

## Notas do ticket 41 (Produto Cliente)

- **O limiar fixo de +20% ganhou o seu melhor caso.** O `CLIENTE-0001` lê a base inteira todo dia, então
  a duração é estável por construção e qualquer desvio é sinal. É o argumento empírico a favor da
  decisão deste ticket contra o limiar adaptativo.
- **E ele terá o pior caso no [ticket 44](44-produto-emprestimo-schema-e-relatorios.md)**: parcelas
  vencem em datas fixas, então o volume é espetado ao longo do mês e um limiar fixo sobre a média pode
  alertar todo dia 5. Vale decidir lá se a estimativa cadastrada acomoda o pico ou a média — o ticket 24
  não previu volume sazonal.

## Notas do ticket 42 (Produto Conta Corrente)

- **O teto de ~59 min não é a restrição que morde primeiro.** Ele é guarda de **orquestração** (deriva
  do `LIMITE_ORFA` e das três tentativas). Quem limita o **tamanho** de um Relatório é o heap da
  exportação (ticket 21), e os dois números não se conversam: uma Coleta pode terminar em 30 minutos,
  dentro de todos os limites daqui, e produzir um artefato que nunca exporta.
- Vale a correção de ênfase na especificação, para ninguém ler o teto de 59 min como se fosse o limite
  de tamanho de um Relatório.

## Notas do ticket 44 (Produto Empréstimo) — lacuna conhecida

- **Este ticket não previu volume sazonal.** Um Relatório cuja duração varia legitimamente com o
  calendário não é atendido por `tempo_estimado` como número único: calibrado pela média, ele alerta
  todo mês; calibrado pelo pico, ele nunca alerta e o sinal morre.
- **Nenhum dos dez Relatórios do mapa tem duração sazonal**, então a lacuna fica **registrada e não
  corrigida** — tornar `tempo_estimado` sazonal seria projetar para um caso inexistente, ao custo de
  coluna, tela de cadastro, guarda do `LIMITE_ORFA` recalculada por dia e o bean do ticket 21 sugerindo
  N valores.
- **O sintoma, quando aparecer**: `ALERTA` recorrente em datas previsíveis (dia 5, fim de mês,
  fechamento trimestral).
- **A saída a tentar primeiro é modelagem, não mecanismo** — pôr a sazonalidade num Relatório cuja
  duração é dominada por custo fixo, como o ticket 44 fez. É a mesma manobra dos tickets 42 e 43, e
  funcionou nas três vezes. Só se ela não couber é que este ticket precisa ser reaberto.
- **O limiar por percentil histórico segue recusado**, pela razão original: acompanha a degradação
  gradual e nunca alerta.
