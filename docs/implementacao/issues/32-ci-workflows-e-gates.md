# 32 — CI: workflows e os gates

**O que construir:** o pipeline que impede regressão. Dois gates: a cobertura não cai, e **todos os
cenários obrigatórios rodaram e passaram**. O segundo é o que de fato importa, porque percentual de
cobertura premia exatamente os testes errados — testar a leitura em cursor com heap apertado cobre
poucas linhas e vale muito; vinte getters cobrem muitas e não valem nada.

**Bloqueado por:** 05, 15.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Runners ARM64, que já trazem Docker sem virtualização aninhada — é a arquitetura de produção e
      a do ambiente de desenvolvimento.
- [ ] `pr` roda unidade + integração; `merge` acrescenta aceitação + E2E e publica o artefato de
      cobertura; o teste de carga fica **fora do gate**, porque ele calibra em vez de verificar.
- [ ] Os testes caros ficam fora do PR: o de cursor com heap apertado e semente volumétrica, e o de
      fonte.
- [ ] Cobertura por **não-regressão**, sem número absoluto. A linha de base vem do artefato publicado
      no merge; quando falta, o job **roda a main uma vez** para regenerá-la, e o fallback é
      **barulhento** — regenerar em silêncio faria um artefato expirado transformar o gate em enfeite.
- [ ] Cada cenário obrigatório da especificação é um identificador; cada identificador é um teste
      marcado; um passo do CI afirma que todos **rodaram e passaram**. Nunca "existem": um teste
      desabilitado satisfaria a presença sem provar nada.
- [ ] A conferência é nas **duas direções**: identificador sem teste pega cenário removido em
      silêncio; teste marcado sem identificador pega cenário sem justificativa — que é o que preserva
      a razão de a lista existir.
- [ ] Os três cenários de health que **já passam** desde a fase inicial — `CO-READINESS-AMORTECIDO`,
      `CO-LIVENESS-SEM-BANCO` e `CO-ACTUATOR-NAO-EXPOSTO` — entram na lista executável com seus
      identificadores. Eles não precisam de código novo, mas sem a marcação a conferência os acusa
      como cenários removidos em silêncio.
- [ ] **Nenhum segredo.** Os Testcontainers sobem o servidor de objetos comunitário com tag fixa, sem
      chave de fornecedor — o que mantém PR de fork rodando e um desenvolvedor novo capaz de rodar a
      suíte.
- [ ] Cache do Maven sim, camadas de imagem não — restaurá-las no runner custa mais do que economiza.
- [ ] Upgrade do provedor de identidade **dispara o E2E completo**, porque a allowlist falha fechada e
      as configurações vivas do realm não são verificáveis por leitura.
