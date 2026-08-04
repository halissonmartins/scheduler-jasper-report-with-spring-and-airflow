# 17 — Exportação PDF e DOCX, com semáforo e defesas da desserialização

**O que construir:** os formatos que desserializam. Aqui entra a única fronteira de segurança real
do sistema e o único controle de capacidade que existe. A desserialização e a exportação rodam na
**mesma JVM da API, sem isolamento** — decisão registrada em ADR —, então os limites deixam de ser
boa prática e viram a proteção.

**Bloqueado por:** 16.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O fluxo é: autorizar → **adquirir o semáforo** → buscar o objeto → conferir SHA-256 →
      desserializar → exportar → liberar. A vaga é adquirida **antes de buscar**, porque conferir o
      hash já exige ter os bytes.
- [ ] `CO-INTEGRIDADE-SHA256` — hash divergente recusa a exportação, com código próprio, log e
      métrica. É a única defesa contra quem tem acesso apenas ao bucket.
- [ ] `CO-OBJECTINPUTFILTER` — objeto de classe fora da allowlist é recusado. Sem este teste o filtro
      pode estar desligado por configuração e todo o resto da suíte passa.
- [ ] `CO-VAZAMENTO-SEMAFORO` — forçar cada modo de falha em sequência e afirmar que a ocupação volta
      a zero. Um caminho de erro que não libere esgota a capacidade da API sem sintoma além de `503`
      crescente.
- [ ] `CO-409-VS-503` — as duas recusas que se confundem têm cenário cada: acima do teto é
      **permanente** (repetir não adianta), semáforo cheio é **transitório** com `Retry-After`
      (repetir é o certo). Trocá-las na UI produz usuário insistindo no que nunca passa e desistindo
      do que passaria.
- [ ] `CO-CSV-FORA-DO-SEMAFORO` — exportações de CSV simultâneas passam mesmo com o semáforo saturado
      pelos formatos caros. Se ele for parar na mesma fila numa refatoração, o formato mais barato
      passa a ser limitado pelo mais caro.
- [ ] `CO-DIVERGENCIA-VERSAO-JASPER` — Artefato gravado por versão diferente **exporta assim mesmo**
      e alerta. Testar que **não recusa** é tão importante quanto testar que avisa: recusar quebraria
      os sete dias seguintes a todo upgrade legítimo.
- [ ] Não há teto de exportação — risco aceito, com o modo de falha nomeado. O `N` do semáforo sai de
      **medição**, não de escolha.
