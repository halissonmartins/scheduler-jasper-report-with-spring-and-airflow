-- Semente VOLUMÉTRICA do Produto Conta Corrente — a maior do mapa.
--
-- Princípio do ticket 40: não persegue volume de produção; o teste roda com
-- `-Xmx96m` e o volume apenas o excede se a leitura bufferizar.
--
-- Forma própria deste Produto: o CONTACORRENTE-0001 agrega POR CONTA, então a
-- cardinalidade da SAÍDA é o número de contas, e a do INSUMO é o número de
-- lançamentos. As duas precisam crescer, e por razões diferentes — a primeira
-- dimensiona o `.jrprint`, a segunda dimensiona a leitura.

SET search_path TO transacional_contacorrente;
SELECT setseed(0.42);

INSERT INTO conta_corrente
    (id, numero, digito, agencia_codigo, titular_id, titular_nome, tipo_conta,
     data_abertura, situacao)
SELECT 1000 + n, 40000 + n, n % 10, 1 + (n % 3), 1000 + n,
       'Correntista volumetrico ' || lpad(n::text, 7, '0'),
       CASE WHEN n % 6 = 0 THEN 'PJ' ELSE 'PF' END,
       CURRENT_DATE - (n % 3600),
       'ATIVA'
FROM generate_series(1, 300000) AS n;

-- ~1,5 milhão de lançamentos na Data de Referência (5 por conta), que o resumo
-- reduz a 300 mil linhas de saída.
INSERT INTO lancamento
    (id, conta_id, data_movimento, natureza, tipo, valor, historico, documento)
SELECT 1000000 + row_number() OVER (),
       c.id,
       CURRENT_DATE - 1,
       CASE WHEN random() < 0.5 THEN 'D' ELSE 'C' END,
       (ARRAY['TED', 'PIX', 'BOLETO', 'CARTAO', 'TARIFA', 'JUROS'])[1 + (floor(random() * 6))::int],
       round((random() * 6000 + 5)::numeric, 2),
       'Movimento gerado pela semente volumetrica com historico longo o bastante '
           || 'para o registro ocupar espaco realista em memoria',
       'DOC' || lpad((floor(random() * 999999))::int::text, 6, '0')
FROM conta_corrente c
CROSS JOIN generate_series(1, 5) AS r
WHERE c.id > 1000;

INSERT INTO saldo_diario (conta_id, data, saldo_inicial, saldo_final, saldo_bloqueado)
SELECT c.id, CURRENT_DATE - 1,
       round((random() * 40000 - 5000)::numeric, 2),
       round((random() * 40000 - 5000)::numeric, 2),
       0
FROM conta_corrente c WHERE c.id > 1000;

INSERT INTO limite_uso (conta_id, data, limite_contratado, valor_utilizado, juros_apurados)
SELECT c.id, CURRENT_DATE - 1,
       round((random() * 20000 + 1000)::numeric, 2),
       round((random() * 8000)::numeric, 2),
       round((random() * 90)::numeric, 2)
FROM conta_corrente c WHERE c.id > 1000;

INSERT INTO tarifa (id, conta_id, data_cobranca, pacote, valor_cobrado, valor_isento)
SELECT 1000000 + row_number() OVER (), c.id, CURRENT_DATE - 1,
       (ARRAY['BASICO', 'INTERMEDIARIO', 'COMPLETO'])[1 + (c.id % 3)],
       round((random() * 60 + 5)::numeric, 2), 0
FROM conta_corrente c WHERE c.id > 1000;
