# 17 — Sessão, logout e exposição seletiva do Keycloak

Type: grilling
Status: resolved
Blocked by: 07, 11

## Question

Como uma sessão termina de verdade, e o que do Keycloak fica exposto?

O documento lista sign in / sign out e diz que o Account Console e a página de registro (com tema customizado) serão expostos seletivamente pelo Traefik para troca de senha e cadastro. A análise comportamental levanta dois problemas:

- **Logout só no frontend deixa a sessão viva no Keycloak.** Decidir: RP-initiated logout (redirect para o `end_session_endpoint`), back-channel logout, ou ambos. Definir o que acontece com um access token ainda válido depois do logout — ele continua funcionando até expirar? Qual TTL torna isso aceitável.
- **Exposição seletiva por rota é granularidade grossa.** Filtrar paths no Traefik é frágil: o Account Console tem muitas rotas e o Keycloak muda paths entre versões. A alternativa é desabilitar as demais features **no realm** e deixar o Traefik só publicar o host. Decidir qual caminho, sabendo que o research 07 e o 11 trazem os fatos.
- **Sessões concorrentes.** Um usuário pode estar logado em dois navegadores? Existe limite?
- **Troca de senha.** Todos os tipos de usuário podem trocar a senha (regra do documento). Isso acontece no Account Console ou numa tela própria da aplicação que chama a Admin API mediada?

## Notas de research

- **Ticket 12**: **back-channel logout é impossível num SPA** — a especificação exige um endpoint
  HTTP no relying party, que um app de página única não tem. Sobra `logoff()` RP-initiated mais um
  TTL curto de access token. Tornar o back-channel logout requisito duro implicaria adotar um BFF,
  o que muda a arquitetura do frontend. Este ticket precisa decidir entre as duas coisas, e a
  decisão tem custo real.

- **Ticket 07**: back-channel logout no Spring Security exige `oauth2Login` **com sessão de
  servidor**; num SPA com resource server stateless não existe sessão a invalidar. Confirma o
  achado do ticket 12 por outro caminho.
- **Ticket 07**: o Admin Console **não pode ser desligado por realm** sem matar junto a Admin API
  — da qual o ticket 14 depende. Logo o filtro de `/admin/**` no Traefik deixa de ser opcional.
- **Ticket 11**: `/realms/` é **obrigatoriamente exposto** para o OIDC funcionar, e é sob ele que
  ficam tanto o Account Console quanto o registro. Não existe recorte por rota que isole "só" os
  dois — mas o Keycloak publica um blueprint Traefik oficial com routers público/interno. A
  recomendação é usar as duas camadas (filtro de rota **e** features desabilitadas no realm), não
  escolher uma.
- **Ticket 07**: o import de realm é **semente, não configuração declarativa** — é pulado se o
  realm já existe. Isso afeta o processo de operação, não só o bootstrap.

## Notas do ticket 14 (escopo do GERENTE)

- **O filtro de `/admin/**` no Traefik deixou de ser defesa em profundidade e virou requisito.** O
  ticket 14 fixou que o GERENTE nunca recebe credencial do Keycloak e que toda ação passa pela
  mediação da API — o que só se sustenta se o Admin Console for inalcançável de fora. O research 07
  já registrou que ele **não pode** ser desligado por realm, então a rota é a única alavanca.
- **A janela de revogação importa mais aqui do que parecia.** Com o GERENTE global e a exclusão
  definitiva, um RELATOR apagado continua com access token válido até `exp`. Este ticket precisa
  dizer o que acontece nesse intervalo — a API valida o token contra um usuário que não existe mais,
  e o comportamento tem de ser deliberado, não acidental.

## Answer

### Logout: SPA puro, RP-initiated

`logoff()` do `angular-auth-oidc-client` redireciona ao `end_session_endpoint`. A sessão do Keycloak
é encerrada **imediatamente** e o refresh para de funcionar na hora; só o access token sobrevive, até
`exp`.

Essa janela residual é a **mesma** de 300 s que o ticket 15 já aceitou, pela mesma razão — e na
prática o token sai da memória da página no redirect.

**O BFF foi considerado e recusado.** Back-channel logout é impossível num SPA puro: a especificação
exige um endpoint HTTP no relying party, e o research 07 confirma pelo outro lado que no Spring
Security ele exige `oauth2Login` com sessão de servidor. Torná-lo requisito duro significaria adotar
um BFF, o que traria ganho real além do logout (o token nunca chegaria ao JavaScript), mas reverteria
a arquitetura do ticket 12, acrescentaria componente ao Compose e recolocaria sessão de servidor num
desenho que o ticket 15 deixou stateless de ponta a ponta.

### Exposição: allowlist, e caminho interno para a Admin API

Duas camadas, como os research 07 e 11 recomendam — filtro de rota **e** features desabilitadas no
realm, não uma ou outra.

**A parte que se resolve por derivação**: Admin API e Admin Console moram os dois sob `/admin/`.
Bloquear esse prefixo no Traefik deixaria o ticket 14 sem Admin API — a menos que a **API REST fale
com o Keycloak pela rede interna do Compose**, sem passar pelo Traefik. É o desenho de routers
público/interno que o próprio blueprint Traefik do Keycloak prevê, e é o que torna o bloqueio viável.

**Rota pública (allowlist):**

```
/realms/{realm}/protocol/openid-connect/*
/realms/{realm}/login-actions/*
/realms/{realm}/account/*
/realms/{realm}/.well-known/*
/resources/**                              (tema customizado)
```

Tudo o mais devolve 404 no Traefik.

Allowlist e não denylist porque as duas **falham em direções opostas**: uma versão nova do Keycloak
que introduza rota administrativa nova nasce bloqueada na allowlist, e nasce publicada na denylist —
sem nada quebrar, logo sem ninguém perceber. O preço da allowlist é que uma rota de login nova quebra
o fluxo, o que é barulhento mas visível. Como a mediação obrigatória do ticket 14 depende do Admin
Console ser inalcançável, falhar fechado é o comportamento certo.

### Troca de senha: Account Console enxugado

Reduzido pela remoção de `view-groups` e `delete-account` das default roles (research 07), com tema
customizado, e já contemplado na allowlist acima.

O argumento decisivo não é conveniência. **Tela própria exigiria dar à aplicação a capacidade de
redefinir senha** — `manage-users` / `reset-password` —, que é exatamente a permissão que o research
07 identificou como escalonamento (permite resetar a senha de qualquer usuário do realm, inclusive
ADMINISTRADORes) e que o ticket 14 organizou a camada 1 inteira para nunca conceder. E com service
account único (ticket 16), essa capacidade ficaria disponível a **todas** as rotas da API.

No Account Console o usuário se autentica a si mesmo: não existe intermediário com poder sobre senha
alheia em lugar nenhum do sistema. Isso não fere o princípio de mediação do ticket 14, que trata do
GERENTE agindo sobre **terceiros** — self-service sobre a própria conta é outra coisa.

### Sessões concorrentes: sem limite

O mesmo usuário pode estar logado em quantos navegadores quiser.

Limitar exigiria customização de authentication flow, e o research 07 registrou que o **import de
realm é semente, não configuração declarativa** — é pulado se o realm já existe. Toda customização de
fluxo vira configuração viva, reproduzida à mão em cada ambiente. Em troca de atrito real para quem
usa desktop e celular, e sem impedir compartilhamento sequencial.

Compartilhamento de credencial fica no terreno da **detecção**: `controle.download` já grava quem
baixou o quê e quando.

### A pergunta herdada do ticket 14

**Token de usuário já excluído: a API serve normalmente até `exp`.**

Isso é deliberado, e é consequência direta do ticket 15. Como a autorização sai **só da claim**, a API
não tem como saber que o usuário sumiu sem consultar o Keycloak no caminho quente — precisamente o
custo recusado lá. A janela é a mesma de 300 s, e o refresh já falha imediatamente.

O registro sobrevive: o histórico de Download é fotografia denormalizada (ticket 04), então continua
legível mesmo apontando para um `sub` que não existe mais.

### Consequência para outros tickets

Tirar o Keycloak do caminho quente tem um corolário que o **ticket 28** precisa absorver: o
`readiness` da API **não deve depender do Keycloak**. O JWKS é cacheado, e uma indisponibilidade do
Keycloak impede login e refresh — mas não impede quem já tem token válido de listar e gerar
relatórios. Amarrar readiness ao Keycloak tiraria de operação instâncias que estão perfeitamente
capazes de trabalhar.
