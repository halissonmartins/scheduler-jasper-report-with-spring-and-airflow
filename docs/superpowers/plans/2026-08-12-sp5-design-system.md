# SP-5 — Design system · Plano de implementação

> **Para executores agênticos:** SUB-SKILL OBRIGATÓRIA — use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para implementar tarefa a tarefa. Os passos usam
> caixas (`- [ ]`) para rastreio.
>
> ⚠️ **A Tarefa 6 está bloqueada** pelas escolhas de SP-4. Ver "Gate" abaixo.

**Objetivo:** entregar o tema, o documento de design system, os componentes canônicos e a página de
referência, com acessibilidade verificada por lint e por teste.

**Arquitetura:** sete tarefas. As cinco primeiras não dependem de SP-4 e entregam tokens, documento,
`estados`, `confirmacao` e a página `/ui`. A sexta é a `tabela` e o estado *carregando*, bloqueados.
A sétima fecha a acessibilidade.

**Tech stack:** Angular 22 · Angular Material 22.1.2 · Angular CDK 22.1.2 · SCSS · Playwright.

**Spec:** [`docs/superpowers/specs/2026-08-12-sp5-design-system-design.md`](../specs/2026-08-12-sp5-design-system-design.md)

---

## Pré-condição dura

**SP-3 precisa estar executado.** Sem `frontend/` não há onde instalar o Material. Confira antes de
começar:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
test -f frontend/package.json && test -f frontend/angular.json \
  && echo "OK: frontend existe" \
  || { echo "PARE: SP-3 nao foi executado. frontend/ nao existe."; exit 1; }
```

## Gate

A **Tarefa 6** implementa a `tabela` e a forma do estado *carregando*. As duas dependem de decisões
que SP-4 produz e que ninguém mais pode tomar:

- **Navegação escolhida** — decide se a tabela precisa de filtro e ordenação (tabela plana), de
  expansão (árvore) ou de nada disso (*drill-down*).
- **Espera escolhida** — decide se *carregando* é modal bloqueante, progresso por linha na tabela,
  ou confirmação prévia.

**Se as escolhas não estiverem disponíveis, pare na Tarefa 5 e reporte.** Implementar a tabela
supondo uma variante produz um componente que será reescrito, e pior: registra como padrão canônico
algo que ninguém decidiu.

---

## Restrições globais

Valem para **todas** as tarefas. Copiadas da spec.

- **Nenhum literal de cor ou espaçamento** em componente. Qualquer `#hex` ou `px` fora dos tokens é
  violação — critério de aceite 3.
- **Só envelopamos o que carrega regra do projeto.** `tabela`, `estados` e `confirmacao`. Botão,
  input e formulário usam Material direto: um envelope que só repassa atributos é a abstração de uso
  único que o `CLAUDE.md` proíbe.
- **Densidade `−2` é global**; nenhum componente a sobrescreve localmente.
- **Angular 22:** componentes *standalone*, `input()`/`output()` como signals, control flow
  `@if`/`@for`. Nada de `NgModule`, `@Input()` decorator ou `*ngIf`.
- **Idioma:** pt-BR na interface, no documento e nos commits. `lang="pt-BR"` no `index.html`.
- **Commits em pt-BR**, assunto imperativo, sem prefixo `feat:`.

---

## Tarefa 1: Material, tema e tokens

**Arquivos:**
- Modificar: `frontend/package.json`, `frontend/src/styles.scss`, `frontend/src/index.html`
- Criar: `frontend/src/estilos/_tokens.scss`

**Interfaces:**
- Produz: as variáveis SCSS `$esp-*`, `$raio-*` e as classes de status, consumidas pelas Tarefas 3
  a 6.

- [ ] **Passo 1: Instalar Material e CDK**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npm install @angular/material@22.1.2 @angular/cdk@22.1.2
```

- [ ] **Passo 2: Gerar a paleta a partir da cor-fonte**

O Angular Material traz um schematic que deriva a paleta Material 3 de uma cor-fonte:

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng generate @angular/material:theme-color \
  --primary-color="#1B5E7E" \
  --directory="src/estilos/" \
  --include-high-contrast=false
```

Isso cria `src/estilos/_theme-colors.scss`.

**Se o schematic não existir nesta versão**, use a paleta pré-definida mais próxima e registre a
troca no `design-system.md`:

```scss
// fallback: paleta pre-definida, caso o schematic nao esteja disponivel
@use '@angular/material' as mat;
$paleta-primaria: mat.$azure-palette;
```

- [ ] **Passo 3: Escrever `src/estilos/_tokens.scss`**

Estes são os únicos valores permitidos. Literal fora daqui é violação do critério 3.

```scss
// Espacamento — escala base 4dp do Material, conforme o guia
$esp-4:  4px;
$esp-8:  8px;
$esp-12: 12px;
$esp-16: 16px;
$esp-24: 24px;
$esp-32: 32px;
$esp-48: 48px;

// Raio — tres valores. Mais que isso ninguem respeita.
$raio-p: 4px;
$raio-m: 8px;
$raio-g: 12px;

// Elevacao — tela administrativa nao precisa dos cinco niveis do Material
$elev-0: none;
$elev-1: 0 1px 2px rgba(0, 0, 0, 0.12);
$elev-2: 0 2px 6px rgba(0, 0, 0, 0.16);
```

- [ ] **Passo 4: Aplicar o tema em `src/styles.scss`**

```scss
@use '@angular/material' as mat;
@use './estilos/theme-colors' as tema;
@use './estilos/tokens' as *;

html {
  @include mat.theme((
    color: (
      primary: tema.$primary-palette,
      tertiary: tema.$tertiary-palette,
    ),
    typography: Roboto,
    density: -2,   // linha de tabela ~40px: 16 linhas visiveis contra 12
  ));

  color-scheme: light;   // modo escuro fica fora de SP-5, por decisao
}

body {
  margin: 0;
  background: var(--mat-sys-surface);
  color: var(--mat-sys-on-surface);
  font-family: Roboto, sans-serif;
}

// Mapa status -> cor. Isto e regra de negocio, nao estetica:
// "processado com alerta" NAO pode parecer erro, porque o artefato e
// valido e utilizavel — so demorou. Em vermelho, o usuario deixaria de
// baixar um relatorio perfeitamente bom. (RN-11, RN-12)
.status-em-processamento { color: var(--mat-sys-on-surface-variant); }
.status-sucesso          { color: var(--mat-sys-primary); }
.status-alerta           { color: var(--mat-sys-tertiary); }
.status-erro             { color: var(--mat-sys-error); }
```

- [ ] **Passo 5: Declarar o idioma**

Em `src/index.html`, trocar `<html lang="en">` por `<html lang="pt-BR">` (`RNF-15`).

- [ ] **Passo 6: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
grep -q 'lang="pt-BR"' src/index.html && echo "idioma: ok"
grep -q 'density: -2' src/styles.scss && echo "densidade: ok"
grep -c 'status-' src/styles.scss   # esperado >= 4
npm run build --silent && echo "build: ok"
```

- [ ] **Passo 7: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/package.json frontend/package-lock.json frontend/src/styles.scss \
        frontend/src/estilos frontend/src/index.html
git commit -m "$(cat <<'EOF'
Tema Material 3 com densidade compacta e tokens fechados

Densidade -2 não é preferência estética: a tabela plana pode chegar a
56 linhas, e a diferença é 16 linhas visíveis contra 12.

O mapa de status para cor é regra de negócio. Processado com alerta usa
a cor terciária e não a de erro, porque o artefato é válido e apenas
demorou — em vermelho, o usuário deixaria de baixar um relatório bom, e
nenhum teste automatizado pegaria isso.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `docs/design/design-system.md`

**Arquivos:**
- Criar: `docs/design/design-system.md`

- [ ] **Passo 1: Escrever o documento**

Seções obrigatórias, com este conteúdo:

**Tokens** — a tabela da spec §3.2, com os valores de `_tokens.scss` e a cor-fonte `#1B5E7E`.
Registrar o contraste verificado: **`#1B5E7E` sobre branco dá 7,12:1**, acima do AA (4,5) e do AAA
(7,0). Ressalvar que o Material *deriva* a paleta da cor-fonte, então cada par gerado ainda precisa
ser conferido.

**Mapa status → cor**, com a justificativa:

```markdown
| Status | Token | Por quê |
|---|---|---|
| `em processamento` | `on-surface-variant` | Neutro: não terminou, não é desfecho |
| `processado com sucesso` | `primary` | — |
| `processado com alerta` | `tertiary` | **Não pode parecer erro.** O artefato é válido e utilizável; o alerta sinaliza degradação de desempenho, não de conteúdo (RN-11) |
| `processado com erro` | `error` | — |
```

**As quatro regras**, escritas como proibição:

1. Nunca usar valor de cor ou espaçamento fora dos tokens.
2. Todo formulário segue o padrão de `/ui`.
3. Toda mensagem de erro aparece pelo componente `estados` — nunca `alert` nem texto solto.
4. Densidade `−2` é global; nenhum componente a sobrescreve.

**Componentes canônicos**, com o caminho de cada um e a regra que encapsula, mais a frase que
explica por que botão e input **não** têm envelope.

**Acessibilidade obrigatória** — a tabela de §3.5, com o método de verificação de cada requisito.

**Modo escuro** — declarado fora de escopo, com o aviso de que acrescentá-lo exige reverificar todo
par de cores em AA; não é ajuste de tema.

- [ ] **Passo 2: Verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
D=docs/design/design-system.md
echo "regras:      $(grep -cE '^[1-4]\. ' $D)  (esperado >= 4)"
echo "status:      $(grep -cE '^\| `(em processamento|processado)' $D)  (esperado 4)"
echo "contraste:   $(grep -c '7,12' $D)  (esperado >= 1)"
git add $D
git commit -m "$(cat <<'EOF'
Design system: tokens, regras e o mapa de status

As regras entram como proibição, que é a forma que um agente não infere
a partir de exemplos e por isso viola quando não está escrita.

Registra o contraste da cor-fonte verificado por cálculo — 7,12 sobre
branco — e ressalva que o Material deriva a paleta, então cada par
gerado ainda precisa ser conferido.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Componente `estados`

**Arquivos:**
- Criar: `frontend/src/app/ui/estados/estados.ts`, `estados.html`, `estados.scss`
- Criar: `frontend/src/app/ui/estados/estados.spec.ts`

**Interfaces:**
- Produz: `<app-estados>` com `modo`, `mensagem`, `erro`, consumido pela `/ui` (Tarefa 5) e por
  todas as telas de SP-7.

- [ ] **Passo 1: Escrever o teste que falha**

```typescript
// estados.spec.ts
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Estados } from './estados';

describe('Estados', () => {
  let fixture: ComponentFixture<Estados>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({ imports: [Estados] }).compileComponents();
    fixture = TestBed.createComponent(Estados);
  });

  it('vazio nao usa a cor de erro — pendente de vinculo nao e falha (RF-16)', () => {
    fixture.componentRef.setInput('modo', 'vazio');
    fixture.componentRef.setInput('mensagem', 'Aguardando configuracao das permissoes.');
    fixture.detectChanges();
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.estado-vazio')).toBeTruthy();
    expect(el.querySelector('.estado-erro')).toBeNull();
  });

  it('erro exibe momento, descricao e correlation id (RF-38)', () => {
    fixture.componentRef.setInput('modo', 'erro');
    fixture.componentRef.setInput('erro', {
      momento: '2026-08-12T14:32:05-03:00',
      descricao: 'Falha ao ler o artefato.',
      correlationId: 'a3f9-2b1c-88de',
    });
    fixture.detectChanges();
    const texto: string = fixture.nativeElement.textContent;
    expect(texto).toContain('2026-08-12T14:32:05-03:00');
    expect(texto).toContain('Falha ao ler o artefato.');
    expect(texto).toContain('a3f9-2b1c-88de');
  });

  it('erro oferece copia em JSON (RF-39)', () => {
    fixture.componentRef.setInput('modo', 'erro');
    fixture.componentRef.setInput('erro', {
      momento: '2026-08-12T14:32:05-03:00',
      descricao: 'Falha ao ler o artefato.',
      correlationId: 'a3f9-2b1c-88de',
    });
    fixture.detectChanges();
    const botao = fixture.nativeElement.querySelector('[data-teste="copiar-erro"]');
    expect(botao).toBeTruthy();
  });
});
```

- [ ] **Passo 2: Rodar e ver falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng test --watch=false --browsers=ChromeHeadless
```

Esperado: falha por `Estados` não existir.

- [ ] **Passo 3: Implementar**

```typescript
// estados.ts
import { Component, input, ChangeDetectionStrategy } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

export type ModoEstado = 'vazio' | 'carregando' | 'erro' | 'sucesso' | 'desabilitado';

export interface ErroExibido {
  momento: string;        // ISO 8601 — RA-41
  descricao: string;
  correlationId: string;
}

@Component({
  selector: 'app-estados',
  standalone: true,
  imports: [MatIconModule, MatButtonModule, MatProgressSpinnerModule],
  templateUrl: './estados.html',
  styleUrl: './estados.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Estados {
  readonly modo = input.required<ModoEstado>();
  readonly mensagem = input<string>('');
  readonly erro = input<ErroExibido | null>(null);

  comoJson(): string {
    return JSON.stringify(this.erro(), null, 2);
  }

  copiar(): void {
    void navigator.clipboard.writeText(this.comoJson());
  }
}
```

```html
<!-- estados.html -->
@switch (modo()) {
  @case ('vazio') {
    <div class="estado estado-vazio" role="status">
      <mat-icon aria-hidden="true">inbox</mat-icon>
      <p>{{ mensagem() }}</p>
    </div>
  }
  @case ('carregando') {
    <div class="estado estado-carregando" role="status" aria-live="polite">
      <mat-progress-spinner mode="indeterminate" diameter="32" />
      <p>{{ mensagem() }}</p>
    </div>
  }
  @case ('erro') {
    <div class="estado estado-erro" role="alert">
      <mat-icon aria-hidden="true">error_outline</mat-icon>
      <p class="descricao">{{ erro()?.descricao }}</p>
      <dl class="detalhe">
        <dt>Momento</dt><dd>{{ erro()?.momento }}</dd>
        <dt>Correlation ID</dt><dd>{{ erro()?.correlationId }}</dd>
      </dl>
      <button mat-stroked-button data-teste="copiar-erro" (click)="copiar()">
        Copiar erro em JSON
      </button>
    </div>
  }
  @case ('sucesso') {
    <div class="estado estado-sucesso" role="status">
      <mat-icon aria-hidden="true">check_circle_outline</mat-icon>
      <p>{{ mensagem() }}</p>
    </div>
  }
  @case ('desabilitado') {
    <div class="estado estado-desabilitado" aria-disabled="true">
      <p>{{ mensagem() }}</p>
    </div>
  }
}
```

```scss
// estados.scss — só tokens, nenhum literal
@use '../../../estilos/tokens' as *;

.estado {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: $esp-8;
  padding: $esp-32 $esp-16;
  text-align: center;
}
.estado-vazio    { color: var(--mat-sys-on-surface-variant); }
.estado-erro     { color: var(--mat-sys-error); }
.estado-sucesso  { color: var(--mat-sys-primary); }
.estado-desabilitado { color: var(--mat-sys-outline); }

.detalhe {
  display: grid;
  grid-template-columns: auto auto;
  gap: $esp-4 $esp-12;
  font-size: 0.85rem;
  color: var(--mat-sys-on-surface-variant);
}
```

O `role="alert"` no erro e o `role="status"` com `aria-live="polite"` no carregando não são
enfeite: são o que faz um leitor de tela anunciar a mudança. Sem eles, o estado muda em silêncio.

- [ ] **Passo 4: Rodar e ver passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng test --watch=false --browsers=ChromeHeadless
```

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/src/app/ui/estados
git commit -m "$(cat <<'EOF'
Componente de estados, com vazio que não parece erro

Os cinco estados num componente só. Dois carregam regra: o vazio é
estado legítimo — o relator pendente de vínculo veria a tela quebrada
no primeiro acesso se viesse em vermelho — e o erro carrega o contrato
de RA-41, com momento, descrição, Correlation ID e cópia em JSON.

O role de alerta e o aria-live não são enfeite: sem eles a mudança de
estado acontece em silêncio para quem usa leitor de tela.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Componente `confirmacao`

**Arquivos:**
- Criar: `frontend/src/app/ui/confirmacao/confirmacao.ts`, `confirmacao.html`, `confirmacao.scss`
- Criar: `frontend/src/app/ui/confirmacao/confirmacao.spec.ts`

**Interfaces:**
- Produz: `Confirmacao` como componente de `MatDialog`, com `DadosConfirmacao` na entrada e
  `string | undefined` (o motivo) na saída.

- [ ] **Passo 1: Escrever o teste que falha**

```typescript
// confirmacao.spec.ts
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { Confirmacao } from './confirmacao';

describe('Confirmacao', () => {
  let fixture: ComponentFixture<Confirmacao>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Confirmacao, NoopAnimationsModule],
      providers: [
        { provide: MatDialogRef, useValue: { close: () => {} } },
        { provide: MAT_DIALOG_DATA, useValue: {
            titulo: 'Reprocessar POUPANCA-0001?',
            aviso: 'Os artefatos desta data serao sobrescritos.',
            rotuloAcao: 'Reprocessar',
        } },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(Confirmacao);
    fixture.detectChanges();
  });

  it('nao habilita a acao com motivo vazio (RF-11)', () => {
    const botao: HTMLButtonElement =
      fixture.nativeElement.querySelector('[data-teste="confirmar"]');
    expect(botao.disabled).toBeTrue();
  });

  it('habilita a acao quando o motivo e preenchido', () => {
    const componente = fixture.componentInstance;
    componente.motivo.setValue('Numero divergente na apuracao de ontem.');
    fixture.detectChanges();
    const botao: HTMLButtonElement =
      fixture.nativeElement.querySelector('[data-teste="confirmar"]');
    expect(botao.disabled).toBeFalse();
  });

  it('exibe o aviso do efeito destrutivo (RN-20)', () => {
    expect(fixture.nativeElement.textContent)
      .toContain('Os artefatos desta data serao sobrescritos.');
  });
});
```

- [ ] **Passo 2: Rodar e ver falhar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng test --watch=false --browsers=ChromeHeadless
```

- [ ] **Passo 3: Implementar**

```typescript
// confirmacao.ts
import { Component, inject, ChangeDetectionStrategy } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';

export interface DadosConfirmacao {
  titulo: string;
  aviso: string;
  rotuloAcao: string;
}

@Component({
  selector: 'app-confirmacao',
  standalone: true,
  imports: [
    ReactiveFormsModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatButtonModule,
  ],
  templateUrl: './confirmacao.html',
  styleUrl: './confirmacao.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Confirmacao {
  readonly dados = inject<DadosConfirmacao>(MAT_DIALOG_DATA);
  private readonly ref = inject(MatDialogRef<Confirmacao, string | undefined>);

  // RF-11: solicitacao sem motivo e rejeitada. A validacao aqui e a
  // primeira barreira; a segunda e no servidor, e as duas sao necessarias.
  readonly motivo = new FormControl('', {
    nonNullable: true,
    validators: [Validators.required, Validators.minLength(10)],
  });

  confirmar(): void {
    if (this.motivo.valid) {
      this.ref.close(this.motivo.value);
    }
  }

  cancelar(): void {
    this.ref.close(undefined);
  }
}
```

```html
<!-- confirmacao.html -->
<h2 mat-dialog-title>{{ dados.titulo }}</h2>

<mat-dialog-content>
  <p class="aviso" role="alert">{{ dados.aviso }}</p>

  <mat-form-field appearance="outline" class="campo-motivo">
    <mat-label>Motivo</mat-label>
    <textarea matInput [formControl]="motivo" rows="3"
              placeholder="Descreva por que esta refazendo a apuracao"></textarea>
    @if (motivo.hasError('required') && motivo.touched) {
      <mat-error>O motivo e obrigatorio.</mat-error>
    }
    @if (motivo.hasError('minlength')) {
      <mat-error>Descreva com ao menos 10 caracteres.</mat-error>
    }
  </mat-form-field>
</mat-dialog-content>

<mat-dialog-actions align="end">
  <button mat-button (click)="cancelar()">Cancelar</button>
  <button mat-flat-button data-teste="confirmar"
          [disabled]="motivo.invalid" (click)="confirmar()">
    {{ dados.rotuloAcao }}
  </button>
</mat-dialog-actions>
```

```scss
// confirmacao.scss
@use '../../../estilos/tokens' as *;

.aviso {
  color: var(--mat-sys-error);
  margin-bottom: $esp-16;
}
.campo-motivo { width: 100%; }
```

- [ ] **Passo 4: Rodar e ver passar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng test --watch=false --browsers=ChromeHeadless
```

- [ ] **Passo 5: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/src/app/ui/confirmacao
git commit -m "$(cat <<'EOF'
Diálogo de confirmação com motivo obrigatório

É o único dos três componentes que existe por regra de negócio e não
por necessidade de interface: RF-11 diz que reprocessamento sem motivo
é rejeitado, e um diálogo genérico de "tem certeza?" não cumpriria
isso.

A validação aqui é a primeira barreira, não a única — o servidor
valida de novo, e as duas são necessárias.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: Página de referência `/ui`

**Arquivos:**
- Criar: `frontend/src/app/ui/referencia/referencia.ts`, `referencia.html`, `referencia.scss`
- Modificar: `frontend/src/app/app.routes.ts`

**Interfaces:**
- Consome: `Estados` (Tarefa 3) e `Confirmacao` (Tarefa 4).

- [ ] **Passo 1: Criar a página**

Seções obrigatórias, nesta ordem: **Tokens** (amostras de espaçamento, raio e as quatro cores de
status) · **Botões** (todas as variantes do Material) · **Campos** (input, textarea, select, com
erro) · **Formulário completo** · **Estados** (os cinco, com `<app-estados>`) · **Diálogo** (botão
que abre `Confirmacao` e mostra o motivo devolvido).

Cada seção com título `<h2>` e um parágrafo dizendo **quando usar aquele padrão** — é o que
transforma a página de vitrine em referência.

Use os dados falsos do catálogo real, coerentes com SP-4: `CONTACORRENTE-1234`,
`Tarifas debitadas por pacote de serviços`, `12/08/2026`.

- [ ] **Passo 2: Registrar a rota**

```typescript
// app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: 'ui',
    // Pagina de referencia do design system. Fica na aplicacao sem link
    // na navegacao: uma referencia que so existe em desenvolvimento
    // diverge do que esta no ar e deixa de servir ao que foi feita.
    loadComponent: () => import('./ui/referencia/referencia').then(m => m.Referencia),
    title: 'Referência do design system',
  },
];
```

- [ ] **Passo 3: Verificar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npm run build --silent && echo "build: ok"
grep -q "path: 'ui'" src/app/app.routes.ts && echo "rota: ok"
echo "literais de cor fora dos tokens: $(grep -rnE '#[0-9a-fA-F]{3,8}\b' src/app/ui --include=*.scss | wc -l)  (esperado 0)"
```

- [ ] **Passo 4: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/src/app/ui/referencia frontend/src/app/app.routes.ts
git commit -m "$(cat <<'EOF'
Página de referência do design system em /ui

É o "exemplo real no repositório" que o checkpoint de P2 exige, e é de
onde se copia o padrão. Cada seção diz quando usar aquilo — sem isso
seria vitrine, não referência.

Fica na aplicação sem link na navegação. Excluí-la do build de produção
faria a referência divergir do que está no ar.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

> ⚠️ **Se as escolhas de SP-4 não estiverem disponíveis, PULE a Tarefa 6 e vá direto para a
> Tarefa 7.** Só a Tarefa 6 depende de SP-4 — lint, contraste e teste de teclado funcionam sobre o
> que já existe, e é melhor ter a acessibilidade verificada agora do que esperar por uma decisão de
> UX. Ao pular, anote no relatório que a Tarefa 6 ficou pendente.

---

## Tarefa 6: `tabela` e o estado *carregando* — BLOQUEADA POR SP-4

**Arquivos:**
- Criar: `frontend/src/app/ui/tabela/tabela.ts`, `tabela.html`, `tabela.scss`, `tabela.spec.ts`
- Modificar: `frontend/src/app/ui/estados/estados.html` (forma do carregando)
- Modificar: `frontend/src/app/ui/referencia/referencia.html` (acrescentar a seção da tabela)

**Interfaces:**
- Consome: a navegação e a espera escolhidas em SP-4; os tokens da Tarefa 1.

- [ ] **Passo 1: Ler as escolhas de SP-4**

Abra `docs/design/decisoes-ux.md` e leia `DUX-01` (navegação) e `DUX-02` (espera). **Se o arquivo
não existir, pare e reporte** — SP-4 não chegou ao fim.

- [ ] **Passo 2: Implementar a `tabela` conforme `DUX-01`**

| Se `DUX-01` escolheu | A `tabela` precisa de |
|---|---|
| Tabela plana com filtros | `matSort` em todas as colunas, `mat-paginator`, e campo de filtro por data e produto. Precisa sustentar **56 linhas** sem rolagem horizontal em 1280 px |
| Árvore expansível | Linhas expansíveis com `@for` aninhado; múltiplos ramos abertos ao mesmo tempo |
| *Drill-down* | Tabela simples, sem filtro nem expansão; a navegação acontece entre rotas |

Em qualquer caso: coluna de código com largura suficiente para 18 caracteres
(`CONTACORRENTE-1234`), e a coluna de status usando as classes `.status-*` da Tarefa 1.

- [ ] **Passo 3: Implementar o carregando conforme `DUX-02`**

| Se `DUX-02` escolheu | O que muda |
|---|---|
| Modal bloqueante | `Estados` no modo `carregando` dentro de um `MatDialog` sem `disableClose: false` |
| **Progresso por linha** | A `tabela` ganha `input` de linhas em processamento e troca a ação por `mat-progress-spinner` naquela linha. O resto continua navegável |
| Confirmação prévia | Reusa `Confirmacao` sem campo de motivo, seguida do modo `carregando` |

- [ ] **Passo 4: Escrever o teste da tabela**

O teste depende da variante. Em todos os casos, verifique: que 56 linhas renderizam; que o código de
18 caracteres não quebra o layout; e que a coluna de status aplica a classe correta para cada um dos
quatro status — em particular que **`processado com alerta` não recebe `.status-erro`**.

- [ ] **Passo 5: Rodar, verificar e commitar**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npx ng test --watch=false --browsers=ChromeHeadless
npm run build --silent && echo "build: ok"
cd ..
git add frontend/src/app/ui
git commit -m "$(cat <<'EOF'
Tabela e estado de carregando, conforme as escolhas de SP-4

Implementados a partir de DUX-01 e DUX-02, e não de suposição. O
protótipo existiu para produzir estas duas decisões.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Acessibilidade verificada

**Arquivos:**
- Modificar: `frontend/eslint.config.js`
- Criar: `frontend/e2e/acessibilidade.spec.ts`
- Criar: `frontend/ferramentas/contraste.mjs`

- [ ] **Passo 1: Ativar as regras de a11y no lint**

Acrescente ao bloco de templates em `eslint.config.js`:

```javascript
{
  files: ['**/*.html'],
  rules: {
    '@angular-eslint/template/label-has-associated-control': 'error',
    '@angular-eslint/template/elements-content': 'error',
    '@angular-eslint/template/alt-text': 'error',
    '@angular-eslint/template/valid-aria': 'error',
    '@angular-eslint/template/click-events-have-key-events': 'error',
    '@angular-eslint/template/interactive-supports-focus': 'error',
  },
},
```

Label sem associação é o erro de acessibilidade mais comum e o mais fácil de detectar
automaticamente — é o que mais rende dos cinco requisitos.

- [ ] **Passo 2: Escrever o verificador de contraste**

```javascript
// ferramentas/contraste.mjs
// Confere pares de cores contra o AA da WCAG: 4.5:1 texto, 3:1 componentes.
const lum = (hex) => {
  const c = hex.replace('#', '');
  const [r, g, b] = [0, 2, 4].map(i => parseInt(c.slice(i, i + 2), 16) / 255);
  const f = v => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
};
const razao = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};

// Pares em uso. Acrescente aqui todo par novo que o tema gerar.
const pares = [
  ['texto sobre superficie', '#1B5E7E', '#FFFFFF', 4.5],
];

let falhou = false;
for (const [nome, fg, bg, minimo] of pares) {
  const r = razao(fg, bg);
  const ok = r >= minimo;
  if (!ok) falhou = true;
  console.log(`${ok ? 'OK  ' : 'FALHA'} ${nome}: ${r.toFixed(2)}:1 (minimo ${minimo})`);
}
process.exit(falhou ? 1 : 0);
```

**Ao rodar, acrescente à lista `pares` todo par que o tema de fato gerou** — o Material deriva a
paleta da cor-fonte, e são os pares derivados que precisam passar, não só a cor-fonte.

- [ ] **Passo 3: Escrever o teste de teclado**

```typescript
// e2e/acessibilidade.spec.ts
import { test, expect } from '@playwright/test';

test('a pagina de referencia e percorrivel por teclado', async ({ page }) => {
  await page.goto('/ui');

  const interativos = await page.locator(
    'button, a[href], input, textarea, select, [tabindex]:not([tabindex="-1"])'
  ).count();
  expect(interativos).toBeGreaterThan(0);

  // Percorre com Tab e confirma que o foco sempre pousa em algo visivel
  for (let i = 0; i < interativos; i++) {
    await page.keyboard.press('Tab');
    const focado = page.locator(':focus');
    await expect(focado).toBeVisible();

    // Foco visivel: o elemento focado precisa ter outline ou box-shadow
    const temIndicador = await focado.evaluate((el) => {
      const s = getComputedStyle(el);
      return (s.outlineStyle !== 'none' && s.outlineWidth !== '0px')
          || s.boxShadow !== 'none';
    });
    expect(temIndicador, `elemento ${i} sem indicador de foco visivel`).toBeTrue();
  }
});

test('o idioma da pagina e pt-BR', async ({ page }) => {
  await page.goto('/ui');
  await expect(page.locator('html')).toHaveAttribute('lang', 'pt-BR');
});
```

- [ ] **Passo 4: Rodar tudo**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow/frontend
npm run lint && echo "lint a11y: ok"
node ferramentas/contraste.mjs && echo "contraste: ok"
npx playwright test e2e/acessibilidade.spec.ts && echo "teclado: ok"
```

- [ ] **Passo 5: Conferir os dez critérios de aceite**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
echo "1. design-system:  $(test -f docs/design/design-system.md && echo ok || echo FALTA)"
echo "2. densidade -2:   $(grep -c 'density: -2' frontend/src/styles.scss)"
echo "3. literais cor:   $(grep -rnE '#[0-9a-fA-F]{3,8}\b' frontend/src/app/ui --include=*.scss | wc -l)  (esperado 0)"
echo "3. literais px:    $(grep -rnE ': *[0-9]+px' frontend/src/app/ui --include=*.scss | wc -l)  (esperado 0)"
echo "4. componentes:    $(ls -d frontend/src/app/ui/*/ | wc -l)  (esperado 4; 3 se a Tarefa 6 ficou bloqueada)"
echo "5. rota /ui:       $(grep -c \"path: 'ui'\" frontend/src/app/app.routes.ts)"
echo "9. erro completo:  $(grep -c 'correlationId' frontend/src/app/ui/estados/estados.html)"
echo "10. motivo trava:  $(grep -c 'motivo.invalid' frontend/src/app/ui/confirmacao/confirmacao.html)"
```

Os critérios 6, 7 e 8 são os comandos do Passo 4.

- [ ] **Passo 6: Commit**

```bash
cd /home/ubuntu/scheduler-jasper-report-with-spring-and-airflow
git add frontend/eslint.config.js frontend/e2e frontend/ferramentas
git commit -m "$(cat <<'EOF'
Acessibilidade verificada: lint, contraste e teclado

Cada requisito ganha um método de verificação em vez de uma boa
intenção. Label por lint, porque é o erro mais comum e o mais fácil de
detectar; contraste por cálculo sobre os pares em uso; foco e teclado
por teste sobre a página de referência, que é onde todos os padrões
coexistem.

O verificador de contraste começa com a cor-fonte e precisa receber
todo par que o tema derivar — o Material gera a paleta, e são os
derivados que precisam passar.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Definição de pronto

SP-5 termina quando os dez critérios do Passo 5 da Tarefa 7 passam e os sete commits estão no
branch.

**Se a Tarefa 6 ficou bloqueada**, SP-5 fica parcialmente entregue: tokens, documento, `estados`,
`confirmacao`, `/ui` e a acessibilidade do que existe. A `tabela` e a forma do carregando entram
quando SP-4 produzir `DUX-01` e `DUX-02` — e isso é esperado, não é falha.
