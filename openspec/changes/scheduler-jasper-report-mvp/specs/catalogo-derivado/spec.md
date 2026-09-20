## ADDED Requirements

### Requirement: Catálogo publicado pelo código na inicialização
Cada módulo processador SHALL publicar, ao iniciar, o seu produto e os seus relatórios no schema
de controle — sigla, nome, código, nome, descrição e tempo estimado inicial. A aplicação MUST NOT
criar nem apagar linha de catálogo: ela guarda apenas o que é mutável.

#### Scenario: Módulo anuncia produto e relatórios
- **WHEN** o módulo processador de um produto inicia pela primeira vez
- **THEN** o produto e os seus relatórios passam a existir no catálogo do schema de controle
- **AND** o tempo estimado inicial de cada relatório é o declarado em código

#### Scenario: Reinício não duplica nem apaga catálogo
- **WHEN** o mesmo módulo inicia novamente após alguém ter editado o nome de um relatório pela
  aplicação
- **THEN** o catálogo continua com uma única linha por relatório
- **AND** o nome editado pela aplicação é preservado, não sobrescrito pelo valor do código

#### Scenario: Não existe criação de produto ou relatório pela aplicação
- **WHEN** qualquer cliente tenta criar produto ou relatório pela API
- **THEN** não existe endpoint que atenda a essa operação

### Requirement: Código de relatório duplicado impede o módulo de iniciar
A inicialização de um produto SHALL ser recusada quando dois de seus relatórios declararem os
mesmos quatro dígitos, porque a violação da unicidade dentro do produto não pode ser persistida.

#### Scenario: Dois relatórios com o mesmo código
- **WHEN** um módulo declara `POUPANCA-0001` duas vezes
- **THEN** o módulo falha na inicialização com erro explícito apontando o código duplicado
- **AND** nenhuma linha de catálogo daquele produto é gravada

#### Scenario: Mesmos quatro dígitos em produtos diferentes
- **WHEN** existem `POUPANCA-0001` e `CLIENTE-0001`
- **THEN** ambos os módulos iniciam normalmente

### Requirement: Formato e imutabilidade de sigla e código
A Sigla SHALL obedecer a `^[A-Z]{1,20}$` e ser única no sistema, e o Código do Relatório SHALL
obedecer a `^[A-Z]{1,20}-\d{4}$`, formado pela sigla do produto ao qual pertence. Ambos são
declarados em código e MUST NOT ser editáveis por interface alguma.

#### Scenario: Sigla fora do formato
- **WHEN** um módulo declara a sigla `Poupanca1`
- **THEN** a inicialização é recusada

#### Scenario: Código não corresponde à sigla do produto
- **WHEN** o módulo `CLIENTE` declara o relatório `POUPANCA-0001`
- **THEN** a inicialização é recusada

#### Scenario: Edição de identificador não existe
- **WHEN** um ADMINISTRADOR edita um relatório
- **THEN** o código e a sigla não fazem parte dos campos aceitos

### Requirement: Edição dos atributos mutáveis do catálogo
O ADMINISTRADOR SHALL editar o nome do produto, e o nome, a descrição e o tempo estimado do
relatório. Nenhum outro perfil tem acesso a essas operações.

#### Scenario: ADMINISTRADOR edita nome do produto
- **WHEN** o ADMINISTRADOR altera o nome do produto de sigla `POUPANCA`
- **THEN** o novo nome passa a aparecer na listagem
- **AND** o caminho dos artefatos já gravados permanece inalterado, porque usa a sigla

#### Scenario: GERENTE ou RELATOR tenta editar catálogo
- **WHEN** um usuário de perfil GERENTE ou RELATOR solicita a edição de um relatório
- **THEN** a requisição é negada por autorização

### Requirement: Tempo estimado obrigatório e positivo
Todo relatório SHALL ter tempo estimado de execução em segundos inteiros e maior que zero,
validado tanto na inicialização do módulo quanto na edição pela aplicação.

#### Scenario: Tempo estimado zero ou negativo na inicialização
- **WHEN** um módulo declara um relatório com tempo estimado `0`
- **THEN** a inicialização é recusada

#### Scenario: Tempo estimado inválido na edição
- **WHEN** o ADMINISTRADOR tenta gravar tempo estimado `-1` ou não inteiro
- **THEN** a edição é recusada com mensagem explícita

### Requirement: Teto da soma dos tempos estimados por produto
A soma dos tempos estimados dos relatórios ativos de um mesmo produto MUST NOT ultrapassar o teto
de 10 minutos, e a edição que fizer a soma estourar SHALL ser recusada. É o que torna a janela do
ciclo uma consequência do catálogo, e não uma estimativa.

#### Scenario: Edição estoura o teto do produto
- **WHEN** o ADMINISTRADOR eleva o tempo estimado de um relatório de modo que a soma do produto
  passe de 10 minutos
- **THEN** a edição é recusada informando a soma atual e o teto

#### Scenario: Inicialização com catálogo acima do teto
- **WHEN** os tempos estimados declarados em código somam mais que o teto do produto
- **THEN** o módulo falha na inicialização

### Requirement: Inativação lógica de relatório e produto
A retirada do catálogo visível SHALL ser feita por inativação, nunca por remoção física, e um
produto SHALL só poder ser inativado quando não tiver relatório ativo. Execuções, auditoria e
histórico de downloads continuam a referenciar o item inativado.

#### Scenario: Produto com relatório ativo
- **WHEN** o ADMINISTRADOR tenta inativar um produto que ainda tem relatório ativo
- **THEN** a inativação é recusada, informando quais relatórios impedem

#### Scenario: Relatório inativado sai do ciclo e da listagem
- **WHEN** um relatório é inativado
- **THEN** o ciclo seguinte não o apura
- **AND** ele deixa de aparecer na listagem
- **AND** as execuções e os downloads já registrados continuam a resolvê-lo

#### Scenario: Nada é apagado
- **WHEN** um produto é inativado
- **THEN** nenhuma linha de catálogo é removida do schema de controle
