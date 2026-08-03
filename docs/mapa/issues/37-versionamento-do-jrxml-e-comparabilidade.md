# 37 — Versionamento do JRXML e comparabilidade entre Execuções

Type: grilling
Status: resolved
Blocked by: 21

## Question

Duas Execuções do mesmo Código de Relatório, em dias diferentes, podem ter layouts diferentes. O que
o sistema promete?

Este ticket graduou da névoa quando o ticket 04 criou o inventário (`jrxml_publicado`) — antes não
havia onde ancorar a pergunta.

Um esclarecimento que reduz o problema pela metade: **o `.jrprint` é autocontido**. Estilos, imagens
e renderers viajam serializados dentro dele, e a exportação não toca no JRXML. Então mudar um JRXML
**não** quebra artefato já gravado — o ticket 18 continua valendo sem alteração.

O que sobra é semântico, e é isso que este ticket decide:

- **Comparabilidade.** O relator baixa `POUPANCA-0001` de 01/08 e de 08/08. Entre as duas datas, o
  JRXML ganhou uma coluna. Os dois PDFs têm o mesmo nome e layouts diferentes, sem nada que o avise.
  Isso é aceitável, é para sinalizar na UI, ou é para impedir?
- **O inventário registra versão?** `jrxml_publicado` guarda hoje o caminho do JRXML. Se guardar
  também um hash ou versão declarada, a Execução pode gravar qual versão a produziu — e aí a
  divergência entre duas Execuções vira detectável em vez de invisível.
- **Onde a versão fica na Execução.** Coluna própria ao lado de `versao_jasperreports` (ticket 05),
  ou dentro de `parametros_entrada`?
- **JRXML que some numa imagem nova.** Um Relatório está cadastrado e a imagem seguinte não traz mais
  o seu JRXML. O cadastro é invalidado, o Relatório é desativado, ou o deploy é recusado? Interage
  com o contrato de publicação do ticket 21.
- **Mudança de JRXML exige nova Execução?** Se o JRXML muda hoje, as Execuções dos últimos 7 dias
  continuam sendo as antigas. Vale reprocessar, ou o histórico é imutável por definição?
- **Isso é versionamento ou é Relatório novo?** Uma mudança que altera colunas talvez devesse ser um
  Código novo, não uma versão nova do mesmo — o que dispensaria o mecanismo inteiro.

## Notas de research

- **Ticket 05**: o `serialVersionUID` do JasperReports é constante fixa, então divergência de versão
  do Jasper falha em **silêncio**, não com `InvalidClassException`. Por isso o ticket 04 já grava
  `versao_jasperreports` na Execução. A versão do JRXML tem exatamente a mesma natureza de risco
  silencioso, e o mesmo remédio é candidato natural.
- **Ticket 04**: o inventário é publicado por um modo `--publicar-inventario` da própria imagem do
  processador, num passo de bootstrap do deploy. É o ponto onde um hash de JRXML seria calculado
  sem custo adicional.
- **Ticket 04**: o cadastro de Relatório só aceita Código presente no inventário — mas o ticket 04
  **não** decidiu o que acontece quando um Código sai do inventário depois de cadastrado.

## Notas do ticket 21 (contrato do Starter)

- **A pergunta "o que acontece quando um Código sai do inventário" foi respondida lá**: a publicação é
  declarativa, o Relatório sai do inventário, o cadastro permanece sinalizado, e a fábrica de DAGs
  para de gerar DAG para ele. Este ticket não precisa mais decidi-la — mas herda a versão difícil
  dela: **um JRXML que muda** não some do inventário, e é por isso que a mudança silenciosa é o
  problema, não a remoção.
- **O bean é o lugar natural do hash.** Como o inventário passou a ser a enumeração dos beans (e não
  um arquivo), calcular o hash do recurso JRXML que o bean aponta é feito no mesmo varrimento do
  `--publicar-inventario`, sem passo novo.
- **Uma pergunta a mais que a SPI abre**: a comparabilidade depende só do JRXML, ou também da
  **consulta**? O bean declara os dois. Mudar a query sem tocar no JRXML muda os números do relatório
  sem mudar o layout — divergência ainda mais invisível que a de layout, e o mesmo mecanismo de hash
  a cobriria.

## Notas do ticket 22 (paginado × não paginado)

- **O padrão de JRXML ganhou uma regra de layout com consequência funcional**: bandas alinhadas numa
  grade comum. Não é estética — o XLSX sai de um `.jrprint` paginado, e banda desalinhada vira célula
  mesclada ou coluna estranha na planilha. Os relatórios de exemplo de cada Produto precisam
  demonstrar isso.
- **Isso realimenta a comparabilidade que este ticket discute**: mudar o alinhamento de bandas num
  JRXML muda o XLSX de forma visível sem mudar o PDF de forma óbvia. É mais um caso em que a
  divergência entre Execuções aparece só num formato.
- **A configuração do exporter XLSX não fica no JRXML** (ticket 22) — a linha de base é código da API.
  Se este ticket adotar hash do JRXML, ele não precisa cobrir configuração de exportação, que evolui
  por outro caminho.

## Notas do ticket 23 (contrato do CSV)

- **A comparabilidade tem uma terceira dimensão além do JRXML e da consulta: os rótulos do CSV.** Eles
  são declarados no bean (ticket 23), não extraídos do JRXML — então mudar um rótulo altera o
  cabeçalho de todo CSV futuro sem mudar layout nenhum, e sem que o hash de um JRXML perceba.
- **Sem regra de derivabilidade** (ticket 23), um mesmo Código pode ter, em datas diferentes, um total
  no PDF que era reproduzível a partir do CSV e outro que não é — porque a consulta mudou. Essa é a
  forma mais invisível da divergência que este ticket discute: nada no layout muda.
- Reforça a pergunta já registrada acima: se este ticket adotar hash, ele deve cobrir **JRXML,
  consulta e rótulos** — os três vivem no bean e são varridos no mesmo `--publicar-inventario`.

## Answer

### O quadro

| | |
|---|---|
| A promessa | **registrar, não avisar** |
| O que grava | `hash_definicao` (SHA-256 de JRXML + consulta + rótulos) e `imagem_origem` |
| Quem calcula | o **container**, no início do job, dos próprios beans |
| Divergiu do inventário | log + métrica, **e o job segue** |
| Histórico | imutável; nada reprocessa sozinho |

### Um hash, e o git para o resto

Dois ou três hashes decompostos foram considerados — `hash_dados` × `hash_apresentacao`, ou um por
dimensão do bean. Ambos param no mesmo lugar: **um hash só sabe dizer "diferente"**. Qualquer
agrupamento é um palpite sobre o que o leitor vai querer, e o corte vaza (um `mapear` que derruba uma
coluna muda dados *e* apresentação; um rótulo alterado quebra o parser de quem consome o CSV, o que
não é "só forma").

O que responde **o que** mudou é o `git diff` entre os dois commits — com precisão que decomposição
nenhuma alcança, porque o bean é código versionado.

> **O hash responde *se*; o git responde *o quê*. O hash é um ponteiro para o git, não um substituto.**

É por isso que `imagem_origem` não é acompanhante: sem ele o hash aponta para lugar nenhum.

### `mapear` fica fora — e isso muda o papel de `imagem_origem`

Dos quatro itens do bean, três são dado e um é código:

| | hashável? | |
|---|---|---|
| `jrxml()` | sim | recurso do classpath → bytes |
| `consulta()` | sim | string |
| rótulos do CSV | sim | lista ordenada de strings |
| `mapear(row)` | **não** | método — exigiria inspeção de bytecode |

Hash do bytecode da classe foi recusado: o `.class` muda por edição irrelevante — helper privado
renomeado, versão de compilador diferente — e **reintroduz exatamente o falso positivo** que fez a
opção "gravar só a imagem" ser recusada. Hash só do método `mapear` é mais estreito mas continua
dependente do compilador e traz ferramenta de bytecode para um caminho que não tem nenhuma.

`mapear` só muda por recompilação, então exige imagem nova, e `imagem_origem` o alcança. Isso promove
aquele campo de decoração a **cobertura da parte não-hashável**.

> **Risco aceito**: mudança apenas no mapeamento aparece no commit, nunca no hash. Quem investiga
> precisa saber que o hash não é exaustivo — está escrito aqui e vai para a especificação.

### O container calcula, não o inventário

Ler o hash de `jrxml_publicado` seria mais barato — um cálculo por deploy em vez de um por Execução —
e está errado pela mesma razão que vem se repetindo neste mapa: **falha aberta**.

Uma imagem subida sem rerodar `--publicar-inventario` faria toda Execução gravar o hash que o
inventário *alega*. O mecanismo passaria a produzir ficção exatamente no caso que ele existe para
pegar, e nada acusaria — o histórico simplesmente mentiria.

Calculando dos próprios beans, a Execução grava **o que de fato rodou**. E de brinde: divergir do
inventário **prova** que o inventário está obsoleto. Não há hoje nenhum outro sinal disso.

### Divergiu: registra e segue

Log mais métrica `inventario_divergente` com label de Código de Relatório (limitado por cadastro,
permitido pela regra do ticket 29), e o job vai até o fim.

O relatório produzido está **correto** — o container tem os beans e rodou com eles. O que está velho é
uma tabela de catálogo. Falhar destruiria trabalho bom por higiene de deploy, e ainda gravaria uma
linha `ERRO` terminal e imutável (ticket 02) registrando um problema **que não está nesta Execução**.

Mesma forma que o ticket 19 deu à divergência de versão do Jasper: **alerta sem recusar**.

Auto-cura — o container reescrever a linha do inventário — foi recusada por dois motivos: apaga a
única evidência de que um passo de deploy foi pulado, e exigiria dar à credencial de runtime escrita
numa tabela que pelo ticket 04 só o bootstrap escreve.

### O histórico é imutável, e o argumento não é filosófico

Nada reprocessa sozinho depois de um deploy. Cada Execução é o retrato fiel do que era verdade naquele
dia, e agora carrega o hash que prova qual definição a produziu.

Reprocessar a janela de retenção automaticamente parece higiene até se lembrar do ticket 20:
**`reprocessar` apaga a Execução anterior**. Um reprocesso automático faria de um deploy um destruidor
de histórico como efeito colateral — até 7 dias × N Relatórios, sem ninguém pedir, cada um consumindo
um container.

O ADMINISTRADOR tem `reprocessar` se quiser, uma data por vez, com motivo gravado.

### Derivado

- **Colunas em `execucao`**: `hash_definicao` e `imagem_origem`, ao lado de `versao_jasperreports`.
  **Não** dentro de `parametros_entrada` — o ticket 06 restringiu `jsonb` a parâmetros e detalhe de
  erro, e valor que se compara entre linhas é coluna, não documento.
- **As mesmas duas colunas em `jrxml_publicado`**, senão não há contra o quê comparar.
- **A entrada do hash precisa ser canônica**: ordem fixa dos rótulos (a declarada no bean, que o
  ticket 23 já torna significativa), encoding fixo, SQL tomado literalmente sem normalizar espaço. Um
  hash que muda por reordenação de `Map` viraria ruído puro e mataria o mecanismo em uma semana.
- **SHA-256**, porque o ticket 04 já o usa para Artefatos — nada novo entra na stack.
- **`hashDefinicao` e `imagemOrigem` no schema `Execucao` da API**, ao lado de `versaoJasperReports`
  (que já está lá, no protótipo do ticket 31). Dado de diagnóstico em lugar de diagnóstico: não
  aparece na listagem do relator, coerente com "registrar, não avisar".
- **Diretriz, não mecanismo**: mudança que altera o **significado** do relatório — outra população,
  outra métrica — deve ser Código novo, não versão nova. Aí a série histórica deixa de ser comparável
  de um jeito que hash nenhum conserta. Mudança de layout, coluna acrescentada, correção de rótulo
  seguem no mesmo Código.
- **"JRXML que some numa imagem nova" não é decidido aqui** — o ticket 21 já respondeu: publicação
  declarativa, o Relatório sai do inventário, o cadastro fica sinalizado, a fábrica para de gerar DAG.
