# 49 — Dimensionamento, backup e capacidade

Type: grilling
Status: open
Blocked by: —

## Question

De que tamanho é a infraestrutura, e como os dados sobrevivem a uma perda?

Graduou da névoa quando os cinco Produtos fecharam e passaram a existir números concretos: dez
Relatórios com volume, tempo estimado e forma de artefato conhecidos.

Decidir:

- **Heap da API.** O ticket 25 registrou que dimensioná-lo "vira exercício obrigatório, em função do
  maior `JasperPrint`". O ticket 42 identificou o maior — `CONTACORRENTE-0001`, ~300 mil linhas — e o
  ADR 0002 confirma que a exportação acontece **na mesma JVM**, sem isolamento. O número sai daqui.
- **O semáforo de exportação** (ticket 25): quantas exportações simultâneas cabem no heap escolhido, e
  qual a espera antes do `503`.
- **O pool de Coletas** (ticket 39): começou em 4 slots com base no orçamento de ~68 de
  `max_connections=100` do research 06. Calibrar contra os dez Relatórios reais.
- **Ocupação do repositório S3.** O ticket 41 deu o primeiro número: `CLIENTE-0001` é fotografia da
  base inteira, diária, e com retenção global de 7 dias (ticket 27) são **sete cópias**. Somar os dez
  Relatórios e decidir se 7 dias continua sendo a retenção certa para todos.
- **Crescimento indefinido de `download` e `auditoria_admin`** (ticket 27, decisão consciente). Estimar
  o volume e decidir se existe algum horizonte em que isso precise de resposta.
- **Backup e restore** do PostgreSQL (controle e cinco transacionais) e do repositório S3. Frequência,
  retenção, e — o que raramente se decide — **como o restore é testado**.
- **As VMs.** Quantas, com que tamanho, e o que roda em cada uma: Traefik, Keycloak, API, Airflow,
  PostgreSQL, repositório S3, stack de observabilidade. O ticket 11 registrou que o socket do Docker é
  o acoplamento perigoso entre Traefik e Airflow.

## Notas de tickets anteriores

- **Ticket 30**: o k6 fica **fora do gate** de CI porque **calibra** em vez de verificar. Este ticket é
  o consumidor desses números.
- **Ticket 40**: o teste de cursor roda com `-Xmx96m` de propósito — é prova de que a leitura
  transmite, **não** uma estimativa de heap de produção. Não confundir os dois números.
- **Ticket 29**: existe métrica de ocupação do bucket, de tamanho de artefato e de contagem de linhas
  por tabela. Todas foram pedidas para este momento.
- **Ticket 06**: o banco de metadados do Airflow é instância separada; o orçamento estimado é ~68 de
  `max_connections=100`.
