# 14 — Identidade: realm semente e resource server

**O que construir:** o usuário consegue entrar, e a API sabe quem ele é e o que ele alcança. O realm
sobe semeado com o client dedicado, os três Perfis e o ADMINISTRADOR inicial; a API valida o token e
concede autoridade pela role certa. O modo de falha aqui é **autorização silenciosamente vazia** —
não exceção.

**Bloqueado por:** 03.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O Keycloak sobe no Compose com tag fixada, o realm semeado, o client dedicado e o
      ADMINISTRADOR inicial com senha vinda de variável de ambiente.
- [ ] O **Perfil** é realm role (conjunto fechado de três, não administrável) e a **Role de
      Relatório** é client role do client dedicado, no padrão que carrega a Sigla do Produto. Os dois
      eixos ficam separados na origem.
- [ ] `CO-CONVERSOR-AUTHORITIES-POSITIVO` — a Role de Relatório certa **concede**, lida da claim
      aninhada. Um teste que só verifique "403 quando não autorizado" passa mesmo com o conversor
      quebrado; é preciso o caso positivo.
- [ ] `CO-CONVERSOR-PERFIL-REALM-ROLE` — o Perfil é lido da claim de realm, com o mesmo modo de falha
      silencioso, e é dele que depende o bypass do ADMINISTRADOR.
- [ ] O import de realm é tratado como **semente, não configuração declarativa** — ele é pulado se o
      realm já existe, e isso é registrado como consequência de operação, não detalhe de bootstrap.
- [ ] A API é resource server stateless. O Keycloak fica fora do caminho quente e **fora do
      readiness**: uma queda dele impede login e refresh, mas não impede quem já tem token de
      trabalhar.
