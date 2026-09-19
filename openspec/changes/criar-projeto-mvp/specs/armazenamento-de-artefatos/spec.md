## ADDED Requirements

### Requirement: Dois arquivos irmãos por execução concluída
Cada execução concluída com sucesso ou alerta SHALL produzir um `.jrprint` — o `JasperPrint` serializado — e
um `.csv.gz` com o dataset bruto da consulta principal, separador `;` (RA-16, RA-17).

#### Scenario: Par de arquivos gravado
- **WHEN** uma execução conclui com sucesso
- **THEN** existem no repositório o `.jrprint` e o `.csv.gz` daquele relatório e data

#### Scenario: CSV não passa pelo motor de relatório
- **WHEN** o `.csv.gz` é gerado
- **THEN** ele contém o dataset da consulta principal, sem subrelatórios, imagens ou formatação

### Requirement: Caminho por identificadores imutáveis
O caminho do artefato SHALL ser **data de referência (`yyyy-MM-dd`) → sigla do produto → código do
relatório** (RN-08, RA-19). O nome do produto SHALL NOT compor o caminho.

#### Scenario: Nome do produto editado
- **WHEN** o nome de um produto é editado
- **THEN** o caminho dos artefatos existentes e dos futuros permanece o mesmo

### Requirement: Janela de retenção de 7 dias
Os artefatos SHALL ser expurgados automaticamente pela política do repositório após a janela de retenção,
com valor padrão de 7 dias configurável por variável de ambiente (RN-36, RN-37, RA-20). A retenção efetiva
SHALL NOT ser menor que a janela declarada.

#### Scenario: Artefato dentro da janela
- **WHEN** um artefato tem menos de 7 dias desde a data de referência
- **THEN** ele continua disponível para exportação

#### Scenario: Expurgo aplicado
- **WHEN** a fronteira de expiração é cruzada
- **THEN** o artefato é removido do repositório
- **AND** aquela data de referência deixa de aparecer na listagem

### Requirement: Marca de expurgo recebida por endpoint dedicado
A API SHALL expor um endpoint autenticado por credencial de serviço que recebe a notificação de remoção do
repositório e marca o artefato como expurgado no schema de controle (RA-21, RA-63). A assinatura da
notificação SHALL ser a de remoção de objeto, não a de transição ou restauração.

#### Scenario: Notificação de expurgo marca o artefato
- **WHEN** o repositório notifica a remoção de um objeto por ciclo de vida
- **THEN** o artefato correspondente é marcado como expurgado no schema de controle

#### Scenario: Endpoint exige credencial de serviço
- **WHEN** a notificação chega sem credencial válida
- **THEN** ela é rejeitada

#### Scenario: Notificação perdida não produz resposta errada
- **WHEN** a marca de expurgo não chegou, mas a data de referência é anterior a hoje menos a janela de retenção
- **THEN** a API deriva o estado expurgado e recusa a exportação com a mensagem de retenção
