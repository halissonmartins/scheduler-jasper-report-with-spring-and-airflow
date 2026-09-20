## ADDED Requirements

### Requirement: Navegação por data, produto e relatório
A listagem SHALL apresentar os relatórios disponíveis navegáveis por data de referência, depois
produto, depois relatório, exibindo a data no formato `dd/MM/yyyy`.

#### Scenario: Navegação completa
- **WHEN** um usuário autorizado abre a listagem
- **THEN** ele escolhe primeiro a data em `dd/MM/yyyy`, depois o produto, depois o relatório

#### Scenario: Datas fora da retenção não aparecem
- **WHEN** uma data de referência já teve seus artefatos expurgados
- **THEN** ela não aparece entre as datas disponíveis

### Requirement: Listagem filtrada pela cadeia de permissão
A listagem de um RELATOR SHALL conter exclusivamente os relatórios alcançados pela sua cadeia de
permissão, e o acesso efetivo SHALL ser a união de todos os caminhos.

#### Scenario: Relator com um grupo
- **WHEN** um RELATOR pertence a um grupo que recebe uma role de relatório ligada a dois
  relatórios
- **THEN** a sua listagem contém exatamente esses dois relatórios

#### Scenario: Relator em múltiplos grupos
- **WHEN** um RELATOR pertence a dois grupos com roles diferentes
- **THEN** a sua listagem é a união dos relatórios de ambos, sem duplicidade

### Requirement: Acesso direto fora da permissão é negado
O sistema SHALL negar o acesso direto a relatório fora da cadeia de permissão do usuário, e não
apenas ocultá-lo da listagem.

#### Scenario: Requisição direta por identificador
- **WHEN** um RELATOR solicita por identificador um relatório que não está na sua cadeia
- **THEN** a requisição é negada por autorização
- **AND** a resposta não revela a existência ou o conteúdo do relatório

### Requirement: RELATOR pendente de vínculo
A listagem de um RELATOR que ainda não pertence a nenhum grupo SHALL vir vazia, acompanhada de
mensagem informando que ele aguarda a configuração das permissões.

#### Scenario: Primeiro acesso após autocadastro
- **WHEN** um RELATOR recém-autocadastrado entra na aplicação
- **THEN** ele entra normalmente
- **AND** a sua listagem vem vazia com a mensagem de aguardo

### Requirement: ADMINISTRADOR enxerga e exporta todos os relatórios
O ADMINISTRADOR SHALL enxergar e exportar todos os relatórios sem passar pela cadeia de permissão.
Esta é a única exceção de autorização do sistema e SHALL ter teste automatizado dedicado.

#### Scenario: Administrador sem grupo algum
- **WHEN** um ADMINISTRADOR que não pertence a nenhum grupo abre a listagem
- **THEN** todos os relatórios ativos aparecem
- **AND** ele consegue exportar qualquer um deles

### Requirement: GERENTE não exporta relatório algum
O GERENTE SHALL administrar o acesso e MUST NOT exportar nem baixar relatório algum, ainda que
esteja em grupos com roles de relatório.

#### Scenario: Gerente tenta exportar
- **WHEN** um GERENTE solicita a exportação de qualquer relatório
- **THEN** a requisição é negada por autorização

### Requirement: Itens inativados somem da listagem e permanecem referenciáveis
Relatório e produto inativados SHALL desaparecer da listagem e SHALL permanecer referenciáveis por
execuções, auditoria e histórico de downloads.

#### Scenario: Relatório inativado com downloads antigos
- **WHEN** um relatório com downloads registrados é inativado
- **THEN** ele não aparece mais na listagem
- **AND** o histórico de downloads continua a exibi-lo
