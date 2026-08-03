# Scheduler Jasper Report

Coleta agendada de dados de relatórios a partir das bases transacionais de cada produto, e
geração sob demanda desses relatórios em PDF, XLSX, DOCX e CSV.

A linguagem deste domínio é **português (pt-BR)**. Os termos abaixo aparecem no código como
estão escritos aqui.

## Language

### Produto e Relatório

**Produto**:
Um domínio de negócio com base transacional própria — Poupança, Cliente, Conta Corrente,
Consórcio, Empréstimo. É a fronteira de leitura: os dados de um Produto só são lidos pela sua
própria Coleta.
_Avoid_: sistema, módulo, domínio

**Sigla**:
O identificador curto e permanente de um Produto (`POUPANCA`, `CONTACORRENTE`), em maiúsculas
sem acento nem espaço, único entre Produtos. É informada no cadastro, nunca derivada do Nome, e
**nunca muda** — porque aparece em todo Código de Relatório e em todo caminho de Artefato.
_Avoid_: prefixo, código do produto, abreviação

**Nome do Produto**:
O rótulo do Produto exibido ao usuário ("Poupança"). Puramente apresentacional e **livremente
alterável** — não participa de nenhum identificador.
_Avoid_: descrição, título

**Relatório**:
A **definição cadastrada** de um relatório: seu Código, nome, descrição, tempo estimado de
execução e o JRXML associado. Existe uma vez e produz muitas Execuções. Um Relatório pertence a
exatamente um Produto.
_Avoid_: relatório disponível, template, modelo

**Código de Relatório**:
O identificador permanente de um Relatório, no formato `SIGLA-NNNN` (`POUPANCA-0001`). A
sequência de quatro dígitos é única **por Produto**, o que dá um teto de 9.999 Relatórios por
Produto. O Código nunca muda.
_Avoid_: id do relatório, chave

### Produção e consumo

**Coleta**:
O processo agendado que lê a base transacional de um Produto e produz os Artefatos de um
Relatório. É a única fronteira de leitura dessas bases.
_Avoid_: ingestão, carga, extração

**Execução**:
Uma rodada da Coleta para o par (Relatório, Data de Referência). Carrega status, início e fim.
É o que o relator escolhe no drop-down — as Execuções bem-sucedidas de um Relatório são o que
está "disponível".
_Avoid_: job, rodada, processamento, batch

**Data de Referência**:
O dia a que uma Execução se refere, no formato `yyyy-MM-dd`. Hoje corresponde ao dia em que a
Execução rodou. O par (Relatório, Data de Referência) é único.
_Avoid_: data de execução, competência, data do relatório

**Artefato**:
Um arquivo produzido por uma Execução e guardado no repositório: o `.jrprint` (o relatório
preenchido, do qual se exporta PDF, XLSX e DOCX) e o `.csv.gz` (o dataset bruto da consulta
principal). Artefatos expiram pela política de retenção; os metadados da Execução sobrevivem a
eles.
_Avoid_: arquivo, objeto, saída, output

**Exportação**:
A conversão sob demanda de um Artefato para o formato que o usuário pediu (PDF, XLSX, DOCX,
CSV). Acontece na hora do pedido e não é guardada.
_Avoid_: geração, renderização, conversão

**Download**:
A entrega de uma Exportação a um usuário, registrada em histórico. O histórico de Downloads
sobrevive ao expurgo dos Artefatos.
_Avoid_: acesso, retirada

### Autorização

**Perfil**:
O que um usuário é no sistema: `ADMINISTRADOR`, `GERENTE` ou `RELATOR`. Conjunto **fechado** de
três valores, definido no código — não é administrável.
_Avoid_: role, papel, tipo de usuário, permissão

**Role de Relatório**:
A chave que concede acesso a um conjunto de Relatórios. Conjunto **aberto**, criado e
administrado pelo GERENTE, e nomeado sob o prefixo reservado `REL_`. Sempre com o qualificador
"de Relatório" — "role" sozinho é ambíguo e não se usa.
_Avoid_: role, permissão, escopo, autorização

**Grupo**:
Um conjunto de usuários de Perfil RELATOR, ao qual se vinculam Roles de Relatório. É o degrau
intermediário da cadeia de concessão: Relatório ← Role de Relatório ← Grupo ← Usuário.
_Avoid_: time, equipe, coletivo, unidade

**Pendente de Vínculo**:
A situação de um usuário RELATOR que se cadastrou pela interface pública e ainda não foi
colocado em nenhum Grupo por um GERENTE. Ele consegue entrar no sistema, mas não alcança
Relatório algum.
_Avoid_: inativo, bloqueado, aguardando aprovação
