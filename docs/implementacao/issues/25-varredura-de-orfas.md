# 25 — DAG de varredura de órfãs

**O que construir:** o que fecha as Execuções que ninguém fechou — worker morto, VM caída,
interrupção manual. O callback de falha não cobre nenhum desses casos. Sem a varredura, uma Execução
fica aberta para sempre e o relator vê "em processamento" indefinidamente.

**Bloqueado por:** 23.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Roda a cada 15 minutos. O custo é um `UPDATE`, então a frequência é puro atraso de detecção — e
      o ganho colateral é tornar "a varredura parou" perceptível em minutos, o que importa porque
      ninguém é notificado de nada.
- [ ] Fecha como `ERRO` com a **origem** gravada e há quanto tempo a Execução estava aberta — é o que
      distingue "morreu de verdade" de "fechada por limite" na análise posterior.
- [ ] Filtra pelo início da Execução, **não** pelo início do processamento: uma Execução cujo
      container nunca chegou a começar tem a segunda coluna nula, e é exatamente o caso que a
      varredura existe para cobrir.
- [ ] **A guarda ataca a causa, não o sintoma**: a varredura calcula o pior caso legítimo a partir do
      cadastro e **falha a task sem fechar nada** se o limite de órfã estiver abaixo dele. Massa não
      é o problema — varredura pausada e retomada fecha órfãs genuínas, e um teto throttlearia
      comportamento correto. Configuração incoerente é que destrói.
- [ ] Isso cobre o buraco que a guarda do cadastro não alcança: ela valida o cadastro e não vê a
      variável de ambiente mudar.
- [ ] Idempotência pela guarda de status: varredura e callback nunca fecham a mesma linha com valores
      diferentes — o segundo casa zero linhas e incrementa a métrica de encerramento perdido.
- [ ] A DAG é **estática**: não sai da fábrica, não está no snapshot, e snapshot vazio não deve fazê-la
      sumir. Também não consome o pool de Coletas.
- [ ] Métrica de idade da última varredura bem-sucedida, com linha própria no painel-resumo — o
      "quem vigia o vigia".
- [ ] Log próprio e teste: erro em processo de reconciliação some no log do processador de DAGs em
      vez do log da task, e uma reconciliação que falha em silêncio deixa Execuções abertas para
      sempre.
