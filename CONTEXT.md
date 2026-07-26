# Contexto: Coleta e Geração de Relatórios

Este contexto cobre a coleta agendada dos dados de relatórios nos sistemas de origem e a geração sob demanda desses relatórios em múltiplos formatos.

## Language

**Relatório**:
Conjunto nomeado de dados pertencente a um Produto, identificado por um Código do Relatório, cujo conteúdo é coletado periodicamente.
_Avoid_: report, extração, arquivo

**Produto**:
Linha de negócio proprietária de um sistema de origem e dos Relatórios que dele derivam (ex.: POUPANCA, CONTACORRENTE).
_Avoid_: sistema, módulo, domínio

**Código do Relatório**:
Identificador de um Relatório, formado pelo nome do Produto (até 20 caracteres) seguida de hífen e quatro dígitos — ex.: POUPANCA-0001. Imutável após a criação e nunca reaproveitado.
_Avoid_: id do relatório, chave, nome técnico

**Cadastro**:
Registro administrativo que torna um Produto ou Relatório conhecido pelo sistema. Sem Cadastro não existe Coleta nem Geração.
_Avoid_: configuração, setup, parametrização

**Coleta**:
Leitura agendada dos dados de um Relatório no sistema de origem e sua gravação no Repositório de Coleta.
_Avoid_: ingestão, carga, importação, ETL

**Execução de Coleta**:
Uma tentativa individual de Coleta de um Relatório para uma Data de Referência, com início, fim e Status de Processamento próprios.
_Avoid_: job, run, processamento, rodada

**Repositório de Coleta**:
Armazenamento onde os dados coletados residem até o fim do seu ciclo de vida. Não confundir com o repositório de código.
_Avoid_: banco, base, storage

**Data de Referência**:
Dia a que os dados coletados se referem, no formato yyyy-MM-dd.
_Avoid_: data de processamento, data de carga, competência

**Geração**:
Produção sob demanda do arquivo de um Relatório, em um Formato de Exportação, a partir dos dados já coletados.
_Avoid_: exportação, renderização, download

**Formato de Exportação**:
Formato do arquivo produzido por uma Geração: PDF, CSV, XLSX ou DOCX.
_Avoid_: tipo de arquivo, extensão, layout

**Status de Processamento**:
Situação de uma Execução de Coleta: em processamento, processado com sucesso, processado com erro ou processado com alerta.
_Avoid_: estado, situação, fase

**Tempo Estimado de Execução**:
Duração esperada, em segundos, de uma Execução de Coleta de um Relatório. Excedida, o Status de Processamento passa a processado com alerta.
_Avoid_: SLA, timeout, prazo

**Janela de Agendamento**:
Periodicidade nomeada que um Relatório escolhe em seu Cadastro e que determina quando sua Coleta ocorre.
_Avoid_: cron, agenda, frequência, horário

### Pessoas e acesso

**Role de Relatório**:
Agrupamento de permissão que reúne Relatórios e Relatores. Um Relator gera apenas os Relatórios alcançados pelas suas Roles de Relatório.
_Avoid_: permissão, grupo, perfil de acesso, papel

**Relator**:
Usuário que gera e baixa os Relatórios aos quais suas Roles de Relatório dão acesso.
_Avoid_: usuário final, consumidor, solicitante

**Gerente**:
Usuário que administra Roles de Relatório — cria, vincula a Relatórios e a Relatores — e remove Relatores.
_Avoid_: supervisor, aprovador, coordenador

**Administrador**:
Usuário que administra Produtos, Relatórios e os usuários Gerente e Administrador, e que também consulta as Execuções de Coleta e a trilha de auditoria de downloads (ADR-0019).
_Avoid_: root, superusuário, admin

**Operação** e **Auditoria**:
Funções organizacionais, não tipos de usuário. Quem as exerce entra no sistema como Administrador; o acesso a Airflow, Grafana, Jaeger e Prometheus não passa pela aplicação e é delimitado pela rede interna. Ver ADR-0019.
_Avoid_: papel de operador, perfil de auditor, role de auditoria
