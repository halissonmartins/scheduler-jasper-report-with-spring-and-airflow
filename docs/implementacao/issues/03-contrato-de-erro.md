# 03 — Contrato de erro RFC 9457, catálogo e Correlation ID

**O que construir:** qualquer erro que a API devolva chega ao usuário com um código estável, o
momento e o Correlation ID que ele pode copiar e passar ao suporte — e esse mesmo identificador
encontra o log e o trace. Um formato só circulando pela API, inclusive nos erros que o framework
gera sozinho.

**Bloqueado por:** nada — pode começar imediatamente.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] As respostas de erro saem em `application/problem+json` conforme a **RFC 9457** (que obsoletou
      a 7807), com as extensões `codigo`, `momento` e `correlationId`, e `type` como URN **não
      dereferenciável**.
- [ ] O catálogo de dezesseis códigos existe como conjunto fechado, com o HTTP e a **natureza** de
      cada um — permanente ou transitória —, porque o front mapeia `codigo` para comportamento.
- [ ] `CO-PROBLEM-DETAIL-UNICO-FORMATO` — um erro gerado pelo próprio Spring (JSON malformado,
      `@Valid` reprovado, 405, 415) sai no mesmo formato. Não há um segundo formato circulando.
- [ ] O Correlation ID é **sempre** o traceId, sem regra de precedência entre identificadores
      concorrentes. Se o MDC estiver vazio quando o handler rodar, gera-se um id e loga-se `WARN`.
- [ ] `CO-OTEL-SEM-COLLECTOR` — a suíte roda sem Collector algum no ambiente, com o SDK **ligado** e
      exportador `none`. Desligar o SDK faria todo cenário de Correlation ID exercitar o fallback em
      vez do caminho de produção.
- [ ] `CO-CABECALHO-ACIMA-DO-LIMITE` — requisição com cabeçalho acima do limite do Tomcat é
      rejeitada **sem** corpo padronizado e **sem** Correlation ID. É a única exceção conhecida à
      garantia, e vira teste para não virar surpresa.
- [ ] Nada vaza: stack trace, SQL, nome de schema, credencial, hash esperado ou obtido, chave do
      objeto, corpo de erro da Admin API, nome de client, nome interno de permissão.
