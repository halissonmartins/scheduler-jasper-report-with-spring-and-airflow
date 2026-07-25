# 24 — Benchmark k6 e calibração dos limites

**What to build:** Os limites de linhas deixam de ser palpite conservador e passam a ser medidos. Pelo ADR-0004 eles são a única proteção contra uma geração grande derrubar a API, então esta calibração é pré-requisito de uso real, não afinação posterior.

**Blocked by:** 11 — Geração em PDF, XLSX e DOCX.

**Status:** ready-for-agent

- [ ] Roteiro de carga executa a geração com contagens crescentes de linhas nos quatro formatos
- [ ] Medição registra tempo de parede, uso de heap da API e tamanho da resposta por formato
- [ ] Cada limite é fixado em cerca de 60% do orçamento de timeout e 50% do heap seguro
- [ ] O teto de memória do navegador é validado contra os navegadores-alvo e considerado no limite final
- [ ] Constantes de limite atualizadas com os valores medidos, substituindo os iniciais
- [ ] Resultado documentado, incluindo o volume a partir do qual cada formato deixa de ser entregável
