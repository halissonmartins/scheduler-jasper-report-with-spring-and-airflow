## ADDED Requirements

### Requirement: Frontend integrado exclusivamente à API REST
A aplicação Angular SHALL se integrar exclusivamente com os endpoints da API REST, e SHALL NOT acessar
repositório de artefatos, banco ou orquestrador diretamente (RA-06).

#### Scenario: Dependências do frontend
- **WHEN** as chamadas de rede do frontend são inspecionadas
- **THEN** todas apontam para a API REST ou para o provedor de identidade

### Requirement: Design system como fonte dos valores visuais
Toda a interface SHALL usar exclusivamente os tokens de cor, tipografia, espaçamento, raio e sombra
declarados em `docs/design/design-system.md`, com componente canônico implementado no repositório para cada
padrão descrito (guia P2).

#### Scenario: Valor fora dos tokens
- **WHEN** um componente introduz valor de cor ou espaçamento fora dos tokens
- **THEN** o lint reprova

#### Scenario: Padrão sem implementação de referência
- **WHEN** o design system descreve um padrão
- **THEN** existe um componente real no repositório implementando-o

### Requirement: Estados canônicos de tela
A interface SHALL ter padrão único e reutilizado para os estados de carregamento, vazio, erro e sucesso
(guia P2).

#### Scenario: Listagem vazia do RELATOR pendente
- **WHEN** um RELATOR sem grupo abre a listagem
- **THEN** o estado vazio canônico é exibido com a mensagem de aguardo de permissões

#### Scenario: Erro exibido na tela
- **WHEN** a API devolve erro
- **THEN** o componente de erro exibe momento, descrição e Correlation ID, com ação de cópia em JSON

### Requirement: Acessibilidade mínima
Toda a interface SHALL atender contraste mínimo AA, foco visível em todo elemento interativo e rótulo
associado a todo input (guia P2).

#### Scenario: Navegação por teclado
- **WHEN** a aplicação é percorrida apenas pelo teclado
- **THEN** todo elemento interativo é alcançável e tem foco visível

### Requirement: Fluxos críticos cobertos por E2E de navegador
Os fluxos de entrar, listar, exportar e baixar SHALL ser cobertos por teste E2E de navegador, com os
cenários em Gherkin em `e2e/features/` (RA-46, RA-48).

#### Scenario: Fluxo de exportação ponta a ponta
- **WHEN** o teste E2E entra como RELATOR autorizado, navega até um relatório e exporta em PDF
- **THEN** o arquivo é baixado com sucesso
