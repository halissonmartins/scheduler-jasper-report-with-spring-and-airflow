# 27 — Angular: shell, OIDC e a tela do RELATOR

**O que construir:** a primeira tela de verdade. O relator entra, vê numa lista única e filtrável
tudo o que pode baixar, clica e recebe o arquivo. Quem não tem acesso a nada cai numa página própria
que explica o que falta — porque lista vazia é **estado, não erro**.

**Bloqueado por:** 15, 16.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Login e logout iniciados pelo cliente, sem BFF. A sessão do provedor morre na hora e o refresh
      para; só o token de acesso sobrevive até expirar, e essa janela residual é a mesma já aceita.
- [ ] Rotas em áreas lazy com o guard no **nó pai**, declarado uma vez: é a forma allowlist, e tela
      nova dentro da área herda proteção. Fica escrito que **o guard não é controle de acesso** —
      quem autoriza é a API, e o preloader baixa chunk sem rodar guard.
- [ ] O drop-down é uma **lista única filtrável**, não selects encadeados nem árvore: a resposta vem
      numa chamada só e os quatro estados de item precisam ser comparáveis lado a lado.
- [ ] Os **quatro** estados de item são visualmente distintos, e o que só demorou **não parece
      problema** — ele é perfeitamente baixável.
- [ ] O download é por requisição autenticada com blob, não por link nativo: um link não mandaria o
      cabeçalho de autorização e exigiria URL assinada, que é justamente o que a exportação síncrona
      fechou. O objeto de URL é liberado depois do uso.
- [ ] A espera tem **estado visível** — sem progresso nativo e com a recusa por capacidade como
      desfecho possível, uma tela parada é indistinguível de travada.
- [ ] A mensagem de erro **vem da API** e a tela apenas mostra. O front mapeia o código só para
      **comportamento**: permanente não convida a repetir, transitório convida. Um catálogo próprio
      divergiria no primeiro código novo e não conheceria o contexto.
- [ ] Correlation ID visível e copiável em toda tela de erro.
- [ ] O selo de expirado diz a **data real**, e o botão **não** é desabilitado pela marcação — a
      exportação tenta assim mesmo.
- [ ] O cliente **não refiltra** a listagem: a API já filtrou pela claim, e refiltrar reimplementaria
      autorização onde ela não vale.
- [ ] Estado por signals num serviço raiz, sem biblioteca externa de estado.
