# 01 — Reconciliar a SPI e os dez beans com os Relatórios decididos

**O que construir:** quem for escrever o Starter precisa de uma SPI que já reflita as decisões
tomadas, e de dez beans que descrevam os Relatórios de verdade em vez de `select 1 as placeholder`.
Hoje a interface pede os rótulos como `Map`, não tem `mapear(row)`, e os beans apontam para um
caminho de JRXML que não é onde os arquivos estão. Nada disso é demonstrável ao usuário — é o
"deixe a mudança fácil" antes da mudança.

**Bloqueado por:** nada — pode começar imediatamente.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Os rótulos das colunas são uma coleção **ordenada por construção** (`List`), nunca um `Map`
      iterado. O tipo impõe a ordem, em vez de a convenção segurá-la.
- [ ] A SPI expõe `mapear(row)`, e a documentação da interface diz explicitamente que **mudar o
      mapeamento não move o `hash_definicao`** — a cobertura dessa parte vem de `imagem_origem`.
- [ ] O caminho declarado por `jrxml()` bate com onde os JRXML de fato estão, para os dez
      Relatórios.
- [ ] Os dez beans carregam Código, consulta, rótulos na ordem decidida e tempo estimado sugerido
      reais, conforme os Relatórios especificados por Produto.
- [ ] Os nomes das classes correspondem aos nomes dos Relatórios decididos, e não aos rótulos
      provisórios do esqueleto.
- [ ] O registro do Starter enumera exatamente os dez Códigos esperados, e `mvn clean install`
      segue verde nos onze módulos.
