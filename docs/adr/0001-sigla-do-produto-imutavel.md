# A Sigla do Produto é um dado próprio e imutável, não uma derivação do Nome

Os exemplos da descrição inicial (`Conta Corrente` → `CONTACORRENTE`, `Poupança` → `POUPANCA`)
sugerem que a sigla usada no Código de Relatório e no caminho dos Artefatos seria derivada do
Nome do Produto por normalização. Decidimos o contrário: a **Sigla é um campo próprio do
Produto**, informada no cadastro (o sistema apenas sugere um valor a partir do Nome), única
entre Produtos e imutável para sempre; o **Nome do Produto passa a ser um rótulo puramente
apresentacional e livremente alterável**.

A derivação tem duas falhas que não se resolvem sem virar, na prática, um campo próprio: nomes
distintos colidem na normalização ("Conta Corrente" e "Contacorrente" produzem a mesma sigla, e
o regex `^[A-Z]{1,20}-\d{4}$` não impede), e renomear um Produto ou muda a sigla — órfãndo todo
o histórico, já que a sigla está em cada Código de Relatório e em cada caminho de Artefato — ou
deixa de refletir o Nome, caso em que ela nunca foi derivada, apenas congelada.

## Consequências

- Renomear um Produto vira operação segura e trivial. Era o cenário mais provável de quebra do
  histórico.
- A sigla deixa de ser função do Nome, então o Nome pode ter acentos, espaços, dígitos e mais de
  20 caracteres sem consequência alguma para identificadores.
- O cadastro de Produto ganha um campo a mais, com validação de unicidade e de formato
  (`^[A-Z]{1,20}$`), e uma decisão a mais para quem cadastra.
- Um Produto cadastrado com a sigla errada exige migração de dados para corrigir — a
  imutabilidade é real, não uma convenção.
