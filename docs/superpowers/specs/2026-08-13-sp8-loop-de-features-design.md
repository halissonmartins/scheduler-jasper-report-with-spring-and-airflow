# SP-8+ — Loop de features (E4)

> Spec do último sub-projeto da decomposição. Entrega `docs/backlog.md` com os 32 tickets de E4,
> ordenados por risco, e os oito planos da frente de Coleta.
>
> Data: 2026-08-13 · Branch: `00-super-powers` · Decomposição em
> [SP-1 §1](./2026-08-09-sp1-linguagem-e-historias-design.md)

---

## 1. Contexto

**SP-8+ não é um sub-projeto como os anteriores.** É a fase E4, que o guia define como um ciclo
repetido:

> *Issue com critério de aceite (vem de P0) → Agente propõe plano → você aprova o **plano**, não o
> código → teste que falha → implementa → CI → revisa o diff → merge.*

E com uma regra de tamanho: *"PR pequeno. Se você não revisa em 15 minutos, o escopo estava
errado."*

**Não há spec por feature em E4.** A user story de SP-1 já é a issue; o que cada ticket precisa é de
um *plano*. Escrever trinta e duas specs seria repetir `user-stories.md` com outro nome.

### 1.1 O que resta depois de SP-7

| Frente | Tickets | Conteúdo |
|---|---|---|
| Coleta — desfechos não-felizes | 7 | Alerta vs. erro · limite do relatório · execução presa · retentativa · recusa com auditoria · teto do dataset · métrica |
| Exportação | 4 | XLSX contínuo · DOCX · CSV · semáforo e recusas |
| Retenção | 2 | Política ILM · webhook de expurgo |
| Reprocessamento | 2 | API dispara a DAG · auditoria com motivo |
| Catálogo | 3 | Publicação ao iniciar · edição · inativação |
| Identidade e acesso | 5 | Autocadastro · senha · roles · grupos · remoção |
| Produtos restantes | 4 | CLIENTE (+ fonte C) · CONTACORRENTE · CONSORCIO (+ barcode) · EMPRESTIMO |
| Frontend e transversais | 5 | Telas por perfil · observabilidade · segurança · release |

---

## 2. Objetivo

Ter a fila de trabalho de E4 escrita e ordenada, e os oito planos da frente mais densa em regra de
negócio prontos para execução assim que SP-7 terminar.

---

## 3. Entregas

### 3.1 `docs/backlog.md`

Formato de cada ticket, seguindo o que E4 pede:

```markdown
### T-07 — Retentativa relê apenas o que não concluiu
- **História:** HS-06 · **RFs:** RF-46, RF-09 · **Risco:** —
- **Aceite:** execução que falha origina nova execução de origem `retentativa`;
  a anterior permanece e passa a não-vigente
- **Depende de:** T-04 · **Tamanho:** M
```

**Ordenado por risco decrescente**, em três blocos.

**Bloco A — o que pode invalidar decisão de arquitetura** (6 tickets)

| # | Ticket | Risco que ataca |
|---|---|---|
| T-01 | Publicação do catálogo pelo módulo ao iniciar | destrava os produtos (`RA-58`) |
| T-02 | Produto CLIENTE, **com a *font extension* da fonte C** | **`R-03`** — fonte ausente no classpath |
| T-03 | Produto CONSORCIO, **com o barcode** | **`R-04`** — `ClassNotFoundException` no renderer |
| T-04 | Exportação XLSX contínua | `RF-21` — a convenção de `RA-59` pode não funcionar |
| T-05 | Semáforo de exportação | **`R-05`** — o teto único de memória |
| T-06 | Expurgo por ILM e o webhook | **`R-10`** — o `--event delete` que a documentação do MinIO erra |

Estes seis primeiro pela mesma lógica que pôs `R-16` no primeiro degrau de SP-7: se algum obrigar a
rever um ADR, é melhor saber com 6 tickets feitos do que com 25.

**Bloco B — Coleta, desfechos não-felizes** (7 tickets), detalhados em §3.2.

**Bloco C — o resto** (19): CONTACORRENTE e EMPRESTIMO · reprocessamento · catálogo administrável ·
identidade e acesso (5) · histórico de downloads · telas por perfil (3) · observabilidade ·
segurança (E5) · release (E6).

**Dois ajustes que a ordenação por risco força:**

- **T-01 sobe para o bloco A** mesmo sem risco próprio: sem a publicação do catálogo, os produtos
  dependeriam do seed de desenvolvimento, e `ADR-0009` diz que catálogo vem do código. Ele não ataca
  risco — destrava quem ataca.
- **CLIENTE vem antes de CONTACORRENTE e EMPRESTIMO**, o que é arbitrário do ponto de vista de
  domínio. O motivo é único: é o primeiro relatório que usa a fonte C, e portanto o único que
  exercita `R-03`.

### 3.2 Os oito planos da frente de Coleta

**Um documento com oito planos, não oito arquivos.** Os oito compartilham as mesmas premissas sobre
SP-7 e o mesmo ambiente; repetir esse bloco oito vezes produziria oito cópias que divergem. Cada
plano é uma seção autocontida, executável isoladamente.

**O bloco de premissas** abre o documento, listando o que os oito assumem de SP-7:

```
ApurarRelatorio.apurar(String codigo, LocalDate data) → Execucao
PreencherRelatorio.preencher(String codigo, LocalDate data) → JasperPrint
RepositorioDeArtefatos.gravar(...) → List<String>
DataSourcePaginado — já verifica o limite a cada avanço
ExecucaoRepositorio.concluir(long id, String status, Instant fim)
Schema controle com os dois triggers (SP-6b)
DAG coleta_diaria com reserva_do_ciclo e apura_poupanca
```

Se SP-7 entregar assinatura diferente, sabe-se qual plano revisar e por quê.

| Plano | Ticket | O que entrega | A sutileza que carrega |
|---|---|---|---|
| P1 | T-01 | Publicação do catálogo ao iniciar | Código duplicado **impede o módulo de subir** (`RF-44`) — não é validação de formulário |
| P2 | T-07 | Classificar desfecho: alerta vs. erro | **D02 — o erro sempre prevalece sobre o alerta**, mesmo tendo estourado o tempo |
| P3 | T-08 | Limite do relatório: abortar no dobro | Os **irmãos do mesmo produto continuam** (`RF-05`) |
| P4 | T-09 | Teto do dataset | Conta **antes** de apurar (`RA-64`); testado injetando a contagem, não volume |
| P5 | T-10 | Retentativa | Relê **apenas** o que não concluiu; a anterior permanece e vira não-vigente |
| P6 | T-11 | Recusa de reexecução | **Evento de auditoria, não Execução** |
| P7 | T-12 | Execução presa | Encerra **inclusive as que a reserva criou e nunca iniciaram** |
| P8 | T-13 | Métrica de apuração limpa | Só **vigentes de origem `agendada`** |

**P6 e P7 são os dois que ninguém escreveria espontaneamente.** O P6 existe porque `RN-18` diz que a
recusa é evento de auditoria: se ela criasse uma Execução, uma tentativa recusada apareceria como
falha de apuração e contaminaria a métrica primária. O P7 está na lista de `RA-68` — encerrar
execução reservada que nunca chegou a iniciar exige distinguir `iniciado_em` nulo de preenchido, e é
exatamente o caso que se esquece.

---

## 4. Método

1. Escrever `docs/backlog.md` com os 32 tickets ordenados.
2. Conferir que todo RF ativo aparece em algum ticket.
3. Escrever o documento com os oito planos da Coleta, começando pelo bloco de premissas.

**Abordagem escolhida: backlog completo mais os oito planos da Coleta.** As alternativas: só o
backlog (mais honesto quanto ao que se sabe hoje, mas deixaria a frente mais densa sem preparo) e
backlog mais o plano de um único ticket (daria partida imediata, sem cobrir a frente).

---

## 5. Fronteiras

**Fora de escopo de SP-8+:**

- **Os planos dos blocos A e C** — nascem quando cada ticket chegar a sua vez, com código real na
  frente.
- **Executar qualquer ticket.** SP-8+ entrega fila e preparo, não implementação.
- **Reescrever `user-stories.md`.** O ticket referencia a história; não a duplica.

---

## 6. Riscos aceitos

- **Os oito planos são escritos sobre código que não existe.** Mitigado pelo bloco de premissas, que
  torna a revisão localizada — mas se SP-7 revelar que o Spring Batch impõe outra estrutura, vários
  serão reescritos.
- **O backlog envelhece.** Trinta e dois tickets planejados hoje refletem o entendimento de hoje; os do
  bloco C são os mais frágeis, por estarem mais longe.
- **A ordenação por risco atrasa valor percebido.** Os seis do bloco A não produzem nada que o
  Relator note; as telas ficam no bloco C. É deliberado — a alternativa deixaria `R-03` e `R-04`
  para o fim.

---

## 7. Critério de aceite

1. `docs/backlog.md` tem 32 tickets, cada um com história, RFs, aceite, dependência e tamanho.
2. Os tickets estão ordenados por risco decrescente, com os seis do bloco A primeiro.
3. **Todo RF ativo do PRD aparece em algum ticket** — conferível por comparação com
   `user-stories.md`.
4. O documento de planos traz os oito, cada um com premissas, tarefas e aceite próprios.
5. O bloco de premissas lista as assinaturas de SP-7 que os oito assumem.

---

## 8. Documentos relacionados

| Documento | Papel |
|---|---|
| [`guias/guia-app-web.md`](../../guias/guia-app-web.md) | Define E4, o ciclo por feature e a regra do PR pequeno |
| [SP-1](./2026-08-09-sp1-linguagem-e-historias-design.md) | `user-stories.md` — as issues que os tickets referenciam |
| [SP-2](./2026-08-10-sp2-decisoes-tecnicas-design.md) | `riscos.md` — `R-03`, `R-04`, `R-05`, `R-10`, que ordenam o bloco A |
| [SP-7](./2026-08-13-sp7-esqueleto-e-fatia-vertical-design.md) | As assinaturas que os oito planos assumem |
