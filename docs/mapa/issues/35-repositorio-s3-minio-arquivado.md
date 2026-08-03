# 35 — Repositório S3: o MinIO foi arquivado. Qual caminho?

Type: grilling
Status: resolved
Blocked by: 10

## Question

Qual implementação do padrão S3 este projeto usa, agora que o MinIO deixou de ser mantido?

O research do ticket 10 derrubou a premissa da descrição inicial: o repositório `minio/minio`
foi **arquivado em 25/04/2026**, o README declara "NO LONGER MAINTAINED", não há mais binários
pré-compilados, e o Console perdeu a administração em maio/2025. Pior para este projeto: o último
release corrigia um bypass de session policy de service account — exatamente o mecanismo em que a
separação de credenciais do ticket 18 se apoia.

Isso é decisão de arquitetura com custo e licença envolvidos, não pesquisa. Decidir:

- **O caminho recomendado pelo research**: AGPL congelado em desenvolvimento e CI, **AIStor Free**
  em produção (nó único, produção permitida, chave via SUBNET). Custo: dependência de uma chave de
  licença e de um fornecedor comercial, com um caminho de upgrade que não é gratuito.
- **Alternativas a pesar**: outra implementação S3 auto-hospedada (SeaweedFS, Garage, Ceph RGW),
  um S3 gerenciado de provedor de nuvem, ou congelar o MinIO AGPL também em produção e aceitar
  ficar sem correções de segurança.
- **O que realmente é exigido.** A descrição inicial pede "um repositório que implementa o padrão
  S3 (Minio)" — o requisito é o padrão S3; o MinIO era a sugestão. Confirmar essa leitura antes de
  qualquer coisa.
- **Consequências para tickets já decididos ou em aberto**: o ticket 18 (credenciais separadas e
  policies), o 27 (lifecycle nativo e expurgo) e o 11 (imagem ARM64 no Compose) assumem semântica
  do MinIO. Verificar o que sobrevive à troca.
- **Ambiente de teste**: seja qual for a produção, o que sobe no Testcontainers e no Compose de
  desenvolvimento.

Registrar como ADR — é caro de reverter, e um leitor futuro vai perguntar por que não é MinIO,
já que a descrição inicial o nomeia.

## Answer

Registrado no [ADR 0003](../../adr/0003-repositorio-s3-aistor-free-em-producao.md) — é caro de
reverter, e um leitor futuro vai perguntar por que não é MinIO, já que a descrição inicial o nomeia.

| | |
|---|---|
| Dev e CI | MinIO AGPL **congelado** em `RELEASE.2025-10-15T17-29-55Z` |
| Produção | **AIStor Free**, nó único |
| Divergência | aceita, contida por lista nomeada de verificação |

### A premissa, confirmada

O requisito é **"um repositório que implementa o padrão S3"**; o MinIO estava entre parênteses. O
research 10 já havia agido sobre essa leitura ao escolher o **AWS SDK v2** em vez do SDK do MinIO.
Fica como regra permanente: **"MinIO" é implementação, nunca contrato** — a spec diz "compatível com
S3" e o código fala S3 puro atrás de uma porta.

### O que descartou a troca de implementação

Este era o caminho mais atraente — sem fornecedor, sem chave, projeto vivo. O custo, medido:

> *"Garage does not implement Amazon S3's ACL or policy access control mechanisms. Instead, it uses
> its own system based on per-access-key-per-bucket logic."*

Num modelo read/write/owner por chave e bucket, **"escreve mas não apaga" não é expressável** — e é
essa propriedade que faz o expurgo ser exclusivamente lifecycle e permite que **nenhuma credencial
tenha `s3:DeleteObject`**, um dos alicerces do ADR 0002. Some junto a omissão deliberada de
`s3:ListBucket` na credencial da API, que impede enumerar o acervo.

Ceph RGW preserva a semântica, mas sua operação é desproporcional para Compose em VMs.

**O principal benefício da escolha feita é negativo**: nenhum ticket precisa ser reaberto. Policies
por operação, lifecycle com filtro vazio e `mc ilm` continuam valendo.

### Riscos aceitos

1. **Chave de licença via SUBNET, renovada a cada 24 h**, em produção. Dependência de rede externa e
   de conta de fornecedor. **O comportamento na falha de renovação não está documentado** no que
   apuramos — item de verificação, não suposição.
2. **CI e produção rodam servidores diferentes.** É a forma do problema que fez este projeto remover
   o H2 (*teste verde, produção divergente, zero sinal*). O delta é muito menor — mesma linhagem,
   mesma API — mas não é nulo: o AIStor divergiu do binário congelado em ao menos a correção do
   bypass de session policy.

O caminho alternativo — AIStor também em dev e CI — daria paridade total, mas poria chave de
licença em cada máquina de desenvolvimento e no runner, com o build passando a depender de rede
externa e de conta de fornecedor. Um desenvolvedor novo não rodaria a suíte sem credencial comercial.

### A contenção

Lista nomeada no ADR 0003, a exercitar **contra o AIStor real** antes de promover: lifecycle com
filtro vazio, `x-amz-expiration`, ausência de `s3:DeleteObject`, ausência de `s3:ListBucket` na API,
expurgo de objeto órfão, e **imagem ARM64 do AIStor** — o ticket 11 verificou ARM64 para o MinIO, não
para o AIStor.
