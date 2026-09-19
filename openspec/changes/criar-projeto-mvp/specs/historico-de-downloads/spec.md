## ADDED Requirements

### Requirement: Registro de todo download
Todo download SHALL ser registrado com usuário, relatório, data de referência, formato e momento (RN-35).

#### Scenario: Download registrado
- **WHEN** um usuário baixa um relatório exportado
- **THEN** existe um registro de download correspondente

### Requirement: Cópia dos identificadores no momento do download
O registro SHALL guardar **cópia** do código do relatório, do nome do relatório, da sigla do produto, da data
de referência e do formato — não apenas as chaves (RN-35, RA-66, RF-51).

#### Scenario: Nome editado depois do download
- **WHEN** o nome de um relatório é editado após um download
- **THEN** o histórico continua exibindo o nome que o relatório tinha no momento do download

#### Scenario: Relatório inativado depois do download
- **WHEN** o relatório é inativado
- **THEN** o registro de download permanece exibível e íntegro

### Requirement: Consulta restrita ao ADMINISTRADOR
O histórico de downloads SHALL ser consultável apenas pelo ADMINISTRADOR (RF-23, PRD §3.2).

#### Scenario: Perfil não autorizado
- **WHEN** um GERENTE ou RELATOR tenta consultar o histórico de downloads
- **THEN** a consulta é negada

### Requirement: Retenção indefinida do histórico
O histórico de downloads SHALL NOT ser expurgado, sobrevivendo indefinidamente à remoção do artefato que
registrou (RN-38, RA-22).

#### Scenario: Artefato expurgado, registro preservado
- **WHEN** o artefato correspondente é expurgado pela política de retenção
- **THEN** o registro do download continua no histórico
