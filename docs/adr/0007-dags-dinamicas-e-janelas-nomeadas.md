# DAGs dinâmicas geradas do Cadastro, com Janelas de Agendamento nomeadas

As DAGs do Airflow são geradas dinamicamente a partir do Cadastro no PostgreSQL, uma DAG por (Produto × Janela de Agendamento). A Janela é escolhida de um vocabulário fechado (ex.: DIARIO_MADRUGADA, HORARIO_COMERCIAL_HORARIO, SEMANAL_DOMINGO) — não existe cron livre no Cadastro.

Cadastrar um novo Relatório em um Produto existente não exige deploy. Cadastrar um novo Produto exige, inevitavelmente, um novo módulo Maven e uma nova imagem. Janelas nomeadas existem porque no Airflow o agendamento é propriedade da DAG, não da tarefa: cron por Relatório significaria uma DAG por Relatório.

## Considered Options

- **DAG estática por Produto, lista de Relatórios lida em runtime** — recomendada e recusada; não haveria consulta ao banco em tempo de parse.
- **Manifesto exportado do Cadastro** — descartada; introduz um passo de sincronização e o risco de manifesto obsoleto.

## Consequências (risco aceito e mitigação)

- O arquivo de DAG consulta o PostgreSQL a cada parse. Uma indisponibilidade do banco faria DAGs desaparecerem da interface e o agendamento parar silenciosamente. Mitigação obrigatória: cache local da última lista válida com fallback em caso de falha, `min_file_process_interval` em ~300s e timeout curto de conexão para que o parse não trave o scheduler.
- Como a Coleta é dirigida pelo Cadastro, **não existe dado coletado para Relatório não cadastrado**. A linha 32 da descrição inicial ("a inclusão de um novo relatório no repositório não exige o seu cadastro prévio") foi revogada por incompatibilidade.
