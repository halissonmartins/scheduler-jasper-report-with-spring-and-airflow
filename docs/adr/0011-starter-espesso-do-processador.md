# Starter espesso para os processadores de Coleta

O `processor-starter` é deliberadamente profundo: ele possui o ciclo de vida da Execução de Coleta, a escrita em lote no MongoDB, a troca de ponteiro no PostgreSQL (ADR-0006), o registro de metadados e Status de Processamento — incluindo a regra do Tempo Estimado de Execução → processado com alerta —, a exportação OTLP e as políticas de chunk, retry e skip. Um processador de Produto fornece apenas um DataSource, seu SQL e o mapeamento de linha.

A invariante do ponteiro é o tipo de regra que quebra em silêncio se cada processador a reimplementar: um processador que esquecesse a troca produziria relatórios desatualizados sem erro em lugar algum. Com o starter espesso ela existe em um único lugar, e o sexto Produto custa quase nada.

## Consequências

- O starter também publica um artefato `test-fixtures` com passos Cucumber reutilizáveis (semear o banco de origem via Testcontainers, executar o job, verificar linhas, ponteiro e status), para que cada processador escreva cenários em vez de andaime.
- Auto-configuração é magia: quem depura um processador precisa conhecer o starter.
