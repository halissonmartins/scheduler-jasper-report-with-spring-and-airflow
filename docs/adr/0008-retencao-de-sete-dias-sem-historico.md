# Retenção de 7 dias e ausência de relatórios históricos

As linhas coletadas expiram por índice TTL após a janela de retenção, cujo padrão é sete dias. A janela é configurável dentro de um teto, e o número deixou de ser literal — ver ADR-0018. O PostgreSQL retém Cadastros, metadados e auditoria por muito mais tempo (são dados pequenos).

## Consequências

- Como a Geração é síncrona e não persiste artefato (ADR-0004), **o sistema não consegue produzir um relatório mais antigo que a janela de retenção**. A tela de visualização por dd/MM/yyyy oferece no máximo tantas datas quanto a janela, e esse limite deriva do parâmetro em vez de ser escrito à mão.
- Relatórios de fechamento de mês, de trimestre ou solicitados por auditoria estão fora de escopo. Isso é deliberado, não uma limitação temporária, e **aumentar a retenção não os cria**: fechamento é agregação entre dias, que não existe no desenho (ADR-0018).
- Execuções superadas (ADR-0006) são recolhidas pelo mesmo TTL, sem rotina própria.
