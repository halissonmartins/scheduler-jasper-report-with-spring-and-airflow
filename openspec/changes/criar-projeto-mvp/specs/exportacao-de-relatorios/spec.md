## ADDED Requirements

### Requirement: Exportação síncrona sem status persistido
A exportação SHALL devolver o arquivo ou o erro na mesma requisição, e SHALL NOT ter status persistido
(RN-30, RF-19).

#### Scenario: Arquivo devolvido na mesma requisição
- **WHEN** um usuário autorizado solicita a exportação de um relatório disponível
- **THEN** o arquivo é devolvido na resposta daquela requisição
- **AND** nenhum registro de status de exportação é criado

### Requirement: Exportação lê apenas o artefato apurado
A exportação SHALL ler exclusivamente o artefato já apurado e o schema de controle, e SHALL NOT acessar
schema transacional de produto algum (RN-31, RA-29).

#### Scenario: API sem acesso transacional
- **WHEN** as fontes de dados configuradas na API são inspecionadas
- **THEN** nenhuma delas aponta para schema transacional de produto

### Requirement: Quatro formatos de entrega
A exportação SHALL oferecer PDF, XLSX, DOCX e CSV (RN-32). PDF, XLSX e DOCX SHALL ser produzidos a partir do
`.jrprint`; o CSV SHALL ser servido a partir do `.csv.gz`, sem passar pelo motor de relatório (RA-27).

#### Scenario: PDF e DOCX preservam paginação
- **WHEN** o usuário exporta em PDF ou DOCX
- **THEN** a paginação do artefato renderizado é preservada

#### Scenario: CSV é o dataset bruto
- **WHEN** o usuário exporta em CSV
- **THEN** o conteúdo é o dataset da consulta principal, sem subrelatórios, imagens nem formatação
- **AND** o separador é `;`

### Requirement: XLSX contínuo com cabeçalho único
A exportação XLSX SHALL ser entregue como planilha contínua, com o cabeçalho de coluna aparecendo
**exatamente uma vez** (RN-33, RF-21). Todo JRXML do projeto SHALL colocar o cabeçalho de coluna na banda
`title` e manter em `pageHeader`/`pageFooter` apenas ornamento descartável (RA-59).

#### Scenario: Cabeçalho aparece uma vez
- **WHEN** um relatório de várias páginas é exportado em XLSX
- **THEN** o cabeçalho de coluna aparece exatamente uma vez na planilha
- **AND** não há espaço vazio entre linhas nem uma aba por página

#### Scenario: Teste por relatório
- **WHEN** um relatório novo é adicionado ao projeto
- **THEN** existe teste próprio dele exportando em XLSX e afirmando o cabeçalho único

### Requirement: Exportação condicionada ao status vigente
A exportação SHALL ser permitida somente quando a execução vigente do par estiver em
`processado com sucesso` ou `processado com alerta` (RN-42, RF-20).

#### Scenario: Par em erro ou em processamento
- **WHEN** a exportação é solicitada para par cuja execução vigente está em `processado com erro` ou
  `em processamento`
- **THEN** a exportação é recusada com mensagem explicando a indisponibilidade

### Requirement: Recusa explícita por retenção
A solicitação de exportação de artefato já expurgado SHALL ser recusada com mensagem explícita de
indisponibilidade por retenção, nunca com erro genérico (RN-39, RF-24).

#### Scenario: Artefato expurgado
- **WHEN** o usuário solicita exportação de data cujo artefato já foi expurgado
- **THEN** a resposta identifica a indisponibilidade por retenção

### Requirement: Limite de exportações simultâneas
O número de exportações simultâneas SHALL ser limitado ao teto de RNF-10, e a requisição excedente SHALL ser
**recusada de imediato** com indicação de repetir mais tarde — sem enfileiramento (RN-53, RF-48, RA-60).

#### Scenario: Requisição acima do teto
- **WHEN** chega uma exportação além do limite de simultâneas
- **THEN** ela é recusada imediatamente com indicação de repetir mais tarde
- **AND** a requisição não fica aguardando vaga

#### Scenario: Vaga liberada após conclusão
- **WHEN** uma exportação em curso termina
- **THEN** uma nova exportação volta a ser aceita
