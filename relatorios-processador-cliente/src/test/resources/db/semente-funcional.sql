-- Semente FUNCIONAL do Produto Cliente — carregada em todo teste de integração.
-- Mesmo padrão do ticket 40: `setseed` fixa o gerador, as datas flutuam com
-- CURRENT_DATE, e a janela é de 10 dias (maior que a retenção de 7, senão o
-- estado "expirado" não existe nos dados — achado do ticket 32).

SET search_path TO transacional_cliente;
SELECT setseed(0.42);

INSERT INTO cliente (id, tipo_pessoa, nome, cpf_cnpj, data_nascimento, data_cadastro, situacao)
SELECT n,
       CASE WHEN n % 7 = 0 THEN 'J' ELSE 'F' END,
       CASE WHEN n % 7 = 0 THEN 'Empresa ' || lpad(n::text, 3, '0') || ' Ltda'
            ELSE 'Cliente ' || lpad(n::text, 3, '0') END,
       lpad(((n * 8737) % 100000000000)::text, 11, '0'),
       CASE WHEN n % 7 = 0 THEN NULL ELSE DATE '1960-01-01' + ((n * 137) % 14000) END,
       CURRENT_DATE - ((n * 31) % 4000),
       CASE WHEN n % 20 = 0 THEN 'INATIVO'
            WHEN n % 33 = 0 THEN 'BLOQUEADO'
            ELSE 'ATIVO' END
FROM generate_series(1, 120) AS n;

INSERT INTO endereco (id, cliente_id, tipo, logradouro, numero, bairro, municipio, uf, cep, principal)
SELECT n, n, 'RESIDENCIAL',
       'Rua das Flores', (100 + n)::text, 'Centro',
       (ARRAY['Belo Horizonte', 'São Paulo', 'Curitiba', 'Recife'])[1 + (n % 4)],
       (ARRAY['MG', 'SP', 'PR', 'PE'])[1 + (n % 4)],
       lpad(((n * 1301) % 100000000)::text, 8, '0'),
       true
FROM generate_series(1, 120) AS n;

INSERT INTO contato (id, cliente_id, tipo, valor, principal, verificado)
SELECT n, n, 'EMAIL', 'cliente' || n || '@exemplo.test', true, n % 3 <> 0
FROM generate_series(1, 120) AS n;

INSERT INTO documento (id, cliente_id, tipo, numero, orgao_emissor, data_emissao, data_validade)
SELECT n, n,
       CASE WHEN n % 7 = 0 THEN 'CONTRATO' ELSE 'RG' END,
       lpad(((n * 4441) % 1000000000)::text, 9, '0'),
       'SSP', CURRENT_DATE - ((n * 53) % 5000), CURRENT_DATE + ((n * 11) % 3000)
FROM generate_series(1, 120) AS n;

INSERT INTO segmentacao (id, cliente_id, data_apuracao, segmento, faixa_renda, renda_estimada, score)
SELECT row_number() OVER (),
       c.id,
       CURRENT_DATE - d,
       (ARRAY['VAREJO', 'EXCLUSIVO', 'PRIVATE', 'EMPRESARIAL'])[1 + (c.id % 4)],
       (ARRAY['ATE_3SM', 'DE_3_A_10SM', 'DE_10_A_30SM', 'ACIMA_30SM'])[1 + (c.id % 4)],
       round((random() * 45000 + 1500)::numeric, 2),
       (200 + floor(random() * 800))::smallint
FROM generate_series(0, 9) AS d
CROSS JOIN cliente c;

INSERT INTO situacao_historico
    (id, cliente_id, data_mudanca, situacao_anterior, situacao_nova, motivo)
SELECT row_number() OVER (), c.id, CURRENT_DATE - ((c.id * 13) % 10),
       'ATIVO', c.situacao, 'Ajuste gerado pela semente funcional'
FROM cliente c
WHERE c.situacao <> 'ATIVO';
