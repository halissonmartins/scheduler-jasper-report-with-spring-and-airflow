# 38 — Árvore de Grupos e proteção do `PENDENTES`

Type: grilling
Status: resolved
Blocked by: 16

## Question

Como é a árvore de Grupos no Keycloak, e o que impede um GERENTE de derrubar o cadastro público?

O ticket 14 escopou o service account de mediação a uma **"subárvore de grupos de relatório"** —
`Groups:manage` e `Groups:manage-membership` restritos a ela. Mas nada no mapa define essa árvore, e
sem defini-la o escopo do FGAP não é configurável.

A tensão central, que aparece ao juntar os tickets 07, 14 e 16:

- O `PENDENTES` precisa estar **dentro** da subárvore administrável, porque permissão FGAP escopada
  por grupo **não alcança usuário sem grupo** (research 07 §3.5) — que é justamente o problema que o
  `PENDENTES` existe para resolver.
- Mas estando dentro, um GERENTE — que o ticket 14 decidiu ser **global** — pode **apagar o próprio
  `PENDENTES`**. A partir daí todo cadastro novo cai em lugar nenhum: o Default Group não existe
  mais, ninguém enxerga quem se cadastrou, e o RELATOR espera para sempre por um vínculo que
  ninguém sabe que está pendente.

Decidir:

- **Formato da árvore.** Raiz única (`/relatorios/...`), uma raiz por Produto, ou grupos planos com
  convenção de nome. Interage com a legibilidade da auditoria do ticket 14.
- **Onde fica o `PENDENTES`** em relação à subárvore administrável, e como ele é protegido de
  exclusão. Candidatos: política negativa do FGAP v2 (o research 07 registra que a v2 suporta
  exclusões do tipo "administra tudo, exceto X"), validação na camada de mediação, ou os dois.
- **Nomenclatura dos Grupos** criados pelo GERENTE, e se ela carrega a Sigla do Produto como o nome
  das Roles de Relatório passou a carregar (ticket 14).
- **Quem cria a raiz da subárvore.** Import de realm (semente, ticket 07) ou bootstrap? Lembrando que
  com `--import-realm` a importação é **pulada** se o realm já existe, então a raiz não pode depender
  dela para ambientes já existentes.
- **Grupo vazio e grupo órfão.** Um Grupo sem nenhuma Role de Relatório vinculada, ou sem membros, é
  erro, alerta ou situação normal?
- **Profundidade.** Subgrupos são permitidos? O Keycloak herda role mappings de grupo pai para
  subgrupo, o que muda o alcance efetivo de uma concessão.

## Notas de research

- **Ticket 07 §3.5**: permissão escopada por grupo não enxerga usuário sem grupo; **Default Groups**
  são a saída, porque todo usuário criado entra automaticamente neles.
- **Ticket 07**: o FGAP v2 permite **políticas negativas** — o exemplo da documentação é
  "administra usuários, exceto os membros do grupo de admins". É o mecanismo candidato para proteger
  o `PENDENTES` sem tirá-lo da subárvore.
- **Ticket 14**: o GERENTE é global e a exclusão que ele faz é definitiva, com auditoria que registra
  só o fato. Isso eleva o custo de qualquer exclusão acidental nesta árvore.

## Notas do ticket 16 (pendente de vínculo)

- **O `PENDENTES` virou a única superfície de trabalho do GERENTE.** Não há e-mail de aviso: o
  contador de membros do `PENDENTES` é o único sinal de que alguém está esperando. Isso agrava a
  tensão central deste ticket — apagar o grupo não degrada uma funcionalidade acessória, **desliga o
  onboarding inteiro em silêncio**, e ninguém percebe porque o sinal de que havia gente esperando era
  justamente o grupo apagado.
- **A listagem filtra `emailVerified = true`.** Cadastros não verificados entram no `PENDENTES` na
  criação (Default Group é aplicado na criação; a required action bloqueia o login) e ficam
  invisíveis para o GERENTE. Sem expiração automática, eles acumulam no grupo indefinidamente — o que
  este ticket precisa levar em conta ao dimensionar e monitorar a árvore.
- **Vincular = adicionar ao Grupo real + remover do `PENDENTES`**, numa operação só. O Keycloak não
  tira ninguém de Default Group sozinho. A árvore precisa deixar essa transição óbvia e atômica.
- **Um único service account** (ticket 16): a mesma credencial administra o `PENDENTES` e os Grupos
  de relatório. Se a proteção do `PENDENTES` for por política negativa do FGAP, ela recai sobre essa
  credencial única — e é a única barreira estrutural disponível.

## Answer

### O quadro

| | |
|---|---|
| Árvore | raiz única `/relatorios`, **um nível**, `PENDENTES` e Grupos como irmãos |
| Proteção do `PENDENTES` | **só a guarda na mediação** (risco aceito) |
| Estruturas | criadas por **passo manual de runbook**, conferidas por leitura no boot |
| Grupo vazio / sem Role | ambos normais; o **vínculo** a Grupo sem Role é que é recusado |

### O que a documentação do Keycloak corrigiu

Duas premissas do ticket caíram na apuração (context7, docs do Keycloak em `fine-grain-v2.adoc`):

**1. Não existe "subárvore administrável".** O FGAP v2 escopa permissão por **lista de UUIDs de
recurso** ou pelo **tipo inteiro** — não há noção de ramo da árvore. A expressão do ticket 14
("`Groups:manage` restrito à subárvore de grupos de relatório") não é diretamente configurável.

A permissão fica então por `resourceType: Groups` **sem** `resources`, com os escopos `view`,
`manage`, `view-members`, `manage-members`, `manage-membership`. Isso tem uma vantagem que a lista de
UUIDs não teria: alcança automaticamente todo Grupo que o GERENTE criar. A alternativa exigiria, a
cada Grupo novo, um segundo passo registrando-o como recurso da permissão — **não atômico**, e um
Grupo criado cuja permissão falhou ficaria inadministrável.

**2. Política negativa não é necessária.** A regra de conflito do FGAP v2 é melhor:

> *"Resource-specific permissions take precedence over broader 'all-resource' permissions. If specific
> permissions exist for a resource, the 'all-resource' permission is ignored."*

Ou seja, uma permissão específica no UUID do `PENDENTES` concedendo apenas `view`, `view-members` e
`manage-membership` **substituiria** a ampla naquele recurso, e `manage` — que apaga e renomeia —
simplesmente não seria concedido. Barreira estrutural, sem negação e sem código.

**Este mecanismo foi apresentado e recusado.** Ver "Risco aceito" abaixo.

### A árvore: raiz única, um nível

```
/relatorios
├── PENDENTES          (Default Group do realm)
├── <Grupo>            (criado pelo GERENTE)
└── <Grupo>
```

Profundidade é recusada por um motivo concreto: **o Keycloak herda role mappings de pai para filho**.
Um Grupo criado sob outro ganharia as Roles do pai sem que isso aparecesse na tela em que o GERENTE
trabalha — alcance efetivo mudando em silêncio, o modo de falha que este mapa vem recusando ticket
após ticket. E nada no documento pede hierarquia.

Raiz por Produto foi recusada por amarrar Grupo a Produto: uma equipe que precisa de relatórios de
Poupança **e** Empréstimo viraria dois Grupos com os mesmos membros, mantidos à mão, divergindo no
primeiro esquecimento. O ticket 14 deixou alçada por Produto acrescentável depois — a árvore não
precisa antecipá-la.

A raiz **não é fronteira de segurança** (o escopo do FGAP é por tipo, não por ramo). Ela paga
legibilidade: agrupa o que é deste sistema e dá à auditoria do ticket 14 um prefixo estável.

> **A planura tem de ser imposta, não convencionada.** A mediação cria Grupo sempre como filho direto
> da raiz, nunca de outro Grupo. Sem isso a herança volta pela porta dos fundos.

### Risco aceito: a guarda em código é a única barreira

O override do FGAP foi apresentado com três modos de falha concretos da alternativa e **recusado**. A
razão do lado escolhido é legítima: o override é mais **configuração viva** no Keycloak, e o ticket 17
já marcou o acúmulo dessa configuração como risco de upgrade — o import de realm não a reproduz.

Fica registrado o que se aceita junto:

1. **Endpoint novo nasce desprotegido.** A guarda protege os caminhos de que alguém se lembrou. É a
   forma **denylist**, e o ticket 17 escolheu allowlist no Traefik pela razão oposta — *"rota
   administrativa nova numa versão futura nasce bloqueada"*. Aqui, a próxima operação que tocar Grupos
   em lote nasce sem guarda até alguém notar.
2. **A guarda pode apontar para nada.** Comparar nome quebra se o grupo for recriado com outro nome;
   comparar UUID de configuração quebra num rebuild de realm. Nos dois casos a proteção some **sem
   erro**.
3. **A credencial não está sozinha para sempre.** Se o segredo do service account vazar, ou se um
   script de operação passar a usá-lo, a guarda não está no caminho.

**Mitigação adotada para o (2), e que sai de graça**: o grupo protegido é identificado como **o
Default Group do realm**, derivado da configuração ao vivo — não por nome literal nem por UUID
duplicado em configuração. Rename e rebuild deixam de quebrá-la em silêncio.

### As estruturas: runbook cria, boot confere

Criar a raiz, criar o `PENDENTES` e marcá-lo como Default Group é **passo manual de runbook**.

Criar pela API foi recusado pelo mesmo cuidado do ticket 14: definir Default Group é configuração de
**realm**, fora do recorte `Groups`/`Users`/`Clients`; concedê-la daria à credencial da mediação poder
sobre o realm inteiro.

Mas passo manual sozinho não tinha detecção alguma, e a falha que ele destrava é a mais silenciosa do
mapa: sem o Default Group, todo cadastro novo cai em lugar nenhum, o GERENTE não vê ninguém esperando,
e o ticket 16 já estabeleceu que **não há e-mail de aviso** — o contador do grupo era o único sinal. O
RELATOR espera indefinidamente e nada acusa.

Então a API **lê** e confirma no boot: a raiz existe, o `PENDENTES` existe, e ele é Default Group.
Somente leitura — nenhuma escrita, nenhum alargamento de credencial.

> **A conferência vira indicador no health group `dependencias` (ticket 28), não linha de log.**
> "Reclamar alto" sem canal de notificação (ticket 29) é reclamar no vazio. O grupo de dependências
> existe exatamente para isto: visível, sem virar decisão de balanceamento. **Não toca o `readiness`**,
> coerente com a decisão do ticket 17 de manter o Keycloak fora dele.

### Grupo vazio é normal; o vínculo inócuo não é

Grupo sem membros e Grupo sem Role são situações normais — criar e depois atribuir é o fluxo natural,
e exigir Role na criação não cobriria o caso que de fato acontece: um Grupo que **perde** a última
Role com membros dentro.

O que é recusado é **vincular alguém a um Grupo sem nenhuma Role de Relatório**. O vínculo remove a
pessoa do `PENDENTES` na mesma operação (ticket 16) — apagando o único sinal de que ela esperava — e
entrega zero relatórios. O contador passa a dizer "resolvido" quando nada foi resolvido, e o RELATOR
não tem canal para reclamar.

Recusar custa ao GERENTE uma ordem de operações (Roles primeiro) e vale exatamente no instante em que
o sinal seria destruído.

### Derivado

- **O nome do Grupo não carrega a Sigla do Produto.** Decorre da árvore plana: um Grupo pode reunir
  Roles de mais de um Produto — foi o argumento que derrubou a raiz por Produto —, então uma Sigla no
  nome mentiria. A Sigla vive no nome da Role (`REL_<SIGLA>_<NOME>`, ticket 14), onde é verdade porque
  a Role pertence a um só Produto. Nome livre, único dentro da raiz.
- **Cadastros não verificados acumulam no `PENDENTES` indefinidamente** (ticket 16: Default Group é
  aplicado na criação, a listagem filtra `emailVerified`, não há expiração). O contador de membros do
  grupo **não** é a contagem que o GERENTE vê — a tela filtra, o contador bruto não. Se algum painel
  usar o contador bruto, ele vai divergir da tela por construção.
- **Cenários obrigatórios para o ticket 30**: a mediação recusa apagar o Default Group; vincular a
  Grupo sem Role é recusado; o indicador de dependências cai quando o `PENDENTES` deixa de ser Default
  Group; a mediação cria Grupo sempre como filho direto da raiz.
- **Item de runbook** para a névoa de operação: criação da raiz, do `PENDENTES` e da marcação de
  Default Group, com a nota de que o `--import-realm` é pulado em realm existente.
