# 49 — Dimensionamento, backup e capacidade

Type: grilling
Status: resolved
Blocked by: —

## Question

De que tamanho é a infraestrutura, e como os dados sobrevivem a uma perda?

Graduou da névoa quando os cinco Produtos fecharam e passaram a existir números concretos: dez
Relatórios com volume, tempo estimado e forma de artefato conhecidos.

Decidir:

- **Heap da API.** O ticket 25 registrou que dimensioná-lo "vira exercício obrigatório, em função do
  maior `JasperPrint`". O ticket 42 identificou o maior — `CONTACORRENTE-0001`, ~300 mil linhas — e o
  ADR 0002 confirma que a exportação acontece **na mesma JVM**, sem isolamento. O número sai daqui.
- **O semáforo de exportação** (ticket 25): quantas exportações simultâneas cabem no heap escolhido, e
  qual a espera antes do `503`.
- **O pool de Coletas** (ticket 39): começou em 4 slots com base no orçamento de ~68 de
  `max_connections=100` do research 06. Calibrar contra os dez Relatórios reais.
- **Ocupação do repositório S3.** O ticket 41 deu o primeiro número: `CLIENTE-0001` é fotografia da
  base inteira, diária, e com retenção global de 7 dias (ticket 27) são **sete cópias**. Somar os dez
  Relatórios e decidir se 7 dias continua sendo a retenção certa para todos.
- **Crescimento indefinido de `download` e `auditoria_admin`** (ticket 27, decisão consciente). Estimar
  o volume e decidir se existe algum horizonte em que isso precise de resposta.
- **Backup e restore** do PostgreSQL (controle e cinco transacionais) e do repositório S3. Frequência,
  retenção, e — o que raramente se decide — **como o restore é testado**.
- **As VMs.** Quantas, com que tamanho, e o que roda em cada uma: Traefik, Keycloak, API, Airflow,
  PostgreSQL, repositório S3, stack de observabilidade. O ticket 11 registrou que o socket do Docker é
  o acoplamento perigoso entre Traefik e Airflow.

## Notas de tickets anteriores

- **Ticket 30**: o k6 fica **fora do gate** de CI porque **calibra** em vez de verificar. Este ticket é
  o consumidor desses números.
- **Ticket 40**: o teste de cursor roda com `-Xmx96m` de propósito — é prova de que a leitura
  transmite, **não** uma estimativa de heap de produção. Não confundir os dois números.
- **Ticket 29**: existe métrica de ocupação do bucket, de tamanho de artefato e de contagem de linhas
  por tabela. Todas foram pedidas para este momento.
- **Ticket 06**: o banco de metadados do Airflow é instância separada; o orçamento estimado é ~68 de
  `max_connections=100`.

## Notas do ticket 45 (arquitetura Angular)

- **O maior artefato tem um segundo consumidor de memória: o navegador.** O front baixa por
  `HttpClient` com blob (ticket 45), então o arquivo exportado passa inteiro pela memória da aba antes
  de virar `createObjectURL`.
- **Dimensionar o heap da API não basta**: o mesmo número precisa ser confrontado com o que um
  navegador em máquina modesta aguenta, e é ele que decide se o teto de exportação do ticket 25 é o
  heap do servidor ou o do cliente.

## Answer

Fecha o mapa. As três decisões vão na mesma direção — manter a infraestrutura mínima — e as três são
riscos aceitos, com o modo de falha nomeado.

### O quadro

| | |
|---|---|
| Teto de exportação | **não existe**; semáforo e alerta são a contenção |
| Backup | existe; **restore não é ensaiado** |
| Infraestrutura | **uma VM só** |

### Risco aceito 1: sem teto de exportação

O ticket 25 escreveu que *"o teto de tamanho de Relatório é definido aqui, e só aqui"* e o valor nunca
foi posto. Um teto por bytes do `.jrprint` foi apresentado — conferível pelo metadado já gravado,
**antes do semáforo** e sem consumir slot — e recusado, junto com a alternativa de dimensionar o `N` do
semáforo pelo pior caso.

O que se aceita:

- **O modo de falha não é "a exportação falhou".** Pelo ADR 0002 a exportação roda **na JVM da API, sem
  isolamento**: um `OutOfMemoryError` deixa a JVM em estado indefinido, não uma requisição. O ticket 28
  pôs o `readiness` para cair após N falhas seguidas, mas uma JVM em OOM pode não responder ao health
  check — e como todas as instâncias recebem o mesmo padrão de pedido, caem juntas.
- **O gatilho é uso ordinário**: um RELATOR exportando PDF do `CONTACORRENTE-0001`, que o ticket 42
  identificou como o maior do sistema. Não é ataque, é a tela funcionando.
- **A contenção nomeada erodiu.** O ticket 25 aceitou o risco escrevendo que a contenção seria "métrica
  de tamanho com alerta no Grafana". O ticket 29, três tickets depois, decidiu **alertas sem canal de
  notificação**. A contenção virou "alguém percebe se estiver olhando" — e ninguém revisitou o ticket 25.

> **Consequência**: os números que o k6 vai calibrar (ticket 30) deixam de ser conforto e passam a ser a
> única defesa — o `N` do semáforo, o heap da API contra o maior `.jrprint`, e o multiplicador entre
> artefato serializado e heap ocupado.

### Risco aceito 2: backup sem ensaio de restore

Backup do PostgreSQL (controle e cinco transacionais) e do repositório S3 existe. **O restore é
executado pela primeira vez no dia em que importa**, com o comando sendo lido naquele momento.

Um ensaio periódico em VM descartável, com asserções fixas — contagem de linhas, última Execução
presente, um Artefato lido de fato do S3 — foi apresentado e recusado pelo custo de infraestrutura
recorrente.

> **Uma coisa cai de graça, e vale registrar.** A divergência entre os dois backups é **tolerável por
> decisão anterior**: restaurar o PostgreSQL num ponto e o S3 em outro produz metadado apontando para
> objeto ausente, e o ticket 27 já resolveu isso — a listagem marca expirado pela data mas a exportação
> **tenta assim mesmo**, devolvendo `410` quando não acha. O sistema degrada em vez de quebrar. Não foi
> projetado para o restore; é subproduto de uma decisão tomada por outro motivo.

### Risco aceito 3: uma VM só

Traefik, Keycloak, API, Airflow, Mailpit, observabilidade, PostgreSQL e repositório S3 no mesmo host,
em Docker Compose.

**Este risco não é independente do primeiro, e é por isso que os dois ficam escritos juntos**: com o
OOM da API aceito como alcançável por uso ordinário, pôr o PostgreSQL e o repositório S3 no mesmo host
faz o modo de falha da aplicação **alcançar os dados**. Numa separação aplicação/dados, a VM sem estado
poderia ser reconstruída à vontade — que é justamente o que o deploy roll-forward do ticket 48 quer.

Duas mitigações que não custam VM:

- **Limites de memória por container no Compose** passam a ser a única separação entre a API e o banco.
  Sem eles, "uma VM só" significa que qualquer processo pode consumir tudo.
- **Traefik por arquivo estático, em vez de descoberta via Docker.** O ticket 11 apontou o socket do
  Docker como o acoplamento perigoso entre Traefik e Airflow — acesso ao socket é equivalente a root no
  host —, e numa VM só isso fica mais agudo. O Airflow **precisa** do socket pelo `DockerOperator`; o
  Traefik não precisa. Tirá-lo dele remove metade do problema de graça.

### Números que este ticket fixa

- **Ocupação do repositório S3**: `CLIENTE-0001` e `CONSORCIO-0001` são fotografias diárias da base
  inteira; com retenção global de 7 dias (ticket 27), são **sete cópias de cada** a qualquer momento.
  É a primeira estimativa concreta, e o que faz a métrica de ocupação do bucket ser dimensionamento e
  não só diagnóstico de lifecycle.
- **Pool de Coletas**: 4 slots (ticket 39), a calibrar contra os dez Relatórios reais, lembrando que o
  `minimumIdle` do HikariCP precisa estar fixado em 2 no processador — senão dez containers ociosos
  seguram cem conexões.
- **`download` e `auditoria_admin` crescem indefinidamente** (ticket 27, decisão consciente). Contagem
  de linhas por tabela é a métrica barata que avisa se a estimativa estava errada por uma ordem de
  grandeza.

### Derivado

- **O navegador é um segundo consumidor de memória** (ticket 45): o front baixa por `HttpClient` com
  blob, então o artefato exportado passa inteiro pela memória da aba. Sem teto no servidor, também não
  há teto no cliente — e ali o sintoma é a aba morrendo, sem `503` nem mensagem.
- **O runbook do ticket 48 ganha uma entrada**: API reiniciando sozinha sob carga de exportação é
  sintoma de OOM, e a primeira ação é olhar o tamanho do artefato pedido, não a métrica de latência.
