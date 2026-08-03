# 12 — Stack do módulo frontend (Angular, OIDC, estado, design system)

> Research do ticket [`12-stack-frontend.md`](../issues/12-stack-frontend.md).
> Levantamento feito em **2026-08-02**. Versões conferidas direto no registro npm e nas
> documentações oficiais (via MCP context7 e fetch das páginas primárias).

---

## Matriz de versões apurada (npm, 2026-08-02)

Consultado com `npm view <pacote> version` / `peerDependencies` no ambiente local.

| Pacote | Última versão | Peer de `@angular/core` |
|---|---|---|
| `@angular/core` | **22.1.0** | — |
| `@angular/cli` | **22.1.2** | — |
| `@angular/material` / `@angular/cdk` | **22.1.0** | `^22.0.0 \|\| ^23.0.0` |
| `primeng` | **22.0.0** (tag `latest`); `21.1.9` na tag `v21-stable` | `^22.0.0` |
| `angular-auth-oidc-client` | **21.0.2** (2026-05-01) | `>=20.0.0` |
| `@ngrx/signals` / `@ngrx/store` | **21.1.1** | **`^21.0.0`** — ainda **não** cobre Angular 22 |
| `keycloak-js` | **26.2.4** (2026-04-22) | sem peer declarado |
| `oidc-client-ts` | **3.5.0** | agnóstico de framework (`engines.node >=18`) |
| `keycloak-angular` | **22.0.0** | `^22`, exige `keycloak-js ^18..^26` |
| `@playwright/test` | **1.62.1** | — (local: **1.60.0**) |
| `typescript` | 7.0.2 — **incompatível**, ver abaixo | — |

**Achado com consequência imediata:** `@ngrx/signals@21.1.1` e `@ngrx/store@21.1.1` declaram
peer `@angular/core: ^21.0.0`. Existe apenas `22.0.0-beta.0` publicado. Ou seja, **hoje NgRx
não instala limpo em Angular 22** — travaria o projeto no Angular 21 ou exigiria
`--legacy-peer-deps`. Isso não é preferência; é bloqueio de instalação.

---

## 1. Angular: versão, janela de suporte e convenções atuais

### Versão e janela de suporte

- A política oficial é **24 meses por major**: 12 meses de *Active support* (updates e patches
  regulares) + 12 meses de *LTS* (só correções críticas e de segurança).
  Fonte: [angular.dev/reference/releases](https://angular.dev/reference/releases).
- **A partir do v22 a cadência mudou: um major a cada 12 meses** (antes era a cada 6), com
  4–6 minors por major e patches semanais.
  Fonte: [angular.dev/reference/releases](https://angular.dev/reference/releases).
- Calendário apurado na mesma página:

  | Versão | Lançamento | Fim do Active | Fim do LTS |
  |---|---|---|---|
  | **v22.0.0** | 2026-06-03 | 2027-06 | **2028-06** |
  | v21.0.0 | 2025-11-19 | 2026-06-03 | 2027-06 |
  | v20.0.0 | 2025-05-28 | 2025-11-19 | 2026-11-28 |

  A mudança de cadência é o que faz o **v22 valer bem mais que o v21**: o v22 fica em suporte
  ativo até meados de 2027 e em LTS até meados de 2028, enquanto o v21 já **saiu do Active
  support em 2026-06-03** — está em LTS hoje.

### Compatibilidade de Node / TypeScript / RxJS

Da tabela oficial em [angular.dev/reference/versions](https://angular.dev/reference/versions):

| Angular | Node.js | TypeScript | RxJS |
|---|---|---|---|
| **22.0.x** | `^22.22.3 \|\| ^24.15.0 \|\| ^26.0.0` | **`>=6.0.0 <6.1.0`** | `^6.5.3 \|\| ^7.4.0` |
| 21.0.x–21.2.x | `^20.19.0 \|\| ^22.12.0 \|\| ^24.0.0` | `>=5.9.0 <6.0.0` | `^6.5.3 \|\| ^7.4.0` |
| 20.0.x–20.3.x | `^20.19.0 \|\| ^22.12.0 \|\| ^24.0.0` | `>=5.8.0 <6.0.0` | `^6.5.3 \|\| ^7.4.0` |

Duas armadilhas concretas:

1. **O TypeScript mais recente no npm é 7.0.2, e o Angular 22 NÃO o aceita** — a faixa é
   `>=6.0.0 <6.1.0`. O `package.json` precisa fixar `"typescript": "~6.0.0"`. Um
   `npm i -D typescript@latest` quebra o build.
2. O Angular 22 exige **Node `^24.15.0`** (e não qualquer 24.x). O ambiente tem **24.16.0**,
   portanto atende — mas por pouca margem. Ver seção 8.

### Convenções recomendadas hoje

- **Standalone é o padrão e NgModule é legado.** O guia de boas práticas oficial diz
  textualmente: *"Always use standalone components over NgModules… Do not explicitly set
  `standalone: true` … as it is the default in Angular v20+"*.
  Fonte: [angular.dev — best practices](https://angular.dev/assets/context/best-practices.md).
  O guia de NgModules complementa: *"The Angular team recommends using standalone components
  instead of `NgModule` for all new code."*
  Fonte: [angular.dev/guide/ngmodules/overview](https://angular.dev/guide/ngmodules/overview).
- **Bootstrap por `bootstrapApplication(App, appConfig)`**, com providers em um
  `ApplicationConfig` — não há mais `AppModule`.
  Fonte: [angular.dev/api/platform-browser/bootstrapApplication](https://angular.dev/api/platform-browser/bootstrapApplication).
- **Zoneless é o padrão a partir do v21.** A doc do `provideZonelessChangeDetection()` diz:
  *"This feature is enabled by default in Angular v21+; therefore, `provideZoneChangeDetection`
  should not be used to override it."* E o roadmap registra que, com zoneless estável e padrão,
  **a estratégia padrão de change detection passou a ser `OnPush`**, e
  `ChangeDetectionStrategy.Default` foi renomeada para `Eager`.
  Fontes: [angular.dev/guide/zoneless](https://angular.dev/guide/zoneless),
  [angular.dev/api/core/provideZonelessChangeDetection](https://angular.dev/api/core/provideZonelessChangeDetection),
  [angular.dev/roadmap](https://angular.dev/roadmap).

  > Consequência prática: **em zoneless, mutar um array e esperar a view atualizar não funciona
  > mais**. Todo estado que alimenta template tem de ser `signal`. Isso muda como se escreve o
  > frontend inteiro e precisa entrar na spec como regra, não como dica.

- **Runner de teste unitário padrão mudou para Vitest.** *"The Angular CLI uses Vitest as the
  default unit test runner for new projects."* O builder é `@angular/build:unit-test`; Karma
  continua disponível via `ng new --test-runner=karma` ou `"runner": "karma"`.
  Fontes: [angular.dev/guide/testing/migrating-to-vitest](https://angular.dev/guide/testing/migrating-to-vitest),
  [angular.dev/guide/testing/karma](https://angular.dev/guide/testing/karma).
  (Detalhe que interage com o ticket 09 — registrado aqui só como fato.)

---

## 2. OIDC: `angular-auth-oidc-client` vs `keycloak-js` vs `oidc-client-ts`

### O que cada um é

| | `angular-auth-oidc-client` | `keycloak-js` | `oidc-client-ts` |
|---|---|---|---|
| Escopo | Biblioteca **Angular** (providers, guards, interceptor) | Adapter **do Keycloak**, agnóstico de framework | Biblioteca OIDC genérica, agnóstica de framework |
| Versão | 21.0.2 | 26.2.4 | 3.5.0 |
| Integração Angular | nativa | via `keycloak-angular@22` (3º pacote) | manual (você escreve guard/interceptor) |
| Licença | MIT | Apache-2.0 (projeto Keycloak) | Apache-2.0 |

### Authorization Code + PKCE

- **`angular-auth-oidc-client`**: o README lista explicitamente *"Code Flow with PKCE, Code Flow
  PKCE with Refresh tokens, Implicit Flow, Session Management 1.0, OAuth 2.0 Token Revocation
  (RFC7009), Proof Key for Code Exchange (PKCE) (RFC7636)"* e suporte a PAR.
  Fonte: [README do repositório](https://github.com/damienbod/angular-auth-oidc-client/blob/main/README.md).
- **`keycloak-js`**: suporta PKCE, com **S256 como padrão**. A doc: *"The method for Proof Key
  Code Exchange (PKCE) to use. Configuring this value enables the PKCE mechanism. Available
  options: 'S256' — The SHA256 based PKCE method (default)"*.
  Fonte: [keycloak.org — JavaScript adapter](https://www.keycloak.org/securing-apps/javascript-adapter).
- **`oidc-client-ts`**: implementa OIDC/OAuth2 para apps de browser, incluindo PKCE.
  Fonte: [github.com/authts/oidc-client-ts](https://github.com/authts/oidc-client-ts).

Do lado do servidor, o Keycloak recomenda o mesmo: *"it is recommended to use the Authorization
Code Flow with Proof Key for Code Exchange (PKCE) for public clients."*
Fonte: [keycloak/docs/guides/securing-apps/oidc-layers.adoc](https://github.com/keycloak/keycloak/blob/main/docs/guides/securing-apps/oidc-layers.adoc).

**Conclusão: os três atendem PKCE. Isso não decide nada.**

### Silent refresh — aqui os caminhos divergem

Existem **duas** técnicas com o mesmo apelido, e elas envelheceram de forma muito diferente:

**(a) Refresh token** (`useRefreshToken: true` + `scope: 'offline_access'`) — chamada
server-to-server no `token_endpoint`. Não depende de cookie de terceiros. Configuração do
`angular-auth-oidc-client`:

```ts
provideAuth({ config: {
  authority: '--idp--', clientId: '--client_id--',
  scope: 'openid profile offline_access', responseType: 'code',
  silentRenew: true, useRefreshToken: true,
  ignoreNonceAfterRefresh: true,        // se o IdP não devolve id_token no refresh
  // allowUnsafeReuseRefreshToken: true // só se o refresh token NÃO for rotacionado
}})
```
Fonte: [silent-renew.md](https://github.com/damienbod/angular-auth-oidc-client/blob/main/docs/site/angular-auth-oidc-client/docs/documentation/silent-renew.md).

**(b) iframe oculto** (`silent-renew.html`, `checkAuthIncludingServer()`, `check-sso`) —
**depende de cookie de terceiros**. A própria doc do `angular-auth-oidc-client` marca
`checkAuthIncludingServer` como *"It only works with iframe silent renew and not with refresh
tokens."*
Fonte: [public-api.md](https://github.com/damienbod/angular-auth-oidc-client/blob/main/docs/site/angular-auth-oidc-client/docs/documentation/public-api.md).

E a doc do Keycloak é ainda mais explícita sobre a fragilidade dessa via: *"the adapter relies on
third-party cookies for Session Status iframe, silent `check-sso` and partially also for regular
(non-silent) `check-sso`"* — em navegadores com política restritiva o **Session Status iframe
fica indisponível e se autodesabilita**, e o silent `check-sso` cai para o check-sso normal (com
redirect visível).
Fonte: [keycloak.org — JavaScript adapter](https://www.keycloak.org/securing-apps/javascript-adapter).

> **Regra que sai daí:** usar **refresh token rotacionado**, não iframe. Qualquer desenho que
> dependa de iframe de sessão está construindo sobre um mecanismo que os navegadores estão
> ativamente desligando.

### Back-channel logout — o ponto que decide o desenho (entra no ticket 17)

**Back-channel logout não é implementável por uma SPA sozinha.** A spec exige que o RP exponha
um endpoint HTTP que recebe um POST do OP:

> *"RP URL that will cause the RP to log itself out when sent a Logout Token by the OP. This URL
> SHOULD use the https scheme and MAY contain port, path, and query parameter components."*

O `logout_token` é um JWT assinado com `iss`, `aud`, `iat`, `exp`, `jti`, `events` (e `sub`/`sid`
opcionais), e **nunca** pode conter `nonce` — justamente para não ser confundido com um ID Token.
Fonte: [OpenID Connect Back-Channel Logout 1.0](https://openid.net/specs/openid-connect-backchannel-1_0.html).

Um SPA servido como arquivos estáticos **não tem onde receber esse POST**. Portanto:

- **Nenhuma** das três bibliotecas "suporta back-channel logout" no sentido da spec — não é
  limitação delas, é limitação arquitetural do RP público. O `angular-auth-oidc-client` lista
  "Session Management 1.0", não back-channel logout.
  Fonte: [README](https://github.com/damienbod/angular-auth-oidc-client/blob/main/README.md).
- A alternativa nominal — **front-channel logout** — também é frágil pelo mesmo motivo de cookie:
  a spec renderiza `<iframe src="frontchannel_logout_uri">` e reconhece que *"Some User Agents
  (browsers) are starting to block access to third-party content by default… the
  `frontchannel_logout_uri` might not be able to access the RP's login state when rendered by the
  OP in an iframe because the iframe is in a different origin"*. A própria spec aponta o
  back-channel como a alternativa não afetada.
  Fonte: [OpenID Connect Front-Channel Logout 1.0](https://openid.net/specs/openid-connect-frontchannel-1_0.html).

**O que sobra para o SPA, de fato:**

1. **RP-initiated logout** — `oidcSecurityService.logoff()` dispara o `end_session_endpoint` do
   Keycloak, encerrando a sessão **no servidor** e não só no browser. Aceita `logoffMethod: 'POST'`
   e `customParams` (a spec só permite `state`, `logout_hint`, `ui_locales`).
   Fonte: [login-logout.md](https://github.com/damienbod/angular-auth-oidc-client/blob/main/docs/site/angular-auth-oidc-client/docs/documentation/login-logout.md).
   Isso já resolve o problema levantado no ticket 17 ("logout só no frontend deixa a sessão viva
   no Keycloak") — desde que se use `logoff()` e não apenas limpar `localStorage`.
2. **TTL curto do access token** — o access token continua válido até expirar, mesmo após o
   logout. A janela de exposição é exatamente o TTL. Decisão numérica pertence ao ticket 17.
3. **Se back-channel logout for requisito duro**, a única saída é um **BFF** (Backend-for-Frontend):
   um componente servidor que é o RP confidencial, recebe o `logout_token` e invalida uma sessão
   com cookie. Isso é uma mudança de arquitetura — o token deixa de viver no browser. Custa um
   módulo novo e conflita com a regra do documento de que o frontend "realiza a integração com os
   endpoints do módulo API REST" via JWT.

### Estado de manutenção do `keycloak-js` — sinal de alerta

O `keycloak-js` **não está deprecado** — a doc oficial o apresenta como solução corrente para
apps client-side, sem aviso de descontinuação.
Fonte: [keycloak.org — JavaScript adapter](https://www.keycloak.org/securing-apps/javascript-adapter).

Mas o histórico de publicação levanta a sobrancelha (via `npm view keycloak-js time`):

```
26.1.5  2025-04-11      26.2.2  2025-12-11
26.2.0  2025-02-20      26.2.3  2026-02-04
26.2.1  2025-10-09      26.2.4  2026-04-22
```

Quatro releases em ~14 meses, e a linha parou no **26.2** enquanto o servidor Keycloak seguiu para
26.5.x. Além disso, usá-lo em Angular exige um **terceiro pacote de terceiros**
(`keycloak-angular@22`, mantido fora do projeto Keycloak) para ter guards e interceptor —
somando dois pontos de acoplamento de versão em vez de um.

---

## 3. Guards por role — e a ressalva que precisa estar escrita

### Como se faz

Guards funcionais (`CanActivateFn`, `CanMatchFn`) rodam **dentro de um injection context**, então
`inject()` funciona direto:

```ts
export const authGuard: CanActivateFn = () => {
  const authStore = inject(AuthStore);
  const router = inject(Router);
  return authStore.isAuthenticated() ? true : router.parseUrl('/login');
};
```
Fontes: [angular.dev/guide/routing/testing](https://angular.dev/guide/routing/testing),
[angular.dev/guide/di/dependency-injection-context](https://angular.dev/guide/di/dependency-injection-context).

Guards se compõem em array e executam na ordem declarada — `canActivate: [authGuard, adminGuard]`
é "autenticado **E** admin". `canActivateChild` protege toda a subárvore; `canMatch` decide se a
rota sequer **casa**, permitindo rota de fallback com o mesmo `path`.
Fonte: [angular.dev/guide/routing/route-guards](https://angular.dev/guide/routing/route-guards).

**`canMatch` é a escolha certa para rota por perfil**, não `canActivate`:

```ts
{ path: 'gestao', canMatch: [roleGuard('GERENTE')],
  loadChildren: () => import('./gestao/gestao.routes').then(m => m.routes) },
{ path: 'gestao', component: SemPermissao },   // fallback
```

Dois motivos concretos: (a) com `canMatch` o **chunk lazy do módulo de gestão nem é baixado** por
quem não tem a role — um RELATOR jamais recebe o JS das telas de ADMINISTRADOR; (b) permite o
fallback acima sem `redirectTo` espalhado.
Fonte: [angular.dev/api/router/CanMatchFn](https://angular.dev/api/router/CanMatchFn).

O `angular-auth-oidc-client` já entrega `autoLoginPartialRoutesGuard` pronto para o caso "rota
protegida dispara o login se não autenticado", usável em `canActivate` e `canLoad`.
Fonte: [auto-login.md](https://github.com/damienbod/angular-auth-oidc-client/blob/main/docs/site/angular-auth-oidc-client/docs/documentation/auto-login.md).

E o token vai automaticamente no `Authorization` das rotas listadas em `secureRoutes`:

```ts
providers: [
  provideHttpClient(withInterceptors([authInterceptor()])),
  provideAuth({ config: { /* ... */ secureRoutes: ['https://api.exemplo/'] } }),
]
```
Fonte: [interceptors.md](https://github.com/damienbod/angular-auth-oidc-client/blob/main/docs/site/angular-auth-oidc-client/docs/documentation/interceptors.md).

> **Detalhe operacional:** `secureRoutes` faz *prefix match* de URL. Se a API estiver atrás do
> Traefik no mesmo host do frontend, o prefixo tem de ser específico o bastante (`/api/`) para
> não vazar o access token em requisições de assets.

### A ressalva (obrigatória na spec)

**Guard de role no Angular é usabilidade, não segurança.** O bundle está na máquina do usuário; um
`roleGuard` é um `if` em JavaScript que qualquer pessoa desabilita no DevTools. A decisão de
autorização que **vale** é a que o `spring-boot-starter-oauth2-resource-server` toma na API REST,
validando a assinatura do JWT. O guard existe para não mostrar um menu que resultaria em 403 —
nada além disso.

Isso tem consequência direta no ticket 15: se a API resolve autorização consultando o banco
(cadeia `relatório → role → grupo → usuário`), **o frontend não deve tentar replicar essa
cadeia**. O frontend deve pedir à API a lista do que o usuário pode ver e renderizar isso. Caso
contrário passam a existir duas implementações da mesma regra, e elas vão divergir.

Ler roles do JWT no cliente é apenas decodificar o payload (base64url) — o `userData` do
`angular-auth-oidc-client` (`realm_access.roles` / `resource_access.<client>.roles` no Keycloak).
**Não validar assinatura no cliente**: não adianta nada e dá falsa sensação de segurança.

---

## 4. Estado: signals nativos vs NgRx vs serviço simples

### O tamanho real deste frontend

Pelo `docs/descricao-inicial.md`, as telas são: sign in/out/up, troca de senha, gestão de usuários,
gestão de roles de relatório, gestão de grupos e vínculos, cadastro de produtos e relatórios,
listagem de relatórios disponíveis por data/produto/código, download e histórico de downloads.
São **telas CRUD e uma listagem com filtro**. Não há estado cross-cutting complexo: nenhum
carrinho, nenhum editor colaborativo, nenhum undo/redo, nenhum fluxo offline.

### O que o Angular já dá nativamente

- `signal`, `computed`, `linkedSignal` para estado e estado derivado.
  Fonte: [angular.dev/guide/signals](https://angular.dev/guide/signals).
- **`resource()` / `httpResource()` para dados assíncronos** — reexecutam o loader sempre que os
  `params` (que são signals) mudam, e expõem `status()`, `value()`, `hasValue()`, `error()`:

  ```ts
  isLoading = computed(() => this.userResource.status() === 'loading');
  hasError  = computed(() => this.userResource.status() === 'error');
  ```
  Fontes: [angular.dev/guide/signals/resource](https://angular.dev/guide/signals/resource),
  [angular.dev/api/common/http/HttpResourceFn](https://angular.dev/api/common/http/HttpResourceFn).

  Isso cobre com precisão o caso do drop-down encadeado do ticket 32: um `httpResource` cuja URL
  deriva da data selecionada, outro que deriva do produto selecionado. Trocar a data recarrega os
  produtos automaticamente, sem `subscribe` nem `switchMap`.
- `linkedSignal` resolve o problema clássico do drop-down encadeado (resetar a seleção filha
  quando a lista pai muda) sem código imperativo.
  Fonte: [angular.dev — linkedSignal](https://angular.dev/guide/signals/linked-signal).

### O que o NgRx dá a mais

`@ngrx/signals` (SignalStore) traz `signalStore(withState, withComputed, withMethods)`, com opção
`{ providedIn: 'root' }` para singleton e `patchState` para atualização imutável.
Fonte: [ngrx.io/guide/signals/signal-store](https://ngrx.io/guide/signals/signal-store).

É bom, mas repare no que ele efetivamente adiciona sobre um serviço com signals: uma convenção de
nomes e DevTools (via `@ngrx/toolkit`). O `withMethods` com `inject(Service)` é, estruturalmente,
o mesmo que métodos em um `@Injectable({providedIn:'root'})` que guarda signals.

### O bloqueio

`@ngrx/signals@21.1.1` e `@ngrx/store@21.1.1` declaram peer `@angular/core: ^21.0.0`. Só existe
`22.0.0-beta.0`. **Adotar NgRx hoje significa ou ficar no Angular 21 (que já saiu do Active
support em 2026-06-03) ou instalar com `--legacy-peer-deps`.** Nenhuma das duas é aceitável para
um projeto que está começando agora.

### Trade-off

| Opção | Quando escolher | Custo |
|---|---|---|
| **Serviço `@Injectable({providedIn:'root'})` com signals + `httpResource`** | Estado por feature, poucas telas compartilhando estado — **este caso** | Zero dependência. Sem DevTools de time-travel. |
| **`@ngrx/signals` (SignalStore)** | Muitos stores, time grande precisando de convenção imposta, necessidade de DevTools | Dependência a mais; **hoje incompatível com Angular 22** |
| **`@ngrx/store` (Redux clássico)** | Estado global com muitas origens de mutação, auditoria de ações, efeitos complexos | Boilerplate alto; **hoje incompatível com Angular 22**; desproporcional aqui |

**Critério de decisão objetivo:** se em algum momento **três ou mais features não relacionadas**
precisarem ler e escrever o mesmo pedaço de estado, ou se aparecer necessidade real de
time-travel debugging, aí NgRx SignalStore se paga. Enquanto for "cada tela cuida do seu estado
+ um `SessionStore` global com usuário e roles", serviço com signals é a resposta.

O único estado verdadeiramente global aqui é o **`SessionStore`** (usuário, roles, estado
"pendente de vínculo" do ticket 16) — um serviço, um `signal`, alguns `computed`.

---

## 5. Design system: Angular Material vs PrimeNG vs CSS próprio

### PrimeNG mudou de licença no v22 — achado decisivo

Isto foi verificado abrindo os tarballs publicados no npm (`npm pack primeng@<v>` +
`tar -xzOf … package/LICENSE.md`):

- **`primeng@20.4.0` e `primeng@21.1.9`** → `# PRIMENG LICENSES` → `## PRIMENG COMMUNITY VERSIONS
  LICENSE` → **"The MIT License (MIT) — Copyright (c) 2016-2026 PrimeTek"**.
- **`primeng@22.0.0`** (a única versão com peer `@angular/core: ^22.0.0`) → o LICENSE.md é outro:

  > *"This package is part of **PrimeUI**, a family of commercial UI libraries by PrimeTek
  > Informatics. … PrimeUI may be used under one of two licenses."*
  >
  > **Community License (Free)** — livre apenas para organizações que atendem **todos** os
  > critérios: menos de **US$ 1.000.000** de receita bruta anual, menos de **5 desenvolvedores**,
  > menos de **10 funcionários**, menos de **US$ 3.000.000** de capital de risco/investimento
  > externo. Suporta até 4 desenvolvedores e **exige renovação anual** confirmando elegibilidade.
  >
  > **Commercial License (Paid)** — licenciada **por desenvolvedor**, para quem não se qualifica.
  >
  > *"A valid license key is required to use this software. … A missing, invalid, or expired key
  > may cause the software to display a license notice."*

  Fonte: `LICENSE.md` dentro de `primeng-22.0.0.tgz` no registro npm
  (`npm view primeng@22.0.0 license` → `"SEE LICENSE IN LICENSE.md"`).

> **Atenção à armadilha de pesquisa:** o `LICENSE.md` no branch `master` do GitHub
> ([raw.githubusercontent.com/primefaces/primeng/master/LICENSE.md](https://raw.githubusercontent.com/primefaces/primeng/master/LICENSE.md))
> ainda descreve o modelo antigo (community MIT + LTS comercial). **O arquivo publicado no
> pacote v22 é diferente.** Quem checar só o GitHub conclui errado. Confie no tarball.

Para um sistema de relatórios de domínio bancário (Poupança, Conta Corrente, Consórcio,
Empréstimo), a hipótese realista é que a organização **não** se qualifica para a Community License
(menos de 10 funcionários / menos de US$ 1M de receita). Isso torna o PrimeNG v22 uma **decisão de
compra**, com license key a gerenciar em build e runtime — não uma decisão técnica.

Existe rota de fuga: fixar em **`primeng@21.1.9`** (tag `v21-stable`, ainda MIT) — mas essa versão
tem peer `@angular/core: ^22.0.0`? Não: a `21.1.9` acompanha Angular 21. Ou seja, **ficar no
PrimeNG MIT significa ficar no Angular 21**, que já saiu do Active support. O acoplamento é real.

### Angular Material

- **MIT** (`npm view @angular/material license` → `MIT`), mantido pelo time do Angular, versão
  `22.1.0` alinhada com `@angular/core@22`.
- Sistema de tema atual é baseado em **system tokens expostos como CSS custom properties**, o que
  torna a tradução do protótipo HTML/CSS/JS bem mais direta do que parece:

  ```css
  .minha-tela {
    background: var(--mat-sys-primary-container);
    color: var(--mat-sys-on-primary-container);
    border: 1px solid var(--mat-sys-outline-variant);
    font: var(--mat-sys-body-large);
  }
  ```
  E o tema se declara em um `@include mat.theme(...)`, com `mat.theme-overrides(...)` para ajustes
  pontuais.
  Fontes: [material.angular.dev/guide/theming](https://material.angular.dev/guide/theming),
  [material.angular.dev/guide/typography](https://material.angular.dev/guide/typography).
- Tabela com sort e paginação existe pronta (`MatTableDataSource`, `<mat-paginator>`, `MatSort`) —
  cobre a listagem de relatórios e o histórico de downloads.
  Fonte: [material.angular.dev/components/table/overview](https://material.angular.dev/components/table/overview).

### O gap concreto do Material: não existe PickList

O protótipo do ticket 32 precisa de **dois painéis com transferência** (roles ↔ grupos,
usuários ↔ grupos). PrimeNG tem `<p-picklist>` pronto, com filtro por painel, `sourceheader`/
`targetheader` e drag-and-drop (que por sua vez exige `@angular/cdk`).
Fonte: [v20.primeng.org/picklist](https://v20.primeng.org/picklist).

O Angular Material **não tem componente equivalente**. Tem as primitivas no CDK — verificado nos
type declarations publicados de `@angular/cdk@22.1.0`, arquivo `drag-drop`:

```ts
declare function moveItemInArray<T>(array: T[], fromIndex: number, toIndex: number): void;
declare function transferArrayItem<T>(currentArray: T[], targetArray: T[],
                                      currentIndex: number, targetIndex: number): void;
declare function copyArrayItem<T>(...): void;
declare class CdkDropListGroup<T> { /* selector: [cdkDropListGroup] */ }
// CdkDropList expõe a entrada `connectedTo` sob o alias `cdkDropListConnectedTo`
```

Ou seja: montar um pick-list sobre `cdkDropListConnectedTo` + `transferArrayItem` é **um
componente a escrever**, estimável em algumas centenas de linhas com filtro e acessibilidade. Não
é gratuito, mas é uma vez só e fica sob controle do projeto — e é reusado nas duas telas de
vínculo.

### Trade-off

| Opção | A favor | Contra |
|---|---|---|
| **Angular Material 22** | MIT; mesmo time do Angular; versão casada com core 22; tema por CSS vars facilita traduzir o protótipo; a11y séria | **Sem PickList** — escrever um sobre CDK drag-drop; visual "Material" pode destoar do protótipo |
| **PrimeNG 22** | PickList, DataTable e ~80 componentes prontos; economiza semanas | **Licença PrimeUI comercial + license key**; decisão jurídica/financeira, não técnica |
| **PrimeNG 21.1.9 (MIT)** | MIT de verdade | **Prende o projeto no Angular 21**, fora do Active support desde 2026-06-03 |
| **CSS próprio** | Fidelidade total ao protótipo; zero licença | Reescrever tabela, datepicker, dialog, select, a11y e foco. Custo altíssimo para o valor que entrega aqui |

**Critério de decisão:** se a organização se qualifica para a PrimeUI Community License **e**
alguém aceita renovar/gerenciar license key anualmente, PrimeNG v22 economiza trabalho real.
Caso contrário — que é a hipótese default aqui — Angular Material + um componente `DualList`
próprio sobre CDK drag-drop.

---

## 6. Download de arquivo grande e fluxo assíncrono com polling

### O download em si

`HttpClient.get()` tem overload com `responseType: 'blob'` que devolve `Observable<Blob>`, e
overloads com `observe: 'response'` (para ler o header `Content-Disposition`) e `observe: 'events'`
(para acompanhar progresso).
Fonte: [angular.dev/api/common/http/HttpClient](https://angular.dev/api/common/http/HttpClient).

Progresso de **download** vem via `reportProgress: true` + `observe: 'events'`, filtrando
`HttpEventType.DownloadProgress` (`event.loaded` / `event.total`).
Fontes: [angular.dev/guide/http/making-requests](https://angular.dev/guide/http/making-requests),
[angular.dev/api/common/http/HttpEventType](https://angular.dev/api/common/http/HttpEventType).

> **Pegadinha documentada:** *"the default fetch backend does not support upload progress events;
> you must configure HttpClient with `withXhr()` to enable them."*
> Fonte: [angular.dev/guide/http/making-requests](https://angular.dev/guide/http/making-requests).
> A ressalva é sobre **upload**; para download, `DownloadProgress` só é emitido se o servidor
> mandar `Content-Length` — sem ele, dá para mostrar bytes recebidos mas não percentual. Se o
> Traefik ou a API usarem `Transfer-Encoding: chunked` ou compressão, **não haverá `total`**, e a
> barra tem de ser indeterminada. Isso é decisão para o ticket 11/25.

**O que trava a UI e o que não trava.** Nada disso bloqueia a thread — o XHR/fetch é assíncrono.
O que efetivamente trava é: (a) segurar um `Blob` de dezenas de MB em memória no browser; (b)
`URL.createObjectURL()` sem `revokeObjectURL()` depois, que vaza memória até o reload.

Para arquivos realmente grandes existe alternativa que evita o Blob por completo: a API responde
`202` com uma **URL pré-assinada do MinIO**, e o frontend faz `window.location.href = url` (ou um
`<a download>`). O browser baixa direto do storage, sem passar pela heap da API nem pela do
browser. Isso conversa diretamente com o ticket 25 ("o resultado vive onde?") e com a regra do
documento de que "a geração e download do relatório deve ser feito pelo módulo de API REST" —
que precisa ser lida como "a API **autoriza e orquestra**", não necessariamente "os bytes
trafegam pela API".

### O polling (depende do ticket 25)

Se o ticket 25 fechar em híbrido (`202 Accepted` + polling), o padrão em Angular 22 é signals:

- Um `signal` com o `jobId` retornado pelo `202`.
- Um `httpResource` (ou `resource`) cujo `params` deriva desse `jobId` — dispara sozinho quando o
  id aparece.
- Um `effect` com `setTimeout`/`setInterval` chamando `.reload()` do resource enquanto
  `status() !== 'concluido'`; `computed` derivam os estados de tela.
  Fontes: [angular.dev/guide/signals/resource](https://angular.dev/guide/signals/resource),
  [angular.dev/api/common/http/HttpResourceFn](https://angular.dev/api/common/http/HttpResourceFn).

O `resourceFromSnapshots` + `linkedSignal` documentado no guia resolve o efeito colateral
desagradável do polling — a tela piscar "carregando" a cada ciclo: mantém o último valor durante
o `loading`.
Fonte: [angular.dev/guide/signals/resource](https://angular.dev/guide/signals/resource).

Um detalhe de ciclo de vida que costuma ser esquecido: **o polling tem de parar** quando o
componente é destruído (`DestroyRef`/`takeUntilDestroyed`) e idealmente quando a aba perde
visibilidade — senão N relatores com abas abertas geram tráfego constante contra a API.

---

## 7. Playwright + Angular

### Seletores estáveis

`page.getByTestId('x')` casa com `data-testid` por padrão; o atributo é configurável globalmente:

```ts
export default defineConfig({ use: { testIdAttribute: 'data-testid' } });
```
Aceita lista separada por vírgula (`'data-pw,data-ti'`).
Fontes: [playwright.dev/docs/api/class-testoptions](https://playwright.dev/docs/api/class-testoptions),
[playwright.dev/docs/api/class-locator](https://playwright.dev/docs/api/class-locator),
[playwright.dev/docs/api/class-selectors](https://playwright.dev/docs/api/class-selectors).

Recomendação de uso, na ordem: `getByRole` → `getByLabel` → `getByTestId`. `getByRole` testa
acessibilidade de graça; `data-testid` é o escape hatch para o que não tem papel semântico
(linhas de tabela, chips, itens do pick-list).

**Ponto específico do Angular:** o Material gera classes com hash/sufixo instáveis
(`.mat-mdc-*`, `_ngcontent-xyz`) que mudam entre versões — **nunca** ancorar seletor nelas. Nas
listagens geradas por `@for`, aplicar `data-testid` com chave do domínio
(`data-testid="relatorio-POUPANCA-0001"`), não com índice.

### Rodar no CI

Workflow oficial:

```yaml
- uses: actions/checkout@v5
- uses: actions/setup-node@v5
  with: { node-version: lts/* }
- run: npm ci
- run: npx playwright install --with-deps
- run: npx playwright test
- uses: actions/upload-artifact@v4
  if: ${{ !cancelled() }}
  with: { name: playwright-report, path: playwright-report/, retention-days: 30 }
```
Fonte: [playwright.dev/docs/ci-intro](https://playwright.dev/docs/ci-intro).

Complementos oficiais:
- `workers: process.env.CI ? 1 : undefined` para estabilidade no CI.
  Fonte: [playwright.dev/docs/ci](https://playwright.dev/docs/ci).
- `reporter: process.env.CI ? 'github' : 'list'` para gerar annotations no GitHub.
  Fonte: [playwright.dev/docs/test-reporters](https://playwright.dev/docs/test-reporters).
- `webServer: { command: 'npm run start', url: 'http://localhost:4200',
  reuseExistingServer: !process.env.CI }` sobe o Angular antes dos testes.
  Fonte: [playwright.dev/docs/test-webserver](https://playwright.dev/docs/test-webserver).

### Roles nos testes E2E — casa exatamente com os 3 perfis

O padrão oficial de **multiple signed in roles**: um *setup project* faz login uma vez por perfil e
salva `storageState` em arquivos distintos (`playwright/.auth/admin.json`, `gerente.json`,
`relator.json`); os testes declaram qual usar. Dá até para instanciar dois contextos no mesmo teste
e verificar interação entre perfis — por exemplo, **o GERENTE vincula o RELATOR a um grupo e o
RELATOR passa a ver o relatório**, que é justamente a regra de negócio central do documento.
Fonte: [playwright.dev/docs/auth](https://playwright.dev/docs/auth).

> **Ressalva:** o login passa pelo Keycloak, ou seja, por **outra origem**. O `storageState`
> guarda cookies e `localStorage` **por origem** — funciona, mas o `storageState` expira junto com
> a sessão do Keycloak. Em suíte longa, o setup precisa reautenticar. E se o realm usar verificação
> de e-mail (Mailpit, conforme o documento), o setup de cadastro do RELATOR terá de ler a caixa do
> Mailpit via API HTTP.

### Fato do ambiente local que precisa entrar no `package.json`

O ambiente tem **Playwright 1.60.0** com os browsers em `/opt/ms-playwright`:

```
chromium-1223  chromium_headless_shell-1223  ffmpeg-1011
```

Conferido nos `browsers.json` publicados de `playwright-core`:

| Playwright | revisão do Chromium exigida |
|---|---|
| **1.60.0** | **1223** ← é o que está instalado |
| 1.62.1 (latest no npm) | 1234 |

Ou seja: **fixar `@playwright/test@1.60.0`** reaproveita o Chromium já baixado (com
`PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright`, já exportado no ambiente). Subir para 1.62.1 exige
um `npx playwright install` novo — o que em ARM64 não é instantâneo. No CI (`ubuntu-latest`, x64)
isso é irrelevante; localmente, economiza um download por máquina.

---

## 8. Node: versão a fixar

Do calendário oficial ([nodejs/Release/schedule.json](https://github.com/nodejs/Release/blob/main/schedule.json)):

| Linha | Início | Vira LTS | Maintenance | Fim |
|---|---|---|---|---|
| v22 "Jod" | 2024-04-24 | 2024-10-29 | 2025-10-21 | 2027-04-30 |
| **v24 "Krypton"** | 2025-05-06 | **2025-10-28** | 2026-10-20 | **2028-04-30** |
| v26 | 2026-05-05 | 2026-10-28 | 2027-10-20 | 2029-04-30 |

Cruzando com a exigência do Angular 22 (`^22.22.3 || ^24.15.0 || ^26.0.0`,
[angular.dev/reference/versions](https://angular.dev/reference/versions)):

- **Node 24 é a escolha.** É LTS ativo, é o que está no ambiente (**24.16.0**), e seu fim de vida
  (2028-04-30) **cobre o fim do LTS do Angular 22** (2028-06 — quase; faltam ~2 meses, mas àquela
  altura já se terá migrado de major).
- Node 26 ainda **não é LTS** (só vira em 2026-10-28). Adotar agora é correr sem necessidade.
- Node 22 entra em *maintenance* desde 2025-10-21 e morre em 2027-04-30 — mais curto que o
  Angular 22.

**Fixar `"engines": { "node": ">=24.15.0 <25" }` no `package.json`** e o mesmo em `.nvmrc` e nas
imagens Docker. O piso `24.15.0` não é decorativo: é o mínimo que o Angular 22 aceita da linha 24.

**E fixar `"typescript": "~6.0.0"`** — repetindo o achado da seção 1, o `typescript@latest` hoje é
**7.0.2** e está **fora** da faixa aceita pelo Angular 22 (`>=6.0.0 <6.1.0`).

---

## Recomendação

### Stack

| Item | Escolha | Por quê, em uma linha |
|---|---|---|
| **Framework** | **Angular 22.1.x** | Nova cadência de 12 meses; Active até 2027-06, LTS até 2028-06. O v21 já saiu do Active em 2026-06-03. |
| **Node** | **24.x, piso `24.15.0`** (`engines` + `.nvmrc`) | LTS até 2028-04-30; é o mínimo que o Angular 22 aceita na linha 24. |
| **TypeScript** | **`~6.0.0`** — fixar | `latest` é 7.0.2 e **quebra** o Angular 22. |
| **Arquitetura** | Standalone + `bootstrapApplication` + rotas lazy por feature | Padrão oficial; NgModule é legado. |
| **Change detection** | **Zoneless** (padrão do v21+), `OnPush` implícito | Padrão. Implica: **todo estado de template é `signal`**. |
| **Estado** | **Serviço `providedIn:'root'` com signals + `httpResource`**; um `SessionStore` global | NgRx hoje **não instala** em Angular 22 (peer `^21.0.0`) e é desproporcional ao tamanho real. |
| **OIDC** | **`angular-auth-oidc-client` 21.0.2**, Code+PKCE com **refresh token rotacionado** | MIT, integração Angular nativa (guards + interceptor), sem pacote-ponte de terceiros. |
| **Design system** | **Angular Material 22.1.0** + componente `DualList` próprio sobre CDK drag-drop | MIT e versionado com o core. PrimeNG v22 virou licença comercial com license key. |
| **E2E** | **`@playwright/test` fixado em 1.60.0**, `data-testid`, `storageState` por perfil | Reaproveita o Chromium 1223 já instalado em `/opt/ms-playwright`. |
| **Unit test** | Vitest (`@angular/build:unit-test`, padrão do CLI) | Fato registrado; decisão final é do ticket 09. |

### As três decisões que realmente importam

**1. PrimeNG está fora — por licença, não por técnica.**
`primeng@22.0.0` (a única versão compatível com Angular 22) mudou para a licença **PrimeUI**:
gratuita só para organizações com **< US$ 1M de receita, < 5 devs, < 10 funcionários, < US$ 3M de
funding**, com renovação anual e **license key obrigatória** em runtime. Ficar no PrimeNG MIT
(`21.1.9`) prende o projeto no Angular 21, já fora do Active support. Verificado no `LICENSE.md`
dentro do tarball publicado — **o `LICENSE.md` do GitHub `master` ainda mostra o texto antigo e
induz ao erro**. Se a organização se qualificar à Community License, revisitar: o `<p-picklist>`
economiza trabalho real nas duas telas de vínculo.

**2. Back-channel logout é impossível neste desenho — registrar como risco aceito ou mudar a arquitetura.**
A spec OIDC exige que o RP **exponha um endpoint HTTP** para receber o `logout_token`. Um SPA de
arquivos estáticos não tem onde. Front-channel logout é a alternativa nominal, mas a própria spec
admite que quebra com bloqueio de cookie de terceiros. O que sobra e funciona:
`oidcSecurityService.logoff()` (RP-initiated, encerra a sessão **no Keycloak**, não só no browser)
+ **TTL curto de access token**. A janela em que um token revogado continua aceito é exatamente o
TTL — número que o **ticket 17** precisa fixar. Se back-channel logout virar requisito duro, a
única saída é um **BFF**, e isso é módulo novo, não configuração.

**3. Guard de role é usabilidade; a autorização mora na API.**
Usar `canMatch` (não `canActivate`) para rotas por perfil, para que o chunk das telas de
ADMINISTRADOR nem seja baixado por um RELATOR. Mas escrever na spec, com todas as letras: **isso é
UX, não segurança** — o `if` está na máquina do usuário. E o corolário para o **ticket 15**: se a
autorização final é do banco, o frontend **não replica** a cadeia `relatório → role → grupo →
usuário`; ele pede à API a lista do que o usuário pode ver. Duas implementações da mesma regra
divergem, sempre.

### Pontos que este research deixa em aberto (para os tickets donos)

- **Ticket 17** — TTL do access token e do refresh token; se haverá BFF; exposição do Account Console.
- **Ticket 25** — síncrono/híbrido; se o download sai por URL pré-assinada do MinIO (o que remove
  o `Blob` grande da heap do browser *e* da API) ou streamando pela API.
- **Ticket 32** — o protótipo decide se as telas de vínculo pedem mesmo um pick-list de dois
  painéis; é isso que dimensiona o custo do `DualList` próprio.
- **Ticket 09** — runner unitário e como o Playwright encaixa no pipeline junto com Newman.
- **Ticket 11** — se o Traefik/API emitem `Content-Length` nos downloads; sem ele, a barra de
  progresso é obrigatoriamente indeterminada.
