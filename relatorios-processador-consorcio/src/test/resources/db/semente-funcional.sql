-- Semente FUNCIONAL do Produto Consórcio.
-- Padrão do ticket 40: `setseed` fixo, datas relativas a CURRENT_DATE, janela de
-- 10 dias (maior que a retenção de 7 — achado do ticket 32).
--
-- Os `dia_assembleia` são espalhados de propósito: é o que faz haver assembleia
-- em vários dias distintos da janela, reproduzindo a propriedade que dissolve a
-- mensalidade (ticket 43).

SET search_path TO transacional_consorcio;
SELECT setseed(0.42);

INSERT INTO grupo (codigo, bem_referencia, valor_credito, prazo_meses,
                   taxa_administracao, data_constituicao, dia_assembleia, situacao)
SELECT 100 + n,
       (ARRAY['Automóvel Popular', 'Automóvel Executivo', 'Imóvel Urbano',
              'Motocicleta', 'Serviços'])[1 + (n % 5)],
       round((40000 + n * 9500)::numeric, 2),
       (ARRAY[60, 80, 100, 180])[1 + (n % 4)],
       0.1800,
       CURRENT_DATE - (400 + n * 17),
       1 + (n % 10),
       'ATIVO'
FROM generate_series(1, 12) AS n;

INSERT INTO cota (id, grupo_codigo, numero, consorciado_id, consorciado_nome,
                  data_adesao, situacao, percentual_pago)
SELECT row_number() OVER (),
       g.codigo,
       c,
       row_number() OVER (),
       'Consorciado ' || lpad((row_number() OVER ())::text, 4, '0'),
       CURRENT_DATE - (300 + (c * 7) % 300),
       CASE WHEN c % 19 = 0 THEN 'CANCELADA'
            WHEN c % 11 = 0 THEN 'CONTEMPLADA'
            WHEN c % 37 = 0 THEN 'QUITADA'
            ELSE 'ATIVA' END,
       round((random() * 95 + 2)::numeric, 3)
FROM grupo g
CROSS JOIN generate_series(1, 25) AS c;

INSERT INTO parcela (id, cota_id, numero, data_vencimento, data_pagamento,
                     valor_devido, valor_pago)
SELECT row_number() OVER (),
       ct.id, p,
       CURRENT_DATE - (p * 30),
       CASE WHEN random() < 0.9 THEN CURRENT_DATE - (p * 30) + 2 ELSE NULL END,
       round((random() * 900 + 300)::numeric, 2),
       CASE WHEN random() < 0.9 THEN round((random() * 900 + 300)::numeric, 2) ELSE NULL END
FROM cota ct
CROSS JOIN generate_series(1, 6) AS p;

INSERT INTO assembleia (id, grupo_codigo, numero, data_realizacao, fundo_comum, fundo_reserva)
SELECT row_number() OVER (),
       g.codigo,
       (d + 1)::smallint,
       CURRENT_DATE - d,
       round((random() * 400000 + 50000)::numeric, 2),
       round((random() * 40000 + 5000)::numeric, 2)
FROM grupo g
CROSS JOIN generate_series(0, 9) AS d
WHERE (g.codigo + d) % 4 = 0;

INSERT INTO contemplacao (id, assembleia_id, cota_id, modalidade, valor_lance, percentual_lance)
SELECT row_number() OVER (),
       a.id,
       ct.id,
       (ARRAY['SORTEIO', 'LANCE_LIVRE', 'LANCE_FIXO'])[1 + (ct.id % 3)],
       CASE WHEN ct.id % 3 = 0 THEN NULL ELSE round((random() * 30000 + 2000)::numeric, 2) END,
       CASE WHEN ct.id % 3 = 0 THEN NULL ELSE round((random() * 45 + 5)::numeric, 3) END
FROM assembleia a
JOIN LATERAL (
    SELECT id FROM cota WHERE grupo_codigo = a.grupo_codigo ORDER BY id LIMIT 2
) ct ON true;

INSERT INTO lance (id, assembleia_id, cota_id, valor, percentual, vencedor)
SELECT row_number() OVER (),
       a.id, ct.id,
       round((random() * 30000 + 1000)::numeric, 2),
       round((random() * 45 + 3)::numeric, 3),
       false
FROM assembleia a
JOIN LATERAL (
    SELECT id FROM cota WHERE grupo_codigo = a.grupo_codigo ORDER BY id DESC LIMIT 5
) ct ON true;
