## ADDED Requirements

### Requirement: Cadeia de permissão em N:N
A concessão de acesso SHALL seguir a cadeia **Relatório → Role de relatório → Grupo → Usuário**, com todos os
elos em N:N, e o acesso efetivo SHALL ser a **união** de todos os caminhos (RN-22, RF-33).

#### Scenario: Usuário em múltiplos grupos
- **WHEN** um RELATOR pertence a dois grupos com roles de relatório distintas
- **THEN** ele acessa a união dos relatórios alcançados pelos dois grupos

#### Scenario: Remoção de um caminho não derruba os outros
- **WHEN** uma role de relatório ou um grupo é removido
- **THEN** o acesso concedido por ele cessa
- **AND** o acesso concedido por outro caminho permanece

#### Scenario: Revogação imediata
- **WHEN** o vínculo de um usuário a um grupo é removido
- **THEN** o acesso aos relatórios correspondentes cessa imediatamente

### Requirement: Separação estrutural entre Perfil e Role de relatório
Perfil SHALL viver como realm role, criado na inicialização do realm; Role de relatório SHALL viver como
client role de um cliente dedicado, criada pelo GERENTE (RA-61). Os endpoints do GERENTE SHALL operar
exclusivamente sobre client roles desse cliente.

#### Scenario: GERENTE não alcança perfil
- **WHEN** um GERENTE tenta criar, atribuir ou promover um Perfil, inclusive manipulando diretamente a
  requisição
- **THEN** a operação é negada, porque o alvo está em outro espaço de nomes e outro endpoint

#### Scenario: GERENTE cria role de relatório
- **WHEN** um GERENTE cria uma role de relatório e a vincula a um relatório e a um grupo
- **THEN** os usuários daquele grupo passam a alcançar o relatório

### Requirement: GERENTE administra acesso e não exporta
O GERENTE SHALL administrar roles, grupos e vínculos, e SHALL NOT listar nem exportar relatórios (RN-25,
RF-18).

#### Scenario: GERENTE tenta exportar
- **WHEN** um GERENTE solicita a exportação de qualquer relatório
- **THEN** a solicitação é negada

### Requirement: ADMINISTRADOR com acesso irrestrito
O ADMINISTRADOR SHALL acessar todos os relatórios sem passar pela cadeia de permissão — única exceção de
autorização do sistema, com teste automatizado dedicado (RN-24, RF-17, RA-68).

#### Scenario: ADMINISTRADOR sem grupo nem role
- **WHEN** um ADMINISTRADOR sem grupo algum exporta um relatório
- **THEN** a exportação é permitida

### Requirement: Gestão de usuários por perfil
O ADMINISTRADOR SHALL cadastrar e remover usuários ADMINISTRADOR e GERENTE; ADMINISTRADOR e GERENTE SHALL
remover usuários RELATOR (PRD §3.2, RF-35).

#### Scenario: GERENTE remove RELATOR
- **WHEN** um GERENTE remove um usuário RELATOR
- **THEN** a remoção é aplicada

#### Scenario: GERENTE tenta remover outro GERENTE
- **WHEN** um GERENTE tenta remover um usuário GERENTE ou ADMINISTRADOR
- **THEN** a operação é negada

### Requirement: Teste de autorização por rota
Toda rota nova SHALL ter teste de autorização cobrindo pelo menos um perfil autorizado e um não autorizado
(guia E5).

#### Scenario: Rota sem teste de autorização
- **WHEN** um PR adiciona uma rota sem teste de autorização
- **THEN** a definition of done não é atendida e o PR é devolvido
