# Convenções do mapa (wayfinder)

Este diretório é o issue tracker deste esforço. Ele existe porque o repositório usa o tracker
**markdown local** do wayfinder, adaptado para viver em `docs/` (documentação de primeira classe,
versionada, não rascunho descartável).

## Layout

```
docs/mapa/
  map.md              o mapa — destino, notas, decisões, névoa, fora de escopo
  issues/NN-slug.md   um arquivo por ticket, numerado a partir de 01
  research/           descobertas dos tickets de tipo research
  prototipos/         artefatos dos tickets de tipo prototype
```

## Formato de um ticket

```markdown
# NN — Título

Type: research | prototype | grilling | task
Status: open | claimed | resolved
Blocked by: NN, NN        (ou — quando não há bloqueio)

## Question

<a decisão ou investigação que este ticket resolve>
```

A resposta **não** faz parte do corpo. Ela é acrescentada como `## Answer` no momento da resolução.

## Tipos de ticket

| Tipo | Modo | Como se resolve |
|---|---|---|
| `research` | AFK | Subagente `/research`; grava em `research/` |
| `prototype` | HITL | `/prototype`; artefato em `prototipos/` |
| `grilling` | HITL | `/grilling` + `/domain-modeling`, uma pergunta por vez |
| `task` | HITL ou AFK | Trabalho manual que destrava uma decisão |

HITL = com humano no circuito. O agente **nunca** responde pelo humano num ticket HITL.

## Como trabalhar o mapa

1. Ler `map.md` — a visão de baixa resolução, não todos os tickets.
2. Escolher o ticket. Sem indicação do usuário, vale o primeiro da **fronteira**: `Status: open`,
   sem bloqueador em aberto, e não reivindicado.
3. **Reivindicar**: trocar para `Status: claimed` e salvar **antes** de qualquer trabalho.
4. Resolver, consultando os tickets fechados que forem relevantes (zoom sob demanda).
5. Registrar: acrescentar `## Answer` ao ticket, trocar para `Status: resolved`, e acrescentar
   uma linha em **Decisions so far** no `map.md` (resumo + link).
6. Criar tickets novos que a resposta tenha revelado; graduar a névoa que tenha ficado nítida,
   removendo-a de **Not yet specified**.

**Nunca resolva mais de um ticket por sessão** — exceto os de `research`, que rodam em paralelo.

Um ticket está **desbloqueado** quando todo arquivo listado em `Blocked by` está `resolved`.
