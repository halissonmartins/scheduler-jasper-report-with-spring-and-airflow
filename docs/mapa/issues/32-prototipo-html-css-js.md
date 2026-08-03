# 32 — Protótipo HTML/CSS/JS descartável

Type: prototype
Status: resolved
Blocked by: 01, 31

## Question

Como as três telas mais incertas se comportam de verdade?

Fase inicial do documento: prototipação usando somente HTML, CSS e JavaScript, descartável. O documento nomeia as três funcionalidades a prototipar — todas com decisões de comportamento que texto não resolve.

Construir (use `/prototype`):

- **Drop-down de relatórios disponíveis**: `dd/MM/yyyy` → nome do produto → código do relatório. Perguntas que o protótipo tem de responder: são três selects encadeados ou uma árvore? Datas sem relatório aparecem? Como se mostra um item expirado (ticket 27)? Onde o usuário escolhe o formato de exportação? Como se comporta a espera se a geração for assíncrona (ticket 25)?
- **Vinculação das roles de relatório aos grupos de usuário**: dois painéis com transferência, tabela com checkboxes, ou busca e adição? Quantos itens de cada lado, realisticamente?
- **Vinculação dos usuários aos grupos**: mesma pergunta, mais o caso dos RELATORes pendentes de vínculo (ticket 16) — eles aparecem numa fila separada?
- **A mensagem de erro** com horário, descrição, Correlation ID e o botão de copiar JSON (ticket 26), para ver se o formato é usável.

Dados de mentira, sem backend. Serve para reagir, não para reaproveitar.

Ao final, **solicitar revisão e aguardar aprovação** antes de encerrar a fase. Gravar em `docs/mapa/prototipos/html/` e linkar daqui.

## Notas do ticket 16 (pendente de vínculo)

Duas telas ganharam requisito concreto, e uma terceira apareceu:

- **Página dedicada de "sem acesso"** — é tela própria, não banner sobre a principal: sem drop-down,
  sem filtros, sem botões inertes. O mesmo texto serve tanto para quem aguarda vínculo quanto para
  quem foi vinculado a um Grupo que ainda não libera Relatório algum — a API **não distingue** os dois
  casos, então o protótipo não deve inventar variação que o backend não sabe produzir.
- **Fila de pendentes na tela do GERENTE** — sim, é fila separada, e é a **única** superfície que
  avisa que alguém está esperando (não há e-mail). Precisa mostrar **há quanto tempo** cada um aguarda
  e ordenar pelos mais antigos. O protótipo deve mostrar a lista com idades bem espalhadas (2 dias,
  12 dias, 94 dias) para revelar se a ordenação e o destaque funcionam.
- **Vincular é uma ação, não duas** — do ponto de vista do GERENTE, "vincular ao Grupo X" tem de ser
  um gesto só, ainda que por baixo sejam duas chamadas (entrar no Grupo, sair do `PENDENTES`). O
  protótipo é onde se descobre se a tela sugere isso ou convida a fazer metade.
- **Contador de pendentes** — onde ele vive na navegação, e se some quando zera.

## Notas do ticket 17 (sessão e exposição)

- **Há uma costura visível onde o usuário sai da aplicação.** Trocar a senha leva ao Account Console
  do Keycloak, que é outra interface — com tema customizado, mas ainda assim outra origem, outra
  navegação e um caminho de volta que precisa existir. O protótipo é onde se descobre se isso é
  aceitável ou se assusta.
- **O logout precisa de affordance** e ele redireciona para fora (RP-initiated, `end_session_endpoint`)
  antes de voltar. Não é um botão que limpa a tela — é uma ida e volta.
- Vale prototipar essas duas saídas mesmo sem backend, porque o incômodo delas é de percurso, não de
  função.

## Notas do ticket 26 (formato de erro)

- **O botão de copiar JSON copia o corpo da resposta verbatim.** Como o contrato é RFC 9457, a
  resposta **já é** o JSON — não há segunda serialização a montar na tela. Isso simplifica o
  protótipo e é o que o documento pede, sem trabalho extra.
- **Dois erros precisam parecer diferentes, e é fácil errar isso.** `ARTEFATO_ACIMA_DO_LIMITE` é
  **permanente** — a tela não deve convidar a tentar de novo; `EXPORTACAO_INDISPONIVEL` é
  **transitório**, com `Retry-After` — e aí tentar de novo é exatamente o certo. O protótipo é onde se
  descobre se a diferença fica óbvia ou se as duas viram "deu erro".
- **A mensagem de sem permissão é genérica por decisão**, cobrindo quatro situações. A UI precisa
  orientar a **refazer login**, que é o que resolve o caso do acesso revogado com token ainda válido —
  sem isso, o usuário fica preso por até cinco minutos sem saber o que fazer.
- **Correlation ID visível e copiável** em toda tela de erro: é o que o usuário passa ao suporte, e é
  o que amarra a resposta, o log no Graylog e a linha de auditoria.

## Notas do ticket 27 (retenção × histórico)

- **O drop-down tem três estados de item, não dois**: disponível, **expirado** (com a data real do
  expurgo) e **sem dados**. Os dois últimos se parecem na tela e significam o oposto — um teve arquivo
  e não tem mais, o outro nunca teve. O protótipo é onde se descobre se a distinção fica clara.
- **Um item marcado como expirado pode baixar com sucesso.** Foi decisão do ticket 27: a marcação é
  conservadora e a exportação tenta assim mesmo. A tela não deve desabilitar o botão pela marcação —
  no máximo avisar.
- **A data do expurgo é dado da mensagem**, não o prazo. A UI não promete "7 dias": ela diz "expirado
  em 08/08/2026", porque o arredondamento é em UTC e a Data de Referência é de São Paulo.
- **O histórico de downloads do ADMINISTRADOR cresce indefinidamente** — vale prototipar a listagem já
  com paginação e filtro por período, e não como tabela única.

## Notas do ticket 31 (Swagger descartável)

O contrato existe e está aprovado: [`../prototipos/openapi-descartavel.yaml`](../prototipos/openapi-descartavel.yaml).
O protótipo de tela deve consumir **exatamente** essa forma, com dados de mentira.

- **O drop-down é alimentado por uma chamada só.** `/execucoes-disponiveis` devolve tudo (~70 linhas)
  e o frontend agrupa em memória — trocar de nível **não vai à rede**. Se o protótipo simular latência
  por nível, estará ensaiando um comportamento que a API não tem.
- **Três campos derivados decidem a aparência de cada item**: `temDados`, `expirado` e
  `expuragoPrevisto`. São três estados com aparências parecidas e significados opostos — é o que este
  protótipo precisa provar que fica legível.
- **Lista vazia não é erro.** `[]` leva à página dedicada de "sem acesso", não a uma tela de falha.
- **A URL de exportação é construível** pelo cliente a partir do que a listagem devolve
  (`/relatorios/{codigo}/execucoes/{data}/exportacao?formato=`), sem uma segunda chamada para
  descobrir identificador.
- **`refazer` e `reprocessar` são dois botões, e o servidor decide qual vale.** A tela do
  ADMINISTRADOR não pode oferecer os dois livremente — e `reprocessar` **destrói**, então precisa
  parecer diferente e pedir motivo.
- **O `409` × `503` é o caso de teste visual deste protótipo**: um é permanente e não deve convidar a
  repetir; o outro é transitório e deve. Se as duas telas ficarem iguais, o protótipo falhou.

## Answer

Artefato: [`../prototipos/html/`](../prototipos/html/) — HTML, CSS e JS puros, sem backend, abre por
duplo clique. **Fase encerrada com aprovação**, conforme a regra do documento.

`?tela=disponiveis|sem-acesso|vinculacao|pendentes|erro`, `?variant=A|B|C`, setas `←` `→`.

### Onde as variantes foram gastas, e por quê

Só no **drop-down**. O ticket nomeia quatro telas, mas elas não têm o mesmo grau de incerteza: a fila
de pendentes e a tela de erro já chegaram constrangidas pelas decisões dos tickets 16, 26 e 27 — ali
a pergunta é "isso fica legível?", não "qual formato?". Gastar variantes onde não há pergunta produz
wallpaper.

| | |
|---|---|
| **A** | três selects encadeados — espelha literalmente o documento; mostra um relatório por vez |
| **B** | árvore expansível — mesma hierarquia, tudo visível, com contadores por nível |
| **C** | lista única com filtros — abandona a hierarquia e trata o conjunto como tabela filtrável |

### O que construir revelou

**Um defeito nos dados de teste que valeu por si.** Gerei sete datas para uma retenção de sete dias —
e **nenhum item aparecia como expirado**. Mas a listagem mostra Execuções cujos Artefatos já foram
expurgados, porque os metadados sobrevivem a eles (ticket 02). A janela de dados precisa ser **maior**
que a de retenção para o estado existir na tela. Estendido para dez datas: 29 itens expirados.

Isso é uma suposição errada minha, pega pelo protótipo antes de virar tela de verdade — e é
exatamente o que ele existe para fazer.

**São quatro estados de item, não três.** Além de *disponível*, *sem dados* e *expirado*, o `ALERTA`
também precisa aparecer: o relatório está lá e é baixável, só demorou mais que o estimado. Ficou
`disponível · lento`, para não sugerir problema — o ticket 27 falava em três, e a contagem estava
incompleta.

**A regra do ticket 27 fica verificável no comportamento**, não só na descrição: 29 itens marcados
como expirados e **nenhum** com o botão desabilitado; apenas os 3 `sem dados` bloqueiam. E o selo diz
`expirado em 31/07/2026` — a data real —, nunca "7 dias", porque o arredondamento é em UTC e a Data
de Referência é de São Paulo.

**As duas saídas da aplicação ficaram no cabeçalho, marcadas com `↗`.** Trocar senha leva ao Account
Console e sair é RP-initiated logout — os dois vão para fora e voltam. Marcá-las como saída foi a
forma encontrada de não fingir que são telas daqui.

### O que o protótipo assume da API, e não deve inventar

- **Uma chamada só** alimenta o drop-down; trocar de nível **não vai à rede**. Nenhuma variante simula
  latência por nível, porque a API não tem esse comportamento.
- **Lista vazia é estado**, não erro — leva à tela dedicada, que é a mesma para "aguardando vínculo" e
  "vinculado sem Relatório", porque a API não distingue os dois.
- **A URL de exportação é construída pelo cliente** a partir do que a listagem devolve, sem segunda
  chamada para descobrir identificador.
- **Vincular é um gesto**, ainda que sejam duas chamadas por baixo — e a falha pela metade tem
  mensagem própria.

### O que fica para a arquitetura do Angular decidir

O protótipo é descartável e não resolve: rota, estado compartilhado, guardas por Perfil, nem o design
system. Ele responde **como as telas se comportam**, não como o frontend se organiza — isso segue na
névoa do mapa.
