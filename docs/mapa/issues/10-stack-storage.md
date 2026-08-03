# 10 — Stack: storage (MinIO, lifecycle, credenciais)

Type: research
Status: resolved
Blocked by: —

## Question

Como o MinIO é configurado, e quem executa o expurgo?

Levantar com fontes primárias (use context7) e recomendar:

- **MinIO**: versão, mudanças recentes de licença e de console, e o cliente Java (SDK MinIO vs AWS SDK v2 apontado para o endpoint S3).
- **Expurgo**: o documento pede uma variável de ambiente (padrão 7 dias) para apagar automaticamente. Isso é **lifecycle policy nativa** do bucket ou um job da aplicação? A análise comportamental prefere o lifecycle por confiabilidade, mas a variável de ambiente sugere aplicação. Levantar como configurar lifecycle por prefixo e se ele consegue expirar `.jrprint` e `.csv.gz` **juntos**.
- **Credenciais separadas**: política que dá `PutObject` aos processadores e apenas `GetObject` à API — base do ticket 18. Levantar a sintaxe de policy do MinIO.
- **Versionamento de bucket**: ajuda ou atrapalha o `forcar_reprocessamento` (ticket 20)? Interage com a retenção.
- **Integridade**: ETag/checksum nativo vs hash gravado nos metadados, para a verificação exigida no ticket 18.
- **Layout de bucket**: um bucket para tudo, um por produto, ou um por ambiente.

Registrar as descobertas em `docs/mapa/research/10-storage.md`.

## Answer

Research completo em [`../research/10-storage.md`](../research/10-storage.md).

- **O MinIO da stack original acabou.** O repositório `minio/minio` foi arquivado em 25/04/2026, o README declara "THIS REPOSITORY IS NO LONGER MAINTAINED", não há mais binários pré-compilados e o último release (`RELEASE.2025-10-15T17-29-55Z`) corrigia justamente um bypass de session policy de service account. O Console perdeu toda a administração em maio/2025 — usuários, policies e lifecycle só por `mc`.
- **Servidor**: congelar o último binário AGPL em dev/CI; em produção usar **AIStor Free** (nó único, produção permitida, gratuito, mas com chave via SUBNET e EULA proprietária). Tratar "MinIO" como implementação e falar S3 puro atrás de uma porta.
- **Cliente**: **AWS SDK v2** com `endpointOverride` + `pathStyleAccessEnabled(true)` e configuração *explícita* de checksum — desde a 2.30.0 o SDK manda CRC32 por padrão e isso já quebrou contra MinIO (issue #20845, corrigida no AIStor).
- **Expurgo**: **lifecycle nativo**, nunca job da aplicação. O motivo decisivo não é confiabilidade e sim segurança: com lifecycle, **nenhuma credencial de cliente precisa de `s3:DeleteObject`** — pré-requisito do ticket 18. A variável de 7 dias vira o `--expire-days` de uma regra aplicada no bootstrap.
- **`.jrprint` + `.csv.gz` juntos**: uma regra de filtro vazio cobre os dois (lifecycle filtra por prefixo, nunca por extensão); mesma data de criação ⇒ mesma expiração (criação + N dias arredondado para a meia-noite UTC seguinte). A remoção física é assíncrona e **não atômica** — a API deve tratar "um dos dois ausente" como expirado.
- **Versionamento: desligado.** Transforma a retenção de 1 em 3 parâmetros, cria o bug "expirado que não sumiu", duplica storage e não acrescenta nada ao registro de `forcar_reprocessamento` que o schema de controle já faz.
- **Integridade**: ETag descartado (não é MD5 garantido e é composto em multipart). Usar **SHA-256 calculado pelo processador e gravado no schema de controle**, conferido antes de desserializar.
- **Layout**: um bucket por ambiente, prefixo por data/produto/relatório. **Alerta ao ticket 03**: filtro de lifecycle é prefixo literal sem wildcard — retenção diferenciada por produto exigiria o produto **antes** da data no path.
