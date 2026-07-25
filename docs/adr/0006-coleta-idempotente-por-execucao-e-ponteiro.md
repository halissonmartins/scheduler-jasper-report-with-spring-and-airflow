# Coleta idempotente por Execução identificada e troca de ponteiro

Cada linha gravada no MongoDB é marcada com o identificador da Execução de Coleta que a escreveu. Ao concluir com sucesso, a Execução troca o ponteiro de "execução corrente" na linha de metadados do PostgreSQL correspondente a (Data de Referência, Produto, Relatório). A Geração lê exclusivamente as linhas da execução corrente.

O Airflow repete tarefas e operadores fazem backfill, então a Coleta precisa ser repetível sem corromper dados. Sem isso, uma reexecução duplicaria linhas ou exporia dados parciais.

## Considered Options

- **Apagar e reinserir no lugar** — descartado: existe uma janela de minutos em que a Geração devolve dados parciais ou vazios, e uma reexecução que falha destrói o dado bom sem substituto.
- **Rejeitar duplicidade com índice único** — descartado: transformaria cada retentativa transitória do Airflow em intervenção humana.

## Consequências

- Execuções superadas coexistem com a corrente até o TTL apagá-las (ADR-0008) — custo de disco limitado pela retenção.
- O histórico de reprocessamento sai de graça.
- A troca de ponteiro é atômica: nunca há janela sem dado publicado.
