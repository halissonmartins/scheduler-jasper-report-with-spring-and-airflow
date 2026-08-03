# 25 — Geração sob demanda: síncrona ou assíncrona?

Type: grilling
Status: resolved
Blocked by: 02, 04

## Question

O relator pede um PDF. A API responde com o arquivo, ou com um protocolo?

O documento diz "geração síncrona" e "download do relatório", o que sugere request/response. A análise comportamental aponta o custo: desserializar um `JasperPrint` grande e exportar DOCX/XLSX é operação de segundos a minutos, com alto consumo de heap. Com N relatores concorrentes, a API REST vira gargalo e ponto de OOM.

Decidir:

- **Síncrono, assíncrono, ou híbrido.** O híbrido (síncrono até um limiar de tamanho, `202 Accepted` + polling acima dele) atende o caso comum sem sacrificar o caso grande, mas dobra o contrato de API. Decidir e escrever.
- **Limites concretos.** Teto de páginas, de linhas e de bytes por exportação. Timeout de exportação. O que a API responde ao ultrapassar.
- **Concorrência.** Quantas exportações simultâneas a API aceita? Fila com limite, semáforo, ou pool dedicado. O que acontece quando enche.
- **Heap.** Dimensionamento da JVM da API em função do maior `JasperPrint` esperado. Interage com o ticket 18 (isolar a desserialização) e com o 21 (limite prático do objeto).
- **Onde a exportação roda.** Na mesma JVM da API, num worker separado, ou num container efêmero. O documento exige que "a geração e download do relatório seja feita pelo módulo de API REST" — confirmar até onde essa regra vai.
- **Se assíncrono: o resultado vive onde?** Um objeto temporário no MinIO com TTL curto, ou em memória/disco local. Note que cache de exportação está **fora de escopo**, então o binário não é reaproveitado entre usuários.

## Notas do ticket 15 (autorização)

- **A autorização não é problema deste ticket.** Ela sai da claim, sem I/O: as Roles de Relatório
  vêm de `resource_access.<client>.roles` e o `SELECT` em `relatorio_role_relatorio` resolve o resto.
  Nada de chamada ao Keycloak no caminho da exportação.
- **Mas isso cria uma pergunta que é deste ticket**: num fluxo assíncrono, a autorização é avaliada
  no **pedido** (quando o token existe) ou na **entrega** (quando o polling volta, possivelmente com
  token renovado ou já revogado)? Com janela de revogação de 300 s e uma exportação que pode levar
  minutos, os dois instantes divergem de verdade.
- **E se o resultado for um objeto temporário no MinIO**, a URL de recuperação precisa ser
  autorizada de novo — ou ser inadivinhável e de vida curta. Um link que sobrevive à revogação é a
  forma mais fácil de furar a decisão do ticket 15.
- **O ADMINISTRADOR tem bypass** e alcança todos os Relatórios, então qualquer limite de concorrência
  ou de tamanho precisa valer para ele também — é justamente quem tende a exportar o maior volume.

## Notas do ticket 18 (desserialização)

- **A desserialização e a exportação rodam na JVM da API** — isolamento em processo separado foi
  considerado e recusado (ADR 0002). Consequência direta e pesada para este ticket: **não há
  contenção de OOM**. Um `JasperPrint` grande demais não derruba um worker, derruba a API inteira,
  para todos os usuários.
- Isso promove os **limites de tamanho e de concorrência** de "boa prática" a **única proteção**
  contra o ponto de ruptura que a análise comportamental aponta. O teto de páginas/linhas/bytes e o
  semáforo de exportações simultâneas deixam de ser opcionais.
- **Dimensionar o heap da API** vira exercício obrigatório aqui, em função do maior `JasperPrint`
  esperado vezes a concorrência permitida — não em função do caso médio.
- O **SHA-256 é conferido antes de desserializar**, então o fluxo de exportação tem um passo a mais
  antes de qualquer trabalho útil: buscar o Artefato, conferir o hash, só então desserializar. Num
  desenho assíncrono, é onde a falha de integridade precisa ser reportada.

## Notas do ticket 21 (contrato do Starter)

- **O teto de tamanho de Relatório é definido aqui, e só aqui.** O Starter usa `JRVirtualizer` com
  `maxPages`, o que resolve a memória da **Coleta** — mas o ticket 18 pôs a desserialização e a
  exportação na mesma JVM da API, sem isolamento, e ali o `.jrprint` inteiro volta ao heap. Um
  Relatório que a Coleta produz confortavelmente pode ser exatamente o que derruba a API.
  Dimensionar o container processador não protege nada.
- **O limite precisa ser imposto na Coleta, não só na exportação.** Se o teto só existir aqui, um
  Relatório grande demais é gravado com sucesso e só falha na hora em que alguém tenta baixá-lo —
  todo dia, para sempre, sem nunca ser corrigido na origem. Vale decidir se a Coleta recusa
  (`ERRO` com código próprio) acima de um limite de páginas ou linhas.
- **O virtualizer é um botão de dois gumes** (doc do Jasper): `maxPages` baixo demais virtualiza sem
  necessidade e degrada; alto demais estoura antes de a virtualização começar. O valor não sai de
  cálculo — sai de medição, e é insumo do teste de carga que este ticket precisa definir.

## Notas do ticket 22 (paginado × não paginado)

- **A API desserializa um print por exportação, não dois.** A opção de gravar um segundo `.jrprint`
  não paginado foi recusada, então o pior caso de heap não dobrou — o que importa porque não há
  isolamento (ADR 0002).
- **A exportação XLSX ganhou configuração fixa** — `onePagePerSheet(false)`,
  `removeEmptySpaceBetweenRows(true)`, `detectCellType(true)` — aplicada pela API a toda exportação.
  Ela roda **depois** da desserialização, então não altera o pico de memória, mas entra no tempo de
  exportação que este ticket precisa limitar.
- **Os quatro formatos partem do mesmo objeto em heap.** Um limite de tamanho vale para todos
  igualmente; não há formato "barato" que dispense o teto.

## Notas do ticket 23 (contrato do CSV)

- **Correção ao ponto acima: são três formatos, não quatro.** O CSV **não desserializa nada** — o
  `.csv.gz` já está gravado, e a API busca e transmite. Não há `JasperPrint` em heap nem exporter
  rodando.
- **Consequência prática**: os limites de tamanho e o semáforo de concorrência que este ticket precisa
  definir aplicam-se a PDF, XLSX e DOCX. O CSV pode ter caminho próprio, muito mais barato, e servido
  com `Content-Encoding: gzip` sequer passa os bytes pelo heap.
- **Isso muda o desenho do fluxo assíncrono**, se ele existir: faz pouco sentido colocar CSV numa fila
  de exportação junto com os formatos caros. Vale decidir se o CSV é sempre síncrono.
- **O SHA-256 continua sendo conferido** antes de entregar o CSV — integridade não depende de haver
  desserialização.

## Answer

### Assíncrono não resolveria o problema que motivou a pergunta

A análise comportamental levanta o assíncrono por causa do consumo de heap. Mas o ADR 0002 pôs a
desserialização e a exportação na **mesma JVM da API** — então `202 Accepted` + polling mudaria
**quando** o trabalho acontece, não **onde**. O pico de memória é idêntico.

O que o assíncrono compraria de fato: não segurar conexão HTTP por minutos, e uma fila que limita
concorrência de brinde. Mas concorrência um **semáforo** limita igual, sincronamente — e o
`.jrprint` já vem preenchido, então exportar é renderizar, não coletar: segundos, não minutos.

O que ele cobraria: cache de exportação está **fora de escopo**, então o resultado precisaria viver
num armazenamento temporário, com TTL e autorização própria; dobraria o contrato de API; e
acrescentaria uma **segunda máquina de estados** ao lado da que este mapa levou sete tickets fechando.

### Decisão: síncrono

```
autorizar (claim, sem I/O)
  -> adquirir semáforo (espera limitada, depois 503)
  -> buscar o Artefato no repositório
  -> conferir SHA-256
  -> desserializar
  -> exportar
  -> liberar semáforo
```

**O semáforo é adquirido antes de buscar o objeto**, não antes de desserializar — conferir o hash já
exige ter os bytes em memória, então a vaga precisa cobrir desde o download.

`N` sai de **medição**, não de escolha: `heap disponível ÷ (maior .jrprint desserializado + folga)`.
O multiplicador entre o tamanho serializado e o heap ocupado é o que o teste de carga com k6
(ticket 30) precisa estabelecer.

**Semáforo cheio → espera limitada, depois `503` com `Retry-After`.** Como as exportações duram
segundos, a maioria das colisões se resolve na espera e o usuário não percebe. O tempo de espera
conta **dentro** do timeout de exportação, não somado por cima dele.

**O CSV fica fora do semáforo.** Ele não desserializa nada (ticket 23) — a API busca e transmite, com
`Content-Encoding: gzip`, sem os bytes passarem pelo heap. Ocupar vaga com ele penalizaria o formato
mais barato do sistema. O SHA-256 continua sendo conferido.

### Uma pergunta que se dissolveu

O ticket 15 perguntou se, num fluxo assíncrono, a autorização seria avaliada no **pedido** ou na
**entrega** — instantes que divergem de verdade com janela de revogação de 300 s e exportação de
minutos.

**Com síncrono não existem dois instantes.** E não há armazenamento temporário, nem TTL, nem URL de
recuperação que sobreviva à revogação — que o ticket 15 apontava como a forma mais fácil de furar a
decisão dele.

### Risco aceito: limite só na exportação

Argumentei por impor o teto **também na Coleta**: terminado o fill, o Starter mediria o `.jrprint`
serializado e, acima do teto, encerraria como `ERRO` com código próprio sem subir nada — o problema
apareceria na origem, onde dá para corrigir (filtrar a consulta, quebrar o Relatório). Decisão: só na
exportação.

Consequência: o Artefato grande demais é coletado com sucesso **todos os dias**, ocupa espaço até a
retenção, aparece como disponível no drop-down, e falha no clique. Quem descobre é o **relator**; quem
pode consertar é o ADMINISTRADOR.

**Contenção**: a Coleta emite métrica de tamanho do Artefato por Código de Relatório, e o Grafana
alerta quando ela ultrapassa o teto de exportação. O ADMINISTRADOR descobre no dia em que começa a
acontecer, em vez de pelo chamado do relator dias depois. É o mesmo mecanismo já escolhido para
`ALERTA` no ticket 24 — sem infraestrutura nova.

### Derivado

- **Heap da API**: dimensionado por `maior .jrprint desserializado × N + folga`. Não é função do caso
  médio — sem isolamento (ADR 0002), é o pior caso que derruba tudo, para todos.
- **Acima do teto**: `409` com código próprio (ticket 26). **Semáforo cheio**: `503` com `Retry-After`.
- **Onde a exportação roda**: na JVM da API, conforme a regra do documento de que "a geração e
  download devem ser feitos pelo módulo de API REST" — e conforme o ADR 0002, que recusou isolamento.
- **O teto vale igualmente para o ADMINISTRADOR**, que tem bypass de autorização (ticket 15) e é
  justamente quem tende a exportar o maior volume. Bypass é de alcance, não de limite.

## Notas do ticket 42 (Produto Conta Corrente)

- **O maior `JasperPrint` do mapa tem forma e volume.** Este ticket disse que dimensionar o heap da API
  "vira exercício obrigatório, em função do maior `JasperPrint`" — é o `CONTACORRENTE-0001`, ~300 mil
  linhas de saída na semente volumétrica. O insumo que faltava para fazer a conta existe.
- **O risco aceito daqui encontrou o primeiro caso concreto.** Sem teto na Coleta, contido só por
  métrica de tamanho com alerta, o Produto de maior volume é exatamente onde ele morde — e o ticket 42
  o evitou por **modelagem** (resumo por conta em vez de detalhe por lançamento), não por controle.
- **Diretriz que saiu de lá e vale aqui**: "todo lançamento de todas as contas" é extração de dados, não
  relatório. Um relatório é agregado ou recortado, e um dump não deveria caber neste sistema — é a
  contenção mais barata do risco aceito, porque atua antes de qualquer teto.
