# 11 — Geração em PDF, XLSX e DOCX

**What to build:** Os outros três Formatos de Exportação, cada um com seu limite próprio, produzidos pelos templates Jasper do Relatório.

**Blocked by:** 10 — Geração síncrona em CSV com contagem prévia.

**Status:** ready-for-agent

- [ ] Relator gera e baixa PDF, XLSX e DOCX de um Relatório e Data de Referência a que tem acesso
- [ ] Cada formato tem seu limite como constante versionada: XLSX 100.000, PDF 25.000, DOCX 25.000 linhas (ADR-0004)
- [ ] Pedido acima do limite do formato é recusado pela contagem prévia, antes de iniciar a renderização
- [ ] O limite de XLSX respeita também o teto físico de 1.048.576 linhas por planilha
- [ ] Formato inválido ou não suportado é recusado com mensagem clara
- [ ] Cenários Cucumber cobrindo os três formatos e a recusa por limite em cada um
