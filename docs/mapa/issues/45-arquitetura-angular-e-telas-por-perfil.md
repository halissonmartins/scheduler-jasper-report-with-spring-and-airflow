# 45 — Arquitetura interna do Angular e inventário de telas por perfil

Type: grilling
Status: claimed
Blocked by: —

## Question

Como o módulo Angular é organizado por dentro, e quais telas cada Perfil vê?

Graduou da névoa quando o protótipo descartável (ticket 32) e as três decisões de autorização
(tickets 15, 16, 17) fecharam. Antes disso, decidir rotas e guards seria inventar contrato.

Decidir:

- **Módulos e rotas.** Lazy loading por área? Uma rota por Perfil, ou uma árvore com guards? O
  ticket 12 fixou Angular 22.1 **zoneless** e Angular Material — o que muda a estratégia de detecção
  de mudança e o que "estado" significa aqui.
- **Estado.** O ticket 12 registrou que o **NgRx não instala em Angular 22**. Signals puros, um serviço
  com `signal`/`computed`, ou outra biblioteca? A aplicação tem pouco estado compartilhado (drop-down
  encadeado, sessão, inventário) — vale medir antes de importar arquitetura.
- **Guards por role.** O ticket 16 pôs o **Perfil em `realm_access.roles`** e as Roles de Relatório em
  `resource_access`. O guard lê o Perfil; a lista de Relatórios **não** é filtrada no cliente, porque a
  API já filtra (ticket 15). Confirmar que o cliente não reimplementa autorização.
- **Inventário de telas por Perfil** — RELATOR, GERENTE, ADMINISTRADOR. O ticket 32 desenhou quatro
  telas do RELATOR e o ticket 31 fixou 16 caminhos REST; falta o mapa completo, incluindo as telas do
  GERENTE que consultam a Admin API ao vivo (ticket 16) e as do ADMINISTRADOR (cadastro de Produto e
  Relatório, histórico de Download, auditoria).
- **As três variantes do drop-down** do ticket 32 (selects encadeados × árvore × lista filtrada) — qual
  vai para a implementação.
- **Sessão e logout.** O ticket 17 decidiu SPA puro com `angular-auth-oidc-client` e RP-initiated
  logout, sem BFF. Falta: onde o token vive, o que acontece na expiração durante uma exportação
  síncrona (ticket 25), e como a janela de 300 s se manifesta na tela.
- **Erro na tela.** O ticket 26 fixou RFC 9457 com catálogo de dezesseis códigos e Correlation ID.
  Decidir como o `codigo` vira mensagem em pt-BR e onde o Correlation ID aparece para o usuário
  reportar.

## Notas de tickets anteriores

- **Ticket 32**: são **quatro** estados de item, não três — `ALERTA` é baixável e só demorou, então
  precisa parecer diferente de problema. E os dados de teste precisam de janela maior que a retenção,
  senão "expirado" não existe na tela.
- **Ticket 25**: a exportação é **síncrona** e pode devolver `503` quando o semáforo está cheio. A tela
  precisa de um estado de espera e de uma mensagem para `503` que não pareça erro do usuário.
- **Ticket 31**: há **duas assincronias diferentes** — a exportação é síncrona, mas o disparo de Coleta
  é `202`. As duas telas não podem parecer a mesma coisa.
- **Ticket 27**: item marcado como expirado ainda **tenta baixar**, e pode funcionar. A tela não deve
  desabilitar o botão pela marcação.
