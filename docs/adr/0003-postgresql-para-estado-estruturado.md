# PostgreSQL para todo o estado estruturado e para o JobRepository

O PostgreSQL guarda os Cadastros (produtos, relatórios, roles de relatório e seus vínculos), os metadados de Execução de Coleta, a trilha de auditoria e o `JobRepository` do Spring Batch (implementação JDBC). O MongoDB guarda exclusivamente as linhas coletadas sob TTL.

O motivo não é técnico-obrigatório: verificamos que o Spring Batch 6 oferece um `JobRepository` para MongoDB (`@EnableMongoJobRepository`), portanto um banco relacional não é imposto pelo framework. A escolha se justifica porque `produto ↔ relatório ↔ role de relatório ↔ usuário` é uma teia de relações N:N que quer integridade referencial, e porque a auditoria precisa sobreviver por anos — perfil de retenção e backup oposto ao das coleções com TTL.

## Consequências

- Todo container de processador precisa de credenciais do PostgreSQL além do MongoDB e do seu banco de origem.
- A divisão fica explícita: permanente e relacional no PostgreSQL, efêmero e sem esquema no MongoDB.
