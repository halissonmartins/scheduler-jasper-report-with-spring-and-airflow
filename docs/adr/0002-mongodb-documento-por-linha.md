# MongoDB com um documento por linha para os dados coletados

Os dados coletados são gravados no MongoDB, um documento por linha do Relatório, com índice composto em (dataReferencia, produto, codigoRelatorio, seq) para leitura ordenada e determinística durante a Geração.

Escolhido pela liberdade de esquema por Relatório: cada Relatório tem campos próprios e não queremos migração de esquema para cadastrar um novo Relatório.

## Considered Options

- **CSV/JSONL comprimido em object store (S3/MinIO)** — recomendado na análise e recusado. Custaria menos disco (gzip), transformaria a retenção de 7 dias em uma regra de lifecycle do bucket e evitaria operar um replica set; mas não oferece consulta ad-hoc dentro do conteúdo e trata o esquema como convenção de arquivo, não do dado.
- **PostgreSQL com JSONB** — descartado: ~70 GB de JSONB com alta rotatividade traria bloat e ajuste de autovacuum, e concentraria todo o risco operacional no banco relacional.

## Consequências

- Um documento por linha é obrigatório: o teto de 16 MB por documento impede guardar um Relatório inteiro em um único documento.
- Nomes de campos repetem em cada documento; o disco real fica acima do volume bruto (a compressão snappy do WiredTiger mitiga cerca de metade).
- O índice TTL que implementa a retenção (ADR-0008) apaga milhões de documentos por dia, concorrendo em escrita com a Coleta.
- Produção exige replica set e rotina de backup próprios (ADR-0009).
