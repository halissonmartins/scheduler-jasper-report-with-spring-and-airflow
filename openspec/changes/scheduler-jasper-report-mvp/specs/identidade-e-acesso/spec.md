## ADDED Requirements

### Requirement: Entrada e saída da aplicação
O sistema SHALL autenticar o usuário contra o provedor de identidade e SHALL trafegar a
autorização entre frontend e API por JWT. A saída encerra a sessão.

#### Scenario: Entrada bem-sucedida
- **WHEN** um usuário cadastrado entra com credenciais válidas
- **THEN** o frontend recebe um JWT e passa a chamar a API com ele

#### Scenario: Requisição sem credencial
- **WHEN** a API recebe requisição sem JWT válido em endpoint protegido
- **THEN** a requisição é negada

### Requirement: Perfil como conjunto fechado definido em código
Os três perfis — ADMINISTRADOR, GERENTE e RELATOR — SHALL existir como **realm roles** criadas na
inicialização do realm, e MUST NOT ser criados, removidos ou renomeados pela aplicação. Um usuário
tem exatamente um perfil.

#### Scenario: Realm inicializado
- **WHEN** o provedor de identidade sobe pela primeira vez
- **THEN** as três realm roles existem
- **AND** nenhum endpoint da aplicação cria ou remove realm role

#### Scenario: Usuário com dois perfis
- **WHEN** se tenta atribuir dois perfis ao mesmo usuário
- **THEN** a operação é recusada

### Requirement: ADMINISTRADOR inicial criado na inicialização
Um usuário de perfil ADMINISTRADOR SHALL ser criado automaticamente ao iniciar o provedor de
identidade, com senha definida em variável de ambiente.

#### Scenario: Primeiro acesso ao ambiente
- **WHEN** o ambiente sobe do zero
- **THEN** existe um ADMINISTRADOR utilizável, com a senha da variável de ambiente
- **AND** essa senha não está versionada no repositório

### Requirement: Role de relatório como conjunto aberto
A Role de relatório SHALL existir como **client role** de um cliente dedicado, criada e removida
pelo GERENTE, e SHALL ser vinculável a relatórios e a grupos. O vínculo
*Relatório → Role de relatório* SHALL viver em tabela do schema de controle, por ser o único elo
que precisa conhecer o catálogo.

#### Scenario: Gerente cria e vincula uma role
- **WHEN** o GERENTE cria uma role de relatório e a vincula a dois relatórios e a um grupo
- **THEN** a client role existe no cliente dedicado
- **AND** o vínculo com os relatórios está no schema de controle

#### Scenario: Remoção de role revoga somente o seu caminho
- **WHEN** uma role de relatório é removida e um usuário alcançava um dos seus relatórios também
  por outro grupo
- **THEN** ele continua alcançando aquele relatório pelo outro caminho

### Requirement: Cadeia de permissão N:N com acesso pela união
A concessão de acesso SHALL seguir a cadeia *Relatório → Role de relatório → Grupo → Usuário*, com
todos os elos N:N, e o acesso efetivo SHALL ser a união de todos os caminhos.

#### Scenario: União de caminhos
- **WHEN** um usuário está em dois grupos cujas roles apontam para conjuntos diferentes de
  relatórios
- **THEN** ele alcança a união dos dois conjuntos

#### Scenario: Vínculo removido
- **WHEN** o usuário é removido de um grupo
- **THEN** o acesso aos relatórios que vinham apenas daquele grupo cessa imediatamente

### Requirement: GERENTE não promove ninguém
O GERENTE MUST NOT criar nem promover usuário a GERENTE ou a ADMINISTRADOR, nem pela interface nem
por manipulação direta da requisição. A separação SHALL ser estrutural: os endpoints do GERENTE
operam exclusivamente sobre client roles do cliente dedicado, e Perfil está em outro espaço de
nomes e outro endpoint.

#### Scenario: Gerente tenta atribuir realm role
- **WHEN** um GERENTE envia requisição pedindo a atribuição da realm role ADMINISTRADOR a alguém
- **THEN** a requisição é negada
- **AND** nenhum endpoint disponível ao GERENTE alcança realm roles

#### Scenario: Teste dedicado da separação
- **WHEN** a suíte de testes roda
- **THEN** existe teste automatizado que afirma a impossibilidade de o GERENTE promover alguém

### Requirement: Gestão de usuários administrativos pelo ADMINISTRADOR
O ADMINISTRADOR SHALL cadastrar e remover usuários de perfil ADMINISTRADOR e GERENTE. RELATOR
SHALL poder ser removido tanto pelo ADMINISTRADOR quanto pelo GERENTE.

#### Scenario: Administrador cadastra um GERENTE
- **WHEN** o ADMINISTRADOR cadastra um usuário com perfil GERENTE
- **THEN** o usuário passa a existir com a realm role correspondente

#### Scenario: Gerente remove um RELATOR
- **WHEN** o GERENTE remove um usuário RELATOR
- **THEN** o usuário é removido e perde o acesso

### Requirement: Autocadastro público apenas de RELATOR
O autocadastro público SHALL criar exclusivamente usuários de perfil RELATOR, sempre no estado
*pendente de vínculo*, pela página de registro do provedor de identidade com tema customizado.
MUST NOT existir escolha de perfil, fila de aprovação, verificação de e-mail obrigatória nem grupo
padrão.

#### Scenario: Autocadastro concluído
- **WHEN** alguém se autocadastra pela página pública
- **THEN** o usuário é criado com perfil RELATOR e sem grupo algum
- **AND** ele consegue entrar na aplicação imediatamente

#### Scenario: Tentativa de escolher o perfil
- **WHEN** a requisição de autocadastro inclui um campo de perfil
- **THEN** o campo é ignorado e o perfil criado é RELATOR

#### Scenario: Sem acesso por omissão
- **WHEN** o RELATOR recém-criado consulta a listagem
- **THEN** nenhum relatório é alcançado, porque não há grupo padrão

### Requirement: Troca e recuperação da própria senha
Todo usuário, de qualquer perfil, SHALL poder trocar a própria senha e recuperá-la por e-mail. O
console de conta e a página de registro SHALL ser expostos seletivamente pelo ingress, e o
restante do console administrativo do provedor de identidade MUST NOT ser exposto.

#### Scenario: Recuperação por e-mail
- **WHEN** um usuário solicita a recuperação de senha
- **THEN** a mensagem chega ao servidor SMTP local e permite redefinir a senha

#### Scenario: Console administrativo não exposto
- **WHEN** alguém tenta acessar o console administrativo pelo ingress
- **THEN** o acesso não é exposto, enquanto o console de conta e o registro seguem acessíveis
