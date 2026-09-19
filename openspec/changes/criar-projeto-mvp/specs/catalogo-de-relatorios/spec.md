## ADDED Requirements

### Requirement: Catálogo derivado do código
Produto e Relatório SHALL ser declarados em código e publicados no schema de controle pelo módulo
processador na sua inicialização (RN-49, RA-58). A aplicação SHALL NOT criar nem remover produto ou
relatório.

#### Scenario: Publicação na inicialização
- **WHEN** um módulo processador inicia
- **THEN** seu produto e seus relatórios existem no catálogo com código, nome, descrição e tempo estimado

#### Scenario: Reinicialização não sobrescreve atributos editados
- **WHEN** o módulo reinicia após o nome de um relatório ter sido editado pela aplicação
- **THEN** o nome editado é preservado

#### Scenario: Endpoint de criação não existe
- **WHEN** qualquer interface da aplicação é inspecionada
- **THEN** não há operação de criação nem de remoção física de produto ou relatório

### Requirement: Identificadores imutáveis
A Sigla do produto SHALL obedecer a `^[A-Z]{1,20}$` e ser única; o Código do relatório SHALL obedecer a
`^[A-Z]{1,20}-\d{4}$` e ser formado pela Sigla do seu produto (RN-01, RN-02). Ambos SHALL ser imutáveis.

#### Scenario: Tentativa de editar sigla ou código
- **WHEN** uma requisição tenta alterar a sigla de um produto ou o código de um relatório
- **THEN** a alteração é recusada

#### Scenario: Código com prefixo de outro produto
- **WHEN** um módulo declara um relatório cujo prefixo não é a sigla do seu próprio produto
- **THEN** o módulo não inicia

### Requirement: Código de relatório único dentro do produto
Os 4 dígitos do Código SHALL ser únicos dentro do mesmo Produto, e a violação SHALL impedir o módulo de
iniciar (RN-03, RF-44).

#### Scenario: Dois relatórios com o mesmo código
- **WHEN** um módulo declara dois relatórios com o mesmo código
- **THEN** o módulo falha a inicialização com erro explícito
- **AND** nada é persistido no catálogo

### Requirement: Tempo estimado obrigatório e limitado
Todo relatório SHALL ter tempo estimado em segundos inteiros maior que zero (RN-04). A soma dos tempos
estimados dos relatórios ativos de um mesmo produto SHALL NOT ultrapassar o teto de RNF-19 (RN-48).

#### Scenario: Tempo estimado inválido na inicialização
- **WHEN** um módulo declara relatório com tempo estimado zero ou negativo
- **THEN** o módulo não inicia

#### Scenario: Edição que estoura o teto do produto
- **WHEN** o ADMINISTRADOR edita o tempo estimado de forma que a soma do produto ultrapasse o teto
- **THEN** a edição é recusada com mensagem explicando o teto e a soma resultante

### Requirement: Inativação em vez de remoção
Produto e relatório SHALL ser inativados, nunca removidos fisicamente (RN-50). Um produto SHALL NOT ser
inativado enquanto tiver relatório ativo (RN-05, RF-50).

#### Scenario: Inativação de produto com relatório ativo
- **WHEN** o ADMINISTRADOR tenta inativar um produto que ainda tem relatório ativo
- **THEN** a inativação é recusada

#### Scenario: Referências sobrevivem à inativação
- **WHEN** um relatório é inativado
- **THEN** ele desaparece da listagem
- **AND** execuções, auditoria e histórico de downloads continuam referenciando-o
