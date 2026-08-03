# 41 — Produto Cliente: schema transacional e os dois Relatórios de exemplo

Type: grilling
Status: resolved
Blocked by: —

## Question

Como é o schema transacional de Cliente, e como são os seus dois Relatórios de exemplo?

Este ticket graduou da névoa quando o [ticket 40](40-primeiro-produto-schema-e-relatorios-de-exemplo.md)
fechou e **fixou o padrão**. Ele é replicação deliberada: não revela arquitetura nova, e por isso é
folha — nada depende dele, e ele pode rodar em paralelo com os outros três ou ser adiado sem travar o
destino.

O padrão a replicar, já decidido no ticket 40:

- **Schema autossuficiente**, cinco a seis tabelas, sem junção com outro Produto (ticket 04: a
  credencial deste módulo só lê o próprio schema). Cópias denormalizadas onde um sistema real teria FK
  para outro domínio.
- **Um Relatório analítico de alto volume + um sintético denso.** O analítico prova cursor, streaming,
  CSV volumoso e grade de bandas no XLSX; o sintético prova imagens, fontes e agregação.
- **Dois perfis de semente**, gerados com `generate_series` e `setseed`, com datas relativas a
  `CURRENT_DATE` e janela **maior que a retenção**.
- **Grade comum nos JRXML** (ticket 22) e `whenNoDataType` no default.
- **Rótulos do CSV em `List` ordenada** (ticket 37), `tempo_estimado` sugerido no bean (ticket 21),
  cron no cadastro do Produto (ticket 39).

O que este ticket precisa decidir, e é onde ele não é cópia:

- **Quais tabelas modelam cadastro e relacionamento de clientes**, e o que nele é próprio o bastante para o schema não virar o de
  Poupança com outros nomes.
- **O que cada um dos dois Relatórios responde**, com Código `CLIENTE-0001` e `CLIENTE-0002`,
  nome, descrição e consulta.
- **O volume plausível** deste domínio, que decide se o analítico é de fato de alto volume — se não
  for, o par precisa de outra divisão de trabalho.
- **O tempo estimado sugerido** de cada um, e o cron do Produto: cadastro tende a ser lido a qualquer hora, então o horário aqui compete menos com a disponibilidade da origem e mais com a janela do painel-resumo (ticket 29).

## Notas do ticket 40 (primeiro Produto)

- **O risco aceito lá vale aqui, e é aqui que ele custa**: o schema rico de seis tabelas foi escolhido
  sabendo que semente e manutenção se multiplicam por cinco. Se o custo se mostrar alto neste ticket,
  vale registrar — é o sinal de que a decisão do ticket 40 precisa ser revisitada antes dos dois
  Produtos restantes, não depois.
- **A prova da fonte não se repete.** O teste de `ignore.missing.font=false` já existe no ticket 40 e
  guarda o empacotamento do monorepo inteiro. Este Produto não precisa de um segundo.

## Answer

### Artefatos escritos

| | |
|---|---|
| DDL | `relatorios-processador-cliente/src/main/resources/db/migration/V1__schema_transacional_cliente.sql` |
| Sementes | `.../src/test/resources/db/semente-funcional.sql`, `.../semente-volumetrica.sql` |
| JRXML | `.../src/main/resources/relatorios/CLIENTE-0001.jrxml`, `.../CLIENTE-0002.jrxml` |

### O que este Produto trouxe de novo

É o primeiro Produto **cadastral** do mapa, e isso põe em xeque a metade "analítico de alto volume" do
padrão: um domínio cadastral não tem movimento diário com volume natural.

**`CLIENTE-0001` — Base Cadastral Completa** resolve isso sem forçar nada: todo cliente ativo, com
endereço principal, contato principal e segmentação vigente. É o que um produto cadastral de fato
produz — extrato regulatório, carga para CRM — e dá alto volume por construção.

```sql
SELECT c.id, c.nome, c.cpf_cnpj, c.tipo_pessoa, c.situacao,
       e.uf, e.municipio, ct.valor AS contato, s.segmento, s.score
  FROM cliente c
  LEFT JOIN endereco e    ON e.cliente_id = c.id  AND e.principal
  LEFT JOIN contato ct    ON ct.cliente_id = c.id AND ct.principal
  LEFT JOIN segmentacao s ON s.cliente_id = c.id  AND s.data_apuracao = :dataReferencia
 WHERE c.situacao = 'ATIVO'
 ORDER BY e.uf, c.id
```

- Grupo por UF. Tempo estimado sugerido: **300 s**.
- Rótulos do CSV, na ordem: `Código`, `Nome`, `CPF/CNPJ`, `Tipo de Pessoa`, `Situação`, `UF`,
  `Município`, `Contato Principal`, `Segmento`, `Score`.

**`CLIENTE-0002` — Distribuição da Base por Segmento e UF** (sintético, denso): agrega por UF ×
segmento × faixa de renda, com quantidade, renda média, score médio e percentual ativo. Tempo estimado
sugerido: **20 s**.

- Rótulos: `UF`, `Segmento`, `Faixa de Renda`, `Quantidade de Clientes`, `Renda Média Estimada`,
  `Score Médio`, `Percentual Ativo`.

`segmentacao` é o que dá substrato ao sintético — exatamente o papel que `remuneracao_mensal` cumpre em
Poupança. Sem ela o `CLIENTE-0002` cairia em "contar clientes por UF", e o par deixaria de exercitar a
formatação densa que é a razão de o sintético existir no padrão.

### O schema

`cliente`, `endereco`, `contato`, `documento`, `segmentacao`, `situacao_historico`.

Um `vinculo` autorreferente (sócio, representante, cônjuge) foi considerado e recusado: enriqueceria o
exemplo com uma estrutura que Poupança não tem, mas nenhum dos dois Relatórios decididos precisa dela —
seria tabela existindo para o schema parecer completo, com custo de semente real.

### Duas propriedades que valem mais que o exemplo

**1. O volume não varia com a Data de Referência.** O `CLIENTE-0001` lê a base inteira todo dia, então
a duração é estável por construção. Isso faz o limiar **fixo** de +20% do ticket 24 funcionar
especialmente bem aqui — e é o contraste exato do [ticket 44](44-produto-emprestimo-schema-e-relatorios.md),
onde parcelas vencem em datas fixas e o volume é espetado ao longo do mês.

Consequência para a semente volumétrica: o que precisa crescer é a tabela `cliente`, não o recorte de
uma data. É a primeira semente do mapa com essa forma.

**2. Sete cópias da base inteira no bucket.** Snapshot diário completo, com retenção global de 7 dias
(ticket 27). É o primeiro número concreto para a névoa de operação e capacidade, e um argumento a mais
para a métrica de ocupação do bucket que o ticket 27 já pedia — aqui ela deixa de ser diagnóstico de
lifecycle e vira dimensionamento.

### A restrição que este ticket descobriu

"Deltas diários + base completa mensal" é o desenho que um sistema real teria, e **não é expressável**:
o ticket 39 pôs o cron no cadastro do **Produto**, então os dois Relatórios de um Produto compartilham
frequência obrigatoriamente. Isso não estava escrito lá.

**Não reabre o ticket 39** — nenhum Produto decidido até agora precisa de frequências distintas, e a
`Base Cadastral Completa` diária é escolha legítima, não contorno. Mas fica anotado no ticket 39, para
que o próximo Produto que precise de duas frequências saiba que está diante de uma decisão de
arquitetura e não de exemplo.

### Derivado

- **Cron do Produto Cliente: `0 4 * * *`**, uma hora depois de Poupança. Registra-se o **escalonamento
  de uma hora por Produto** como padrão para os três restantes (05:00, 06:00, 07:00): com pool de 4
  slots (ticket 39), dez Coletas partindo juntas às 03:00 só formariam fila e fariam
  `coleta_partida_segundos` disparar. A janela 03–07 mantém "o dia" apertado o bastante para o
  painel-resumo do ticket 29 continuar respondendo "está tudo bem hoje?".
- **A prova da substituição de fonte não se repete.** Ela vive no `POUPANCA-0002` e guarda o
  empacotamento do monorepo inteiro; um segundo teste não acrescentaria cobertura.
- **Índice `ix_cliente_situacao`** em `(situacao, id)`: o analítico recorta por situação sobre a base
  inteira, e sem ele a Coleta lê e descarta os inativos linha a linha.
- **Índices parciais em `endereco` e `contato`** (`WHERE principal`): os dois `LEFT JOIN` do analítico
  batem exatamente neles, e sem os índices cada linha da base vira duas buscas completas.
