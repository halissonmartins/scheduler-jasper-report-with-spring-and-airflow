# 22 — Paginado × não paginado: o conflito do `.jrprint` único com o XLSX

Type: grilling
Status: resolved
Blocked by: 21

## Question

Como o XLSX sai apresentável se existe um único `JasperPrint` desenhado para PDF?

O documento reconhece o problema e propõe mitigar "desprezando a paginação quando o formato selecionado for XLSX". A análise comportamental aponta que isso não funciona como descrito: `isIgnorePagination` atua no **fill**, não no **export**. Desprezar a paginação no momento da exportação é tarde demais — o `JasperPrint` já está paginado e posicionado, e o exporter de Excel monta o grid a partir de coordenadas.

Decidir entre os caminhos, todos com custo:

- **Dois prints na coleta.** A Coleta grava dois `.jrprint`: um paginado (PDF, DOCX) e um não paginado (XLSX). Custo: armazenamento dobrado e tempo de fill dobrado. Coerente com a arquitetura, e é a saída que a análise recomenda.
- **Refill sob demanda.** A API refaz o fill sem paginação quando pedem XLSX — mas isso exige acesso ao schema transacional a partir da API, o que viola frontalmente a regra "a Coleta é a única fronteira de leitura".
- **XLSX a partir do CSV.** O `.csv.gz` já é o dataset bruto. Gerar XLSX dele, não do Jasper — o XLSX vira dado, não visão formatada. Barato, mas muda a promessa do formato e reabre o ticket 23.
- **Aceitar o XLSX feio.** Registrar como limitação conhecida.

A decisão realimenta o ticket 21 (quantos fills o Starter faz) e o 03 (quantos objetos por path).

## Notas do ticket 03 (chave e data)

- **O layout já reserva espaço para o segundo print**, então esta decisão não fica presa a uma
  escolha de nomenclatura. O caminho é `{yyyy-MM-dd}/{SIGLA}/{CODIGO}/`, com os objetos nomeados
  pelo Código, e o segundo print entraria como sufixo:

  ```
  2026-08-01/POUPANCA/POUPANCA-0001/POUPANCA-0001.jrprint
  2026-08-01/POUPANCA/POUPANCA-0001/POUPANCA-0001-nao-paginado.jrprint
  2026-08-01/POUPANCA/POUPANCA-0001/POUPANCA-0001.csv.gz
  ```

- **Os três objetos caem sob a mesma regra de lifecycle** (filtro vazio, bucket inteiro) e têm a
  mesma data de criação, logo expiram na mesma rodada. A opção "dois prints" não cria trabalho novo
  de retenção.
- **Sem discriminador de execução no caminho**: se a Coleta gravar dois prints, os dois são
  sobrescritos juntos num reprocessamento.
- Se o caminho escolhido for **XLSX a partir do CSV**, nada muda no layout — o `.csv.gz` já está lá.

## Notas do ticket 21 (contrato do Starter)

- **O ponto de extensão existe e é barato.** O job é um step tasklet único, com o CSV derivado do
  mesmo `JRDataSource` que o Jasper consome. Um segundo fill (não paginado) entraria **no mesmo
  tasklet**, sobre o mesmo cursor — sem step novo, sem segunda leitura da origem, e com garantia de
  que os dois prints vieram das mesmas linhas.
- **Cuidado**: um `JRDataSource` só é consumido **uma vez**. Dois fills exigem ou reabrir a leitura
  (duas passadas, com o risco de divergência que o ticket 21 evitou), ou materializar as linhas em
  memória entre os dois — que é exatamente o que o `JRVirtualizer` e o desenho em pull existem para
  não fazer. Esta é a dificuldade central da opção "dois prints", e ela não aparecia antes.
- **A opção "XLSX a partir do CSV" ficou mais barata em comparação**, porque o `.csv.gz` já é
  produzido na mesma passada e já contém exatamente as linhas do dataset principal.
- **O limite real de tamanho é o heap da API** (ticket 21), não o do processador. Dois prints dobram
  o que a API precisa desserializar, então esta decisão interage com os limites do ticket 25.

## Answer

### A premissa do ticket estava incompleta

A análise comportamental está certa na primeira metade: `isIgnorePagination` atua no **fill**, e no
momento da exportação já é tarde — o `JasperPrint` chega paginado e posicionado.

Mas a conclusão que ela tira daí, de que só resta gravar dois prints, **não se sustenta**. Existe
caminho no export, e é o documentado pelo próprio Jasper para exatamente este caso — há um sample
chamado `nopagebreak` dedicado a ele:

| Configuração | Efeito documentado |
|---|---|
| `setOnePagePerSheet(false)` | não quebra em uma aba por página |
| `setRemoveEmptySpaceBetweenRows(true)` | *"collapses empty rows for a flow-oriented layout"*, contra o default `false` que *"preserves whitespace for pixel-perfect layouts"* |
| `net.sf.jasperreports.export.xls.detect.cell.type=true` | número e data viram tipos do Excel em vez de texto |

### Decisão: um print, exporter configurado

Mantém-se **um único `.jrprint`**. O XLSX sai dele, com a configuração acima.

O XLSX continua sendo **visão formatada**, coerente com PDF e DOCX — não vira dado. Zero
armazenamento extra, zero fill extra.

**A regra da descrição inicial precisa ser reescrita na spec**: de *"mitigado desprezando a paginação
quando o formato selecionado for XLSX"* para *"mitigado por configuração do exporter"*.

### Por que não os dois prints

O custo real só ficou visível depois do ticket 21: o `JRDataSource` é consumido **uma vez**. Dois
fills exigiriam ou uma segunda leitura da origem — reintroduzindo a divergência entre saídas que o
ticket 21 eliminou por construção — ou materializar as linhas em memória entre os dois fills, que é
exatamente o que o `JRVirtualizer` e o desenho em pull existem para não fazer. Dobraria também o que
a API desserializa, onde não há isolamento (ADR 0002).

E não o XLSX a partir do CSV: seria a opção mais barata, mas o XLSX deixaria de ser visão formatada,
perdendo título, grupos, subtotais e imagens — passando a divergir do PDF **por desenho**, e dando ao
`.csv.gz` um segundo consumidor com requisitos próprios.

### A configuração vive no código da API

Linha de base aplicada a **toda** exportação XLSX, dos cinco Produtos. O critério foi o que acontece
por **omissão**: com a linha de base no JRXML, um Relatório novo cujo autor esqueceu produz planilha
ruim e ninguém percebe até alguém reclamar. No código da API, o padrão vale para todos, e propriedades
no JRXML ficam reservadas para exceção deliberada — o que vira revisão, não descuido.

Também dá um lugar só para mudar quando o padrão precisar evoluir, em vez de N arquivos.

### O que continua imperfeito, e onde se conserta

O grid do Excel segue derivado de coordenadas: bandas desalinhadas viram células mescladas ou colunas
estranhas, e o cabeçalho de página continua repetido ao longo da planilha.

Isso é limitação conhecida e **mitigável na origem**, não no exporter: JRXML com bandas alinhadas numa
grade comum exporta muito melhor. Entra como regra do padrão de JRXML, e os relatórios de exemplo de
cada Produto precisam demonstrá-la.

### O que esta decisão fecha em outros tickets

- **Ticket 21**: "quantos fills o Starter faz" → **um**. O desenho de passada única permanece intacto.
- **Ticket 03**: o sufixo `-nao-paginado` que o layout reservava fica sem uso. Dois objetos por
  Execução.
- **Ticket 25**: a API não desserializa o dobro.
- **Ticket 23**: o XLSX continua sendo visão formatada, então o `.csv.gz` mantém um consumidor só.
