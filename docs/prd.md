# Scheduler Jasper Report With Spring and Airflow

## Requisitos de Produto

### Descrição:
Periodicamente a aplicação irá coletar os dados de vários relatórios de forma agendada e salvar no formato JasperPrint em um repositório S3.
É um coletor agendado (ingestão de dados) e um gerador/conversor sob demanda de relatórios.
Através de uma funcionalidade o usuário com perfil de relator irá solicitar a geração síncrona de um desses relatórios, essa aplicação irá recuperar os dados coletados e gerar o relatório em formatos PDF, CSV, XLSX ou DOCX.
Possui funcionalidades para realizar: sign in, sign out, sign up, gestão de roles de relatório, gestão de usuários, cadastro de relatórios, visualização dos relatórios disponíveis por dd/MM/yyyy e produto, download dos relatórios.
O comportamento central é: Airflow dispara um container Spring Batch → o módulo lê o schema transacional do seu produto → produz `.jrprint` + `.csv.gz` → grava no repositório → registra metadados.

### Fluxo:
Coleta Agendada -> Geração do JasperPrint serializado -> Repositório -> Registra Metadados -> API de Geração sob Demanda em Múltiplos Formatos

### Estrutura de armazenamento dos dados dos relatórios:
yyyy-MM-dd -> nome do produto -> código do relatório -> estrutura com os dados não estruturados

#### Formato do código do relatório:
Nome do produto (máximo de 20 caracteres) + - + código com 4 números (maiúsculas, sem acento, sem espaço `^[A-Z]{1,20}-\d{4}$`).
	Exemplos:
	- POUPANCA-0001
	- CLIENTE-0005
	- CONTACORRENTE-1234
	- CONSORCIO-9874
	- EMPRESTIMO-4567

### Regras Negociais:
- Formatos de exportação: PDF, XLSX, DOCX, CSV.
- Ciclo de Vida dos Status (em processamento, processado com sucesso, processado com erro, processado com alerta)
- Se o tempo de execução ultrapassar o que foi cadastrado no "tempo estimado de execução", o status será "processado com alerta".
- O usuário do tipo RELATOR se cadastra e aguarda um usuário do tipo GERENTE o adicionar um grupo de relatório.
- O usuário com o tipo GERENTE não pode incluir outro usuário com o tipo GERENTE.
- Por padrão o usuário que fizer o cadastro via interface web pública aguardará o vinculo a um grupo por um usuário GERENTE.
- Somente usuários do tipo ADMINISTRADOR e RELATOR podem gerar relatórios cadastrados.
- Todos os tipos de usuários podem trocar a senha.
- Exibir mensagens de erro no seguinte formato: horário do erro, descrição do erro, Correlation ID, Botão para copiar formato em JSON
- Modo de concessão de permissão dos usuários aos relatórios: relatório - role de relatório - grupo de usuários - usuário
- Se o tempo de execução ultrapassar o "tempo estimado de execução" cadastrado, o status final será "processado com alerta", inclusive quando a execução também tiver registrado falhas — o alerta prevalece sobre o erro. Ao atingir o dobro do tempo estimado (margem de 100%), a execução é interrompida por timeout duro e encerrada com o status "processado com erro", que prevalece sobre o alerta.
- A tabela de metadados de processamento é a fonte da verdade do status. Quando o container Spring Batch terminar de forma anômala e não conseguir registrar seu próprio encerramento, o Airflow atualizará a execução para "processado com erro" através do callback de falha da task, encerrando qualquer execução que permaneça em "em processamento".
- A combinação de data de referência e código do relatório é única. Uma nova execução para um par já processado com sucesso é rejeitada (processado com erro), mantendo intactos os artefatos e os metadados da execução original.
- A DAG aceita o parâmetro forcar_reprocessamento, que invalida a execução anterior do par data de referência + código do relatório e permite nova geração, sobrescrevendo os artefatos no repositório. O acionamento é restrito aos usuários dos tipos ADMINISTRADOR, e cada uso é registrado com o identificador do solicitante, o motivo informado e o Correlation ID.
- O conteúdo já está paginado e posicionado. Exportar um `JasperPrint` desenhado para PDF em XLSX/CSV costuma sair feio (o exporter Excel monta grid a partir de coordenadas). Isso será mitigado despresando a paginação quando o formato selecionado for XLSX.
- O RELATOR se cadastra e espera. Ao logar deve ser exibido uma solicitando que ele aguarde a configuração das permissões para emitir relatório.
- A data `yyyy-MM-dd` é o dia em que o job rodou.
- Administrador pode cancelar a execução de um relatório

### Tipos de usuário:
- ADMINISTRADOR: efetua o cadastrado/remoção de usuários do tipo GERENTE/ADMINISTRADOR, cadastro/remoção de produtos, cadastro/remoção de relatórios, visualização do histórico downloads.
- GERENTE: somente cadastra roles do tipo "RELATORIO", vincula roles de relatórios a relatórios, cadastra/remove grupos, vincula roles de relatórios a grupos de usuários do tipo RELATOR, inclui/remove usuários dos grupos e exclusão dos usuários do tipo RELATOR.
- RELATOR: apenas consegue gerar os relatórios em seu usuário tem acesso.

## Fora de escopo
- MFA 
- Rotação obrigatória da senha inicial do ADMINISTRADOR