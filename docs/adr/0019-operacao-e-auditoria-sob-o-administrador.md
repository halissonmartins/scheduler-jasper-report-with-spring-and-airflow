# Operação e Auditoria são funções do ADMINISTRADOR, não tipos de usuário

Os tipos de usuário continuam sendo três: ADMINISTRADOR, GERENTE e RELATOR. "Operação" e "Auditoria" são funções organizacionais, não papéis do realm — quem as exerce no sistema entra como **ADMINISTRADOR**. Concretamente: a consulta de Execuções de Coleta e a consulta da trilha de `auditoria_geracao` são restritas ao ADMINISTRADOR, e GERENTE e RELATOR recebem 403 em ambas.

O acesso operacional que não passa pela aplicação — Airflow, Grafana, Jaeger, Prometheus, Compose — continua sem identidade de aplicação: a fronteira ali é a rede interna (ADR-0009, ADR-0017), não o Keycloak.

Registrado porque o spec descreve vinte histórias sob as personas "Operação" e "Auditoria" e um leitor futuro procuraria os tipos de usuário correspondentes sem encontrá-los. A ausência é deliberada.

## Considered Options

- **Role AUDITOR somente-leitura** — recomendada e recusada. A trilha registra qual Relator baixou o quê e quando: é dado comportamental sobre pessoas, sobrevive anos (ADR-0003) enquanto o resto expira em dias (ADR-0008), e uma role de leitura pura seria barata de impor e de provar em cenário. Recusada em favor de manter três tipos de usuário.
- **Role OPERADOR** — recusada, e sem controvérsia: as histórias de Operação são majoritariamente propriedades do sistema ou acesso a ferramenta interna. O que sobra na aplicação é a consulta de Execuções, cujo conteúdo — runId, código, datas, status, contagem — não tem peso pessoal.

## Consequências (riscos aceitos)

- **Não há separação de funções entre administrar e auditar.** Quem cadastra Produtos, Relatórios e usuários privilegiados é a mesma identidade que lê a trilha de acessos. Uma auditoria interna que queira revisar o comportamento da própria administração não tem, no sistema, um assento distinto de onde olhar.
- **O dado mais duradouro do sistema ganha o leitor mais poderoso.** `auditoria_geracao` é a única tabela que sobrevive anos e descreve o comportamento de pessoas; sob o ADR-0016 ela não tem classificação nem mascaramento, e agora tem como leitor o tipo de usuário com mais capacidade.
- Conceder acesso de auditoria a alguém passa a significar conceder ADMINISTRADOR — ou seja, dar também CRUD de Cadastros e gestão de usuários. Não existe concessão parcial.
- Vale notar que o quebra-molas perdido era pequeno: o ADMINISTRADOR concede roles e poderia conceder AUDITOR a si mesmo de qualquer forma. A diferença é que a autoconcessão apareceria nos admin events do Keycloak, enquanto o acesso direto não deixa evento nenhum.
- Se um requisito de auditoria externa aparecer depois, o caminho de volta é conhecido e barato — a role é somente-leitura sobre uma tabela que já existe. Reabrir este ADR é a forma de fazê-lo.
