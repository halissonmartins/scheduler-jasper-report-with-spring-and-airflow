# 30 — Ingress e e-mail: Traefik e Mailpit

**O que construir:** o que fica exposto ao mundo, e o caminho pelo qual alguém de fora vira usuário.
A exposição do provedor de identidade é por **allowlist**, que falha fechada — uma rota
administrativa nova numa versão futura nasce bloqueada, em vez de nascer publicada sem nada quebrar
e portanto sem ninguém perceber.

**Bloqueado por:** 14.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Traefik com allowlist publicando apenas os caminhos públicos do provedor — protocolo, ações de
      login, console de conta e recursos do tema. Tudo o mais devolve 404 na borda.
- [ ] Duas camadas, não uma: filtro de rota **e** features desabilitadas no realm.
- [ ] A API fala com a Admin API pela **rede interna**, sem passar pela borda — sem isso, bloquear o
      prefixo administrativo mataria a mediação junto.
- [ ] `CO-ALLOWLIST-TRAEFIK-FLUXOS` — login, cadastro público, verificação de e-mail e troca de senha
      passam. A allowlist falha fechada por decisão, e é isso que exige o teste de navegador: uma
      rota nova quebra o fluxo, o que é o comportamento desejado, mas só ajuda se alguém descobrir no
      CI e não em produção.
- [ ] `CO-CADASTRO-DISPARA-VERIFICACAO` — o cadastro público gera o e-mail de verificação, conferido
      no Mailpit de pé.
- [ ] **Só o provedor dispara e-mail, e só dois**: verificação de endereço e redefinição de senha. A
      API **não fala SMTP** — não ganha modo de falha novo nem entra no readiness.
- [ ] O Mailpit **captura em vez de entregar**, então o cadastro deixa de ser autoserviço: fica
      registrado no runbook que um operador abre a UI, acha o link e repassa.
- [ ] A UI do Mailpit entra na allowlist **com autenticação própria** e volume persistente — ela
      contém links de verificação e redefinição em texto claro, e é porta de tomada de conta. Sem
      volume, um restart apaga links pendentes e quem esperava recomeça do zero.
- [ ] O assunto do e-mail carrega **para quem é** e **qual a ação**, não marca: quem lê é o operador
      varrendo a caixa.
- [ ] Traefik configurado por **arquivo estático**, não por descoberta via socket do Docker — o
      orquestrador precisa do socket, a borda não, e acesso a ele equivale a root no host.
