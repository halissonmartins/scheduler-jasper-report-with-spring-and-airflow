## ADDED Requirements

### Requirement: Mono repositório com versão única
O código-fonte SHALL residir num único repositório, com todos os módulos backend compartilhando a mesma
versão e as mesmas versões de dependência (RA-01). A versão do JasperReports SHALL ser idêntica em todo
módulo que serializa ou desserializa `JasperPrint`.

#### Scenario: Versão única de dependência
- **WHEN** o build agrega as dependências resolvidas de todos os módulos
- **THEN** existe exatamente uma versão de JasperReports em todo o reator
- **AND** a divergência de versão entre módulos reprova o build

#### Scenario: Módulos exigidos existem
- **WHEN** o reator Maven é construído
- **THEN** existem a biblioteca comum, o starter do processador, os 5 módulos processadores e a API REST

### Requirement: Ambiente local reproduzível
Um clone limpo SHALL subir o ambiente completo e rodar os testes sem passo manual além dos comandos
documentados no `README.md`.

#### Scenario: Subida em três comandos
- **WHEN** um clone limpo executa os comandos de setup, subida e teste documentados
- **THEN** as dependências de RA-51 sobem via Docker Compose
- **AND** a API responde `UP` em `/actuator/health/readiness`

#### Scenario: Nenhum segredo real versionado
- **WHEN** o repositório é varrido por scanner de segredos
- **THEN** nenhuma credencial real é encontrada
- **AND** toda variável necessária está declarada em `.env.example` sem valor sensível

### Requirement: CI bloqueante por PR
O CI SHALL executar lint, compilação, testes e build a cada PR, e SHALL reprovar o PR quando qualquer etapa
falhar (RA-53).

#### Scenario: PR com teste falhando
- **WHEN** um PR contém um teste que falha
- **THEN** o CI reprova e o merge é bloqueado

#### Scenario: Números PROVISÓRIO não reprovam PR
- **WHEN** uma métrica marcada `PROVISÓRIO` no PRD §10 ainda não foi medida pelo spike de calibração
- **THEN** o CI não usa esse número como critério de reprovação

### Requirement: Timezone e idioma fixos
Toda aplicação e todo contêiner SHALL executar no fuso `America/Sao_Paulo` (RA-52, RNF-14), e toda mensagem
destinada ao usuário SHALL estar em pt-BR (RNF-15).

#### Scenario: Data de referência resolvida no fuso correto
- **WHEN** o ciclo dispara às 03h00 de `America/Sao_Paulo`
- **THEN** a data de referência é o dia local do disparo, e não o dia em UTC

### Requirement: Artefatos de documentação exigidos pelo guia
O repositório SHALL conter os artefatos que o guia exige e que os documentos existentes já referenciam:
`docs/glossario.md`, `docs/user-stories.md`, `docs/especificacao.md`, `docs/adr/`,
`docs/arquitetura/c4-contexto.md`, `docs/riscos.md`, `docs/design/fluxos.md`,
`docs/design/decisoes-ux.md`, `docs/design/design-system.md`, `ARCHITECTURE.md` e `README.md`.

#### Scenario: Referência apontando para documento inexistente
- **WHEN** um documento do repositório referencia outro documento por caminho
- **THEN** o caminho referenciado existe

#### Scenario: ARCHITECTURE.md declara proibições
- **WHEN** o `ARCHITECTURE.md` é lido
- **THEN** ele declara explicitamente os invariantes como proibições, incluindo que nenhum módulo além da
  Coleta acessa schema transacional
