# 12 — Stack: frontend (Angular, OIDC, estado, design system)

Type: research
Status: resolved
Blocked by: —

## Question

Qual a stack do módulo frontend?

Levantar com fontes primárias (use context7) e recomendar:

- **Angular**: versão atual e sua janela de suporte; standalone components, signals e o estado atual das convenções recomendadas.
- **OIDC**: `angular-auth-oidc-client` vs `keycloak-js` vs `oidc-client-ts`. Qual suporta bem Authorization Code + PKCE, silent refresh, e **back-channel logout**. Base para os tickets 17 e a névoa de telas.
- **Guards por role**: como ler roles do JWT no Angular e proteger rotas — e a ressalva de que autorização no cliente é só usabilidade, nunca segurança.
- **Estado**: signals nativos vs NgRx vs serviço simples, dado o tamanho real deste frontend (listagem, download, e telas de gestão).
- **Design system**: Angular Material vs PrimeNG vs CSS próprio, considerando que o protótipo descartável é HTML/CSS/JS puro e precisa ser traduzível.
- **Download de arquivo grande** e fluxo assíncrono com polling (depende do ticket 25) — como fazer no Angular sem travar a UI.
- **Playwright + Angular**: seletores estáveis, `data-testid`, e como rodar no CI.
- **Node**: versão a fixar (o ambiente tem Node 24 LTS).

Registrar as descobertas em `docs/mapa/research/12-frontend.md`.

## Answer

Research completo em [`../research/12-frontend.md`](../research/12-frontend.md).

**Stack**: Angular **22.1.x** (nova cadência de 12 meses; Active até 2027-06, LTS até 2028-06 — o v21 já saiu do Active em 2026-06-03), **Node 24 com piso `24.15.0`** (LTS até 2028-04-30), e **TypeScript fixado em `~6.0.0`** — o `typescript@latest` é 7.0.2 e está fora da faixa aceita pelo Angular 22 (`>=6.0.0 <6.1.0`). Standalone + `bootstrapApplication`, **zoneless por padrão** desde o v21 (implica: todo estado de template é `signal`).

**Estado**: serviço `providedIn:'root'` com signals + `httpResource`, mais um `SessionStore` global. NgRx está descartado por bloqueio real, não por gosto: `@ngrx/signals@21.1.1` declara peer `@angular/core: ^21.0.0` e **não instala em Angular 22**.

**OIDC**: `angular-auth-oidc-client` 21.0.2 (MIT, guards e interceptor nativos), Code+PKCE com **refresh token rotacionado** — não iframe, que depende de cookie de terceiros que os navegadores estão desligando.

**Três achados que mudam decisões:**
1. **PrimeNG está fora por licença.** A v22.0.0 (única compatível com Angular 22) migrou para a licença **PrimeUI**: grátis só abaixo de US$ 1M de receita / 5 devs / 10 funcionários, com **license key obrigatória**. Ficar no PrimeNG MIT (21.1.9) prende o projeto no Angular 21. O `LICENSE.md` do GitHub `master` ainda mostra o texto MIT antigo e induz ao erro — o que vale é o tarball publicado. Recomendação: **Angular Material 22** (MIT) + um `DualList` próprio sobre CDK drag-drop, já que o Material não tem PickList.
2. **Back-channel logout é impossível num SPA.** A spec OIDC exige que o RP exponha um endpoint HTTP para receber o `logout_token`; arquivo estático não tem onde. Front-channel também quebra com bloqueio de cookie de terceiros (a própria spec admite). Sobra `logoff()` RP-initiated + **TTL curto de access token** — número que o **ticket 17** precisa fixar. Back-channel como requisito duro só com **BFF**, que é módulo novo.
3. **Guard de role é usabilidade, não segurança.** Usar `canMatch` (não `canActivate`) para que o chunk das telas de ADMINISTRADOR nem seja baixado por um RELATOR — mas a autorização que vale é a da API. Corolário para o **ticket 15**: o frontend não replica a cadeia `relatório → role → grupo → usuário`; pede à API a lista do que o usuário pode ver.

**Playwright**: fixar `@playwright/test@1.60.0` — exige Chromium rev **1223**, exatamente o que já está em `/opt/ms-playwright` (a 1.62.1 exige 1234 e forçaria download novo em ARM64). `data-testid` com chave de domínio (nunca classes `.mat-mdc-*`, que mudam entre versões) e `storageState` por perfil, que mapeia direto nos três tipos de usuário.
