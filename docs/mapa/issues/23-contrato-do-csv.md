# 23 — Contrato do CSV e a divergência PDF × CSV

Type: grilling
Status: resolved
Blocked by: 21

## Question

O que exatamente o `.csv.gz` contém, e como se explica que ele difira do PDF?

O documento já decidiu que o CSV não passa pelo Jasper, é o dataset da query principal (sem subrelatórios e imagens), com separador `;` para Excel pt-BR.

Falta fechar o contrato e a regra de comunicação:

- **Detalhes de formato ainda abertos**: encoding (UTF-8 com ou sem BOM — o Excel pt-BR precisa do BOM para acentos), quoting (sempre, ou só quando necessário), escape, terminador de linha, formato de data, separador decimal (vírgula pt-BR ou ponto), e valores nulos.
- **Cabeçalho técnico ou rotulado.** Nomes de coluna do banco ou os rótulos do JRXML? Rotulado é mais útil e mais frágil.
- **A divergência será reportada como bug.** O CSV não terá campos calculados, grupos, subtotais nem formatação definidos no JRXML — o mesmo relatório apresenta números e colunas diferentes conforme o formato. Escrever a regra explícita na spec e na UI: o CSV é o **dataset** da query principal; o PDF é a **visão formatada**. Decidir onde essa mensagem aparece para o usuário.
- **Campos calculados no JRXML.** Se um subtotal importante só existe no JRXML, ele some do CSV. Decidir se cálculos relevantes migram para a query (e então aparecem nos dois) ou ficam só na visão.
- **Compressão e tamanho.** `.csv.gz` sempre, ou só acima de um limiar. Qual o teto de linhas.

## Notas do ticket 21 (contrato do Starter)

- **O CSV é escrito linha a linha, conforme o Jasper puxa** — ele deriva do mesmo `JRDataSource`, no
  mesmo tasklet, numa passada só. Isso já garante **por construção** que ele contém exatamente as
  linhas do dataset principal, que era a promessa que este ticket precisa formalizar.
- **Consequência de forma**: o CSV é produzido em *streaming*, então tudo o que este ticket decidir
  precisa ser decidível **por linha**, sem olhar o conjunto. Cabeçalho e encoding saem no início;
  totalizadores ou alinhamento por largura de coluna, não — exigiriam segunda passada ou acumulação
  em memória, que é o que o desenho em pull existe para evitar.
- **Quem mapeia campo já está definido**: o `mapear(row)` do bean do módulo. Falta dizer se as colunas
  do CSV são exatamente os campos desse mapeamento ou um subconjunto declarado à parte.
- **Formatação de data e decimal**: como o CSV não passa pelo Jasper, ele não herda os padrões do
  JRXML. A regra pode viver no Starter (uma para todos os Produtos) ou no bean do módulo — e a
  primeira é o que mantém os cinco Produtos consistentes.
- **Campos calculados**: com a leitura em pull, migrar um subtotal para a query é barato (ele passa a
  existir nos dois formatos); mantê-lo só no JRXML é o que produz a divergência que este ticket
  precisa explicar ao usuário.

## Notas do ticket 22 (paginado × não paginado)

- **O `.csv.gz` mantém um consumidor só.** O XLSX continua saindo do `.jrprint`, como visão formatada,
  então o CSV não ganha um segundo público com requisitos próprios. A opção "XLSX a partir do CSV"
  foi considerada e recusada — se tivesse sido escolhida, este ticket precisaria servir análise de
  dados **e** planilha de apresentação ao mesmo tempo.
- **A mensagem sobre a divergência tem dois lados, não três.** Fica "PDF, XLSX e DOCX são a visão
  formatada; CSV é o dataset" — e não um terceiro caso em que o XLSX se parece com o CSV. Isso
  simplifica o texto que este ticket precisa escrever para a UI.

## Answer

### O contrato

| | |
|---|---|
| Separador | `;` |
| Encoding | UTF-8 **com BOM** |
| Decimal | vírgula — `1234,56` |
| Data | `dd/MM/yyyy` |
| Terminador de linha | CRLF |
| Quoting | só quando necessário (campo contém `;`, aspas ou quebra de linha); aspas duplicadas para escapar |
| Valor nulo | campo vazio |
| Cabeçalho | **rotulado**, declarado no bean junto do mapeamento |
| Colunas | exatamente os campos de `mapear(row)`, na ordem declarada |
| Compressão | `.csv.gz` sempre |

**A coerência é a decisão, não cada item.** O documento já escolhera `;` "para Excel pt-BR", e
meio-termo aqui é pior que qualquer extremo: `;` com decimal em ponto faz o Excel pt-BR abrir as
colunas certas e tratar todo número como **texto** — planilha bonita que não soma uma coluna. Sem BOM,
acento vira `Ã§`. Ou se vai até o fim na escolha do Excel, ou não se começa.

Custo assumido: quem for analisar em ferramenta de dados precisa de parâmetros — em pandas,
`read_csv(f, sep=';', decimal=',', encoding='utf-8-sig')`. Uma linha, mas é preciso saber.

**Rótulos vêm do bean, não do JRXML.** Extrair cabeçalho de coluna do JRXML seria frágil de um jeito
que só falha em relatório específico — lá o cabeçalho é elemento de texto que pode ser expressão,
texto estilizado ou imagem. O bean já declara o mapeamento; o rótulo cabe no mesmo lugar, explícito.
Manter o rótulo igual ao do PDF vira item de revisão do Relatório, não dependência de runtime.

**As colunas são exatamente o mapeamento.** Um subconjunto declarado à parte seria uma segunda
declaração livre para divergir.

### O CSV é o único formato que não desserializa

O `.csv.gz` já está gravado no repositório. A API **busca e transmite** — não há `JasperPrint` a
desserializar, nem exporter a rodar.

Consequências:

- Os limites de heap do ticket 25, que existem porque a exportação roda na JVM da API sem isolamento
  (ADR 0002), **não se aplicam ao CSV**.
- Dá para servi-lo com `Content-Encoding: gzip`, deixando o navegador descomprimir, sem os bytes
  passarem pelo heap da API.
- O SHA-256 continua sendo conferido antes de entregar (ticket 18), porque a integridade não depende
  de haver desserialização.

### Riscos aceitos

1. **Sem regra de derivabilidade.** Argumentei por uma regra testável: *todo número que o PDF mostra
   está no CSV ou é derivável das linhas dele*. Subtotais e totais poderiam continuar sendo
   `<variable>` do JRXML desde que somar a coluna correspondente do CSV chegasse ao mesmo valor;
   cálculo que não satisfizesse isso — base filtrada por regra que o CSV não carrega, valor vindo de
   subrelatório — migraria para a query e viraria coluna. Decisão: sem regra, cada Relatório decide.
2. **Sem aviso na UI.** Argumentei por uma linha no ponto de escolha do formato, porque é ali que a
   expectativa se forma e é o relator, não o integrador, quem confere CSV contra PDF. Decisão: a regra
   fica na especificação e na descrição do endpoint no OpenAPI.

**Efeito combinado**: a divergência não é **prevenida** nem **explicada onde é encontrada**. O relator
que baixa o CSV, soma a coluna e compara com o total do PDF pode achar um número diferente, sem meio
de reproduzi-lo a partir dos dados que recebeu e sem ter sido avisado. A resposta existe — em
documento que ele não lê e não deveria precisar ler.

### Derivado

- **`.csv.gz` sempre**, sem limiar. O documento já nomeia a extensão, e comprimir condicionalmente
  criaria um ramo a mais para economizar quase nada num arquivo pequeno.
- **O teto de linhas não é deste ticket.** Como o CSV não passa por desserialização, quem o limita é o
  limite da própria Coleta (ticket 25), não o da exportação.
