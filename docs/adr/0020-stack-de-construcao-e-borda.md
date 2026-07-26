# Stack de construção e borda

Decisões que faltavam para o projeto ser construível. Nenhuma delas é controversa isoladamente; estavam ausentes, não recusadas.

| Peça | Escolha |
|---|---|
| Migração de esquema (PostgreSQL) | **Flyway**, SQL versionado; o DDL oficial do Spring Batch entra como primeira migration; JPA com `ddl-auto=validate` |
| Acesso a dados (PostgreSQL) | **Spring Data JPA** |
| Ingress e TLS | **Traefik**, descoberta por labels do Compose, ACME/Let's Encrypt |
| E-mail | **Mailpit** em todos os ambientes (ver consequências) |
| CI | **GitHub Actions** em runners hospedados x86 |
| Contrato e cliente | **springdoc-openapi** produz o OpenAPI; **openapi-generator** (`typescript-angular`) gera o cliente |
| Sistemas de origem | **PostgreSQL** em todos os Produtos, somente leitura |
| Versões de infra | Tag `maior.menor` explícita por imagem, em variável do `.env` |
| Proteção contra bots | **reCAPTCHA** do Keycloak, chaves no `.env`, desligado em dev e teste |
| Log estruturado | Structured logging nativo do Spring Boot, sem encoder de terceiro (ADR-0017) |

## Consequências

- **Produção não tem autocadastro nem recuperação de senha enquanto o Mailpit for o destino final.** Mailpit captura e exibe o e-mail, não o entrega. Como o RELATOR só existe por autocadastro e o ADR-0010 exige verificação de e-mail antes de a conta ser utilizável, nenhum Relator consegue ativar conta em produção, e a história 7 (senha esquecida) não funciona. Decidido conscientemente: o sistema fica utilizável por usuários criados administrativamente até que um relay real seja configurado. Trocar o Mailpit por um relay é mudança de variável de ambiente, não de código.
- **Isso revoga na prática uma contrapartida que o ADR-0010 chamou de obrigatória.** A verificação de e-mail continua ligada no realm; o que falta é a entrega. A rotina de limpeza de contas nunca liberadas passa a ter mais importância, não menos.
- Traefik concentra o timeout de leitura do ADR-0004: é lá que o pior caso de Geração precisa caber, e é a configuração cujo erro produz download truncado em vez de página de erro.
- CI em x86 e produção em ARM64: as imagens usadas são multi-arch, mas nenhuma suíte roda na arquitetura de produção. Bug específico de arquitetura só aparece na VM.
- Flyway passa a ser o dono do esquema — inclusive das tabelas do Spring Batch. Atualizar a versão do Spring Batch exige revisar o DDL dele como migration, não confiar em criação automática.
- `PostgreSQL` como origem única simplifica hoje e esconde a promessa do ADR-0011 de isolar a mecânica: só um segundo vendor provaria que o starter realmente não vaza detalhe de origem.
- reCAPTCHA desligado em dev e teste significa que o caminho de cadastro exercitado pelo E2E não é exatamente o de produção.
