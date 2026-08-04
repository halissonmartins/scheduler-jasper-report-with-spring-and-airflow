# 21 — Mediação do Keycloak: Roles, Grupos e `PENDENTES`

**O que construir:** o GERENTE trabalha sem nunca tocar o provedor de identidade. Ele vê a fila de
quem se cadastrou, cria Roles no padrão, monta Grupos e vincula pessoas — tudo pela API, que
intermedeia com um service account de escopo mínimo. É o maior risco de segurança do sistema, e a
auditoria é o controle compensatório.

**Bloqueado por:** 03, 14.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O GERENTE **nunca** recebe credencial do provedor, e a API nunca repassa a Admin API crua. O
      service account recebe o mínimo — **nunca a permissão de gerenciar usuários do realm**, que
      permite resetar a senha de qualquer um, inclusive de um ADMINISTRADOR.
- [ ] Toda ação vira linha de auditoria denormalizada, **inclusive as recusadas**: com alçada global,
      é a única evidência possível de alguém tateando a fronteira.
- [ ] Nome de Role fora do padrão é recusado; Role que atravessaria Produtos é recusada.
- [ ] `CO-PENDENTES-FILTRA-EMAILVERIFIED` — cadastro não verificado **não** aparece na listagem.
      Cadastros entram no grupo padrão na criação e a verificação bloqueia só o login; sem o filtro,
      exigir verificação não protege a lista de nada.
- [ ] Vincular a um Grupo **remove do grupo de pendentes na mesma operação**. O provedor não remove
      de grupo padrão sozinho, e sem isso o contador — único sinal que existe — mente para sempre.
- [ ] `CO-VINCULACAO-INCOMPLETA` — entrou no Grupo e a remoção falhou é **reportado**, não sucesso
      silencioso. São dois requests que precisam parecer um; testar o caminho de falha, não só o
      feliz.
- [ ] `CO-VINCULO-SEM-ROLE` — vincular alguém a Grupo sem Role alguma é recusado: apagaria o sinal de
      que a pessoa esperava e entregaria zero relatórios.
- [ ] `CO-RECUSA-APAGAR-DEFAULT-GROUP` — recusado **pela guarda**, provadamente. Um teste que só
      verifique "a chamada falhou" passa igual no dia em que a guarda sumir e outra coisa recusar por
      acaso. A guarda identifica o grupo como **o grupo padrão do realm**, não por nome nem UUID.
- [ ] `CO-GRUPO-FILHO-DA-RAIZ` — Grupo criado é sempre filho direto da raiz. A planura é imposta, não
      convencionada: o provedor herda concessões de pai para filho, e profundidade mudaria alcance
      efetivo em silêncio.
- [ ] `CO-DEPENDENCIAS-PENDENTES` — o indicador de dependências cai quando o grupo de pendentes deixa
      de ser o grupo padrão. Conferência **somente leitura** no boot.
- [ ] `CO-CAMINHO-INTERNO-ADMIN-API` — a API alcança a Admin API pela rede interna. Apontá-la para o
      host público faz a mediação inteira parar de funcionar.
- [ ] `CO-EXCLUSAO-REMOVE-SESSAO` — excluir um usuário remove a sessão e o refresh falha. **A
      proporcionalidade da janela de revogação depende disso**: se não remover, um usuário excluído
      segue renovando o token indefinidamente.
- [ ] O contador de pendentes é a única notificação que existe — não há e-mail de aviso, e o contador
      bruto diverge da tela por construção, porque a listagem filtra e ele não.
