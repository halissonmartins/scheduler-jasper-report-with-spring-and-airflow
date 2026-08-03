# Research 10 — Storage: MinIO, lifecycle, credenciais

Ticket: [`../issues/10-stack-storage.md`](../issues/10-stack-storage.md)
Data da pesquisa: 2026-08-02
Método: fontes primárias (repositórios oficiais, documentação oficial, especificação S3 da AWS) via MCP context7 e fetch direto. Toda afirmação abaixo tem link para a fonte que a sustenta.

> **Achado que muda a premissa do ticket.** O ticket pergunta "qual versão do MinIO usar". A resposta de 2026 é que o MinIO da tech stack original **não existe mais como produto open source mantido**: o repositório foi arquivado em 25/04/2026 e a edição comunitária deixou de publicar binários. Isso não invalida a decisão de usar um repositório S3 — invalida a decisão de tratar "MinIO" como um item de stack sem alternativa. Ver seção 1 e a Recomendação.

---

## 1. MinIO: versão, licença e console

### 1.1 O repositório está arquivado

- O repositório `minio/minio` **foi arquivado pelo dono em 25/04/2026 e está read-only**. A API do GitHub retorna `archived: true`, `pushed_at: 2026-04-24T17:54:39Z`, licença `AGPL-3.0`. — [github.com/minio/minio](https://github.com/minio/minio) · [api.github.com/repos/minio/minio](https://api.github.com/repos/minio/minio)
- O README abre com o aviso, textual: **"THIS REPOSITORY IS NO LONGER MAINTAINED."**, e aponta duas alternativas: **AIStor Free** ("Full-featured, standalone edition for community use (free license)") e **AIStor Enterprise**. — [README.md](https://raw.githubusercontent.com/minio/minio/master/README.md)
- O mesmo README declara que **a edição comunitária passou a ser distribuída apenas como código-fonte**: *"We will no longer provide pre-compiled binary releases for the community version."* O caminho restante é `go install github.com/minio/minio@latest` ou construir a própria imagem Docker. — [README.md](https://raw.githubusercontent.com/minio/minio/master/README.md)
- O README também alerta que *"all usage of MinIO in your application stack requires validation against AGPLv3 obligations, which include but are not limited to the release of modified code"*. — [README.md](https://raw.githubusercontent.com/minio/minio/master/README.md)

### 1.2 Última versão binária publicada

- O release mais recente é **`RELEASE.2025-10-15T17-29-55Z`**, publicado em 16/10/2025, rotulado *"Security/CVE"*: corrige uma escalação de privilégio em que era possível **contornar as session policies de service accounts e do STS** — exatamente o mecanismo em que o ticket 18 pretende apoiar a separação de credenciais. Antecessores: `RELEASE.2025-09-07T16-13-09Z` e `RELEASE.2025-07-23T15-54-02Z`. — [releases](https://api.github.com/repos/minio/minio/releases?per_page=5)
- Consequência direta: **congelar nessa versão significa aceitar que a próxima CVE de IAM não terá correção upstream**. É um risco de segurança, não de conveniência, e bate de frente com o objetivo do ticket 18.

### 1.3 Mudança de licença e do Console

- A licença do servidor é **AGPLv3** (campo `license` da API do GitHub e o próprio README). — [api.github.com/repos/minio/minio](https://api.github.com/repos/minio/minio)
- **Remoção das funções administrativas do Console (maio/2025).** A discussão oficial no repositório documenta o salto de `20250422221226.0.0` para `20250524170830.0.0` em que "todas as funções de admin sumiram" mesmo logado como `minioadmin`; a thread foi fechada e trancada **sem resposta de mantenedor**, e a causa apontada pela comunidade é a mudança de licença/escopo do browser (PR no repositório `object-browser`). — [minio/minio#21316](https://github.com/minio/minio/discussions/21316)
- O README atual descreve o que restou: *"an embedded web-based object browser built into MinIO Server"*, para criar bucket, subir e navegar objetos — sem gestão de usuários, policies ou lifecycle. Porta configurável via `--console-address`. — [README.md](https://raw.githubusercontent.com/minio/minio/master/README.md)
- Existe um fork comunitário do console, **`OpenMaxIO/openmaxio-object-browser`** (AGPL-3.0, ~1.959 estrelas, último push em 24/06/2025), criado para restaurar a UI administrativa. — [api.github.com/repos/OpenMaxIO/openmaxio-object-browser](https://api.github.com/repos/OpenMaxIO/openmaxio-object-browser)
- **Implicação operacional para este projeto**: qualquer coisa administrativa (criar usuário, criar policy, aplicar lifecycle) **tem de ser feita por `mc` ou por SDK**, nunca pela UI. Isso na verdade é bom — vira infraestrutura como código no `docker-compose` em vez de clique manual.

### 1.4 AIStor Free — os termos reais

- **Topologia permitida: apenas standalone / nó único.** A licença concede uso *"solely in standalone mode (single-node deployments without distributed clustering or high availability)"*. — [MinIO AIStor Free Tier License Agreement](https://www.min.io/legal/aistor-free-agreement)
- **Produção é permitida**: o acordo cita explicitamente *"commercial production workloads, prototyping, personal projects, homelabs, research, education, backups, or media repositories"*, desde que em standalone. — [acordo AIStor Free](https://www.min.io/legal/aistor-free-agreement)
- **Sem custo, sem garantia, sem SLA** ("AS IS", "NO WARRANTY"). Última atualização do texto: 30/01/2026. — [acordo AIStor Free](https://www.min.io/legal/aistor-free-agreement)
- **Proibida a redistribuição**: *"may not distribute, sublicense, rent, lease, resell, or redistribute the Software (in whole or in part) to any third party"*. Isso impede embutir o binário em uma imagem própria publicada, mas não impede referenciar a imagem oficial no `docker-compose`. — [acordo AIStor Free](https://www.min.io/legal/aistor-free-agreement)
- **Exige chave de licença**, obtida no SUBNET e aplicada com `mc license register` / `mc license update`, com renovação automática a cada 24h. Ou seja: **uma dependência de rede externa e de conta** no bootstrap do ambiente. — [docs.min.io — Licenses](https://docs.min.io/aistor/operations/licenses/)

> Como este projeto roda **Docker Compose em VMs** (regra arquitetural de `descricao-inicial.md`), a restrição de nó único do AIStor Free **não é impeditiva**. A dependência de chave/SUBNET é o custo real.

---

## 2. Cliente Java: SDK do MinIO × AWS SDK v2

### 2.1 SDK do MinIO para Java (`io.minio:minio`)

- **Está vivo, ao contrário do servidor.** `minio/minio-java` **não está arquivado**, licença **Apache-2.0**, último push em 18/06/2026. — [api.github.com/repos/minio/minio-java](https://api.github.com/repos/minio/minio-java)
- Versão atual **9.0.3** (12/06/2026, "Security and bug fix release"); 9.0.2 em 10/06/2026; 9.0.1 em 19/05/2026. — [releases](https://api.github.com/repos/minio/minio-java/releases?per_page=3)
- **A 9.0.0 (20/03/2026) é um refactor total**: "Refactor entire code for v9.0.0" e "Sync APIs with S3 specification", marcada como Major Release, sem guia de migração detalhado no corpo do release. — [release 9.0.0](https://api.github.com/repos/minio/minio-java/releases/tags/9.0.0)
- Requisito mínimo: **Java 1.8 ou superior**; dependência Maven publicada como `9.0.3`. — [README](https://raw.githubusercontent.com/minio/minio-java/master/README.md)
- API relevante para nós: `MinioClient.builder().endpoint(...).credentials(...)`, `putObject`, `getObject`, `getPresignedObjectUrl` (com `expiration(long, TimeUnit)`) e `setBucketLifecycle`. — [minio-java — API reference](https://github.com/minio/minio-java/blob/master/_autodocs/api-reference/minio-client.md) · [docs/API.md](https://github.com/minio/minio-java/blob/master/docs/API.md)

### 2.2 AWS SDK v2 apontado para o endpoint S3

- Configuração canônica para endpoint não-AWS, tirada do próprio código de teste do SDK (o comentário no teste cita explicitamente MinIO/mock):

  ```java
  S3Client.builder()
      .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(ak, sk)))
      .region(Region.US_EAST_1)
      .endpointOverride(URI.create("http://minio:9000"))
      .serviceConfiguration(c -> c.pathStyleAccessEnabled(true))
      .build();
  ```
  — [AclTest.java](https://github.com/aws/aws-sdk-java-v2/blob/master/services/s3/src/test/java/software/amazon/awssdk/services/s3/AclTest.java) · [EndpointOverrideEndpointResolutionTest.java](https://github.com/aws/aws-sdk-java-v2/blob/master/services/s3/src/test/java/software/amazon/awssdk/services/s3/EndpointOverrideEndpointResolutionTest.java)
- `pathStyleAccessEnabled` **é `false` por padrão** (virtual-hosted-style), e precisa ser ligado explicitamente para endpoints por host/porta. — [S3Configuration.java](https://github.com/aws/aws-sdk-java-v2/blob/master/services/s3/src/main/java/software/amazon/awssdk/services/s3/S3Configuration.java)

### 2.3 A armadilha de interoperabilidade: checksums a partir do SDK 2.30.0

Esta é a diferença prática mais importante entre os dois clientes e **precisa entrar na spec**:

- A partir da **versão 2.30.0** do AWS SDK for Java 2.x, o SDK **calcula um checksum CRC32 automaticamente em todo upload** quando nenhum checksum ou algoritmo é informado. — [Data integrity protection with checksums](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/s3-checksums.html)
- O padrão resolvido no código é `RequestChecksumCalculation.WHEN_SUPPORTED`, com cadeia de resolução: system property `aws.requestChecksumCalculation` → env `AWS_REQUEST_CHECKSUM_CALCULATION` → perfil `request_checksum_calculation` → default. — [RequestChecksumCalculationResolver.java](https://github.com/aws/aws-sdk-java-v2/blob/master/core/sdk-core/src/main/java/software/amazon/awssdk/core/checksums/RequestChecksumCalculationResolver.java)
- Junto com essa mudança, **o SDK parou de calcular MD5** nas operações que o exigiam. O resultado contra MinIO foi quebra concreta: `deleteObjects()` falha com *"Missing required header for this request: Content-Md5."* — o mesmo código funciona contra a AWS S3 e o LocalStack. — [minio/minio#20845](https://github.com/minio/minio/issues/20845)
- A issue do MinIO recebeu os rótulos **`fixed` e `fixed-in-aistor`** (PR #20855). Ou seja: **a correção está garantida no AIStor; na edição comunitária arquivada, depende da versão congelada**. — [minio/minio#20845](https://github.com/minio/minio/issues/20845)
- Mitigações oficiais da AWS, ambas aplicáveis a "third-party S3-compatible storage providers" nas palavras da própria documentação:
  - `requestChecksumCalculation(WHEN_REQUIRED)` + `responseChecksumValidation(WHEN_REQUIRED)`;
  - o plugin **`LegacyMd5Plugin`**, lançado no SDK **2.31.32**, que restaura o MD5 nas operações que o exigem.
  — [Data integrity protection with checksums](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/s3-checksums.html) · [LegacyMd5Plugin.java](https://github.com/aws/aws-sdk-java-v2/blob/master/services/s3/src/main/java/software/amazon/awssdk/services/s3/LegacyMd5Plugin.java)

### 2.4 Trade-off

| Critério | SDK MinIO (`io.minio:minio` 9.0.3) | AWS SDK v2 (`s3`) |
|---|---|---|
| Licença | Apache-2.0 ([fonte](https://api.github.com/repos/minio/minio-java)) | Apache-2.0 |
| Manutenção | Ativa (push 18/06/2026) | Ativa |
| Acoplamento ao fornecedor | Alto — o cliente é do MinIO | Nenhum — qualquer S3 |
| Interop de checksum | Alinhado por construção com o servidor MinIO | Exige configuração explícita (§2.3) |
| Estabilidade da API | **9.0.0 foi refactor total em 03/2026** ([fonte](https://api.github.com/repos/minio/minio-java/releases/tags/9.0.0)) | Estável desde 2018 |
| Superfície/peso | Pequeno, focado | Grande, modular |
| Presigned URL | `getPresignedObjectUrl` ([fonte](https://github.com/minio/minio-java/blob/master/_autodocs/api-reference/minio-client.md)) | `S3Presigner` |

**Critério de decisão:** se existe qualquer probabilidade de trocar o servidor de objetos (e a seção 1 mostra que existe), o AWS SDK v2 é a única escolha que sobrevive à troca. Se o MinIO/AIStor fosse permanente, o SDK MinIO seria mais simples.

---

## 3. Expurgo: lifecycle nativo do bucket × job da aplicação

### 3.1 Como se configura lifecycle por prefixo

- Via CLI, uma regra por prefixo, com dias de expiração:
  ```shell
  mc ilm rule add --prefix "doc/" --expire-days "300" --noncurrent-expire-days "100" myminio/mybucket
  ```
  — [mc ilm rule add](https://github.com/minio/docs/blob/main/source/reference/minio-mc/mc-ilm-rule-add.rst)
- Via SDK Java do MinIO, com `RuleFilter(prefix)` + `Expiration(null, days, null)`:
  ```java
  rules.add(new LifecycleRule(Status.ENABLED, null,
      new Expiration((ZonedDateTime) null, 365, null),
      new RuleFilter("logs/"), "rule2", null, null, null));
  minioClient.setBucketLifecycle(SetBucketLifecycleArgs.builder().bucket(b).config(config).build());
  ```
  — [minio-java docs/API.md](https://github.com/minio/minio-java/blob/master/docs/API.md)
- `PutBucketLifecycleConfiguration` / `GetBucketLifecycleConfiguration` / `DeleteBucketLifecycle` são suportados pelo MinIO. — [s3-api-compatibility.rst](https://raw.githubusercontent.com/minio/docs/main/source/reference/s3-api-compatibility.rst)

### 3.2 Semântica do filtro (isto responde "`.jrprint` e `.csv.gz` expiram juntos?")

Da especificação S3, que o MinIO segue:

- Cada bucket tem **uma única configuração de lifecycle**, com **até 1.000 regras**; o limite não é ajustável. — [Lifecycle configuration elements](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- **Um filtro pode ter no máximo um prefixo** e zero ou mais tags; para prefixos diferentes, *"specify separate rules"*. — [idem](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- Um **filtro vazio aplica a regra a todos os objetos do bucket**. — [idem](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- O filtro casa por **prefixo de chave**, não por extensão. `logs/` pega `logs/mylog.txt`, `logs/temp1.txt` e `logs/test.txt`. — [idem](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)

**Conclusão:** como o layout do ticket 03 coloca `.jrprint` e `.csv.gz` **na mesma "pasta"** (`yyyy-MM-dd/produto/codigo/...`), **uma única regra cobre os dois** — não é preciso (nem é possível) filtrar por extensão. Não existe filtro por sufixo em lifecycle S3.

### 3.3 Quando o objeto some, de fato

- A data é calculada como **data de criação + N dias, arredondada para cima até a próxima meia-noite UTC**. Exemplo da própria AWS: objeto criado em 15/01 às 10h30 UTC com regra de 3 dias expira em 19/01 00:00 UTC. — [Lifecycle rules: Based on an object's age](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- No MinIO, a remoção **depende do scanner**, que roda como *"lower priority continuous process where READ and WRITE actions are preferred"*, e portanto *"object versions that meet the requirements for expiration **may not immediately be removed** from MinIO"*. — [object-delete.rst](https://github.com/minio/docs/blob/main/source/administration/object-management/object-delete.rst)
- O paralelismo é ajustável por `MINIO_ILM_EXPIRATION_WORKERS` (1 a 500, default 100, introduzido em `RELEASE.2024-03-03T17-50-39Z`). — [settings/ilm.rst](https://github.com/minio/docs/blob/main/source/reference/minio-server/settings/ilm.rst)

**Implicação para o ticket 27:** a data de expurgo é **determinística e previsível** (meia-noite UTC seguinte), mas a **remoção física é assíncrona e pode atrasar**. Logo:
1. A UI **pode** calcular/exibir "expirado" a partir da data — e vai acertar antes do objeto sumir de verdade (falso-positivo benigno).
2. A API **não pode** tratar "objeto presente" como "não expirado". A fonte da verdade da expiração é o metadado, não o bucket.
3. Como `.jrprint` e `.csv.gz` são escritos na mesma execução, têm a mesma data de criação e portanto **a mesma data de expiração arredondada**. A remoção física dos dois, porém, **não é atômica**: pode haver janela em que um existe e o outro não. A API precisa tratar "um dos dois ausente" como *expirado*, nunca como erro genérico.

### 3.4 Lifecycle nativo × job da aplicação

| | Lifecycle nativo | Job da aplicação |
|---|---|---|
| Quem apaga | O próprio servidor de objetos, via scanner ([fonte](https://github.com/minio/docs/blob/main/source/administration/object-management/object-delete.rst)) | A API ou um módulo batch |
| Credencial necessária | **Nenhum cliente precisa de `s3:DeleteObject`** | Alguém precisa de `s3:DeleteObject` no bucket |
| Roda com a aplicação parada? | Sim | Não |
| Precisão temporal | Meia-noite UTC + atraso do scanner | Controlada pela aplicação |
| Retenção diferenciada por produto | Uma regra por prefixo (até 1.000) | Lógica arbitrária |
| Onde a variável de ambiente atua | No **bootstrap**, aplicando a regra | Em tempo de execução, a cada varredura |

**O argumento decisivo é de segurança, e é o mesmo do ticket 18:** com lifecycle nativo, **nenhuma credencial de cliente precisa de permissão de exclusão**. Os processadores ficam com `PutObject` apenas, a API com `GetObject` apenas, e mesmo assim os dados expiram. Um job de aplicação obriga a existir, em algum lugar, uma credencial capaz de apagar artefatos — que é exatamente a superfície que o ticket 18 quer eliminar.

A variável de ambiente do documento original (`padrão 7 dias`) continua existindo e continua sendo a fonte da configuração: ela é o **parâmetro do `--expire-days`** aplicado no bootstrap, não o intervalo de um job.

**Limitação registrada:** o MinIO **não suporta a ação `AbortIncompleteMultipartUpload` via `PutBucketLifecycle`**. Uploads multipart abortados não são limpos por lifecycle. — [s3-api-compatibility.rst](https://raw.githubusercontent.com/minio/docs/main/source/reference/s3-api-compatibility.rst)

---

## 4. Credenciais separadas: a policy que o ticket 18 precisa

### 4.1 Sintaxe

O MinIO usa **um subconjunto do IAM**, com `"Version": "2012-10-17"`, `Effect`/`Action`/`Resource` e ARNs `arn:aws:s3:::bucket` e `arn:aws:s3:::bucket/prefixo/*`; suporta variáveis de policy (`${aws:username}`, `${jwt:preferred_username}`) e a condição `s3:prefix` em `ListBucket`. — [policy-based-access-control.rst](https://github.com/minio/docs/blob/main/source/administration/identity-access-management/policy-based-access-control.rst)

Ações relevantes confirmadas como suportadas: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` (mapeia para `ListObjectsV2`), `s3:GetBucketLocation`, `s3:ListAllMyBuckets`, `s3:GetObjectAttributes`, `s3:GetObjectVersionAttributes`, `s3:ListBucketMultipartUploads`. — [policy-based-access-control.rst](https://github.com/minio/docs/blob/main/source/administration/identity-access-management/policy-based-access-control.rst)

Ciclo de vida operacional (tudo por CLI, já que o Console perdeu essas telas — §1.3):
```bash
mc admin policy create  myminio processador-escrita /policies/processador.json
mc admin user   add     myminio processador  <senha>
mc admin policy attach  myminio processador-escrita --user processador
```
— [policy-based-access-control (exemplos mc)](https://context7.com/minio/docs/llms.txt)

### 4.2 Policy dos processadores (escrita)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EscritaDeArtefatos",
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": ["arn:aws:s3:::relatorios/*"]
    }
  ]
}
```

Notas apoiadas em fonte:
- **Não incluir `s3:DeleteObject`.** Com lifecycle nativo (§3.4) o expurgo não passa por credencial de cliente.
- **Não incluir `s3:GetObject`.** O processador escreve e registra o hash; não precisa reler.
- Se o artefato for grande a ponto de usar **multipart**, o MinIO suporta `CreateMultipartUpload`, `UploadPart`, `CompleteMultipartUpload`, `AbortMultipartUpload`, `ListParts` — e documenta que **`ListMultipartUploads` exige o nome exato do objeto como prefixo**. — [s3-api-compatibility.rst](https://raw.githubusercontent.com/minio/docs/main/source/reference/s3-api-compatibility.rst). Se o cliente escolhido acionar multipart, valide em teste de integração se `s3:PutObject` sozinho basta; caso contrário acrescente `s3:AbortMultipartUpload` e `s3:ListBucketMultipartUploads` — e **só isso**, nunca `s3:*`.
  *(Ponto a confirmar empiricamente — ver seção 9.)*

### 4.3 Policy da API REST (leitura)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LeituraDeArtefatos",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectAttributes"],
      "Resource": ["arn:aws:s3:::relatorios/*"]
    }
  ]
}
```

- **Sem `s3:ListBucket` de propósito.** A listagem de relatórios disponíveis (o drop-down por data → produto → código) sai do **schema de controle**, não do bucket — é o que a regra arquitetural já determina. Não conceder `ListBucket` transforma o bucket em *lookup* por chave conhecida: quem obtiver a credencial da API não consegue enumerar o acervo.
- `s3:GetObjectAttributes` é opcional; entra se a verificação de integridade do ticket 18 quiser ler checksum/tamanho sem baixar o objeto (§6).
- **Sem `s3:PutObject`.** É essa ausência que sustenta a mitigação do ticket 18: mesmo com RCE hipotético na API, ela não consegue plantar um `.jrprint` malicioso no bucket.

### 4.4 O que essa separação *não* resolve

A separação impede que a **API** escreva. Ela **não** impede que um processador comprometido escreva um `.jrprint` malicioso que a API depois desserialize — os processadores têm `PutObject` por definição. Por isso a separação de credenciais é **necessária mas não suficiente**, e o hash conferido (§6) + `ObjectInputFilter` continuam obrigatórios no ticket 18.

Registre-se também que a última CVE corrigida no MinIO comunitário foi justamente **bypass de session policy em service accounts/STS** ([§1.2](#12-última-versão-binária-publicada)): a policy só vale o que valer a implementação do servidor que a aplica.

---

## 5. Versionamento de bucket × `forcar_reprocessamento` (ticket 20)

### 5.1 Fatos

- Habilita-se na criação: `mc mb --with-versioning ALIAS/BUCKET`. — [mc mb](https://github.com/minio/docs/blob/main/source/reference/minio-mc/mc-mb.rst)
- **Em bucket versionado, `Expiration` não apaga nada de imediato**: cria um `DeleteMarker` sobre a versão corrente. As versões antigas continuam ocupando espaço. — [object-lifecycle-management.rst](https://github.com/minio/docs/blob/main/source/administration/object-management/object-lifecycle-management.rst) · [tabela de ações × versionamento](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- Para realmente liberar espaço é preciso somar flags: `--noncurrent-expire-days` (versões não-correntes), `--expire-delete-marker` (MinIO *não* expira delete markers por padrão, mesmo quando são a única versão restante) e/ou `--expire-all-object-versions`. — [object-lifecycle-management.rst](https://github.com/minio/docs/blob/main/source/administration/object-management/object-lifecycle-management.rst)
- Os dias de uma versão não-corrente contam **a partir da criação da versão sucessora**, não da criação original. — [Lifecycle rules: Based on an object's age](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)

### 5.2 Análise

O documento decidiu que `forcar_reprocessamento` **sobrescreve os artefatos** no repositório. Com versionamento:

- **Atrapalha a retenção.** A regra de 7 dias passa a precisar de 3 parâmetros em vez de 1, e um erro de configuração faz o artefato "expirado" continuar existindo indefinidamente como versão não-corrente — o oposto exato da intenção do requisito. É o cenário mais provável de bug silencioso da seção inteira.
- **Não é necessário para auditoria.** O documento já exige que cada `forcar_reprocessamento` seja registrado com solicitante, motivo e Correlation ID — isso vive no **schema de controle**, que é a fonte da verdade do status. Versionamento guardaria o *binário* antigo, que ninguém pediu e que o próprio requisito de retenção manda destruir.
- **Duplica armazenamento** por padrão, o que é caro num acervo que já grava dois artefatos por execução (e possivelmente três, se o ticket 22 decidir por dois prints).
- **Não ajuda a idempotência** (ticket 20): a rejeição de reexecução de um par já processado é decidida no banco, antes de qualquer I/O no bucket.

O único cenário em que versionamento ajudaria é rollback de um reprocessamento equivocado dentro da janela de 7 dias — e mesmo esse é resolvido rodando a coleta de novo, já que os dados de origem continuam no schema transacional.

---

## 6. Integridade: ETag/checksum nativo × hash nos metadados

### 6.1 Por que o ETag não serve como hash de integridade

- A própria AWS descreve o ETag com ressalva condicional: *"for objects **where the ETag is the MD5 digest** of the object, you can calculate the MD5 while putting an object..."* — a redação admite que nem sempre é. — [PutObject API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html)
- Em **multipart**, os checksums retornados *"may not be a direct checksum value of the full object. Instead, it's a calculation based on the checksum values of each individual part"* — o valor depende do tamanho de parte usado pelo cliente, e portanto não é reproduzível por quem só tem os bytes. — [PutObject API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html) · [Checking object integrity](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html)
- Conclusão: **ETag é um identificador de opacidade, não um hash de conteúdo verificável.** Não pode ser o mecanismo do ticket 18.

### 6.2 Checksums adicionais do S3

- Algoritmos suportados pela S3: `CRC64NVME` (default), `CRC32`, `CRC32C`, `SHA1`, `SHA256`, `MD5`, `XXHASH*`, `SHA512`. — [Checking object integrity](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html)
- O `mc` do MinIO expõe `--checksum` com valores **`MD5`, `CRC32`, `CRC32C`, `SHA1`, `SHA256`**, e a documentação nota que *"the flag requires server trailing headers and works with AWS or MinIO targets"*. — [mc cp](https://github.com/minio/docs/blob/main/source/reference/minio-mc/mc-cp.rst) · [mc put](https://github.com/minio/docs/blob/main/source/reference/minio-mc/mc-put.rst)
- No AWS SDK v2, o `getObject` valida automaticamente quando `checksumMode(ChecksumMode.ENABLED)`, **mas** *"If the object wasn't uploaded with a checksum, no validation takes place"* — falha silenciosa se o upload não gravou checksum. — [Data integrity protection with checksums](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/s3-checksums.html)
- O MinIO suporta `GetObjectAttributes`, que permite ler checksum/tamanho sem baixar o objeto. — [s3-api-compatibility.rst](https://raw.githubusercontent.com/minio/docs/main/source/reference/s3-api-compatibility.rst)

### 6.3 Trade-off para o ticket 18

| Opção | A favor | Contra |
|---|---|---|
| **A. ETag** | Zero código | Não é MD5 garantido; quebra em multipart; não verificável |
| **B. Checksum nativo S3 (`x-amz-checksum-sha256`)** | Servidor valida na escrita; API valida na leitura | Depende de suporte do servidor (§2.3 mostra que já quebrou); ainda é composto em multipart; validação silenciosamente ausente se o upload não gravou |
| **C. SHA-256 calculado pela aplicação e gravado no schema de controle** | **Independe do servidor de objetos**; a verificação é da aplicação contra a aplicação; é a mesma fonte da verdade do status; sobrevive a troca de MinIO por qualquer outro S3 | Custo de uma passada de hash sobre os bytes; exige o hash antes do upload |

**Critério:** o ticket 18 quer garantir que os bytes desserializados são os que o processador escreveu. Só a opção **C** dá essa garantia ponta a ponta, porque o elo de confiança não passa pelo bucket. **B** é bom como defesa em profundidade (detecta corrupção de transporte/disco cedo), e é barato ligar junto. **A** deve ser descartada explicitamente na spec, para ninguém "otimizar" para ela depois.

---

## 7. Layout de bucket

### 7.1 Fatos

- **O MinIO não limita o número de buckets**, mas *"recommends no more than 500,000 buckets per deployment"*. — [mc mb — Bucket Limits Per Deployment](https://github.com/minio/docs/blob/main/source/reference/minio-mc/mc-mb.rst)
- **Lifecycle é por bucket**: uma configuração por bucket, até 1.000 regras. — [Lifecycle configuration elements](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- **Policies operam por prefixo dentro do bucket** (`arn:aws:s3:::bucket/prefixo/*`), então segregação por prefixo já dá granularidade de permissão. — [policy-based-access-control.rst](https://github.com/minio/docs/blob/main/source/administration/identity-access-management/policy-based-access-control.rst)
- As **métricas v2 por bucket têm limite de 100 buckets** por questão de performance; acima disso é preciso usar métricas v3. — [metrics-v2.rst](https://github.com/minio/docs/blob/main/source/operations/monitoring/metrics-v2.rst) *(cruza com o ticket 29 — cardinalidade)*

### 7.2 Opções

| Opção | A favor | Contra |
|---|---|---|
| **Um bucket por ambiente** (`relatorios` em cada VM/ambiente) | 1 regra de lifecycle serve tudo; 2 policies servem tudo; sem risco de esquecer regra ao cadastrar produto novo | Sem isolamento de blast radius entre produtos |
| **Um bucket por produto** (`relatorios-poupanca`, ...) | Isolamento por produto; retenção diferenciada trivial | 5+ lifecycles, 5+ policies, e **cada produto novo exige provisionamento** — o oposto de "cadastrar um relatório novo"; polui métricas por bucket |
| **Um bucket por ambiente + prefixo por produto** | Combina os dois: um lifecycle global, e policies/regras por prefixo quando (e se) precisar de retenção diferenciada | Nenhum relevante |

Como o path do ticket 03 já é `yyyy-MM-dd/produto/codigo/...`, o **produto é o segundo componente da chave, não o primeiro** — o que significa que uma regra por produto exigiria filtro por prefixo `*/produto/`, e **wildcards no meio não existem em filtro de lifecycle** (o filtro é prefixo literal, §3.2). **Isto é uma restrição forte que o ticket 03 precisa saber:** se um dia se quiser retenção diferenciada por produto, o **produto tem de vir antes da data no path**.

---

## 8. Recomendação

1. **Trate "MinIO" como implementação, não como contrato.** A spec deve dizer "repositório compatível com S3", e o código deve falar S3 puro atrás de uma porta (`RepositorioDeArtefatos`). Isso já era boa prática; com o repositório arquivado (§1.1) virou requisito.
2. **Servidor — decidir com este critério:**
   - *Ambiente de desenvolvimento/teste e CI*: **congelar `RELEASE.2025-10-15T17-29-55Z`** (último binário AGPL publicado). Custo zero, sem chave de licença, e o risco de CVE não corrigida é aceitável fora de produção.
   - *Produção em Docker Compose numa VM*: **AIStor Free**. É nó único (o que já é a topologia), permite carga de produção, é gratuito e continua recebendo correções — inclusive a de interop de checksum que ficou marcada como `fixed-in-aistor` (§2.3). O custo é a chave de licença via SUBNET e a EULA proprietária.
   - *Se a dependência de chave/SUBNET for inaceitável*: avaliar troca do servidor de objetos por outra implementação S3, **não** manter o binário arquivado em produção. Esta é uma decisão de operação, não de código — e por isso o item 1 é o que a torna barata.
   Registre a escolha como ADR com o motivo, porque ela vai ser questionada.
3. **Cliente: AWS SDK v2**, com `endpointOverride` + `pathStyleAccessEnabled(true)`, e **configuração explícita de checksum** (`requestChecksumCalculation`/`responseChecksumValidation`, com `LegacyMd5Plugin` se o servidor escolhido exigir MD5). Motivo: é a única escolha neutra, e a §1 mostra que a neutralidade agora tem valor concreto. Fixe as duas propriedades na configuração — o default mudou uma vez e pode mudar de novo (§2.3).
4. **Expurgo: lifecycle nativo, sempre.** Não escreva job de expurgo. A variável de ambiente (padrão 7 dias) alimenta o `--expire-days` de uma regra aplicada num **passo de bootstrap idempotente** do Compose (container `mc` de init). Motivo principal não é confiabilidade — é que **nenhuma credencial de cliente precisa de `s3:DeleteObject`**, o que é pré-requisito da separação do ticket 18 (§3.4).
5. **Uma regra, filtro vazio, bucket inteiro.** `.jrprint` e `.csv.gz` ficam no mesmo prefixo, têm a mesma data de criação e portanto a mesma data de expiração arredondada (§3.2, §3.3). Não tente filtrar por extensão — lifecycle S3 não filtra por sufixo.
6. **Versionamento: desligado.** Ele transforma a regra de retenção de 1 parâmetro em 3, cria a classe de bug "objeto expirado que não sumiu", duplica armazenamento e não entrega nada que o schema de controle já não registre sobre `forcar_reprocessamento` (§5).
7. **Integridade: SHA-256 calculado pelo processador e gravado no schema de controle**, conferido pela API antes de desserializar. ETag descartado explicitamente. Checksum nativo do S3 como defesa em profundidade opcional (§6).
8. **Layout: um bucket por ambiente, prefixo por data/produto/relatório.** E **avise o ticket 03**: se houver qualquer intenção futura de retenção diferenciada por produto, o produto precisa vir **antes** da data no path, porque filtro de lifecycle é prefixo literal sem wildcard (§7.2).

### Insumos diretos para os tickets dependentes

**Para o 18 (desserialização segura):**
- As duas policies concretas estão em §4.2 e §4.3, com a justificativa de cada ação omitida.
- Omitir `s3:ListBucket` da API é uma decisão de segurança barata e não custa funcionalidade (a listagem vem do banco).
- A separação **não** cobre processador comprometido (§4.4) — o hash e o `ObjectInputFilter` continuam obrigatórios.
- ETag **não** serve como hash (§6.1). Use SHA-256 da aplicação (§6.3, opção C).
- Contexto de risco: a última correção do MinIO comunitário foi bypass de session policy (§1.2).

**Para o 27 (retenção × histórico):**
- O expurgo é do servidor, não da aplicação (§3.4) — a variável de ambiente configura a **regra**, aplicada no bootstrap.
- A data de expiração é **previsível**: criação + N dias, arredondado para a meia-noite UTC seguinte (§3.3). Dá para materializar/derivar "expirado" na listagem sem consultar o bucket.
- A remoção física é **assíncrona** e pode atrasar (scanner de baixa prioridade). "Objeto ainda presente" ≠ "não expirado" — a fonte da verdade é o metadado.
- `.jrprint` e `.csv.gz` compartilham data de expiração, mas **a remoção não é atômica**: a API deve tratar "um dos dois ausente" como expirado.
- Retenção diferenciada por produto é possível (1 regra por prefixo, até 1.000 regras), **mas exige mudar a ordem do path** (§7.2). Se ficar em retenção global, isso não importa — e a variável única do documento sugere global.
- O S3 devolve `x-amz-expiration: expiry-date="...", rule-id="..."` na resposta do `PutObject` quando há regra de expiração aplicável ([PutObject API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html)). Se o servidor escolhido devolver esse header, o processador pode gravar a data de expurgo **vinda do servidor** em vez de recalculá-la — mais confiável. **Confirmar em teste** (§9).

---

## 9. Pontos não confirmados (honestidade sobre os limites desta pesquisa)

Estes itens não foram fechados em fonte primária e devem virar teste de integração, não suposição na spec:

1. **`x-amz-expiration` no MinIO/AIStor.** A especificação S3 define o header ([PutObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html)) e há relatos de que o MinIO o emite, mas não localizei a afirmação na documentação oficial do MinIO. Verificar com um `PutObject` real contra o servidor escolhido.
2. **Suficiência de `s3:PutObject` isolado para multipart no MinIO.** A lista de ações suportadas ([fonte](https://github.com/minio/docs/blob/main/source/administration/identity-access-management/policy-based-access-control.rst)) não detalha o mapeamento das operações de multipart para ações de policy. Testar com a policy mínima e um objeto grande o suficiente para acionar multipart.
3. **Qual release comunitária exatamente contém a correção de checksum** da [issue #20845](https://github.com/minio/minio/issues/20845). Os rótulos são `fixed` e `fixed-in-aistor`; se a escolha for congelar o binário AGPL, **teste `deleteObjects`/`putObject` com o AWS SDK v2 na configuração padrão** antes de assumir que funciona.
4. **Comportamento do scanner sob carga.** A documentação diz que a remoção pode atrasar, mas não dá SLA. Se o requisito de 7 dias tiver alguma leitura de conformidade, isso precisa ser medido, não presumido.
