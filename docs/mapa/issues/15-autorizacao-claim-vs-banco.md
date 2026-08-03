# 15 — Autorização relatório→role→grupo→usuário: claim no JWT ou consulta ao banco?

Type: grilling
Status: resolved
Blocked by: 01, 07

## Question

Na hora de gerar ou baixar um relatório, a decisão de autorização sai do token ou do banco?

O documento define a cadeia `relatório → role de relatório → grupo de usuários → usuário` e afirma que a Role de Relatório é uma role real do Keycloak e viaja no JWT. Isso tem duas consequências que precisam de decisão explícita:

- **Janela de revogação.** Se a autorização sai da claim, revogar acesso só surte efeito no próximo refresh. Qual a janela aceitável? Qual o TTL do access token e do refresh token? Existe caso em que a revogação precisa ser imediata (ex.: desligamento) e como se resolve.
- **Inflação do token.** Um relator em muitos grupos infla o JWT, com risco de estourar limites de header no Traefik. Qual o teto realista de roles por usuário? Vale um claim mapper seletivo, ou a claim carrega só os grupos e a resolução fina é no banco?
- **Onde a checagem realmente acontece.** Decidir entre: (a) só a claim, (b) só o banco no momento da geração, (c) claim como filtro grosso + banco como autoridade final. A opção (c) é a mais defensável mas duplica a fonte da verdade — decidir quem reconcilia.
- **Listagem × geração.** O drop-down de relatórios disponíveis precisa filtrar pelo que o usuário pode ver. Se isso vem do banco, a claim vira irrelevante para a listagem.
- **ADMINISTRADOR e RELATOR** ambos geram relatórios (regra do documento). O ADMINISTRADOR passa pela mesma cadeia de roles ou tem bypass?

## Notas de research

- **Tickets 07 e 11**: a premissa deste ticket está errada quanto ao alvo. O header que estoura é
  o limite de **8 KB do Spring Boot/Tomcat** (request line + todos os headers somados), não o do
  Traefik, que é de 1 MiB. A folga real vai até cerca de **100 roles** por usuário — bem mais do
  que a análise comportamental sugeria. Além disso, `include.in.token.scope` **não** reduz o
  tamanho do token.
- **Ticket 07**: a janela de revogação default é de **300 s** (TTL do access token). Este ticket
  precisa dizer se 5 minutos é aceitável ou se algum caso exige revogação imediata.

## Notas do ticket 04 (schema de controle)

- **Não há espelho do Keycloak.** Usuário, Grupo e Role de Relatório vivem só lá; o schema de
  controle guarda apenas `relatorio_role_relatorio` (N:N entre Código de Relatório e nome da role
  `REL_*`), que é o único elo da cadeia que o Keycloak não sabe representar.
- **Isso não força a decisão deste ticket.** Tanto "autorizar pela claim" quanto "autorizar por
  consulta" continuam viáveis, porque nos dois casos o passo `Role de Relatório → Relatório` é uma
  consulta local. A diferença fica só no passo `Usuário → Role de Relatório`: pela claim, vem do
  token; por consulta, exige chamada à Admin API do Keycloak — não a uma tabela local, que não
  existe.
- **Consequência a pesar aqui**: escolher "por consulta" significa uma chamada ao Keycloak no
  caminho quente da geração, não um `SELECT`. Isso muda o custo do trade-off contra a janela de
  300 s de forma relevante.
- As **telas do GERENTE** consultam a Admin API ao vivo, então a disponibilidade do Keycloak já é
  requisito de funcionamento dessas telas de qualquer forma.

## Notas do ticket 14 (escopo do GERENTE)

- **As Roles de Relatório são client roles de um client dedicado**, então no JWT elas chegam em
  `resource_access.<client>.roles`, **não** em `realm_access.roles`. O conversor de authorities
  próprio que o research 07 exige precisa ler a claim aninhada correta — errar isso dá autorização
  silenciosamente vazia.
- **O nome carrega a Sigla** (`REL_<SIGLA>_<NOME>`) e cada Role pertence a exatamente um Produto.
  Se este ticket escolher autorizar pela claim, dá para filtrar por Produto **sem tocar no banco**,
  só lendo o nome da role — o que muda o cálculo do trade-off.
- **Nenhuma decisão daqui foi antecipada**: o passo `Role de Relatório → Relatório` continua sendo
  consulta local em `relatorio_role_relatorio` nos dois desenhos.

## Answer

### A premissa do ticket estava larga demais

A cadeia tem **dois** passos, e só um estava em disputa:

1. `Usuário → Roles de Relatório` — domínio do Keycloak. **É a decisão deste ticket.**
2. `Role de Relatório → Relatório` — `SELECT` em `relatorio_role_relatorio`. Idêntico em qualquer
   desenho.

E a opção (b) do enunciado — "só o banco no momento da geração" — **não existia** da forma imaginada:
o ticket 04 decidiu que não há espelho do Keycloak, então "consultar" significava chamada à Admin API
no caminho quente, com custo de rede e de disponibilidade, não custo de query.

### Decisão: só a claim

```
roles   := jwt.resource_access.<client>.roles        (zero I/O)
codigos := SELECT codigo_relatorio
             FROM relatorio_role_relatorio
            WHERE nome_role = ANY(roles)
```

Duas propriedades que vêm junto e são o motivo principal da escolha:

- **Listagem e geração usam a mesma fonte**, logo não podem discordar. O drop-down nunca mostra o
  que a geração vai recusar — o desenho misto (claim para listar, Keycloak para gerar) produziria
  exatamente esse caso de suporte, com divergência visível ao usuário por até 300 s.
- **O Keycloak fica fora do caminho quente.** Uma indisponibilidade dele impede login e refresh, mas
  não impede que quem já tem token válido liste e gere relatórios. No desenho por consulta, uma
  queda do Keycloak derrubaria a funcionalidade central do sistema.

O research 07 e 11 já haviam desarmado o medo que motivava o desenho por consulta: o limite que
estoura é o **8 KB do Tomcat**, não o Traefik (1 MiB), com folga até cerca de **100 roles** por
usuário — bem acima do realista com `REL_<SIGLA>_<NOME>` e cinco Produtos.

**O conversor de authorities lê `resource_access.<client>.roles`, não `realm_access.roles`.** As
Roles de Relatório são client roles de um client dedicado (ticket 14), e o research 07 registrou que
não existe conversor pronto do Spring para claim aninhada. Errar isso não dá erro — dá autorização
silenciosamente vazia. Por isso o conversor vive em `relatorios-comum`, escrito uma vez e usado por
todos.

### Janela de revogação: 300 s

`accessTokenLifespan` no default. Revogar acesso, ou excluir o usuário, leva até 5 minutos para valer.

**O endpoint `/revoke` não encurta isso.** Ele existe e revoga access e refresh tokens, mas um
*resource server* stateless valida a assinatura do JWT offline e nunca pergunta ao Keycloak se aquele
token foi revogado. Só introspecção a cada requisição fecharia a janela — que é precisamente o custo
de caminho quente recusado acima. A doc de token exchange do Keycloak assume isso ao orientar:
*"Administrators should ensure that access tokens have short lifespans and are automatically revoked
after a certain period"*. **O TTL é o mecanismo**, não um paliativo.

**Item de teste de integração, não fato assumido**: excluir um usuário precisa remover a sessão, para
que o refresh falhe. A doc confirma que a verificação do refresh olha a sessão pelo id e falha se ela
foi removida, mas **não localizei afirmação direta de que excluir o usuário remove a sessão**. Se não
remover, um usuário excluído continua renovando o token e a janela deixa de ser limitada a 300 s —
o que invalidaria a proporcionalidade que sustenta esta decisão.

### ADMINISTRADOR: bypass

O Perfil ADMINISTRADOR alcança todos os Relatórios, sem Role de Relatório nenhuma.

Passar pela mesma cadeia inverteria a hierarquia: quem decide o que o ADMINISTRADOR enxerga passaria
a ser o GERENTE, que está abaixo dele. E o ADMINISTRADOR, que é quem cadastra Relatórios, não
conseguiria verificar um Relatório recém-cadastrado sem pedir permissão a um subordinado. Há ainda
um atrito de modelo: Grupo está definido no glossário como "conjunto de usuários de Perfil RELATOR",
então colocar um ADMINISTRADOR num Grupo exigiria mudar o glossário.

A linha de `download` marca quando o acesso veio do Perfil em vez de Role de Relatório, o que torna
"o que os ADMINISTRADORes andaram baixando" consultável sem estrutura nova.

### Riscos aceitos

1. **Janela de 300 s.** Um RELATOR removido de Grupo — ou excluído — mantém acesso por até 5 minutos.
   Aceito por proporcionalidade: o ativo são relatórios coletados diariamente, e quem perde acesso
   poderia tê-los baixado no minuto anterior. Depende do item de teste acima para permanecer válido.
2. **Sem guarda contra estouro de cabeçalho.** Argumentei por elevar
   `server.max-http-request-header-size` e emitir métrica de roles por token, porque essa falha
   acontece **antes** de qualquer código da aplicação rodar: o Tomcat rejeita a requisição sem
   filtro, sem MDC, sem Correlation ID, sem log da aplicação e sem a mensagem padronizada do ticket
   26 — o diagnóstico parte do zero. Decisão: apenas documentar o teto de ~100 roles. A folga é real;
   abre-se mão do aviso prévio.

### Lacuna que este ticket revelou

**Onde o Perfil vive no Keycloak não está decidido em lugar nenhum** — realm role, client role ou
atributo de usuário. O ticket 01 fixou que é conjunto fechado de três valores e não administrável,
mas não como ele chega ao JWT. O conversor de authorities precisa lê-lo **junto** com as Roles de
Relatório, e o bypass do ADMINISTRADOR depende dele. Encaminhado ao ticket 16, que é dono do cadastro
público e do Default Group onde a atribuição naturalmente acontece.
