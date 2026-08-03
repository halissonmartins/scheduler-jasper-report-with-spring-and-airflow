# 14 — Escopo do GERENTE e mediação da Admin API do Keycloak

Type: grilling
Status: resolved
Blocked by: 01, 07

## Question

Até onde vai o poder de um GERENTE, e como a aplicação impede que ele escape do domínio de relatórios?

Este é o maior risco de segurança do documento. "O GERENTE cadastra roles do tipo RELATORIO" implica chamar a Admin API do Keycloak. Se a aplicação repassar essa capacidade sem mediação, um GERENTE cria ou atribui roles fora do domínio de relatórios — escalonamento de privilégio direto.

Decidir:

- **Mediação obrigatória.** A aplicação intermedeia toda chamada à Admin API com um service account de escopo mínimo, e o GERENTE nunca recebe credencial do Keycloak. Confirmar e escrever quais operações são expostas.
- **Namespace de roles.** Validar prefixo obrigatório (ex.: `REL_`) em toda criação e todo vínculo, recusando qualquer nome fora do namespace. Definir o prefixo e onde a validação vive.
- **Escopo do GERENTE.** A regra impede criar outro GERENTE, mas nada limita **quais** grupos e **quais** RELATORes ele administra — na prática todo GERENTE é global e pode excluir qualquer RELATOR do sistema. Decidir: aceitar GERENTE global (e registrar como risco), ou introduzir um escopo (por produto? por conjunto de grupos?).
- **Auditoria.** Toda operação de concessão/revogação é registrada com autor, alvo, motivo e Correlation ID?
- **Remoção de RELATOR.** "Exclusão dos usuários do tipo RELATOR" apaga do Keycloak, desativa, ou só desvincula? O histórico de downloads dele sobrevive.

## Notas de research

- **Ticket 07**: `manage-users` permite **resetar a senha de qualquer usuário, inclusive
  ADMINISTRADORes** (`UserPermissions.canManage`). Conceder isso ao service account que media as
  ações do GERENTE é escalonamento direto de privilégio.
- **Ticket 07**: o FGAP v2 **não delega criação de role** — o tipo `Roles` só expõe escopos
  `map-role*`. Consequência de peso para este ticket: a Role de Relatório deve ser **client role
  de um client dedicado**, o que permite escopar `Clients:manage` a esse único client em vez de
  conceder `manage-realm`. Isso torna o prefixo `REL_` uma segunda camada, não a única fronteira.

## Answer

### Duas camadas, e o Keycloak só resolve uma

O ticket tratava "escopo do GERENTE" e "escopo do service account" como uma coisa só. São duas, e a
distinção decide o que é configuração e o que é código:

- **Camada 1 — FGAP sobre o service account.** É *uma* identidade que a API usa para **todas** as
  ações de **todos** os GERENTEs. Limita o que a aplicação inteira consegue fazer no Keycloak. Para
  o Keycloak, toda ação vem daqui — ele não distingue qual GERENTE a originou.
- **Camada 2 — autorização na API REST.** Limita *este* GERENTE. Não é delegável ao Keycloak por
  construção; se existir escopo por GERENTE, ele é dado e lógica da aplicação.

A camada 1 limita o estrago de um **bug**. A camada 2 limita o estrago de um **usuário legítimo
agindo fora da sua alçada**. Uma não substitui a outra.

### Camada 1 — mediação obrigatória

O GERENTE **nunca** recebe credencial do Keycloak, e a API REST nunca repassa a Admin API crua. FGAP
v2 habilitado no realm (switch *Admin Permissions*), e o service account recebe **apenas**:

| Permissão | Escopo |
|---|---|
| `Clients:manage` | apenas o client dedicado `relatorios` |
| `Groups:manage`, `Groups:manage-membership` | subárvore de grupos de relatório |
| `Roles:map-role` | por role |
| `Users:view` / `Users:manage` | derivadas de `view-members` / `manage-members` sobre os grupos de relatório |

**Nunca `manage-users`, nunca `manage-realm`.** O research 07 mostrou que `manage-users` permite
resetar a senha de qualquer usuário do realm, inclusive ADMINISTRADORes (`UserPermissions.canManage`
retorna `true` para todo usuário) — com ele, uma falha de validação na mediação deixa de ser "role
indevida criada" e vira comprometimento total do realm.

A criação da role em si não é delegável — o FGAP v2 não tem escopo `manage` no tipo `Roles` — e é
por isso que a Role de Relatório é **client role de um client dedicado**: permite escopar
`Clients:manage` àquele único client em vez de conceder `manage-clients` ou `manage-realm`.

### Camada 2 — alçada do GERENTE: global

Todo GERENTE administra todos os Produtos. Risco aceito, e ele é **lateral**, não vertical: o gerente
que cuida de Poupança consegue conceder acesso aos relatórios de Empréstimo, mas continua sem
alcançar ADMINISTRADOR, outro GERENTE, outro client ou reset de senha — isso é barrado pela camada 1
e pela regra de que GERENTE não cria GERENTE.

### Namespace: uma Role de Relatório pertence a um Produto

`relatorio_role_relatorio` é N:N, então nada impedia uma Role que atravessasse Produtos. Fica
decidido que **não atravessa**: toda Role de Relatório pertence a exatamente um Produto, com
constraint garantindo que todos os seus Relatórios sejam do mesmo Produto.

Formato do nome: **`REL_<SIGLA>_<NOME>`** — `REL_POUPANCA_GERENCIAL`, `REL_EMPRESTIMO_CONTRATOS`.

Nada se perde em expressividade: como Grupo → Role de Relatório também é N:N, acesso multiproduto se
faz vinculando o Grupo a várias Roles. E ganha-se duas coisas: a auditoria fica legível sem join
(dá para ver que alguém saiu do próprio domínio só lendo o nome), e a alçada por Produto — recusada
acima — fica acrescentável depois **sem renomear role nenhuma**.

O client dedicado é a fronteira **estrutural**; o prefixo é a **segunda camada**, validada na
mediação. Nome fora do padrão é recusado e o próprio registro de recusa vai para a auditoria.

### Auditoria — o controle compensatório

Com GERENTE global, a auditoria deixa de ser desejável e passa a ser o controle principal.
Tabela `controle.auditoria_admin`, **denormalizada** pelo mesmo motivo do histórico de Downloads
(ticket 04): usuários, Grupos e Roles podem ser apagados do Keycloak, e um registro que dependa de
join morre junto.

Registra autor (sub + nome na época), ação, alvo (tipo + nome na época), resultado, motivo da recusa
quando houver, Correlation ID e instante. **Tentativas recusadas entram** — num modelo de GERENTE
global, é a única evidência possível de alguém tateando a fronteira. O log estruturado no Graylog
continua saindo, com o mesmo Correlation ID.

### Remoção de RELATOR

O GERENTE **apaga do Keycloak** (`DELETE /admin/realms/{r}/users/{uid}`), e a linha de auditoria
registra apenas o fato — autor, alvo (sub e username), instante, Correlation ID — sem e-mail, nome
ou lista de Grupos.

Isso é seguro do lado dos dados: o histórico de Downloads é fotografia (ticket 04), então não sobra
linha órfã. E a camada 1 garante que o alcance é só quem está nos grupos de relatório — nenhum
GERENTE apaga ADMINISTRADOR ou outro GERENTE por essa via.

O que fica exposto está registrado abaixo.

### Riscos aceitos

1. **GERENTE global.** Argumentei por alçada por Produto: o Produto já é a fronteira de tudo no
   sistema — schema transacional, credencial de banco, Sigla, módulo — e, como o nome da role passou
   a carregar a Sigla, a alçada ficaria acrescentável depois sem migração de nomes. Decisão: global.
   Exposição: qualquer GERENTE concede acesso a relatórios de qualquer Produto.
2. **Exclusão definitiva pelo GERENTE.** Argumentei por desativação (`enabled=false` + remoção dos
   Grupos), com expurgo reservado ao ADMINISTRADOR, porque uma ação reversível transforma a auditoria
   em controle; irreversível, ela vira laudo. Decisão: apaga. Exposição: um GERENTE pode apagar
   RELATORes em massa, sem desfazer possível.
3. **Auditoria mínima na exclusão.** Argumentei por fotografia dos vínculos (username, e-mail, nome,
   lista de Grupos), o que tornaria uma exclusão equivocada recuperável em minutos. Decisão: só o
   fato. Exposição: ninguém sabe a que Grupos a pessoa pertencia; a reconstrução é de memória.

Os riscos 2 e 3 **se compõem com o 1** — é a combinação, não cada um isolado, que merece revisão se
o modelo de confiança sobre os GERENTEs mudar.

## Notas do ticket 38 (árvore de Grupos)

- **Correção**: "`Groups:manage` restrito à subárvore de grupos de relatório" **não é expressável**. O
  FGAP v2 escopa por lista de UUIDs de recurso ou pelo tipo inteiro — não existe noção de ramo da
  árvore (apurado na doc do Keycloak, `fine-grain-v2.adoc`). A permissão fica por
  `resourceType: Groups` **sem** `resources`.
- **E isso é melhor do que a lista de UUIDs seria**: alcança automaticamente todo Grupo que o GERENTE
  criar. Manter uma lista exigiria, a cada criação, um segundo passo registrando o Grupo como recurso
  — não atômico, e um Grupo cuja permissão falhasse ficaria inadministrável.
- **A auditoria ganha um prefixo estável**: todo Grupo do sistema é filho direto de `/relatorios`, e a
  planura é imposta pela mediação, não convencionada.
