# SP-4 — Fluxos e protótipo (P1)

> Spec do quarto sub-projeto. Entrega `docs/design/fluxos.md`, um protótipo navegável descartável
> e `docs/design/decisoes-ux.md`. Fecha a fase P1 do
> [`guias/guia-app-web.md`](../../guias/guia-app-web.md).
>
> Data: 2026-08-12 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

P1 responde *"é usável e desejável?"* antes de existir backend. SP-4 não depende de SP-3 e pode
correr em paralelo a ele.

O guia condiciona a fidelidade ao risco, e a tabela dele é o que mais recorta este sub-projeto:

| Situação | Fidelidade adequada |
|---|---|
| Fluxo crítico, ambíguo ou inédito | Protótipo navegável |
| Tela com muita regra de negócio | Wireframe + fluxo escrito |
| CRUD interno, tela administrativa | **Nenhuma — vá direto ao código** |

### 1.1 Aplicação da tabela a este sistema

| Tela | Fidelidade | Por quê |
|---|---|---|
| Listagem data → produto → relatório | **Protótipo** | Fluxo central, hierarquia de 3 níveis filtrada por permissão — inédito |
| Exportar e baixar | **Protótipo** | Crítico, e **síncrono com espera de até 25 s** (`RNF-08`) |
| Recusas: expurgado, sem permissão, simultaneidade | Wireframe | Muita regra, pouca ambiguidade visual |
| Erro com Correlation ID e cópia JSON | Wireframe | Regra fechada (`RF-38`, `RF-39`) |
| Relator pendente de vínculo | Wireframe | Estado vazio com mensagem |
| Reprocessamento forçado | Wireframe | Motivo obrigatório, confirmação destrutiva |
| Histórico de downloads | — | Tabela administrativa com filtro |
| Catálogo administrável | — | CRUD interno |
| Roles, grupos e usuários (Gerente) | — | CRUD administrativo puro |
| Autocadastro e senha | — | **É o Keycloak com tema** (`RA-33`, `RA-34`) — não desenhamos |

**Dois protótipos, quatro wireframes, quatro telas sem artefato visual** — dez ao todo.

### 1.2 O achado que orienta o sub-projeto

**A espera síncrona é o problema de UX central deste sistema.** `RN-30` exige que a exportação
devolva o arquivo na mesma requisição; `RNF-08` admite p95 de **25 segundos**; `RA-60` recusa de
imediato a terceira exportação simultânea. Nenhum documento do projeto diz o que o usuário vê
nesse intervalo.

É a lacuna que o protótipo existe para fechar.

---

## 2. Objetivo

Responder três perguntas antes de existir uma linha de Angular:

- qual das três navegações atende os dois modos de uso do Relator — quem baixa o mesmo relatório
  todo dia, e quem procura um relatório específico numa data antiga;
- o que o usuário vê durante a espera de até 25 s;
- o que **não** precisa ser desenhado, e por quê.

---

## 3. Entregas

### 3.1 `docs/design/fluxos.md`

Cinco fluxos, cobrindo as três personas. Cada um com persona, gatilho, passo a passo e **os seus
estados de erro embutidos** — erro é ramo do caminho, não jornada própria.

| # | Fluxo | Persona | Estados de erro | Fidelidade |
|---|---|---|---|---|
| **F1** | Baixar um relatório | Relator | Execução não concluída (`RF-20`) · artefato expurgado (`RF-24`) · limite de simultaneidade (`RF-48`) · acesso direto negado (`RF-15`) | Protótipo |
| **F2** | Entrar pela primeira vez | Relator | Pendente de vínculo: entra e vê listagem vazia com aviso (`RF-16`, `RF-55`) | Wireframe |
| **F3** | Conceder acesso | Gerente | Promover a GERENTE ou ADMINISTRADOR é negado, inclusive por requisição direta (`RF-34`) | Só escrito |
| **F4** | Refazer uma apuração | Administrador | Motivo ausente rejeita (`RF-11`) · perfil não-ADMIN não vê a ação (`RF-12`) | Wireframe |
| **F5** | Diagnosticar um erro relatado | Administrador | — parte de um erro (`RF-38`, `RF-39`, `RF-40`) | Wireframe |

**F1, em detalhe**, porque é o que o protótipo responde:

```
1. Relator autenticado abre a aplicação
2. Vê as datas disponíveis — no máximo 7 (RN-36)
3. Escolhe uma data      → vê os produtos que sua cadeia alcança
4. Escolhe um produto    → vê os relatórios permitidos
5. Escolhe um relatório  → escolhe o formato: PDF, XLSX, DOCX ou CSV
6. ESPERA   ← p95 de até 25 s (RNF-08). Ponto de variante.
7. Recebe o arquivo
```

Passos 2–4 são a **variante de navegação**; passo 6 é a **variante de espera**.

**Três observações que os fluxos tornam visíveis e que nenhum documento do projeto registra:**

- **A janela de 7 dias cabe inteira na tela.** O argumento clássico para hierarquia é volume, e
  aqui não há volume — o que enfraquece o *drill-down* antes mesmo do protótipo.
- **`RN-36` some com o artefato por volta das 21h do sétimo dia**, não à meia-noite; `RA-20` chama
  isso de contraintuitivo. Se a listagem exibe "disponível até", F1 precisa dizer o que ela exibe.
- **F3 não tem artefato visual, mas tem fluxo escrito.** A cadeia `Relatório → Role → Grupo →
  Usuário` é N:N em quatro elos. É CRUD, e o guia manda ir direto ao código — mas a **ordem** das
  operações precisa estar escrita, ou cada tela será desenhada supondo uma ordem diferente.

### 3.2 O protótipo

Um **HTML autocontido** em `docs/design/prototipo/`, versionado com um `README.md` que declara o
descarte, e **publicado como Artifact**. Sem backend, sem framework: navegação em JS puro sobre
dados em constante.

**Parte A — navegáveis, com variantes lado a lado**

| | Variantes |
|---|---|
| **A1 · Navegação** | **V1** *drill-down* em páginas sucessivas · **V2** árvore expansível numa página · **V3** tabela plana com filtros de data e produto |
| **A2 · Espera** | **V1** modal bloqueante com progresso · **V2** progresso na linha da tabela, com o resto navegável · **V3** aviso prévio de duração com confirmação, depois progresso |

Cada variante percorre o F1 inteiro, para permitir comparação real.

**Parte B — os quatro wireframes**

`W1` pendente de vínculo · `W2` as três recusas · `W3` erro com Correlation ID e cópia JSON ·
`W4` reprocessamento forçado.

**Regra de baixa fidelidade, obrigatória:** só tons de cinza, borda tracejada, sem ícone, sem
tipografia de marca, rótulo `WIREFRAME` no canto. Wireframe e protótipo dividem o mesmo arquivo por
decisão desta sessão, e sem essa regra a fronteira se dissolve em duas iterações.

**Os dados falsos usam o catálogo real.** O guia adverte que conteúdo de preenchimento esconde
problema de design, e aqui há um concreto: as siglas de `RA-04` são longas — `CONTACORRENTE-1234`
tem 18 caracteres. Com um `PROD-0001` genérico, as três navegações pareceriam igualmente viáveis.
O protótipo carrega os 5 produtos reais, 2 relatórios cada, 7 datas e nomes de relatório
plausivelmente longos.

**O que o protótipo deliberadamente não faz:** não autentica, não valida, não trata erro de rede,
não tem estado persistente. É fachada.

### 3.3 `docs/design/decisoes-ux.md`

Mesmo formato dos ADRs — contexto, opções, escolha, motivo da rejeição. Cinco entradas:

| # | Decisão |
|---|---|
| DUX-01 | Qual navegação da listagem, e por que não as outras duas |
| DUX-02 | Qual tratamento da espera de até 25 s, **e a sua consequência arquitetural** |
| DUX-03 | Por que o CRUD administrativo não foi prototipado — a aplicação da tabela de fidelidade |
| DUX-04 | Por que as telas de identidade são o Keycloak com tema, e o que isso limita |
| DUX-05 | Como a listagem comunica o expurgo, dado que o artefato some às 21h do sétimo dia |

---

## 4. Método

Cinco passos, **e o terceiro é uma parada**:

1. Escrever `fluxos.md` com os 5 fluxos.
2. Construir o protótipo (A1, A2, B).
3. **Publicar como Artifact e parar** — o usuário escolhe as variantes de navegação e de espera.
4. Escrever `decisoes-ux.md` com as escolhas e as rejeições.
5. Escrever o `README.md` do protótipo.

**SP-4 é o primeiro sub-projeto com gate humano no meio.** Os passos 4 e 5 são inexecutáveis sem a
escolha do usuário — não é revisão dispensável, é entrada que falta. O plano marca isso
explicitamente, para que nenhum executor tente adivinhar.

**Abordagem escolhida: divergir apenas nos pontos ambíguos.** Proposta única onde não há dúvida
real; 2–3 variantes onde a dúvida é genuína. As alternativas consideradas foram: proposta única em
tudo (transformaria P1 em validação de uma ideia só, e o erro só apareceria com o Angular pronto) e
divergência ampla nos cinco fluxos (geraria material que ninguém compararia com atenção — o guia
chama isso de *"procrastinação disfarçada de diligência"*).

---

## 5. Fronteiras

**Fora de escopo de SP-4:**

- **Design system, tokens e componentes canônicos** — SP-5. O protótipo é fachada e não estabelece
  padrão visual; qualquer cor ou espaçamento nele é descartável.
- **Qualquer código em `frontend/`** — o protótipo vive em `docs/design/prototipo/` e é critério de
  aceite que assim seja.
- **Telas de identidade** — são o Keycloak com tema (`RA-33`, `RA-34`); o tema é trabalho de SP-8.
- **Acessibilidade** — os requisitos entram em SP-5, com o design system.

---

## 6. Riscos aceitos

- **Não há usuário real para testar.** O guia pede, para fluxo crítico, *"protótipo navegável,
  testado com usuário real"*. O usuário do projeto é o proxy — e proxy não é equivalente: quem
  desenhou o sistema não esbarra nas próprias suposições. Sem mitigação, porque não há usuário
  disponível.
- **O protótipo pode ser promovido apesar do aviso.** Mitigado por viver fora de `frontend/` e pelo
  critério de aceite 9. O guia é claro de que a tentação é o problema, não a distância.
- **Wireframe e protótipo dividem o mesmo arquivo**, por decisão desta sessão. Mitigado pela regra
  de baixa fidelidade, que é verificável (critério 5), mas a proximidade convida ao polimento.
- **A variante de espera escolhida pode ter consequência arquitetural.** Se for a V2 — progresso na
  linha, resto navegável — a exportação passa a exigir requisição em segundo plano com entrega do
  arquivo ao final, e não um `submit` que troca de página. Isso é implementável e **não fere
  `RN-30`**, que exige resposta na mesma requisição e não bloqueio da interface. Mas atravessa para
  SP-5 e SP-7, e por isso `DUX-02` precisa registrar a consequência, e não apenas qual desenho
  ganhou.

---

## 7. Critério de aceite

1. `fluxos.md` tem 5 fluxos, cada um com passo a passo e estados de erro.
2. Todo RF de interface aparece em pelo menos um fluxo.
3. O protótipo percorre F1 ponta a ponta nas 3 variantes de navegação.
4. As 3 variantes de espera são navegáveis.
5. Os 4 wireframes seguem a regra de baixa fidelidade — cinza, tracejado, rótulo `WIREFRAME`.
6. Os dados falsos usam as 5 siglas reais e códigos no formato `SIGLA-NNNN`.
7. `decisoes-ux.md` registra a variante escolhida **e as rejeitadas, com motivo**.
8. O `README.md` do protótipo declara o descarte.
9. **Nenhum arquivo do protótipo está em `frontend/`.**

Os critérios 1, 2, 5, 6, 8 e 9 são conferíveis por comparação de texto; 3 e 4 por inspeção no
Artifact; 7 depende do gate do passo 3.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define P1 e a tabela de fidelidade por risco |
| [`prd.md`](../../prd.md) | Personas (§3.1), perfis (§3.2), os RFs de interface e `RNF-07` a `RNF-09` |
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-33`, `RA-34` (Keycloak), `RA-60` (semáforo), `RA-20` (expurgo às 21h) |
| [SP-1](./2026-08-09-sp1-linguagem-e-historias-design.md) | Histórias de usuário que os fluxos encenam |
| SP-5 | Consome os fluxos aprovados para o design system |
