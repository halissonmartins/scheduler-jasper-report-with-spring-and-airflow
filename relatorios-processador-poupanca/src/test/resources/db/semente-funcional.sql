-- Semente FUNCIONAL — carregada em todo teste de integração.
--
-- Determinismo: `setseed` fixa o gerador, então as contagens e os valores são os
-- mesmos a cada execução. As DATAS flutuam com `CURRENT_DATE` de propósito — os
-- testes afirmam contagens, e a Data de Referência é sempre parâmetro explícito
-- (ticket 20). Datas fixas envelheceriam e passariam a cair fora de qualquer
-- janela de retenção.
--
-- A janela é de 10 dias, não 7: o ticket 32 descobriu no protótipo que, com uma
-- janela igual à retenção, o estado "expirado" simplesmente não existe nos dados
-- de teste — e é um dos quatro estados que a tela precisa mostrar.

SET search_path TO transacional_poupanca;
SELECT setseed(0.42);

INSERT INTO agencia (codigo, nome, municipio, uf) VALUES
    (1, 'Centro',        'Belo Horizonte', 'MG'),
    (2, 'Savassi',       'Belo Horizonte', 'MG'),
    (3, 'Barra Funda',   'São Paulo',      'SP');

INSERT INTO titular (id, nome, cpf_cnpj, data_nascimento)
SELECT n,
       'Titular ' || lpad(n::text, 3, '0'),
       lpad(((n * 8737) % 100000000000)::text, 11, '0'),
       DATE '1960-01-01' + ((n * 137) % 14000)
FROM generate_series(1, 50) AS n;

INSERT INTO conta_poupanca
    (id, numero, digito, agencia_codigo, titular_id, data_abertura, situacao, dia_aniversario)
SELECT n,
       10000 + n,
       n % 10,
       1 + (n % 3),
       n,
       CURRENT_DATE - ((n * 29) % 3000),
       CASE WHEN n % 25 = 0 THEN 'ENCERRADA'
            WHEN n % 17 = 0 THEN 'BLOQUEADA'
            ELSE 'ATIVA' END,
       1 + (n % 28)
FROM generate_series(1, 50) AS n;

-- ~2 mil lançamentos distribuídos em 10 datas.
INSERT INTO lancamento (id, conta_id, data_movimento, tipo, valor, historico, documento)
SELECT row_number() OVER (),
       c.id,
       CURRENT_DATE - d,
       (ARRAY['DEPOSITO', 'SAQUE', 'RENDIMENTO', 'TARIFA'])[1 + (floor(random() * 4))::int],
       round((random() * 4000 + 10)::numeric, 2),
       'Movimento gerado pela semente funcional',
       'DOC' || lpad((floor(random() * 999999))::int::text, 6, '0')
FROM generate_series(0, 9) AS d
CROSS JOIN conta_poupanca c
CROSS JOIN generate_series(1, 4) AS r
WHERE c.situacao = 'ATIVA';

INSERT INTO saldo_diario (conta_id, data, saldo)
SELECT c.id,
       CURRENT_DATE - d,
       round((random() * 90000 + 100)::numeric, 2)
FROM generate_series(0, 9) AS d
CROSS JOIN conta_poupanca c;

INSERT INTO remuneracao_mensal
    (id, conta_id, data_aniversario, base_calculo, taxa_tr, taxa_juros, valor_creditado)
SELECT row_number() OVER (),
       c.id,
       (date_trunc('month', CURRENT_DATE) - (m || ' month')::interval)::date
           + (c.dia_aniversario - 1),
       b.base,
       0.000800,
       0.005000,
       round(b.base * 0.005800, 2)
FROM generate_series(0, 2) AS m
CROSS JOIN conta_poupanca c
CROSS JOIN LATERAL (SELECT round((random() * 90000 + 100)::numeric, 2) AS base) b
WHERE c.situacao = 'ATIVA';
