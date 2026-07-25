# Retenção de 7 dias e ausência de relatórios históricos

As linhas coletadas expiram por índice TTL sete dias após a gravação. O PostgreSQL retém Cadastros, metadados e auditoria por muito mais tempo (são dados pequenos).

## Consequências

- Como a Geração é síncrona e não persiste artefato (ADR-0004), **o sistema não consegue produzir um relatório com mais de 7 dias**. A tela de visualização por dd/MM/yyyy oferece no máximo sete datas.
- Relatórios de fechamento de mês, de trimestre ou solicitados por auditoria estão fora de escopo. Isso é deliberado, não uma limitação temporária.
- Execuções superadas (ADR-0006) são recolhidas pelo mesmo TTL, sem rotina própria.
