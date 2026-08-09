# SP-1 — Linguagem e histórias (P0)

> Spec do primeiro sub-projeto. Entrega `docs/glossario.md` e `docs/user-stories.md`,
> os dois artefatos que a fase P0 do [`guias/guia-app-web.md`](../../guias/guia-app-web.md)
> exige antes de E3.
>
> Data: 2026-08-09 · Branch: `00-super-powers`

---

## 1. Contexto

O repositório tem três documentos e nenhum código: [`prd.md`](../../prd.md),
[`arquitetura-inicial.md`](../../arquitetura-inicial.md) e o guia de implementação. O PRD
define 55 requisitos funcionais e 54 regras de negócio; a arquitetura define 68 decisões
técnicas. Falta a camada entre os dois: **os nomes** e **as histórias**.

O guia é explícito sobre a consequência de pular o glossário — *"três tabelas para a mesma
entidade"* — porque o ponto de contato dele é E2, o schema do banco. E é explícito sobre a
consequência de pular as histórias: *"testes que verificam o código, não o requisito"*.

### Decomposição do projeto

O escopo total (mono repo, biblioteca comum, starter, 5 módulos processadores, API REST,
Angular, Airflow, Keycloak, MinIO, Traefik, Mailpit e a pilha OTel/Graylog/Prometheus/
Grafana/Jaeger) é grande demais para uma spec única. Foi decomposto em sub-projetos, cada um
com o seu próprio ciclo spec → plano → implementação:

| # | Sub-projeto | Fase | Entrega | Depende de |
|---|---|---|---|---|
| **SP-1** | **Linguagem e histórias** | **P0** | **`glossario.md`, `user-stories.md`** | **—** |
| SP-2 | Decisões técnicas | E0 | `adr/NNNN-*.md`, `arquitetura/c4-contexto.md`, `riscos.md`, nomes dos módulos | SP-1 |
| SP-3 | Fundações do repositório | E1 | Mono repo Maven, lint/format, `docker-compose.yml`, `.env.example`, `Makefile`, CI bloqueante, pre-commit, `README.md`, `ARCHITECTURE.md` esquelético | SP-2 |
| SP-4 | Fluxos e protótipo | P1 | `design/fluxos.md`, `decisoes-ux.md`, protótipo navegável descartável | SP-1 |
| SP-5 | Design system | P2 | `design-system.md` + componentes canônicos Angular | SP-4, SP-3 |
| SP-6a | Catálogo de exemplo | E2 | Os 10 relatórios (RA-08), domínios, schemas transacionais, JRXMLs | SP-1, SP-3 |
| SP-6b | Contratos internos | E2 | Schema de controle + Flyway, `openapi.yaml`, tipos gerados, seed | SP-1, SP-3, SP-4 |
| SP-7 | Esqueleto + fatia vertical | E3 | Módulos compilando, health checks, `ARCHITECTURE.md` preenchido, `*.feature`, 1 produto → 1 relatório → `.jrprint` → PDF | SP-5, SP-6a, SP-6b |
| SP-8+ | Loop de features | E4 | Coleta completa · identidade e permissão · exportação · retenção · reprocessamento · catálogo · 4 produtos restantes · telas Angular | SP-7 |
| T | Transversais | E5/E6 | `threat-model.md`, OWASP, scan de dependências, runbook, `CHANGELOG.md` | corre desde SP-7 |

SP-2/SP-3 correm em paralelo a SP-4. `P0 → P1 → P2 precedem E3`, então SP-7 é o ponto de
encontro dos dois eixos.

**Esta spec cobre exclusivamente SP-1.**

---

## 2. Objetivo

Fixar a linguagem ubíqua e o rastreio requisito → história, de modo que:

- SP-6b saiba como nomear cada tabela e cada coluna sem inventar;
- SP-7 saiba quais arquivos `.feature` precisam existir e o que cada um cobre;
- a pergunta *"esse requisito tem cenário?"* seja respondível por leitura de tabela.

Não há código nesta entrega.

---

## 3. Entregas

### 3.1 `docs/glossario.md`

Fonte única dos nomes. Cerca de **42 verbetes**, em seis grupos.

**Formato do verbete:**

```markdown
### Execução
Registro imutável de uma tentativa de apuração de um relatório
numa data de referência.

- Tabela:  `execucao`
- Classe:  `Execucao`
- Campos:  `data_referencia`, `status`, `origem`, `vigente`,
           `tempo_estimado_segundos`
- Regras:  RN-46, RN-47, RN-51
- Não confundir com: Ciclo, Janela de leitura
```

**Grupos e verbetes:**

| Grupo | Verbetes |
|---|---|
| Catálogo | Produto · Sigla · Relatório · Código do relatório · Tempo estimado · Catálogo · Inativação · Módulo processador |
| Coleta | Coleta · Ciclo · Reserva do ciclo · Janela de leitura · Data de referência · Execução · Execução vigente · Origem da execução · Status · Retentativa · Reprocessamento forçado · Limite do relatório · Limite de segurança do produto |
| Artefato e retenção | Artefato · `.jrprint` · `.csv.gz` · Dataset · Repositório de artefatos · Janela de retenção · Expurgo |
| Exportação | Exportação · Formato · Download · Histórico de downloads |
| Identidade e acesso | Perfil · Role de relatório · Grupo · Cadeia de permissão · Pendente de vínculo · Autocadastro |
| Diagnóstico e dados | Correlation ID · Evento de auditoria · Schema de controle · Schema transacional |

**Regras do documento:**

1. **Um termo, uma definição.** Sinônimo não ganha verbete — ganha uma linha `ver X`.
2. **Identificador canônico obrigatório** em todo verbete que vira dado. Verbete conceitual
   (Janela de leitura, Cadeia de permissão) declara explicitamente que não tem.
3. **Seção "Termos que não usamos"**, com o motivo de cada um. Protege as decisões já
   tomadas, que estão expressas como *ausência* de algo e por isso não se inferem de
   exemplos:
   - *cancelamento* — não existe (D20, fora de escopo);
   - *retentativa* ≠ *reprocessamento forçado* — origens distintas (RN-46);
   - *job*, *processamento* — não são termos do domínio;
   - *criar produto*, *cadastrar relatório* — não existem (RN-49, catálogo derivado do código).

**Idioma:** identificadores do domínio em **pt-BR sem acento** (`execucao`,
`data_referencia`, `Execucao`); nomes de framework, infraestrutura e padrões técnicos em
**inglês**. A regra de fronteira entre os dois fica escrita no próprio glossário.

### 3.2 `docs/user-stories.md`

**Formato da história:** título, prosa (persona · objetivo · valor), aceite em **uma frase
verificável**, RFs cobertos, arquivo `.feature` previsto. **Sem Given/When/Then** — os
cenários nascem uma única vez, em E3 (SP-7), já como `.feature` executável.

Duas seções, **28 histórias**.

**Histórias de usuário (15)**

| ID | História | RFs |
|---|---|---|
| HU-01 | *Relator* — encontrar o relatório que preciso | RF-13, RF-14, RF-15, RF-16, RF-55 |
| HU-02 | *Relator* — baixar no formato que preciso | RF-19, RF-20, RF-21, RF-22 |
| HU-03 | *Relator* — entender por que não consigo baixar | RF-24, RF-48, RF-38, RF-39 |
| HU-04 | *Relator* — cadastrar-me sozinho e entrar | RF-29, RF-30 |
| HU-05 | *Todos* — cuidar da minha senha | RF-37 |
| HU-06 | *Gerente* — organizar acesso por role de relatório | RF-31 |
| HU-07 | *Gerente* — dar e tirar acesso por grupo | RF-32, RF-33, RF-36 |
| HU-08 | *Gerente* — não conseguir escalar privilégio | RF-34, RF-18 |
| HU-09 | *Gerente/Admin* — remover um relator | RF-35 |
| HU-10 | *Gerente* — revogar em bloco removendo role ou grupo | RF-43 |
| HU-11 | *Admin* — enxergar e exportar tudo | RF-17 |
| HU-12 | *Admin* — refazer uma apuração | RF-10, RF-11, RF-12 |
| HU-13 | *Admin* — auditar downloads | RF-23, RF-51 |
| HU-14 | *Admin* — ajustar o catálogo | RF-41, RF-47, RF-50 |
| HU-15 | *Admin* — diagnosticar um erro relatado | RF-40 |

**Histórias de sistema (13)** — escritas como *"O sistema deve X, para que Y"*, com o mesmo
campo de aceite e o mesmo rastreio. Cobrem o comportamento autônomo, que não tem persona
humana pedindo mas concentra as regras mais densas do PRD.

| ID | História | RFs |
|---|---|---|
| HS-01 | Reservar o ciclo antes de qualquer apuração | RF-45 |
| HS-02 | Apurar os relatórios ativos e gravar os artefatos | RF-01, RF-02 |
| HS-03 | Classificar o desfecho por falha e por duração | RF-03, RF-04 |
| HS-04 | Abortar o relatório que estourou o dobro, sem derrubar os irmãos | RF-05 |
| HS-05 | Não deixar execução presa em `em processamento` | RF-06 |
| HS-06 | Retentar apenas o que não concluiu | RF-46, RF-09 |
| HS-07 | Recusar reexecução do que já concluiu bem | RF-08 |
| HS-08 | Recusar dataset acima do teto, antes de apurar | RF-49 |
| HS-09 | Nunca aceitar data de referência como entrada | RF-53 |
| HS-10 | Publicar o catálogo ao iniciar, ou não iniciar | RF-44, RF-27 |
| HS-11 | Preservar o que foi inativado | RF-54 |
| HS-12 | Expurgar o artefato vencido | RF-56 *(criado por SP-1 — ver §7)* |
| HS-13 | Medir a apuração limpa | RF-52 |

**Matriz `RF → história → .feature`**, ao fim do documento. Sai por construção do método
(§4), sem auditoria extra. Os 5 RFs aposentados — RF-07, RF-25, RF-26, RF-28, RF-42 — entram
marcados como aposentados e sem história, para que a ausência seja visivelmente deliberada.

### 3.3 Saneamento de referências

`arquitetura-inicial.md` §15 lista como *"Existe"* três documentos que **não existem neste
branch**: `glossario.md`, `adr/` e `especificacao.md`. Correção:

- `glossario.md` → passa a "Existe" **ao fim de SP-1** (esta spec o entrega);
- `adr/` → "Não existe — exigido por E0" (entra em SP-2);
- `especificacao.md` → **linha removida**. O papel dela passa a ser cumprido pelas specs em
  `docs/superpowers/specs/`. Manter referência a um documento de outro método é fonte
  garantida de divergência.

Acrescentar `user-stories.md` à tabela de documentos relacionados do PRD §13.

### 3.4 Emenda ao PRD: RF-56

SP-1 acrescenta **um único requisito** ao PRD, na tabela de Coleta da §9, fechando a lacuna
descrita em §7:

| ID | Requisito | Regras |
|---|---|---|
| **RF-56** | Artefato que ultrapassa a janela de retenção é expurgado, e aquela data de referência deixa de aparecer na listagem | RN-36, RN-37 |

É a única alteração de conteúdo que SP-1 faz no PRD — o resto do saneamento (§3.3) é
correção de referência. O identificador segue a regra do próprio PRD: número novo, nunca
renumeração nem reaproveitamento.

---

## 4. Método

Quatro passos, nesta ordem:

1. Extrair os verbetes de `prd.md` e `arquitetura-inicial.md`; escrever `glossario.md`.
2. Percorrer os RFs **na ordem do PRD**, atribuindo cada um à história do agrupamento de
   §3.2; escrever `user-stories.md`.
3. Gerar a matriz como subproduto do passo 2.
4. Aplicar o saneamento de §3.3.

**Abordagem escolhida: derivação pelo PRD.** As histórias são agrupamento de requisitos, não
descoberta. A alternativa considerada — escrever pela persona e auditar a cobertura depois —
revelaria lacunas do PRD, ao custo de mais trabalho e de sobreposição entre histórias. Ver o
risco em §6.

---

## 5. Fronteiras

**Fronteira com SP-6b, que é onde os dois tocam nomes.** O glossário fixa o **nome** da
tabela, da classe e dos campos que correspondem a conceitos do domínio. Não fixa tipo, chave,
índice, nem campo técnico (`id`, `criado_em`, colunas de junção). SP-6b **acrescenta**; não
renomeia. Se SP-6b precisar de outro nome, a mudança volta ao glossário primeiro — senão o
glossário deixa de ser fonte única no primeiro conflito.

**Fora de escopo de SP-1:**

- Nomes dos módulos → SP-2 (é decisão de arquitetura, vira ADR).
- DDL, migrations e modelagem detalhada → SP-6b.
- Fluxos, wireframes e design system → SP-4 e SP-5.
- Modelos de dados dos 10 relatórios → SP-6a.
- Qualquer código.

---

## 6. Riscos aceitos

- **A derivação pelo PRD não descobre lacunas.** As histórias são agrupamento de RF; um
  buraco no PRD atravessa intacto para os testes. Decisão deliberada. O caso do expurgo (§7)
  é a evidência de que existem buracos — e ele só apareceu porque o agrupamento por
  funcionalidade o expôs, não porque houve auditoria. Nada garante que seja o único.
- **Aceite em uma frase é mais frouxo que Given/When/Then completo.** O checkpoint de P0 do
  guia — *"um teste automatizado conseguiria verificar"* — passa a ser cumprido por
  julgamento, e não por construção. A verificação real só chega em E3, quando os `.feature`
  existirem. Aceito para evitar duas cópias divergentes do mesmo cenário.
- **pt-BR no domínio e inglês no técnico** exige uma regra de fronteira explícita, senão a
  base vira mistura arbitrária. Mitigação: a regra fica escrita no próprio glossário, com
  exemplos dos dois lados.
- **Histórias de sistema não são user stories** no sentido estrito e vão estranhar a quem
  espera o formato canônico. Aceito: forçar persona no comportamento autônomo produziria uma
  intenção que o ADMINISTRADOR não tem — o PRD diz que ele diagnostica e refaz, não que opera
  o ciclo.

---

## 7. Lacuna do PRD encontrada e corrigida

**F05 (expurgo automático dos artefatos) não tinha requisito funcional no PRD.** Existiam
RN-36 e RN-37 (a janela de retenção e o expurgo) e existia RF-24 (recusar exportação de
artefato já expurgado), mas **nenhum RF afirmava que o expurgo acontece**. Sem isso, a
funcionalidade que apaga dado do usuário seria a única do sistema sem cenário automatizado
que a verificasse.

**Correção:** SP-1 acrescenta o **RF-56** ao PRD (§3.4), e HS-12 passa a rastreá-lo. A
matriz fica sem exceção e o critério de aceite 1 vale sem ressalva.

**Consequência de método:** SP-1 deixa de ser um sub-projeto que só consome o PRD e passa a
alterá-lo. É uma alteração de conteúdo, não de forma, e por isso está isolada num requisito
único e explicitamente listada — qualquer outra lacuna encontrada daqui em diante volta a
ser questão, não emenda, salvo decisão nova.

---

## 8. Critério de aceite

Oito afirmações verificáveis. SP-1 está pronto quando todas forem verdadeiras:

1. Todo RF ativo do PRD aparece em **exatamente uma** história na matriz.
2. Os 5 RFs aposentados aparecem marcados como aposentados, sem história.
3. Todo conceito do PRD §7 tem verbete no glossário.
4. Todo verbete que vira dado tem identificador canônico; todo verbete conceitual declara
   explicitamente que não tem.
5. Nenhum termo tem duas definições e nenhum sinônimo tem verbete próprio.
6. Nenhuma história contém Given/When/Then.
7. `arquitetura-inicial.md` §15 não lista como existente nenhum documento inexistente.
8. O PRD contém RF-56, e ele é **o único** requisito acrescentado por SP-1.

Os itens 1 e 2 são conferíveis comparando os `RF-\d+` de `prd.md` com os de
`user-stories.md`. Nenhum script é versionado agora: **SP-3 transforma essa conferência em
gate de CI**, que é onde ela pertence.

---

## 9. Documentos relacionados

| Documento | Papel |
|---|---|
| [`prd.md`](../../prd.md) | Fonte dos RFs, RNs e conceitos |
| [`arquitetura-inicial.md`](../../arquitetura-inicial.md) | Fonte dos termos técnicos e do saneamento de §3.3 |
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define P0 e o checkpoint desta fase |
