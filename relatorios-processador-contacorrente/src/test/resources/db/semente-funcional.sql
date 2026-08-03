-- Semente FUNCIONAL do Produto Conta Corrente.
-- Padrão do ticket 40: `setseed` fixo, datas relativas a CURRENT_DATE, janela de
-- 10 dias (maior que a retenção de 7 — achado do ticket 32).

SET search_path TO transacional_contacorrente;
SELECT setseed(0.42);

INSERT INTO agencia (codigo, nome, municipio, uf) VALUES
    (1, 'Centro',      'Belo Horizonte', 'MG'),
    (2, 'Savassi',     'Belo Horizonte', 'MG'),
    (3, 'Barra Funda', 'São Paulo',      'SP');

INSERT INTO conta_corrente
    (id, numero, digito, agencia_codigo, titular_id, titular_nome, tipo_conta,
     data_abertura, situacao)
SELECT n, 30000 + n, n % 10, 1 + (n % 3), n,
       CASE WHEN n % 6 = 0 THEN 'Empresa ' || lpad(n::text, 3, '0') || ' Ltda'
            ELSE 'Correntista ' || lpad(n::text, 3, '0') END,
       CASE WHEN n % 6 = 0 THEN 'PJ' ELSE 'PF' END,
       CURRENT_DATE - ((n * 23) % 3600),
       CASE WHEN n % 22 = 0 THEN 'ENCERRADA'
            WHEN n % 15 = 0 THEN 'BLOQUEADA'
            ELSE 'ATIVA' END
FROM generate_series(1, 60) AS n;

INSERT INTO lancamento
    (id, conta_id, data_movimento, natureza, tipo, valor, historico, documento)
SELECT row_number() OVER (),
       c.id,
       CURRENT_DATE - d,
       CASE WHEN random() < 0.5 THEN 'D' ELSE 'C' END,
       (ARRAY['TED', 'PIX', 'BOLETO', 'CARTAO', 'TARIFA', 'JUROS'])[1 + (floor(random() * 6))::int],
       round((random() * 6000 + 5)::numeric, 2),
       'Movimento gerado pela semente funcional',
       'DOC' || lpad((floor(random() * 999999))::int::text, 6, '0')
FROM generate_series(0, 9) AS d
CROSS JOIN conta_corrente c
CROSS JOIN generate_series(1, 6) AS r
WHERE c.situacao = 'ATIVA';

INSERT INTO saldo_diario (conta_id, data, saldo_inicial, saldo_final, saldo_bloqueado)
SELECT c.id, CURRENT_DATE - d,
       round((random() * 40000 - 5000)::numeric, 2),
       round((random() * 40000 - 5000)::numeric, 2),
       round((random() * 500)::numeric, 2)
FROM generate_series(0, 9) AS d
CROSS JOIN conta_corrente c;

INSERT INTO limite_uso (conta_id, data, limite_contratado, valor_utilizado, juros_apurados)
SELECT c.id, CURRENT_DATE - d,
       round((random() * 20000 + 1000)::numeric, 2),
       round((random() * 8000)::numeric, 2),
       round((random() * 90)::numeric, 2)
FROM generate_series(0, 9) AS d
CROSS JOIN conta_corrente c
WHERE c.situacao = 'ATIVA';

INSERT INTO tarifa (id, conta_id, data_cobranca, pacote, valor_cobrado, valor_isento)
SELECT row_number() OVER (), c.id, CURRENT_DATE - d,
       (ARRAY['BASICO', 'INTERMEDIARIO', 'COMPLETO'])[1 + (c.id % 3)],
       round((random() * 60 + 5)::numeric, 2),
       round((random() * 20)::numeric, 2)
FROM generate_series(0, 9) AS d
CROSS JOIN conta_corrente c
WHERE c.situacao = 'ATIVA';
