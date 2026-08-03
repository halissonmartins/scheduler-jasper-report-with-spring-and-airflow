-- Semente VOLUMÉTRICA — só no teste de cursor e no cenário de carga (k6).
--
-- Ela NÃO persegue volume de produção. O teste de cursor prova que a leitura
-- transmite em vez de bufferizar, e a forma barata e determinística de provar
-- isso é apertar o heap (`-Xmx96m` no surefire do teste) contra um volume que o
-- excede se bufferizado. Perseguir dezenas de milhões de linhas tornaria o teste
-- lento sem torná-lo mais conclusivo.
--
-- Pressupõe a semente funcional já carregada (agências e titulares).

SET search_path TO transacional_poupanca;
SELECT setseed(0.42);

-- 450 contas adicionais, todas ATIVAS, para o volume ficar concentrado.
INSERT INTO conta_poupanca
    (id, numero, digito, agencia_codigo, titular_id, data_abertura, situacao, dia_aniversario)
SELECT 1000 + n,
       20000 + n,
       n % 10,
       1 + (n % 3),
       1 + (n % 50),
       CURRENT_DATE - ((n * 7) % 3000),
       'ATIVA',
       1 + (n % 28)
FROM generate_series(1, 450) AS n;

-- ~1,8 milhão de lançamentos numa ÚNICA Data de Referência: é o recorte que o
-- POUPANCA-0001 faz, então o volume tem de estar todo no dia que a Coleta lê.
INSERT INTO lancamento (id, conta_id, data_movimento, tipo, valor, historico, documento)
SELECT 1000000 + row_number() OVER (),
       c.id,
       CURRENT_DATE - 1,
       (ARRAY['DEPOSITO', 'SAQUE', 'RENDIMENTO', 'TARIFA'])[1 + (floor(random() * 4))::int],
       round((random() * 4000 + 10)::numeric, 2),
       'Movimento gerado pela semente volumétrica com histórico longo o bastante '
           || 'para o registro ocupar espaço realista em memória',
       'DOC' || lpad((floor(random() * 999999))::int::text, 6, '0')
FROM conta_poupanca c
CROSS JOIN generate_series(1, 4000) AS r
WHERE c.id > 1000;

INSERT INTO saldo_diario (conta_id, data, saldo)
SELECT c.id, CURRENT_DATE - 1, round((random() * 90000 + 100)::numeric, 2)
FROM conta_poupanca c
WHERE c.id > 1000;
