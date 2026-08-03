-- Semente FUNCIONAL do Produto Empréstimo.
-- Padrão do ticket 40: `setseed` fixo, datas relativas a CURRENT_DATE, janela de
-- 10 dias (maior que a retenção de 7 — achado do ticket 32).
--
-- A concentração de `dia_vencimento` em 5, 10, 15 e 20 é DELIBERADA: é a
-- sazonalidade deste domínio, e é o que faz o EMPRESTIMO-0002 ter volume
-- irregular sem que a duração dele varie (ticket 44).

SET search_path TO transacional_emprestimo;
SELECT setseed(0.42);

INSERT INTO produto_credito (codigo, nome, modalidade, taxa_juros_mes, prazo_maximo) VALUES
    (1, 'Consignado Servidor', 'CONSIGNADO',   0.0165, 96),
    (2, 'Crédito Pessoal',     'PESSOAL',      0.0489, 48),
    (3, 'Financiamento Auto',  'VEICULO',      0.0219, 60),
    (4, 'Capital de Giro',     'CAPITAL_GIRO', 0.0275, 36);

INSERT INTO contrato (id, numero, produto_codigo, tomador_id, tomador_nome,
                      data_contratacao, valor_contratado, saldo_devedor, prazo_meses,
                      dia_vencimento, situacao)
SELECT n,
       'CT' || lpad(n::text, 10, '0'),
       1 + (n % 4),
       n,
       'Tomador ' || lpad(n::text, 4, '0'),
       CURRENT_DATE - (60 + (n * 13) % 900),
       round((5000 + n * 830)::numeric, 2),
       round((3000 + n * 610)::numeric, 2),
       (ARRAY[24, 36, 48, 60])[1 + (n % 4)],
       -- Sazonalidade: 80% dos contratos vencem em 5, 10, 15 ou 20.
       CASE WHEN n % 5 = 0 THEN 1 + (n % 28)
            ELSE (ARRAY[5, 10, 15, 20])[1 + (n % 4)] END,
       CASE WHEN n % 23 = 0 THEN 'LIQUIDADO'
            WHEN n % 31 = 0 THEN 'RENEGOCIADO'
            ELSE 'ATIVO' END
FROM generate_series(1, 80) AS n;

INSERT INTO parcela (id, contrato_id, numero, data_vencimento, valor_principal,
                     valor_juros, situacao)
SELECT row_number() OVER (),
       ct.id, p,
       (date_trunc('month', CURRENT_DATE) - ((6 - p) || ' month')::interval)::date
           + (ct.dia_vencimento - 1),
       round((ct.valor_contratado / ct.prazo_meses)::numeric, 2),
       round((ct.saldo_devedor * 0.02)::numeric, 2),
       CASE WHEN p <= 4 THEN 'PAGA'
            WHEN p = 5 AND random() < 0.3 THEN 'PARCIAL'
            ELSE 'ABERTA' END
FROM contrato ct
CROSS JOIN generate_series(1, 6) AS p;

INSERT INTO pagamento (id, parcela_id, data_pagamento, valor, origem)
SELECT row_number() OVER (),
       pa.id,
       pa.data_vencimento + (floor(random() * 5))::int,
       CASE WHEN pa.situacao = 'PARCIAL'
            THEN round(((pa.valor_principal + pa.valor_juros) * 0.4)::numeric, 2)
            ELSE round((pa.valor_principal + pa.valor_juros)::numeric, 2) END,
       (ARRAY['DEBITO', 'BOLETO', 'PIX', 'CONSIGNACAO'])[1 + (pa.id % 4)]
FROM parcela pa
WHERE pa.situacao IN ('PAGA', 'PARCIAL');

INSERT INTO garantia (id, contrato_id, tipo, descricao, valor_avaliado)
SELECT ct.id, ct.id,
       (ARRAY['ALIENACAO', 'HIPOTECA', 'AVAL', 'CONSIGNACAO'])[1 + (ct.id % 4)],
       'Garantia gerada pela semente funcional',
       round((ct.valor_contratado * 1.3)::numeric, 2)
FROM contrato ct;

INSERT INTO renegociacao (id, contrato_origem_id, contrato_destino_id,
                          data_renegociacao, saldo_transferido, desconto_concedido)
SELECT row_number() OVER (), ct.id, ct.id + 1,
       CURRENT_DATE - ((ct.id * 7) % 10),
       round((ct.saldo_devedor * 0.9)::numeric, 2),
       round((ct.saldo_devedor * 0.05)::numeric, 2)
FROM contrato ct
WHERE ct.situacao = 'RENEGOCIADO' AND ct.id < 80;
