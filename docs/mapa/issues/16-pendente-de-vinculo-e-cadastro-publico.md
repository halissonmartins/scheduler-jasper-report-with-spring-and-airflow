# 16 — Estado "pendente de vínculo" e cadastro público

Type: grilling
Status: resolved
Blocked by: 01, 07

## Question

O RELATOR se cadastra e espera. O que acontece nesse intervalo?

O documento diz que ele deve ver uma mensagem pedindo que aguarde a configuração das permissões. Falta modelar o estado inteiro:

- **O estado existe onde?** É ausência de grupo no Keycloak, uma flag no schema de controle, ou um estado explícito de conta? A UI precisa distinguir "cadastrado e aguardando" de "cadastrado, vinculado, mas sem nenhum relatório acessível" — são situações diferentes com a mesma aparência.
- **Verificação de e-mail.** É obrigatória antes do login, ou o usuário loga e só depois verifica? Mailpit está na stack para isso.
- **Restrição de domínio de e-mail.** Registro público sem nenhum filtro é vetor de abuso. Existe allowlist de domínio? CAPTCHA? Aprovação manual já é o filtro suficiente?
- **Notificação ao GERENTE.** Nada no documento avisa que há um cadastro esperando. E-mail? Contador na UI? Sem isso, o RELATOR espera indefinidamente.
- **Expiração.** Um cadastro pendente há 90 dias é o quê?
- **Qual tela ele vê.** Uma página dedicada, um banner, ou um bloqueio no login. Interage com o protótipo (32).

## Notas de research

- **Ticket 07**: permissão FGAP escopada por grupo **não alcança usuário sem grupo**. Um
  **Default Group `PENDENTES`** resolve três coisas de uma vez: materializa o estado Pendente de
  Vínculo, dá alcance ao GERENTE sobre esses usuários, e torna a listagem trivial.
- **Ticket 07**: a restrição de domínio de e-mail sai de graça com o validador `pattern` do User
  Profile do Keycloak — não precisa de código.

## Answer

### Perfil e mediação

- **O Perfil é realm role.** `ADMINISTRADOR` / `GERENTE` / `RELATOR` chegam em `realm_access.roles`,
  separados das Roles de Relatório, que ficam em `resource_access.<client>.roles`. Perfil é
  identidade no realm inteiro, não permissão sobre um client — e manter os eixos separados na origem
  evita que o prefixo `REL_` passe a carregar um segundo trabalho, o de distinguir Perfil de
  permissão. O conversor de authorities em `relatorios-comum` lê **as duas claims**.
- **Um único service account de mediação.** *Risco aceito*: argumentei por dois, separados por
  alçada (`sa-relatorios` sem capacidade de mapear Perfil, `sa-administracao` como único capaz de
  conceder `GERENTE`), porque o documento exige que o ADMINISTRADOR cadastre GERENTEs pela aplicação
  — e com credencial única essa capacidade fica sempre carregada, de modo que um bug de autorização
  na rota do GERENTE basta para autopromoção. Com dois, a falha seria fechada: credencial errada
  devolve 403 do Keycloak. Decisão: um só, com toda a separação vivendo na camada 2 da API. Isso
  **estreita a proteção desenhada no ticket 14**, cuja camada 1 existia para conter exatamente essa
  classe de bug.

### O estado: mensagem única

O `PENDENTES` como **Default Group** é o modelo (research 07): materializa o estado, dá alcance ao
GERENTE sobre recém-cadastrados e torna a listagem trivial.

O ticket queria que a UI distinguisse "cadastrado e aguardando" de "vinculado, mas sem nenhum
Relatório acessível". Com a autorização saindo só da claim (ticket 15), os dois estados produzem
`resource_access.<client>.roles` **vazio** — indistinguíveis sem chamada à Admin API, que é o custo
de caminho quente recusado lá.

Decisão: **não distinguir**. Lista vazia produz sempre a mesma tela.

*Contenção*: o usuário perde o autodiagnóstico, não a solução. As telas do GERENTE consultam a Admin
API ao vivo (ticket 04), então `GET /groups/{PENDENTES}/members` diz exatamente qual dos dois casos
é — o research 07 registra que o Default Group torna essa listagem trivial.

### Notificação: só o contador

O GERENTE vê, ao entrar, quantos cadastros aguardam vínculo. Nenhum e-mail é disparado pela
aplicação — o Mailpit continua servindo apenas ao Keycloak, e a API REST não ganha remetente próprio.

**Requisito que nenhuma pergunta cobriu, e sem o qual o contador mente**: o Keycloak **não remove
ninguém de Default Group automaticamente**. Como o contador é a contagem de membros do `PENDENTES`,
**vincular a um Grupo real precisa incluir remover do `PENDENTES`**, como uma operação só na camada
de mediação. Sem isso, o usuário fica vinculado e continua contando como pendente para sempre.

### Verificação de e-mail: obrigatória

A required action `VERIFY_EMAIL` bloqueia o login até a confirmação.

**Correção registrada**: durante a sessão eu afirmei que quem não verifica "nunca aparece na lista".
Está errado — o Keycloak aplica Default Groups na **criação** do usuário, e a required action bloqueia
o **login**. O cadastro não verificado entra no `PENDENTES` de imediato e contaria no contador.

Consequência obrigatória: **a listagem de pendentes filtra por `emailVerified = true`**. Sem esse
filtro, a verificação obrigatória não protege a lista de nada — que era o motivo de exigi-la.

### Domínio de e-mail: sem restrição

O validador `pattern` do User Profile faria a restrição de graça (research 07), mas o documento
determina que RELATOR se cadastra **somente** pela interface pública, e o ADMINISTRADOR só cadastra
GERENTE e ADMINISTRADOR. Não existe porta dos fundos: uma allowlist excluiria terceirizados e
consultores de virar RELATOR por qualquer caminho.

Os filtros que restam são a verificação obrigatória de e-mail e a aprovação manual do GERENTE, que é
quem decide quem entra em Grupo.

### Expiração: nenhuma

Nada expira sozinho. A lista de pendentes mostra há quanto tempo cada um espera — `createdTimestamp`
já vem do Keycloak, então a idade sai de graça — e ordena pelos mais antigos, tornando a limpeza uma
decisão informada e humana.

Automatizar exclusão foi descartado porque o ticket 14 tornou a exclusão **definitiva**, com auditoria
que registra só o fato: seria apagar conta de pessoa real, irreversivelmente, sem ninguém olhando.

### Tela: página dedicada

Lista de Relatórios vazia leva a uma página própria, sem drop-down nem controles inertes — só a
mensagem e o que fazer a respeito. O documento fixa que ele **entra** ("ao logar deve ser exibido…"),
então bloquear no login está fora. Dá ao protótipo do ticket 32 uma tela concreta em vez de um caso
de borda da tela principal.

### Riscos aceitos

1. **Um único service account.** Este é o mais pesado, porque **estreita a camada 1 do ticket 14**.
   Argumentei por dois separados por alçada — `sa-relatorios` sem capacidade de mapear Perfil, e
   `sa-administracao` como único capaz de conceder `GERENTE` — porque o documento exige que o
   ADMINISTRADOR cadastre GERENTEs pela aplicação, e com credencial única essa capacidade fica sempre
   carregada: um bug de autorização na rota do GERENTE basta para autopromoção. Com dois, a falha
   seria **fechada** (403 do Keycloak). Decisão: um só, com a separação inteira na camada 2.
2. **Mensagem única.** O usuário não distingue os dois estados. Contido pelas telas do GERENTE.
3. **Sem e-mail de aviso.** O tempo de espera do RELATOR passa a depender de alguém lembrar de olhar
   o contador. Argumentei por contador **mais** e-mail, com o e-mail como gatilho.
4. **Sem expiração e sem restrição de domínio.** Cadastros pendentes — inclusive não verificados, que
   ficam invisíveis por causa do filtro — acumulam no realm indefinidamente. A limpeza é humana, e
   definitiva.

## Pergunta herdada do ticket 15 (autorização)

**Onde o Perfil vive no Keycloak?** O ticket 01 fixou que `ADMINISTRADOR`/`GERENTE`/`RELATOR` são
conjunto fechado de três valores, no código, não administrável — mas nunca se decidiu **como o
Perfil chega ao JWT**: realm role, client role do client dedicado, ou atributo de usuário.

Isso caiu aqui porque a atribuição acontece no cadastro público, e o Default Group `PENDENTES` é o
lugar natural para o Perfil `RELATOR` ser concedido automaticamente.

Consequências que dependem da resposta:

- O **conversor de authorities** (em `relatorios-comum`) precisa ler Perfil e Roles de Relatório
  **juntos**, de claims possivelmente diferentes. As Roles de Relatório já se sabe que chegam em
  `resource_access.<client>.roles`.
- O **bypass do ADMINISTRADOR** decidido no ticket 15 é avaliado a partir do Perfil, então ele
  precisa estar no token de forma confiável.
- Se o Perfil for concedido via Default Group, **desvincular alguém de todos os Grupos** pode tirar o
  Perfil junto — o que interage diretamente com a modelagem de Pendente de Vínculo deste ticket.

## Notas do ticket 14 (escopo do GERENTE)

- **O GERENTE é global e a exclusão que ele faz é definitiva**, com auditoria que registra só o fato.
  Isso muda o peso de duas sub-perguntas daqui: "expiração de cadastro pendente" e "notificação ao
  GERENTE". Um pendente esquecido está exposto a ser apagado sem recuperação por qualquer GERENTE, e
  não há trilha que permita reconstruí-lo.
- **O `PENDENTES` precisa estar dentro da subárvore administrável** para o FGAP alcançar os
  recém-cadastrados — mas isso o deixa apagável por um GERENTE global. A árvore de Grupos e a
  proteção do `PENDENTES` viraram o **ticket 38**, que depende da modelagem decidida aqui.
- **Toda ação do GERENTE sobre um pendente passa pela mediação da API** e vai para
  `controle.auditoria_admin`, inclusive as recusadas — o que dá, de graça, a resposta para "quem
  vinculou este RELATOR e quando".

## Notas do ticket 38 (árvore de Grupos)

- **A proteção do `PENDENTES` é guarda em código, e é a única** — o override do FGAP foi apresentado e
  recusado (risco aceito registrado no ticket 38). Ela identifica o grupo protegido como **o Default
  Group do realm**, não por nome nem por UUID de configuração, para que rename e rebuild não a quebrem
  em silêncio.
- **Vincular a Grupo sem nenhuma Role de Relatório é recusado.** O vínculo remove a pessoa do
  `PENDENTES` na mesma operação e entregaria zero relatórios — o contador passaria a dizer "resolvido"
  quando nada foi. É a inversão exata do problema que este ticket resolveu ao tornar a remoção
  obrigatória.
- **O contador bruto de membros do `PENDENTES` diverge da tela por construção**, porque a listagem
  filtra `emailVerified` e o contador não. Painel que use o número bruto vai mostrar um valor maior
  que a fila real.
