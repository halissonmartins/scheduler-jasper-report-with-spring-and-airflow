# O repositório S3 é MinIO AGPL congelado em dev/CI e AIStor Free em produção

A descrição inicial pede "armazenamento dos dados em um repositório que implementa o padrão S3
(Minio)". O requisito é o **padrão S3**; o MinIO estava entre parênteses, como sugestão — e essa
distinção deixou de ser acadêmica: o repositório `minio/minio` **foi arquivado em 25/04/2026**, o
README declara textualmente *"THIS REPOSITORY IS NO LONGER MAINTAINED"*, a edição comunitária passou
a ser distribuída **apenas como código-fonte** (*"We will no longer provide pre-compiled binary
releases for the community version"*), e o Console perdeu as funções administrativas em maio de 2025.

Decidimos: **MinIO AGPL congelado em `RELEASE.2025-10-15T17-29-55Z` em desenvolvimento e CI, e
AIStor Free em produção**, em nó único.

E decidimos, como regra permanente: **"MinIO" é implementação, nunca contrato.** A especificação diz
"repositório compatível com S3", e o código fala S3 puro atrás de uma porta. O research 10 já havia
agido sobre isso ao escolher o **AWS SDK v2** em vez do SDK do MinIO — é a única escolha de cliente
que sobrevive a uma troca de servidor.

## Por que não trocar de implementação

Esta era a alternativa mais atraente: sem fornecedor comercial, sem chave de licença, com projeto
vivo. O custo, quando medido, é que **este sistema construiu dois mecanismos sobre a semântica de IAM
do S3**, e nem toda implementação a tem.

O **Garage** — o candidato mais próximo em perfil de operação — documenta: *"Garage does not
implement Amazon S3's ACL or policy access control mechanisms. Instead, it uses its own system based
on per-access-key-per-bucket logic."* Num modelo de permissão read/write/owner por chave e bucket:

- **"escreve mas não apaga" deixa de ser expressável.** É exatamente a propriedade que faz o expurgo
  ser exclusivamente lifecycle nativo, e que permite **nenhuma credencial da aplicação ter
  `s3:DeleteObject`** — um dos alicerces do modelo de ameaça do [ADR 0002](0002-desserializacao-java-do-jasperprint.md).
- **omitir `s3:ListBucket` da credencial da API** deixa de ser possível — e essa omissão é deliberada:
  ela transforma o bucket em *lookup* por chave conhecida, de modo que quem obtiver a credencial da
  API não consegue enumerar o acervo.

O **Ceph RGW** preserva a semântica completa, mas sua operação é desproporcional para Docker Compose
em VMs, que é o modelo de implantação deste projeto.

Trocar exigiria reabrir os tickets de storage, desserialização e retenção — e substituir um alicerce
de segurança por outro ainda não desenhado.

## Por que não congelar o AGPL também em produção

Seria a opção sem fornecedor, sem chave e sem divergência entre ambientes. O que pesou contra: **a
última correção publicada na edição comunitária foi um bypass de session policy em service
accounts/STS** — precisamente o mecanismo em que a separação de credenciais deste sistema se apoia. A
issue recebeu os rótulos `fixed` e `fixed-in-aistor`. Congelar em produção significa aceitar que a
próxima falha dessa mesma natureza não terá correção.

Há ainda a obrigação de licença: o README alerta que *"all usage of MinIO in your application stack
requires validation against AGPLv3 obligations"*.

## Consequências

- **Os tickets de storage, desserialização e retenção sobrevivem intactos.** Policies por operação,
  lifecycle nativo com filtro vazio e `mc ilm` continuam valendo. Foi o principal critério.
- **Produção passa a depender de uma chave de licença** obtida no SUBNET e **renovada a cada 24 h** —
  uma dependência de rede externa e de conta de fornecedor no ambiente de produção. **O comportamento
  quando a renovação falha não está documentado** no que apuramos; é item de verificação, não
  suposição.
- **A restrição de nó único do AIStor Free não morde**, porque a produção roda Docker Compose em VMs.
  Produção comercial é explicitamente permitida pelo acordo.
- **Redistribuição é proibida**: não se pode embutir o binário numa imagem própria publicada. Não
  impede referenciar a imagem oficial no Compose.
- **CI e produção rodam servidores diferentes.** É a forma do problema que levou este projeto a
  remover o H2 dos testes — *teste verde, produção divergente, zero sinal*. O delta aqui é muito
  menor (mesma linhagem, mesma API), mas não é zero. Contido pela lista abaixo.
- **Sem custo em dev e CI**: o binário congelado dispensa chave, conta e rede externa, então um
  desenvolvedor novo roda a suíte sem obter credencial de fornecedor.

## A lista de verificação que contém a divergência

Exercitar **contra o AIStor real** antes de promover para produção. Entra nos cenários obrigatórios
da estratégia de teste:

1. Regra de lifecycle com **filtro vazio** expurgando `.jrprint` e `.csv.gz` na mesma rodada.
2. `x-amz-expiration` no `PutObject` — **não confirmado nem no MinIO**; revelar qual caminho está em
   uso (header do servidor ou cálculo local).
3. Policy **sem `s3:DeleteObject`** em credencial alguma, e o expurgo funcionando mesmo assim.
4. Policy **sem `s3:ListBucket`** na credencial da API.
5. Expurgo alcançando **objeto órfão sem metadado** — resto de upload interrompido.
6. **Imagem ARM64 do AIStor.** A verificação de ARM64 foi feita para o MinIO, não para o AIStor.

## Quando revisitar

Se a dependência de chave/SUBNET se mostrar inaceitável em operação, ou se a renovação de 24 h
provar-se frágil, o caminho de saída é congelar o AGPL também em produção — aceitando ficar sem
correções — e **não** trocar de implementação, porque a troca custa os dois mecanismos de segurança
descritos acima.
