# 03 — Cadastro de Relatório com Código validado

**What to build:** O ADMINISTRADOR cadastra Relatórios, e o sistema garante que o Código do Relatório é confiável para sempre: formato estrito, sigla de um Produto que existe, imutável depois de criado e nunca reaproveitado. É o que permite que a auditoria de download continue verdadeira anos depois.

**Blocked by:** 02 — Cadastro de Produto.

**Status:** ready-for-agent

- [ ] Cadastro exige Código do Relatório, nome, descrição, Tempo Estimado de Execução e Janela de Agendamento
- [ ] Código validado contra o formato sigla-9999, com número de 0001 a 9999 e 0000 recusado (ADR-0015)
- [ ] Código com sigla que não corresponde a Produto cadastrado é recusado com mensagem explícita
- [ ] Janela de Agendamento aceita apenas valores do vocabulário fechado
- [ ] Tentativa de alterar o Código de um Relatório existente é recusada
- [ ] Código de Relatório excluído não pode ser reaproveitado em novo cadastro
- [ ] Alteração de nome, descrição, Tempo Estimado e Janela é permitida
- [ ] Remoção de Produto que ainda possui Relatórios é recusada
- [ ] Cenários Cucumber cobrindo cada regra acima pelo seam 1
