-- Semente VOLUMÉTRICA do Produto Consórcio — só no teste de cursor e no k6.
--
-- Princípio do ticket 40: não persegue volume de produção; o teste roda com
-- `-Xmx96m` e o volume apenas o excede se a leitura bufferizar.
--
-- Forma deste Produto: o CONSORCIO-0001 é fotografia da carteira de cotas, então
-- o que precisa crescer é `cota` — mesma forma da semente do ticket 41 (Cliente),
-- e não a do ticket 40 (Poupança), que concentra numa data.

SET search_path TO transacional_consorcio;
SELECT setseed(0.42);

INSERT INTO grupo (codigo, bem_referencia, valor_credito, prazo_meses,
                   taxa_administracao, data_constituicao, dia_assembleia, situacao)
SELECT 1000 + n,
       'Grupo volumetrico ' || lpad(n::text, 4, '0'),
       round((40000 + n * 250)::numeric, 2),
       (ARRAY[60, 80, 100, 180])[1 + (n % 4)],
       0.1800,
       CURRENT_DATE - (400 + n),
       1 + (n % 28),
       'ATIVO'
FROM generate_series(1, 800) AS n;

-- 800 grupos × 500 cotas = 400 mil cotas ativas.
INSERT INTO cota (id, grupo_codigo, numero, consorciado_id, consorciado_nome,
                  data_adesao, situacao, percentual_pago)
SELECT 100000 + row_number() OVER (),
       g.codigo, c,
       100000 + row_number() OVER (),
       'Consorciado volumetrico com nome longo o bastante ' || lpad(c::text, 6, '0'),
       CURRENT_DATE - (300 + (c * 3) % 300),
       'ATIVA',
       round((random() * 95 + 2)::numeric, 3)
FROM grupo g
CROSS JOIN generate_series(1, 500) AS c
WHERE g.codigo > 1000;

-- Uma parcela paga por cota basta: o analítico conta pagas, não as lê todas.
INSERT INTO parcela (id, cota_id, numero, data_vencimento, data_pagamento,
                     valor_devido, valor_pago)
SELECT 100000 + row_number() OVER (),
       ct.id, 1,
       CURRENT_DATE - 30, CURRENT_DATE - 28,
       round((random() * 900 + 300)::numeric, 2),
       round((random() * 900 + 300)::numeric, 2)
FROM cota ct
WHERE ct.id > 100000;
