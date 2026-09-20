# Project state

## Decisions

O log de decisões deste projeto é `docs/adr/` (ADR-0001 a ADR-0007), somado às portas de
`Landing` em cada `plan.md`. Não existe um segundo log aqui: duas fontes para a mesma decisão
divergem em uma semana, e nenhuma delas fica autoritativa.

Decisão nova que alcance além de uma feature entra como ADR novo em `docs/adr/`, e o ADR que ela
substitui é marcado como superseded lá mesmo.

## Handoff

**Feature**: scheduler-jasper-report (projeto completo, a pedido do usuário)
**Where**: `plan.md` escrito e aprovado pelo portão — `validate_plan.py` sai 0, com 1 aviso, que é
o registro honesto de 5 questões genuinamente em aberto. `checks.md` ainda não existe.
**In progress**: nada em edição
**Next step**: revisão humana do plano. Aprovado, derivar `checks.md` — cada uma das 19 rotas de
`Surface` deve uma linha de `Coverage` com seus status, cada uma das 11 portas de `Landing` deve
um check, e as nove dimensões devem uma linha em `Swept`.
**Blockers**: questão aberta 1 (evento de expiração do MinIO) bloqueia o critério 61; questão
aberta 3 (design system inexistente) bloqueia os critérios de tela; questão aberta 2 (modelos de
dados dos relatórios de exemplo) bloqueia a entrada em operação.
**Uncommitted**: `.specs/features/scheduler-jasper-report/plan.md`, `.specs/STATE.md`, `.gitignore`
**Branch**: 00-tlc-spec-v2
