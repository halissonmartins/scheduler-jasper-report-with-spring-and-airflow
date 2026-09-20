## ADDED Requirements

### Requirement: Exportação síncrona e sem status persistido
A exportação SHALL devolver o arquivo ou devolver erro na mesma requisição, e MUST NOT criar
registro de status: o ciclo de vida de status pertence exclusivamente à Execução da Coleta.

#### Scenario: Exportação bem-sucedida
- **WHEN** um usuário autorizado solicita a exportação de um par exportável em PDF
- **THEN** a mesma requisição devolve o arquivo PDF
- **AND** nenhuma linha de status de exportação é criada

#### Scenario: Exportação com erro
- **WHEN** a conversão falha
- **THEN** a mesma requisição devolve erro no contrato de erro da API

### Requirement: A exportação nunca toca a base transacional
A exportação SHALL ler exclusivamente o artefato já apurado e o schema de controle. Qualquer
dependência da API para um schema transacional de produto é um defeito.

#### Scenario: Nenhuma conexão transacional na API
- **WHEN** a API exporta qualquer relatório
- **THEN** nenhuma consulta é emitida contra schema transacional de produto

### Requirement: Só exporta execução vigente em sucesso ou alerta
O sistema SHALL recusar a exportação quando a execução vigente do par para aquela data de
referência não estiver em `processado com sucesso` ou `processado com alerta`, porque nos demais
status não existe artefato válido.

#### Scenario: Par em erro
- **WHEN** um usuário solicita exportação de um par cuja execução vigente está em
  `processado com erro`
- **THEN** a exportação é recusada com mensagem explícita

#### Scenario: Par em processamento
- **WHEN** a execução vigente está `em processamento`
- **THEN** a exportação é recusada

#### Scenario: Par em alerta
- **WHEN** a execução vigente está em `processado com alerta`
- **THEN** a exportação é atendida normalmente

### Requirement: Quatro formatos de entrega
O sistema SHALL entregar PDF, XLSX, DOCX e CSV. PDF e DOCX preservam a paginação do artefato
renderizado; XLSX é planilha contínua; CSV vem do dataset bruto.

#### Scenario: Cada formato a partir da sua origem
- **WHEN** o mesmo par é exportado nos quatro formatos
- **THEN** PDF, XLSX e DOCX são produzidos a partir do `.jrprint`
- **AND** o CSV é servido a partir do `.csv.gz`, sem passar pelo motor de relatório

### Requirement: XLSX contínuo com cabeçalho de coluna único
A exportação XLSX SHALL entregar planilha contínua com o cabeçalho de coluna aparecendo
exatamente uma vez. Como `ignorePagination` atua no preenchimento e o `.jrprint` já está paginado,
isso SHALL ser obtido por convenção de autoria: todo JRXML do projeto coloca o cabeçalho de coluna
na banda `title` e mantém em `pageHeader` e `pageFooter` apenas ornamento descartável, e a
exportação exclui essas bandas por origem de elemento, com paginação por planilha desligada e
remoção do espaço vazio entre linhas.

#### Scenario: Relatório de várias páginas exportado em XLSX
- **WHEN** um artefato de cinco páginas é exportado em XLSX
- **THEN** o cabeçalho de coluna aparece exatamente uma vez na planilha
- **AND** não há cabeçalho nem rodapé de página repetidos

#### Scenario: Teste por relatório
- **WHEN** um relatório novo é adicionado ao projeto
- **THEN** existe teste dedicado que exporta aquele relatório em XLSX e afirma o cabeçalho único

### Requirement: CSV é o dataset bruto da consulta principal
A exportação em CSV SHALL entregar o dataset bruto da consulta principal — sem subrelatórios, sem
imagens e sem formatação — descomprimido a partir do `.csv.gz`.

#### Scenario: CSV de relatório com subrelatório
- **WHEN** um relatório que possui subrelatório é exportado em CSV
- **THEN** o arquivo contém apenas as linhas da consulta principal

### Requirement: Semáforo de exportações simultâneas
A API SHALL limitar as exportações simultâneas a 2 e SHALL recusar de imediato a requisição
excedente, com indicação de repetir mais tarde. MUST NOT existir fila, porque a exportação exige
resposta na mesma requisição.

#### Scenario: Terceira exportação simultânea
- **WHEN** duas exportações estão em andamento e chega uma terceira
- **THEN** a terceira é recusada de imediato com indicação de repetir mais tarde
- **AND** ela não é enfileirada nem espera vaga

#### Scenario: Vaga liberada
- **WHEN** uma das exportações em andamento termina
- **THEN** uma nova solicitação é aceita

### Requirement: Latência de exportação
A exportação SHALL respeitar, no percentil 95, 15 s para PDF, 25 s para XLSX e DOCX e 5 s para
CSV. Os valores são provisórios e SHALL ser substituídos por números medidos com `k6`.

#### Scenario: Medição de latência por formato
- **WHEN** a carga de calibração roda contra a API
- **THEN** o p95 de cada formato é registrado e comparado ao teto declarado
