# CSV é escrito em streaming, fora do Jasper

O CSV não passa pelo Jasper Reports. É escrito linha a linha, direto do cursor do MongoDB para o corpo do response, sem materializar a coleção em memória. O Jasper permanece responsável por PDF, XLSX e DOCX.

Registrado porque os limites do ADR-0004 já pressupunham isso sem dizer: CSV em 500.000 linhas contra 25.000 do PDF é uma razão de vinte para um que nenhum ajuste de template explica. A diferença só existe porque os caminhos de geração são diferentes — e isso não estava escrito em lugar nenhum.

## Considered Options

- **Tudo pelo Jasper** — recusada. O Jasper materializa o `JRDataSource` para paginar e calcular; meio milhão de linhas nesse caminho é exatamente o OOM que o ADR-0004 aceita como risco e o benchmark k6 tenta manter longe. Manteria um caminho só, ao custo de derrubar o limite de CSV para a casa do PDF.
- **Jasper com virtualizer** (paginação para disco) — recusada. Mantém o Jasper em todos os formatos, mas acrescenta I/O, arquivos temporários e um modo de falha novo (disco cheio, temporário órfão) no caminho que o ADR-0004 já considera o mais arriscado do sistema.

## Consequências

- Dois caminhos de geração para manter e testar. Os cenários dos tickets 10 e 11 já refletiam essa separação; agora ela tem motivo escrito.
- O CSV não tem template: sem cabeçalho estilizado, sem rodapé, sem formatação por coluna. A primeira linha é o cabeçalho de colunas e nada mais.
- O limite de 500.000 linhas do CSV só se sustenta enquanto essa escrita for realmente incremental. Um `toList()` acidental no meio do caminho reintroduz o OOM sem que nenhum teste funcional perceba — o benchmark k6 é quem defende essa propriedade.
- A contagem prévia do ADR-0004 continua valendo para os quatro formatos: ela protege o tempo de resposta e o teto de blob do navegador, não só a memória do servidor.
