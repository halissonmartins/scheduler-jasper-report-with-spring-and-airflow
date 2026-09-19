## ADDED Requirements

### Requirement: Navegação por data, produto e relatório
A listagem SHALL apresentar os relatórios disponíveis navegáveis por data → produto → relatório, exibindo a
data em `dd/MM/yyyy` (RF-13).

#### Scenario: Datas fora da janela de retenção não aparecem
- **WHEN** a listagem é aberta
- **THEN** somente datas de referência com artefato disponível são oferecidas

#### Scenario: Relatório inativado some da listagem
- **WHEN** um relatório é inativado
- **THEN** ele não aparece mais na listagem

### Requirement: Listagem filtrada pela cadeia de permissão
A listagem de um RELATOR SHALL conter exclusivamente os relatórios alcançados pela sua cadeia de permissão
(RN-23, RF-14). O acesso direto a relatório fora da cadeia SHALL ser negado (RF-15).

#### Scenario: Relatório fora da cadeia
- **WHEN** um RELATOR lista os relatórios disponíveis
- **THEN** relatórios não alcançados pela sua cadeia não aparecem

#### Scenario: Acesso direto por identificador
- **WHEN** um RELATOR requisita diretamente um relatório fora da sua cadeia
- **THEN** a requisição é negada, sem revelar a existência do relatório

### Requirement: RELATOR pendente de vínculo
A listagem de um RELATOR sem grupo SHALL vir vazia, acompanhada de mensagem informando que aguarda a
configuração das permissões (RN-28, RF-16, RF-55).

#### Scenario: Recém-cadastrado entra e vê a mensagem
- **WHEN** um RELATOR que acabou de se autocadastrar entra na aplicação
- **THEN** ele acessa a aplicação
- **AND** sua listagem vem vazia com a mensagem de aguardo

### Requirement: ADMINISTRADOR enxerga tudo
O ADMINISTRADOR SHALL enxergar todos os relatórios sem passar pela cadeia de permissão (RN-24, RF-17).

#### Scenario: Listagem do ADMINISTRADOR
- **WHEN** o ADMINISTRADOR lista os relatórios
- **THEN** todos os relatórios ativos com artefato disponível aparecem, independentemente de grupo ou role
