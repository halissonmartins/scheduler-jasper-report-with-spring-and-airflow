# Código do Relatório: formato estrito, imutável e não reutilizável

O Código do Relatório valida contra `^[A-Z]{2,20}-\d{4}$`; o nome precisa corresponder a um Produto já cadastrado (chave estrangeira, não texto livre); o número vai de 0001 a 9999, sendo 0000 inválido. O Código é imutável após a criação e **nunca é reaproveitado**, mesmo depois da exclusão do Relatório.

A imutabilidade e a proibição de reuso são o motivo do registro: a auditoria de downloads e os dados no MongoDB referenciam o Código. Se um Código pudesse ser reaproveitado, um registro de auditoria antigo passaria a apontar para um Relatório diferente daquele que ele de fato registrou — a trilha mentiria sem que nada aparentasse estar errado.

## Consequências

- Teto permanente de 9999 Relatórios por Produto.
- O nome não pode conter hífen, porque o hífen é o separador (daí `CONTACORRENTE`, não `CONTA-CORRENTE`).
- Cadastrar Produto passa a ser pré-requisito de cadastrar Relatório; a hierarquia de armazenamento (Data de Referência → Produto → Código) nunca contém Produto inexistente.
- Códigos excluídos ficam queimados para sempre; a numeração tem lacunas, e isso é correto.
