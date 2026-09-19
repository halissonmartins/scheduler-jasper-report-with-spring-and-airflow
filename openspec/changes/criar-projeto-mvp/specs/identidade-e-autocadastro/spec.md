## ADDED Requirements

### Requirement: Autenticação por provedor de identidade
A autenticação SHALL ser feita pelo provedor de identidade, e a autorização entre frontend e API SHALL
trafegar por JWT (RA-30). O console administrativo do provedor SHALL NOT ser exposto — apenas a página de
registro e o Account Console (RA-34).

#### Scenario: Requisição sem token
- **WHEN** uma requisição alcança a API sem JWT válido
- **THEN** ela é rejeitada

#### Scenario: Console administrativo não exposto
- **WHEN** as rotas expostas pelo ingress são inspecionadas
- **THEN** o console administrativo do provedor de identidade não está entre elas

### Requirement: ADMINISTRADOR inicial criado na inicialização
Um usuário de perfil ADMINISTRADOR SHALL ser criado automaticamente na subida do provedor de identidade, com
senha vinda de variável de ambiente (RA-32).

#### Scenario: Primeira subida do ambiente
- **WHEN** o ambiente sobe pela primeira vez
- **THEN** existe um ADMINISTRADOR capaz de entrar na aplicação
- **AND** a senha não está versionada no repositório

### Requirement: Autocadastro público exclusivo de RELATOR
O autocadastro público SHALL criar exclusivamente usuários de perfil RELATOR, sempre sem grupo (RN-27,
RF-29, RF-30). SHALL NOT existir escolha de perfil, fila de aprovação nem grupo padrão.

#### Scenario: Autocadastro conclui
- **WHEN** alguém se cadastra pela página pública de registro
- **THEN** o usuário criado tem perfil RELATOR
- **AND** ele não pertence a grupo algum

#### Scenario: Tentativa de escolher perfil
- **WHEN** a requisição de autocadastro tenta informar perfil GERENTE ou ADMINISTRADOR
- **THEN** o perfil informado é ignorado e o usuário é criado como RELATOR

#### Scenario: Entrada imediata sem verificação de e-mail
- **WHEN** o usuário recém-cadastrado tenta entrar
- **THEN** ele entra na aplicação, sem acesso a relatório algum

### Requirement: Troca e recuperação da própria senha
Todo usuário, de qualquer perfil, SHALL trocar a própria senha e recuperá-la por e-mail (RN-29, RF-37).

#### Scenario: Recuperação por e-mail
- **WHEN** um usuário solicita recuperação de senha
- **THEN** a mensagem de redefinição chega ao servidor de e-mail do ambiente
- **AND** o link permite definir nova senha

### Requirement: Perfis como conjunto fechado
Os perfis ADMINISTRADOR, GERENTE e RELATOR SHALL ser um conjunto fechado criado na inicialização do realm, e
SHALL NOT ser administráveis pela aplicação. Um usuário SHALL ter exatamente um perfil (PRD §3.2).

#### Scenario: Aplicação não cria perfil
- **WHEN** as operações expostas pela API são inspecionadas
- **THEN** não há operação de criação ou remoção de perfil
