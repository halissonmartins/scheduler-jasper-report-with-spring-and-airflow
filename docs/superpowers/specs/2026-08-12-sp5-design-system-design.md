# SP-5 — Design system (P2)

> Spec do sexto sub-projeto brainstormado. Entrega `docs/design/design-system.md`, os componentes
> canônicos e a página de referência, mais os requisitos de acessibilidade verificáveis. Fecha a
> fase P2 do [`guias/guia-app-web.md`](../../guias/guia-app-web.md).
>
> Data: 2026-08-12 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

O guia chama o design system de **"o artefato que mais falta em projetos"** e é explícito sobre a
consequência de escrevê-lo sem implementação: *"regra escrita sem exemplo canônico não é seguida
pelo agente: ele copia o que encontra no código, não o que está no documento."*

O checkpoint de P2 é exatamente esse: **existe um componente real no repositório para cada padrão
descrito.**

### 1.1 Dependências, e o que elas bloqueiam

SP-5 depende de dois sub-projetos que ainda não foram executados. O bloqueio é mais estreito do que
parece:

| Entrega de P2 | Depende de SP-4? |
|---|---|
| Tokens: cor, tipografia, espaçamento, raio, elevação | Não |
| Acessibilidade: contraste, foco, teclado, rótulos | Não |
| Botão, input, formulário, diálogo | Não |
| Estados vazio, erro, sucesso, desabilitado | Não |
| **Tabela** | **Sim** — filtro e ordenação se for tabela plana; expansão se for árvore |
| **Estado de carregamento** | **Sim** — modal, progresso por linha, ou confirmação prévia |

E há uma **dependência dura**: os componentes são código Angular, e `frontend/` só nasce em SP-3.

**Resolução:** a spec cobre P2 inteiro; o plano entrega o que independe e marca a tabela e o
carregamento como bloqueados pelas escolhas de SP-4 — o mesmo padrão de gate que SP-4 usa.

### 1.2 A natureza do sistema pesa no quanto investir

**25 usuários simultâneos** (`RNF-11`), todos internos, em telas majoritariamente administrativas.
Não é produto de marca, e a maior parte das telas é CRUD que o próprio guia manda não prototipar.

---

## 2. Objetivo

Que a primeira tela real, em SP-7, encontre token, componente e exemplo prontos — e que a segunda
tela não invente espaçamento, cor nem tratamento de erro.

---

## 3. Entregas

### 3.1 Base: Angular Material 22

Botão, input, form field, tabela com ordenação e paginação, diálogo e barra de progresso vêm
prontos e acessíveis. Versões verificadas: `@angular/material` **22.1.2** e `@angular/cdk`
**22.1.2**, alinhados ao Angular 22 que SP-3 fixa.

**Alternativas rejeitadas:** Angular CDK com estilo próprio (controle visual total, mas escreveríamos
e manteríamos cada componente) e CSS puro com custom properties (contraste, foco, teclado, ARIA e
gestão de foco em modal passariam a ser nossos — exatamente onde erros de acessibilidade se
escondem).

### 3.2 Tokens e tema

`docs/design/design-system.md` documenta o tema; não reinventa um sistema. Material 3 deriva a
paleta de uma cor-fonte, então o que se fixa é curto e verificável.

| Token | Valor | Justificativa |
|---|---|---|
| **Cor-fonte** | `#1B5E7E` — azul-petróleo | Neutra, sem marca. Uma cor institucional inventada seria dívida estética |
| **Erro / alerta / sucesso** | Tokens semânticos do Material 3 | Mapeiam nos quatro status de execução |
| **Tipografia** | Roboto, escala Material 3 | Padrão; nenhuma fonte extra a carregar |
| **Densidade** | **−2** | Linha de tabela ~40 px: 16 linhas visíveis contra 12 na densidade padrão |
| **Espaçamento** | `4 · 8 · 12 · 16 · 24 · 32 · 48` | Escala do guia, base 4 dp do Material |
| **Raio** | `4 · 8 · 12` apenas | Três valores; mais que isso ninguém respeita |
| **Elevação** | `0 · 1 · 2` apenas | Tela administrativa não precisa dos cinco níveis |

**O mapa status → cor, que é onde a cor vira regra de negócio.** Os quatro status de `RN-11` e
`RN-12` têm cor semântica própria, e **`processado com alerta` não pode parecer erro**: o alerta
significa artefato válido e utilizável que apenas demorou. Em vermelho, o usuário deixa de baixar um
relatório perfeitamente bom — erro de design que nenhum teste automatizado pega.

**As quatro regras, escritas como proibição:**

1. **Nunca usar valor de cor ou espaçamento fora dos tokens.** Qualquer `#hex` ou `px` literal em
   componente é violação.
2. Todo formulário segue o padrão da página de referência `/ui`.
3. Toda mensagem de erro aparece pelo componente `estados` — nunca `alert` nem texto solto.
4. Densidade `−2` é global; nenhum componente a sobrescreve localmente.

**Modo escuro fica fora.** Os tokens ficam isolados para que acrescentá-lo depois não seja
retrabalho, mas o documento registra que **isso exige reverificar todo par de cores em contraste
AA** — não é ajuste de tema, é uma passada completa de acessibilidade.

### 3.3 Os três componentes

Em `frontend/src/app/ui/`. Ganham envelope **apenas os que carregam regra do projeto** — o
`CLAUDE.md` proíbe abstração de uso único, e um `<app-botao>` que só repassa atributos para
`mat-button` é exatamente isso.

**`tabela`** — sobre `mat-table`, `matSort` e `mat-paginator`
Recebe definição de colunas e dados; entrega ordenação e paginação. Precisa sustentar as **56
linhas** da tabela plana de SP-4 e comportar códigos de 18 caracteres (`CONTACORRENTE-1234`) sem
rolagem horizontal.
**Parcialmente bloqueado:** se a espera escolhida for a V2, ganha estado por linha.

**`estados`** — os cinco num componente só
Vazio, carregando, erro, sucesso, desabilitado. Dois carregam regra:

- **Vazio não é erro.** O caso de `RF-16` — Relator pendente de vínculo — é estado legítimo, e a
  mensagem é de aguardo. Em vermelho com ícone de alerta, o usuário novo conclui que o sistema
  quebrou no primeiro acesso.
- **Erro carrega o contrato de `RA-41`:** momento em ISO 8601, descrição e Correlation ID, mais a
  ação de copiar em JSON (`RA-42`, `RF-38`, `RF-39`). É o que torna `F5`, o fluxo de diagnóstico,
  possível.

**Parcialmente bloqueado:** a forma do estado *carregando* depende da variante de SP-4.

**`confirmacao`** — sobre `mat-dialog`
Ação destrutiva com **motivo textual obrigatório**, validado antes de habilitar a confirmação, e
aviso explícito do efeito — no reprocessamento forçado, que os artefatos serão sobrescritos
(`RN-20`). Devolve o motivo ou o cancelamento.

É o único dos três que existe por regra de negócio e não por necessidade de interface: `RF-11` diz
que solicitação sem motivo é rejeitada, e um diálogo genérico de "tem certeza?" não cumpriria isso.

### 3.4 A página de referência

Rota `/ui`, renderizando cada padrão com o uso canônico: amostra dos tokens, botões em todas as
variantes, campos, um formulário completo, a tabela com dados falsos, o diálogo e os cinco estados.

**Ela permanece na aplicação, sem link na navegação.** A alternativa — excluí-la do build de
produção — foi rejeitada porque o valor dela é ser referência *viva*: uma página que só existe em
desenvolvimento diverge do que está no ar e deixa de servir ao que foi feita.

O `CLAUDE.md` de `frontend/`, criado por SP-3, passa a apontar `/ui` como o lugar de onde se copia o
padrão.

### 3.5 Acessibilidade, com verificação

| Requisito | Como é verificado |
|---|---|
| Contraste **AA** — 4.5:1 texto, 3:1 componentes | Cálculo sobre os pares de tokens, no aceite |
| Foco visível em todo interativo | Teste Playwright percorrendo `/ui` por `Tab` |
| Navegação por teclado completa | O mesmo teste: toda ação alcançável e acionável sem mouse |
| Todo input com label associado | **Lint** — regras de `@angular-eslint/template`, no CI de SP-3 |
| Idioma | `lang="pt-BR"` no `index.html` (`RNF-15`) |

O lint é o que mais rende: label sem associação é o erro de acessibilidade mais comum e o mais
fácil de detectar automaticamente. Os outros exigem execução, e viram um teste só sobre a página de
referência — onde todos os padrões coexistem.

---

## 4. Método

1. Instalar Angular Material 22.1.2 e configurar o tema (cor-fonte, densidade −2).
2. Escrever `design-system.md`.
3. Implementar `estados` e `confirmacao` — não bloqueados.
4. Montar `/ui` com o que já existe.
5. **Gate:** as escolhas de navegação e espera de SP-4.
6. Implementar `tabela` e a forma do estado *carregando*.
7. Acessibilidade: ativar as regras de lint e escrever o teste de teclado.

**Abordagem escolhida: envelopar só onde há decisão nossa, e uma página de referência para o
resto.** As alternativas: envelopar tudo (cria camadas que não decidem nada, contra a regra de
simplicidade do projeto) e não envelopar nada (mínimo de código, mas sem exemplo canônico a segunda
tela inventa — que é o que o guia adverte).

---

## 5. Fronteiras

**Pré-condição dura:** SP-3 executado. Sem `frontend/`, não há onde instalar.
**Pré-condição parcial:** SP-4 executado até o gate, para a tabela e o carregamento.

**Fora de escopo de SP-5:**

- **Telas de negócio** — SP-7 e SP-8+. SP-5 entrega o vocabulário, não as telas.
- **Modo escuro.**
- **Tema do Keycloak** — as telas de identidade são dele (`RA-33`, `RA-34`), e o tema é SP-8.
- **Qualquer chamada à API.** A página `/ui` usa dados falsos.

---

## 6. Riscos aceitos

- **Dois componentes ficam bloqueados pelo gate de SP-4.** SP-5 entrega incompleto até que as
  variantes sejam escolhidas — a mesma natureza de espera de SP-4, agora propagada.
- **Angular Material impõe uma estética.** Se depois se decidir que a aparência não serve, trocar
  custa reescrever os três componentes e a página de referência. Aceito porque a alternativa era
  construir acessibilidade do zero, e é ali que os erros se escondem.
- **Sem modo escuro.** Acrescentá-lo depois exige reverificar todo par de cores em AA.
- **`/ui` fica exposta em produção**, sem link. Superfície a mais num sistema interno — aceito para
  que a referência não divirja do que está no ar.

---

## 7. Critério de aceite

1. `design-system.md` traz tokens, as quatro regras e o mapa status → cor.
2. Tema Material aplicado, com densidade −2.
3. **Nenhum literal de cor ou espaçamento fora dos tokens** — conferível por varredura de `#hex` e
   `px` nos componentes.
4. `estados`, `confirmacao` e `tabela` existem em `frontend/src/app/ui/`.
5. `/ui` renderiza todos os padrões e os cinco estados.
6. Todo par de cores em uso passa em contraste AA.
7. Regras de a11y do `@angular-eslint` ativas, e o lint passa.
8. Teste de teclado percorre `/ui` sem mouse e alcança toda ação.
9. `estados` em modo erro exibe momento, descrição, Correlation ID e cópia JSON.
10. `confirmacao` **não habilita a ação** enquanto o motivo estiver vazio.

Os critérios 3, 7, 8 e 10 são executáveis.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define P2 e o checkpoint de implementação de referência |
| [`prd.md`](../../prd.md) | `RN-11`, `RN-12` (status), `RN-20`, `RF-11`, `RF-16`, `RF-38`, `RF-39`, `RNF-11`, `RNF-15` |
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | `RA-06` (Angular), `RA-41`, `RA-42` (contrato de erro) |
| [SP-3](./2026-08-12-sp3-fundacoes-do-repositorio-design.md) | Cria `frontend/`, o lint e o CI que verificam a11y |
| [SP-4](./2026-08-12-sp4-fluxos-e-prototipo-design.md) | Produz as escolhas que destravam tabela e carregamento |
