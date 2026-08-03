-- Semente VOLUMÉTRICA do Produto Empréstimo — só no teste de cursor e no k6.
--
-- Princípio do ticket 40: não persegue volume de produção; o teste roda com
-- `-Xmx96m` e o volume apenas o excede se a leitura bufferizar.
--
-- Forma: o EMPRESTIMO-0001 é a carteira de contratos, então o que cresce é
-- `contrato` — forma dos tickets 41 e 43. A sazonalidade dos vencimentos é
-- preservada, e é o que torna esta semente útil para observar que a duração do
-- analítico NÃO varia com ela.

SET search_path TO transacional_emprestimo;
SELECT setseed(0.42);

INSERT INTO contrato (id, numero, produto_codigo, tomador_id, tomador_nome,
                      data_contratacao, valor_contratado, saldo_devedor, prazo_meses,
                      dia_vencimento, situacao)
SELECT 1000 + n,
       'CTV' || lpad(n::text, 9, '0'),
       1 + (n % 4),
       1000 + n,
       'Tomador volumetrico com nome longo ' || lpad(n::text, 7, '0'),
       CURRENT_DATE - (60 + n % 900),
       round((5000 + (n % 400) * 830)::numeric, 2),
       round((3000 + (n % 400) * 610)::numeric, 2),
       (ARRAY[24, 36, 48, 60])[1 + (n % 4)],
       CASE WHEN n % 5 = 0 THEN 1 + (n % 28)
            ELSE (ARRAY[5, 10, 15, 20])[1 + (n % 4)] END,
       'ATIVO'
FROM generate_series(1, 500000) AS n;

-- Duas parcelas por contrato bastam: o analítico CONTA parcelas abertas, e o
-- que dimensiona a saída é o número de contratos.
INSERT INTO parcela (id, contrato_id, numero, data_vencimento, valor_principal,
                     valor_juros, situacao)
SELECT 1000000 + row_number() OVER (),
       ct.id, p,
       (date_trunc('month', CURRENT_DATE) - ((2 - p) || ' month')::interval)::date
           + (ct.dia_vencimento - 1),
       round((ct.valor_contratado / ct.prazo_meses)::numeric, 2),
       round((ct.saldo_devedor * 0.02)::numeric, 2),
       CASE WHEN p = 1 THEN 'PAGA' ELSE 'ABERTA' END
FROM contrato ct
CROSS JOIN generate_series(1, 2) AS p
WHERE ct.id > 1000;

INSERT INTO garantia (id, contrato_id, tipo, descricao, valor_avaliado)
SELECT ct.id, ct.id,
       (ARRAY['ALIENACAO', 'HIPOTECA', 'AVAL', 'CONSIGNACAO'])[1 + (ct.id % 4)],
       'Garantia gerada pela semente volumetrica',
       round((ct.valor_contratado * 1.3)::numeric, 2)
FROM contrato ct WHERE ct.id > 1000;
