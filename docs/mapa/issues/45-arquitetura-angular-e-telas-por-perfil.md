# 45 — Arquitetura interna do Angular e inventário de telas por perfil

Type: grilling
Status: resolved
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

## Answer

### O quadro

| | |
|---|---|
| Drop-down | **variante C** — lista única com filtros |
| Rotas | áreas lazy com **`canMatch` no nó pai** |
| Download | **`HttpClient` com `responseType: 'blob'`** |
| Mensagem de erro | **vem da API**; o front mapeia `codigo` só para comportamento |

### Variante C, e por que a hierarquia não se paga

O ticket 32 construiu as três e deixou a escolha aberta. Fica a **lista única filtrável**.

Três fatos do mapa apontam para ela: a resposta vem numa **chamada só** (`/execucoes-disponiveis`,
~70 linhas, ticket 31); são **quatro** estados de item que precisam ser comparáveis lado a lado
(ticket 32); e o relator típico tem acesso a poucos Relatórios — hierarquia de três níveis sobre um
punhado de linhas é cerimônia. Em Angular Material é uma `MatTable` com filtro, não um componente
próprio.

Os selects encadeados espelhariam o texto do documento, mas escondem os quatro estados atrás da última
seleção — o relator não vê que há item expirado até chegar nele. A árvore era o meio-termo mais
informativo, e custaria o componente mais caro de manter (CDK tree) para um conjunto que cabe numa
tela.

### Rotas: `canMatch` no pai, e o que ele **não** é

```
/relatorios   → loadChildren, canMatch: [ehRelator]
/gestao       → loadChildren, canMatch: [ehGerente]
/admin        → loadChildren, canMatch: [ehAdministrador]
```

O guard fica no **nó pai**, declarado uma vez, e toda tela criada dentro da área **herda proteção**.
É a forma allowlist — a mesma razão pela qual o ticket 17 escolheu allowlist no Traefik: o que nasce
depois nasce coberto. Rotas planas com `canActivate` por tela seriam denylist, e a tela nova nasceria
desprotegida até alguém lembrar.

`canMatch` em vez de `canActivate` porque ele roda **antes** do match — apurado na fonte do router:

> `runCanMatchGuards` … em `matchWithChecks`, *"only an exact `true` value is treated as a match —
> everything else … results in the route being skipped"*. Já o `canActivate` roda depois do
> `recognize`, ou seja, com o chunk lazy já carregado.

> **Mas o guard não é controle de acesso, e isso precisa estar escrito.** Quem autoriza é a API
> (ticket 15). E o **preloader ignora guards**: `preloadConfig` baixa o chunk sem rodar guard nenhum a
> menos que `canLoad` esteja definido — então, com estratégia de preload ligada, o bundle do `/admin`
> chega ao navegador do RELATOR de qualquer forma. O ganho do `canMatch` é **bytes na navegação**, não
> segurança.

Um shell por Perfil na raiz foi recusado por um motivo concreto: o ticket 16 pôs o Perfil como
**realm role**, e nada impede um usuário de ter dois. A raiz teria de escolher um, e escolher errado
esconderia metade do sistema sem erro algum.

### Download: blob, porque a alternativa reabre o que o ticket 25 fechou

A exportação é síncrona e devolve bytes. Um `<a download>` faria o navegador transmitir direto para o
disco, com progresso nativo — e **não mandaria `Authorization`**. Isso exigiria sessão por cookie ou
URL assinada, e o ticket 25 fechou essa porta ao dissolver a autorização em dois instantes: não há
link temporário sobrevivendo à revogação.

Então `HttpClient` com `responseType: 'blob'`, o interceptor do `angular-auth-oidc-client` aplicando o
token como em toda outra chamada — um caminho de autenticação só.

Um service worker injetando o header juntaria os dois mundos, e foi recusado por trazer ciclo de vida,
versionamento e cache próprios a um app que não é offline-first.

Consequências a escrever:
- **`URL.revokeObjectURL` depois do uso**, senão o blob fica retido pela vida da aba.
- **O arquivo passa inteiro pela memória do navegador.** O maior é o `CONTACORRENTE-0001` (ticket 42),
  o que liga esta decisão ao dimensionamento do ticket 49.
- **A espera precisa de estado visível**: sem progresso nativo, e com o `503` do semáforo (ticket 25)
  como desfecho possível, uma tela parada é indistinguível de travada.

### Erro: um catálogo só, no lado que conhece o contexto

O `detail` do `ProblemDetail` (RFC 9457, ticket 26) já vem em pt-BR e a tela apenas mostra. O front
mapeia o `codigo` somente para **comportamento**, e o ticket 32 já achou a distinção que importa:
`EXPORTACAO_INDISPONIVEL` é permanente e **não** deve convidar a tentar de novo; o `503` é transitório
e deve.

Um catálogo próprio no front permitiria redação de tela e i18n sem tocar no backend, e criaria dois
catálogos que divergem no primeiro código novo — além de não saber o contexto: diria "limite excedido"
onde a API diz qual limite e de quanto.

**Correlation ID visível e copiável em toda tela de erro** (ticket 32) — é o que o usuário passa ao
suporte.

### Inventário de telas por Perfil

**`/relatorios` — RELATOR**
- Listagem filtrável de Execuções disponíveis (variante C), com os quatro estados de item.
- Página dedicada de **"sem acesso"**: lista vazia é **estado, não erro** (tickets 31 e 32).

**`/gestao` — GERENTE**
- Fila do `PENDENTES` — a **única** superfície que revela quem está esperando (tickets 16 e 38).
- Vinculação de RELATOR a Grupo — recusada quando o Grupo não tem Role alguma (ticket 38).
- Gestão de Grupos e das Roles de Relatório vinculadas a eles.
- Usuários dentro da alçada, consultando a Admin API ao vivo (ticket 16).

**`/admin` — ADMINISTRADOR**
- Cadastro de Produto, com a Sigla **imutável** (ADR 0001) e o `cron` (ticket 39).
- Cadastro de Relatório: Código validado contra o inventário, nome, descrição e `tempo_estimado`
  pré-preenchido pela sugestão do bean (ticket 21).
- **Inventário publicado**, mostrando cadastrado-não-publicado e publicado-não-cadastrado (ticket 04).
- Histórico de Execuções com **`refazer` e `reprocessar` como dois botões**, e o servidor decidindo
  qual vale (ticket 20) — as duas telas não podem parecer a mesma coisa.
- Histórico de Download (fotografia denormalizada, ticket 04).
- Auditoria administrativa, que registra também as **recusas** (ticket 14).
- Usuários GERENTE e ADMINISTRADOR.

### Derivado

- **O cliente não filtra a listagem.** A API já filtrou pela claim (ticket 15); refiltrar no front
  reimplementaria autorização onde ela não vale, e divergiria dela em silêncio.
- **Estado**: serviço `providedIn:'root'` com signals e `httpResource`, mais o `SessionStore` global —
  já fixado no ticket 12, incluindo o motivo de o NgRx estar fora (peer de `@angular/core: ^21.0.0`,
  não instala em Angular 22).
- **Token expirando durante a exportação não quebra a requisição em voo** — o resource server valida na
  entrada. O risco é o clique seguinte: o interceptor trata `401` levando ao re-login e preservando a
  URL de retorno.
- **A janela de 300 s do ticket 17 não tem representação na tela.** Não há o que mostrar, e inventar um
  aviso sugeriria um controle que não existe.
- **O selo de expirado diz a data real** (`expirado em 31/07/2026`), nunca "7 dias" — o arredondamento é
  em UTC e a Data de Referência é de São Paulo (tickets 03 e 32). E o botão **não** é desabilitado pela
  marcação: a exportação tenta assim mesmo (ticket 27).
