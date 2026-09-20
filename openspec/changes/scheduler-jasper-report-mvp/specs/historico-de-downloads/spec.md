## ADDED Requirements

### Requirement: Registro de todo download com cópia dos identificadores
Todo download SHALL ser registrado com usuário, relatório, data de referência, formato e momento,
e o registro SHALL guardar **cópia** do código do relatório, do nome do relatório, da sigla e do
nome do produto como estavam naquele instante — não apenas as chaves.

#### Scenario: Download registrado
- **WHEN** um usuário baixa um relatório em XLSX
- **THEN** existe registro com usuário, código, nome, sigla, data de referência, formato e momento

#### Scenario: Nome do relatório editado depois
- **WHEN** o nome do relatório é alterado um ano depois do download
- **THEN** o registro daquele download continua exibindo o nome vigente no momento do download

### Requirement: Consulta do histórico privativa do ADMINISTRADOR
O histórico de downloads SHALL ser consultável pelo ADMINISTRADOR, e MUST NOT ser acessível a
GERENTE ou RELATOR.

#### Scenario: Administrador consulta o histórico
- **WHEN** o ADMINISTRADOR abre o histórico de downloads
- **THEN** os registros são exibidos

#### Scenario: Outro perfil tenta consultar
- **WHEN** um GERENTE ou RELATOR chama o endpoint do histórico
- **THEN** a requisição é negada por autorização

### Requirement: Histórico sobrevive ao expurgo e à inativação
O histórico de downloads MUST NOT ser expurgado: ele SHALL sobreviver indefinidamente à remoção do
artefato que registrou e à inativação do relatório e do produto.

#### Scenario: Artefato expurgado
- **WHEN** o artefato de uma data já expurgada é procurado a partir do histórico
- **THEN** o registro do download continua listado, com indicação de que o artefato não está mais
  disponível

#### Scenario: Relatório inativado
- **WHEN** o relatório baixado é inativado
- **THEN** o registro do download permanece consultável e legível
