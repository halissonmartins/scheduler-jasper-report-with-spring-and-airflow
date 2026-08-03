-- Semente VOLUMÉTRICA do Produto Cliente — só no teste de cursor e no k6.
--
-- Mesmo princípio do ticket 40: não persegue volume de produção. O teste roda
-- com `-Xmx96m` e o volume aqui apenas o excede se a leitura bufferizar.
--
-- Diferença em relação a Poupança, e é a propriedade que este Produto traz: o
-- volume NÃO se concentra numa Data de Referência. O CLIENTE-0001 lê a base
-- inteira todo dia, então o que precisa crescer é a tabela `cliente`.

SET search_path TO transacional_cliente;
SELECT setseed(0.42);

INSERT INTO cliente (id, tipo_pessoa, nome, cpf_cnpj, data_nascimento, data_cadastro, situacao)
SELECT 1000 + n,
       CASE WHEN n % 7 = 0 THEN 'J' ELSE 'F' END,
       'Cliente volumetrico ' || lpad(n::text, 7, '0'),
       lpad(((n * 8737 + 77) % 100000000000)::text, 11, '0'),
       DATE '1960-01-01' + (n % 14000),
       CURRENT_DATE - (n % 4000),
       'ATIVO'
FROM generate_series(1, 600000) AS n;

INSERT INTO endereco (id, cliente_id, tipo, logradouro, numero, bairro, municipio, uf, cep, principal)
SELECT 1000 + n, 1000 + n, 'RESIDENCIAL',
       'Avenida Volumetrica com nome longo o bastante para o registro ocupar espaco realista',
       (100 + n % 9000)::text, 'Distrito Industrial',
       (ARRAY['Belo Horizonte', 'São Paulo', 'Curitiba', 'Recife'])[1 + (n % 4)],
       (ARRAY['MG', 'SP', 'PR', 'PE'])[1 + (n % 4)],
       lpad(((n * 1301) % 100000000)::text, 8, '0'),
       true
FROM generate_series(1, 600000) AS n;

INSERT INTO contato (id, cliente_id, tipo, valor, principal, verificado)
SELECT 1000 + n, 1000 + n, 'EMAIL', 'volumetrico' || n || '@exemplo.test', true, true
FROM generate_series(1, 600000) AS n;

INSERT INTO segmentacao (id, cliente_id, data_apuracao, segmento, faixa_renda, renda_estimada, score)
SELECT 1000 + n, 1000 + n, CURRENT_DATE - 1,
       (ARRAY['VAREJO', 'EXCLUSIVO', 'PRIVATE', 'EMPRESARIAL'])[1 + (n % 4)],
       (ARRAY['ATE_3SM', 'DE_3_A_10SM', 'DE_10_A_30SM', 'ACIMA_30SM'])[1 + (n % 4)],
       round((random() * 45000 + 1500)::numeric, 2),
       (200 + floor(random() * 800))::smallint
FROM generate_series(1, 600000) AS n;
