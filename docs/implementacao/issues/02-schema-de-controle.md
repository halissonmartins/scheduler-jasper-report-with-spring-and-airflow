# 02 — Schema de controle: migrações e os sete usuários

**O que construir:** o lugar onde tudo o mais grava e lê. Ao fim deste ticket o banco tem o schema
de controle inteiro, e a fronteira arquitetural de leitura deixa de ser disciplina de código e passa
a ser imposta pelo PostgreSQL: a credencial de um Produto simplesmente não alcança o schema de
outro.

**Bloqueado por:** nada — pode começar imediatamente.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] As tabelas do schema de controle existem por migração Flyway, com uma instância por natureza
      de schema e `baselineOnMigrate=false`.
- [ ] `jsonb` aparece apenas em `parametros_entrada` e `detalhe_erro`. Valor que se compara entre
      linhas é coluna.
- [ ] O índice de unicidade é **parcial**, excluindo `ERRO` e `SEM_DADOS`:
      ```sql
      CREATE UNIQUE INDEX ON execucao (codigo_relatorio, data_referencia)
        WHERE status NOT IN ('ERRO', 'SEM_DADOS');
      ```
      Não existe checagem equivalente na aplicação — este índice é a regra inteira.
- [ ] `CO-INDICE-PARCIAL-QUATRO-COMBINACOES` — par com `ERRO` aceita nova Execução; com `SEM_DADOS`
      aceita; com `SUCESSO` rejeita; com `ALERTA` rejeita.
- [ ] `CO-CORRIDA-ABRIR-EXECUCAO` — duas conexões inserindo o mesmo par simultaneamente, uma falha.
- [ ] `CO-ISOLAMENTO-CREDENCIAL` — a credencial de um Produto **não** lê o schema transacional de
      outro. O teste roda com as credenciais reais; como superusuário ele passaria verde e a
      produção falharia.
- [ ] `download.execucao_id` é `ON DELETE SET NULL`, e as tabelas de histórico são denormalizadas —
      legíveis sozinhas depois que Relatório, usuário ou Execução deixarem de existir.
- [ ] Existe índice por `nome_role` em `relatorio_role_relatorio`: é a consulta do caminho quente de
      toda listagem e toda exportação.
