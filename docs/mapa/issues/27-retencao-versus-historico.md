# 27 — Retenção × histórico e o download de item expirado

Type: grilling
Status: resolved
Blocked by: 03, 10

## Question

Os artefatos somem em 7 dias e o histórico fica. O que o usuário vê quando clica num link morto?

O documento decide as duas pontas: variável de ambiente com padrão de 7 dias para expurgo automático no MinIO, e histórico de downloads não expurgado junto com os relatórios. A intenção está certa; a consequência é um histórico cheio de links quebrados.

Decidir:

- **Comportamento do download expirado.** Um 404 semântico com mensagem específica ("este relatório foi expurgado pela política de retenção em <data>"), não um erro genérico. Definir o código de erro no catálogo (ticket 26) e como a UI o apresenta.
- **A UI sabe antes de clicar?** Se os metadados guardam a data de expurgo, a listagem pode marcar o item como expirado em vez de deixar o usuário descobrir no clique. Decidir se o estado "expirado" é derivado da data ou materializado (interage com o ticket 02).
- **`.jrprint` e `.csv.gz` expiram juntos.** Garantir que a política não deixe um sem o outro — o que exige que a regra de lifecycle case com o layout de path do ticket 03.
- **Quem executa o expurgo.** Lifecycle nativo do MinIO ou job da aplicação (o research 10 traz os fatos). Se for lifecycle, a variável de ambiente configura o quê, e quando é aplicada.
- **Retenção diferenciada.** Todos os relatórios expiram em 7 dias, ou o prazo é por produto/relatório? A variável única sugere global — confirmar.
- **O histórico de downloads cresce para sempre?** Ele não é expurgado com os relatórios, mas precisa de alguma política própria.

## Notas do ticket 02 (ciclo de vida)

- **"Expirado" é derivado, não materializado** — decidido no ticket 02. A sub-pergunta "derivado da
  data ou materializado" está fechada: `now() > data_expurgo_prevista`, calculado na leitura. O
  `status` da Execução nunca é sobrescrito pelo expurgo, então a taxa de sucesso histórica
  sobrevive. A listagem consegue marcar o item como expirado antes do clique, sem consultar o
  MinIO.
- **`SEM_DADOS` não tem nada a expurgar** — essas Execuções não gravam Artefato. A política de
  retenção não precisa lidar com objetos vazios, e a UI precisa distinguir "expirado" de "sem
  dados", que são erros diferentes no catálogo do ticket 26.
- **`ERRO` também não deixa Artefato íntegro** — confirmar com o ticket 24 (artefatos parciais) se
  o expurgo precisa varrer restos de execução interrompida.

## Notas do ticket 03 (chave e data)

- **Uma regra de lifecycle, filtro vazio, bucket inteiro.** O layout ficou
  `{yyyy-MM-dd}/{SIGLA}/{CODIGO}/`, com `.jrprint` e `.csv.gz` no mesmo prefixo e com a mesma data
  de criação — logo, a mesma data de expiração arredondada. Não existe filtro por sufixo em
  lifecycle S3, e não é preciso.
- **"7 dias" é aproximado em relação à data de negócio.** A expiração é arredondada para a
  meia-noite **UTC** seguinte, mas a Data de Referência é `America/Sao_Paulo`. Um Artefato criado em
  01/08 às 23:00 BRT expira em 09/08 00:00 UTC, que é 08/08 às 21:00 BRT. A mensagem de item
  expirado precisa dizer a data certa, e a UI não deve prometer "7 dias" ao pé da letra.
- **A remoção não é atômica** entre o `.jrprint` e o `.csv.gz` (research 10): existe janela em que um
  já sumiu e o outro não. A promessa de "expirar juntos" é sobre a *regra*, não sobre o instante — e
  o comportamento de download precisa tolerar o par incompleto.
- **Retenção diferenciada por Produto é possível sem mudar o layout.** O filtro de lifecycle aceita
  tags (`mc ilm rule add --tags`), o que corrige a conclusão do research 10 §7.2 de que exigiria a
  Sigla antes da data. Custo: etiquetar na escrita exige `s3:PutObjectTagging` na credencial do
  processador, hoje não prevista.

## Notas do ticket 26 (formato de erro)

- **`ARTEFATO_EXPIRADO` está reservado no catálogo, com `410 Gone`** — este ticket decide o texto e a
  apresentação. O `410` é semanticamente melhor que `404` porque afirma que o recurso **existiu** e
  foi removido deliberadamente, que é exatamente o caso.
- **O contrato é RFC 9457**, então a mensagem vai em `detail` e há espaço para extensões próprias.
  Se este ticket quiser informar **quando** o Artefato expirou, é uma extensão a mais — e ela é a
  diferença entre "não está mais disponível" e "foi expurgado em 09/08/2026 pela política de
  retenção".
- **A distinção com `EXECUCAO_SEM_DADOS` precisa ser nítida** e os dois já estão no mesmo catálogo:
  um significa que nunca houve arquivo, o outro que houve e não há mais. Confundi-los na UI faz o
  relator procurar por um relatório que nunca existiu, ou desistir de um que poderia ser reprocessado.
- **A remoção não é atômica** entre o `.jrprint` e o `.csv.gz` (research 10). Existe janela em que um
  formato responde e o outro dá `410` para a mesma Execução — vale decidir se a listagem antecipa isso
  ou se o usuário descobre no clique.

## Answer

### Item expirado: a listagem avisa, a exportação verifica

A marcação de "expirado" é **derivada** de `data_expurgo_prevista` (ticket 02) e serve de aviso na
listagem, sem consultar o repositório.

Mas a **exportação tenta buscar assim mesmo**, e só devolve `410 ARTEFATO_EXPIRADO` se o objeto de
fato não estiver lá.

O motivo é um fato do research 10: a remoção no MinIO **depende do scanner**, que é *"lower priority
continuous process"*, e objetos elegíveis *"may not immediately be removed"*. O desvio é sempre para
**mais tarde** — passada a data prevista, os bytes podem continuar disponíveis por um tempo não
definido nem observável. A marcação derivada é, portanto, **conservadora**: ela diz "expirado"
enquanto o download ainda funcionaria.

Recusar pela data descartaria esses downloads sem ganho — e não custa consulta extra, porque a API
buscaria o objeto de qualquer forma. O efeito visível é um item marcado como expirado que ainda baixa:
surpresa boa, não defeito.

### Isso dissolve a não-atomicidade

A janela em que o `.jrprint` já sumiu e o `.csv.gz` não (ou o inverso) **deixa de ser um problema a
modelar**. Cada formato consulta o repositório no momento do pedido e responde pelo que existe: um
pode dar `410` e o outro entregar, e isso é a verdade daquele instante, não uma inconsistência.

**A listagem não antecipa por formato.** Fazer isso exigiria sondar o MinIO por linha e por formato —
exatamente o custo que o desenho evita, e que motivou omitir `s3:ListBucket` da credencial da API
(research 10). Ela marca a Execução inteira pela data prevista; a realidade por formato se descobre
no clique.

### Retenção: global

Uma variável de ambiente, padrão **7 dias**, e **uma** regra de lifecycle nativo com **filtro vazio**
sobre o bucket inteiro — como a descrição inicial define. O `.jrprint` e o `.csv.gz` ficam no mesmo
prefixo e têm a mesma data de criação, logo a mesma data de expiração arredondada (ticket 03).

Retenção por Produto foi considerada. O ticket 03 mostrou que ela é possível **sem** mudar o layout,
via tags de lifecycle — mas custaria `s3:PutObjectTagging` na credencial do processador, e o ADR 0002
registra que o processador comprometido é justamente o atacante relevante deste sistema. Custaria
também uma regra nova a cada Produto cadastrado, e traria um modo de falha silencioso: objeto sem tag
cai fora de todas as regras e **nunca expira**. Nenhuma necessidade de negócio para prazos distintos
foi levantada.

**Benefício colateral do filtro vazio**: ele recolhe também os objetos órfãos de upload interrompido
que o ticket 24 previu. Eles não têm metadado no schema de controle, mas têm data de criação, e a
regra alcança o bucket inteiro — sem processo de limpeza algum, que seria impossível de qualquer
forma, já que nenhuma credencial tem `s3:DeleteObject`.

### `data_expurgo_prevista` vem do servidor quando possível

O research 10 registra que o `PutObject` pode devolver o header `x-amz-expiration` com a data de
expiração calculada **pelo servidor**, e marcou como **"confirmar em teste"** se o MinIO o emite.

Preferir esse valor ao cálculo local; cair para o cálculo (`criação + N dias`, arredondado para a
meia-noite UTC seguinte) se o header não vier.

**"7 dias" é aproximado em relação à data de negócio.** A expiração arredonda para meia-noite **UTC**,
e a Data de Referência é `America/Sao_Paulo`: um Artefato criado em 01/08 às 23:00 BRT expira em 09/08
00:00 UTC, que é 08/08 às 21:00 BRT. A mensagem de erro informa a **data real** do expurgo, como
extensão do RFC 9457 (ticket 26), e a UI não promete "7 dias" ao pé da letra.

### O histórico não tem política de retenção

`controle.download` e `controle.auditoria_admin` crescem indefinidamente.

O documento exige que o histórico sobreviva ao expurgo dos Artefatos, e as duas tabelas são a trilha
que responde "quem baixou o quê" e "quem concedeu acesso a quem" — valor que aumenta com o tempo. Não
há pressão técnica: mesmo mil downloads por dia dão ~365 mil linhas por ano, irrelevante para o
PostgreSQL.

**Registrado como parte da decisão**: isso significa acumular **dado pessoal indefinidamente** fora do
Keycloak — nome e identificador de usuário, em fotografia denormalizada (tickets 04 e 14). É coerente
com a descrição inicial, que pôs classificação de dados e mascaramento fora de escopo. Está escrito
como escolha consciente, não como omissão; revisá-la é esforço próprio, não ajuste.

### Distinções que a UI precisa manter

- **`ARTEFATO_EXPIRADO`** (410) — houve arquivo, não há mais.
- **`EXECUCAO_SEM_DADOS`** (409) — nunca houve arquivo, porque a origem não tinha linhas e a Coleta
  não gravou nada (ticket 02).

Confundi-los faz o relator procurar por um relatório que nunca existiu, ou desistir de um que poderia
ser reprocessado.

## Notas do ticket 35 (repositório S3)

- **Tudo o que este ticket decidiu sobrevive**, e isso foi o critério principal da escolha: AIStor
  Free preserva a semântica de lifecycle nativo e de policy por operação. Trocar de implementação
  — Garage, por exemplo — teria derrubado o alicerce daqui, porque sem policy do S3 não se expressa
  "escreve mas não apaga", e o expurgo exclusivamente por lifecycle deixa de ser possível.
- **Mas nada disso está confirmado *no AIStor*.** O ADR 0003 lista os pontos a exercitar contra o
  servidor real antes de promover, e três são deste ticket: regra de filtro vazio expurgando os dois
  Artefatos na mesma rodada, `x-amz-expiration` no `PutObject`, e o expurgo alcançando objeto órfão
  sem metadado.
- **O CI roda MinIO AGPL congelado, produção roda AIStor.** O comportamento do scanner — que este
  ticket usa para justificar a marcação conservadora de "expirado" — foi apurado na documentação do
  MinIO. Vale confirmar que o AIStor tem a mesma latência lazy, porque a decisão de "tentar buscar
  assim mesmo" depende disso.

## Notas do ticket 41 (Produto Cliente)

- **O primeiro número concreto de capacidade**: o `CLIENTE-0001` é fotografia da base inteira, diária.
  Com a retenção global de 7 dias decidida aqui, isso são **sete cópias da base completa** no bucket a
  qualquer momento.
- **Isso promove a métrica de ocupação do bucket** que este ticket já pedia: ela deixa de ser só
  diagnóstico de lifecycle não alcançando objetos e passa a ser **dimensionamento** — o número que diz
  se 7 dias é a retenção certa para um Produto cujo artefato não encolhe.
