## ADDED Requirements

### Requirement: Dois arquivos irmãos por execução bem-sucedida
Cada execução concluída com sucesso ou alerta SHALL produzir dois arquivos irmãos: o `.jrprint`,
com o `JasperPrint` serializado que serve a PDF, XLSX e DOCX, e o `.csv.gz`, com o dataset bruto
da consulta principal, comprimido, que serve ao CSV.

#### Scenario: Gravação dos dois artefatos
- **WHEN** uma execução conclui com sucesso
- **THEN** existem o `.jrprint` e o `.csv.gz` daquele par no repositório

#### Scenario: CSV não passa pelo motor de relatório
- **WHEN** o `.csv.gz` é gravado
- **THEN** ele contém o dataset da consulta principal, sem subrelatórios, sem imagens e sem
  formatação, com separador `;`

### Requirement: Caminho do artefato por identificadores imutáveis
O caminho de armazenamento SHALL ser organizado por data de referência em `yyyy-MM-dd`, sigla do
produto e código do relatório, e MUST NOT usar o nome do produto, que é editável.

#### Scenario: Caminho estável após renomear o produto
- **WHEN** o nome do produto de sigla `POUPANCA` é alterado
- **THEN** o caminho dos artefatos já gravados e dos futuros permanece o mesmo

### Requirement: Expurgo automático após a janela de retenção
Os artefatos SHALL ser expurgados automaticamente após uma janela de retenção de 7 dias contada a
partir da data de referência, e o valor SHALL ser configurável por variável de ambiente. Expirada
a janela, aquela data de referência deixa de aparecer na listagem.

#### Scenario: Artefato além da janela
- **WHEN** se passam mais de 7 dias da data de referência
- **THEN** os artefatos daquela data não existem mais no repositório
- **AND** a data deixa de aparecer na listagem

#### Scenario: Janela configurada com outro valor
- **WHEN** a variável de ambiente define 14 dias
- **THEN** o expurgo passa a ocorrer aos 14 dias, sem alteração de código

### Requirement: Marca de expurgo autoritativa com derivação como rede de segurança
A API SHALL expor endpoint autenticado por credencial de serviço que recebe a notificação de
expurgo do repositório e marca o artefato como expurgado no schema de controle. Quando a marca
estiver presente, ela SHALL ser autoritativa; quando faltar, a API SHALL derivar o estado
*expirado* pela comparação `data de referência < hoje − janela de retenção`. Assim uma notificação
perdida custa uma inconsistência transitória, não uma resposta errada ao usuário.

#### Scenario: Notificação recebida
- **WHEN** o repositório notifica a remoção de um artefato
- **THEN** o artefato fica marcado como expurgado no schema de controle

#### Scenario: Notificação perdida
- **WHEN** nenhuma notificação chega para uma data já fora da janela de retenção
- **THEN** a API ainda assim trata aquele artefato como expurgado, pela derivação aritmética

#### Scenario: Endpoint exige credencial de serviço
- **WHEN** a chamada ao endpoint de marca chega sem credencial de serviço válida
- **THEN** ela é recusada

### Requirement: Exportação de artefato expurgado recusada com mensagem explícita
A solicitação de exportação de artefato já expurgado SHALL ser recusada com mensagem explícita de
indisponibilidade por retenção, e MUST NOT resultar em erro genérico nem em nova leitura da base
transacional.

#### Scenario: Pedido de data fora da retenção
- **WHEN** um usuário solicita a exportação de um par cuja data já foi expurgada
- **THEN** a resposta informa indisponibilidade por retenção, nomeando a janela
- **AND** nenhuma reapuração é disparada

### Requirement: Três retenções independentes
O sistema SHALL manter três ciclos de vida independentes: artefatos por 7 dias, metadados de
Execução **nunca** expurgados, e histórico de downloads retido indefinidamente. Nada do catálogo é
apagado — produto e relatório são inativados.

#### Scenario: Métrica de 30 dias sobre artefatos já expurgados
- **WHEN** a taxa de apuração limpa é calculada em janela móvel de 30 dias
- **THEN** os metadados de execução de todos os 30 dias estão disponíveis, ainda que os artefatos
  de 23 deles já tenham sido expurgados

#### Scenario: Download registrado sobrevive ao artefato
- **WHEN** o artefato de um download registrado é expurgado
- **THEN** o registro do download permanece consultável
