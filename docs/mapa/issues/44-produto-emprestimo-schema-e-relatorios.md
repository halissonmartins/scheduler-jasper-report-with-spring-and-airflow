# 44 — Produto Empréstimo: schema transacional e os dois Relatórios de exemplo

Type: grilling
Status: resolved
Blocked by: —

## Question

Como é o schema transacional de Empréstimo, e como são os seus dois Relatórios de exemplo?

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

- **Quais tabelas modelam contratos, parcelas e inadimplência**, e o que nele é próprio o bastante para o schema não virar o de
  Poupança com outros nomes.
- **O que cada um dos dois Relatórios responde**, com Código `EMPRESTIMO-0001` e `EMPRESTIMO-0002`,
  nome, descrição e consulta.
- **O volume plausível** deste domínio, que decide se o analítico é de fato de alto volume — se não
  for, o par precisa de outra divisão de trabalho.
- **O tempo estimado sugerido** de cada um, e o cron do Produto: parcelas vencem em datas fixas, então o analítico tende a ter volume muito irregular ao longo do mês — o limiar de +20% do ticket 24 sobre uma média pode alertar todo dia 5.

## Notas do ticket 40 (primeiro Produto)

- **O risco aceito lá vale aqui, e é aqui que ele custa**: o schema rico de seis tabelas foi escolhido
  sabendo que semente e manutenção se multiplicam por cinco. Se o custo se mostrar alto neste ticket,
  vale registrar — é o sinal de que a decisão do ticket 40 precisa ser revisitada antes dos dois
  Produtos restantes, não depois.
- **A prova da fonte não se repete.** O teste de `ignore.missing.font=false` já existe no ticket 40 e
  guarda o empacotamento do monorepo inteiro. Este Produto não precisa de um segundo.

## Answer

Fecha os **cinco Produtos** do mapa.

### Artefatos escritos

| | |
|---|---|
| DDL | `relatorios-processador-emprestimo/src/main/resources/db/migration/V1__schema_transacional_emprestimo.sql` |
| Sementes | `.../src/test/resources/db/semente-funcional.sql`, `.../semente-volumetrica.sql` |
| JRXML | `.../src/main/resources/relatorios/EMPRESTIMO-0001.jrxml`, `.../EMPRESTIMO-0002.jrxml` |

### A sazonalidade existe, e foi posta onde não dirige o relógio

O ticket 41 previu que este seria o **pior caso** do limiar fixo de +20% do ticket 24: vencimentos se
concentram nos dias 5, 10, 15 e 20, então um `tempo_estimado` calibrado pela média alerta todo mês, e
calibrado pelo pico nunca alerta.

A saída não foi eliminar a sazonalidade — ela é propriedade real do domínio e está **modelada** (80%
dos contratos com `dia_vencimento` em 5, 10, 15 ou 20, tanto na semente funcional quanto na
volumétrica). A saída foi separar onde ela cai:

| | volume | duração |
|---|---|---|
| `EMPRESTIMO-0001` — Posição da Carteira | plano (todo contrato ativo) | estável |
| `EMPRESTIMO-0002` — Vencimentos do Dia | **espetado** (5× ao longo do mês) | dominada por custo fixo |

O sintético produz dezenas de linhas — produto × faixa de atraso — então uma variação de 5× no insumo
mal move o relógio. **O pico de dados não vira pico de duração**, e o limiar fixo do ticket 24 continua
correto nos dois Relatórios.

Não é evasão: o domínio mais sazonal do mapa entrega sazonalidade de verdade. Ela apenas não alimenta a
única métrica que ela quebraria.

### A lacuna do ticket 24 fica registrada, não corrigida

Sabe-se agora que **o ticket 24 não previu volume sazonal**. Nenhum dos dez Relatórios do mapa tem
duração sazonal, então tornar `tempo_estimado` um valor por dia do mês seria projetar para um caso que
não existe — ao custo de coluna nova, tela de cadastro, guarda do `LIMITE_ORFA` recalculada por dia e o
bean do ticket 21 sugerindo N valores.

Trocar o limiar fixo por percentil histórico foi recusado por ser exatamente o limiar adaptativo que o
ticket 24 já recusou, e pela razão que segue válida: ele acompanha a degradação gradual e nunca alerta.

**O que fica escrito no ticket 24**: o sintoma (`ALERTA` recorrente em datas previsíveis) e a saída a
tentar primeiro — **modelagem antes de mecanismo**, que é o que funcionou aqui, no ticket 42 e no
ticket 43.

### Os dois Relatórios

**`EMPRESTIMO-0001` — Posição da Carteira de Contratos**

```sql
SELECT pc.nome, ct.numero, ct.tomador_nome, ct.data_contratacao,
       ct.valor_contratado, ct.saldo_devedor,
       count(p.id) FILTER (WHERE p.situacao = 'PAGA')              AS parcelas_pagas,
       count(p.id) FILTER (WHERE p.situacao IN ('ABERTA','PARCIAL')) AS parcelas_abertas,
       coalesce(max(:dataReferencia - p.data_vencimento)
                FILTER (WHERE p.situacao IN ('ABERTA','PARCIAL')
                         AND p.data_vencimento < :dataReferencia), 0) AS dias_atraso,
       coalesce(max(g.valor_avaliado), 0)                           AS valor_garantia
  FROM contrato ct
  JOIN produto_credito pc ON pc.codigo = ct.produto_codigo
  LEFT JOIN parcela p     ON p.contrato_id = ct.id
  LEFT JOIN garantia g    ON g.contrato_id = ct.id
 WHERE ct.situacao = 'ATIVO'
 GROUP BY pc.nome, ct.numero, ct.tomador_nome, ct.data_contratacao,
          ct.valor_contratado, ct.saldo_devedor
 ORDER BY pc.nome, ct.numero
```

- Grupo por produto de crédito. Tempo estimado sugerido: **480 s**.
- Rótulos: `Produto`, `Contrato`, `Tomador`, `Data de Contratação`, `Valor Contratado`,
  `Saldo Devedor`, `Parcelas Pagas`, `Parcelas em Aberto`, `Dias de Atraso`, `Valor da Garantia`.

**`EMPRESTIMO-0002` — Vencimentos do Dia e Inadimplência por Faixa**: agrega por produto e faixa de
atraso, com os vencimentos da Data de Referência ao lado do estoque em atraso. Tempo estimado
sugerido: **40 s**.

- Rótulos: `Produto de Crédito`, `Faixa de Atraso`, `Parcelas Vencendo`, `Valor Vencendo`,
  `Parcelas em Atraso`, `Valor em Atraso`, `Percentual da Carteira`.

### O schema

`produto_credito`, `contrato`, `parcela`, `pagamento`, `garantia`, `renegociacao`.

- **`pagamento` é tabela separada de `parcela`**, porque uma parcela aceita pagamento **parcial e mais
  de um**. Colapsar os dois numa coluna `valor_pago` faria o relatório de inadimplência mentir na
  primeira amortização parcial — e mentir de forma otimista, que é a pior direção.
- **`renegociacao` guarda o contrato de origem**, então a carteira distingue crédito novo de dívida
  rolada. Sem isso o saldo cresce e ninguém sabe se é originação ou reciclagem. É o substrato próprio
  deste Produto — o papel de `remuneracao_mensal` (Poupança), `segmentacao` (Cliente),
  `limite_uso`/`tarifa` (Conta Corrente) e `lance` (Consórcio).

### Derivado

- **Cron `0 7 * * *`**, fechando o escalonamento 03–07 dos cinco Produtos fixado no ticket 41.
- **A semente volumétrica cresce `contrato`** — forma dos tickets 41 e 43. Dos cinco Produtos, três
  têm semente de carteira e dois têm semente concentrada numa data; ambos os formatos ficam com mais de
  um representante.
- **Índice `ix_parcela_vencimento`** serve ao sintético (recorte pelo dia) e
  **`ix_parcela_aberta`**, parcial, serve ao analítico (contagem de parcelas em aberto por contrato).
  São dois recortes diferentes da mesma tabela, e um índice só não atenderia bem os dois.
- **A prova da substituição de fonte não se repete** — vive no `POUPANCA-0002` (ticket 40) e guarda o
  empacotamento do monorepo inteiro.
