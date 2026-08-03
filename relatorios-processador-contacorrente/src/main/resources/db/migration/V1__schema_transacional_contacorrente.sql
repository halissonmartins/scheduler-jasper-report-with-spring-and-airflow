-- Schema transacional do Produto Conta Corrente.
--
-- Padrão do ticket 40: autossuficiente (ticket 04 dá SELECT apenas em
-- `transacional_contacorrente`), sem junção com outro Produto.
--
-- `agencia` aparece aqui DUPLICADA em relação ao Produto Poupança, de propósito.
-- É consequência direta do isolamento do ticket 04: cada Produto é
-- autossuficiente, então a rede de agências existe copiada em cada schema que
-- precise dela. Não é erro de modelagem — é o preço da fronteira de leitura, e
-- "consertar" isso com um schema compartilhado derrubaria o GRANT que sustenta
-- a segregação por Produto.

CREATE SCHEMA IF NOT EXISTS transacional_contacorrente;
SET search_path TO transacional_contacorrente;

CREATE TABLE agencia (
    codigo    SMALLINT     PRIMARY KEY,
    nome      VARCHAR(60)  NOT NULL,
    municipio VARCHAR(60)  NOT NULL,
    uf        CHAR(2)      NOT NULL
);

CREATE TABLE conta_corrente (
    id             BIGINT      PRIMARY KEY,
    numero         INTEGER     NOT NULL,
    digito         SMALLINT    NOT NULL,
    agencia_codigo SMALLINT    NOT NULL REFERENCES agencia (codigo),
    titular_id     BIGINT      NOT NULL,
    titular_nome   VARCHAR(120) NOT NULL,
    tipo_conta     CHAR(2)     NOT NULL CHECK (tipo_conta IN ('PF', 'PJ')),
    data_abertura  DATE        NOT NULL,
    situacao       VARCHAR(10) NOT NULL
        CHECK (situacao IN ('ATIVA', 'BLOQUEADA', 'ENCERRADA')),
    UNIQUE (agencia_codigo, numero)
);

CREATE INDEX ix_conta_situacao ON conta_corrente (situacao, id);

CREATE TABLE lancamento (
    id             BIGINT         PRIMARY KEY,
    conta_id       BIGINT         NOT NULL REFERENCES conta_corrente (id),
    data_movimento DATE           NOT NULL,
    natureza       CHAR(1)        NOT NULL CHECK (natureza IN ('D', 'C')),
    tipo           VARCHAR(12)    NOT NULL
        CHECK (tipo IN ('TED', 'PIX', 'BOLETO', 'CARTAO', 'TARIFA', 'JUROS')),
    valor          NUMERIC(15, 2) NOT NULL,
    historico      VARCHAR(80)    NOT NULL,
    documento      VARCHAR(20)
);

-- O CONTACORRENTE-0001 agrega os lançamentos do dia POR CONTA. Sem este índice
-- o resumo diário vira seq scan da maior tabela do mapa.
CREATE INDEX ix_lancamento_data_conta ON lancamento (data_movimento, conta_id);

CREATE TABLE saldo_diario (
    conta_id        BIGINT         NOT NULL REFERENCES conta_corrente (id),
    data            DATE           NOT NULL,
    saldo_inicial   NUMERIC(15, 2) NOT NULL,
    saldo_final     NUMERIC(15, 2) NOT NULL,
    saldo_bloqueado NUMERIC(15, 2) NOT NULL DEFAULT 0,
    PRIMARY KEY (conta_id, data)
);

CREATE INDEX ix_saldo_diario_data ON saldo_diario (data);

-- `limite_uso` e `tarifa` são o que faz conta corrente NÃO ser poupança, e são
-- o substrato próprio do CONTACORRENTE-0002 — mesmo papel de `remuneracao_mensal`
-- em Poupança e de `segmentacao` em Cliente.
CREATE TABLE limite_uso (
    conta_id           BIGINT         NOT NULL REFERENCES conta_corrente (id),
    data               DATE           NOT NULL,
    limite_contratado  NUMERIC(15, 2) NOT NULL,
    valor_utilizado    NUMERIC(15, 2) NOT NULL,
    juros_apurados     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    PRIMARY KEY (conta_id, data)
);

CREATE INDEX ix_limite_uso_data ON limite_uso (data);

CREATE TABLE tarifa (
    id             BIGINT         PRIMARY KEY,
    conta_id       BIGINT         NOT NULL REFERENCES conta_corrente (id),
    data_cobranca  DATE           NOT NULL,
    pacote         VARCHAR(20)    NOT NULL,
    valor_cobrado  NUMERIC(15, 2) NOT NULL,
    valor_isento   NUMERIC(15, 2) NOT NULL DEFAULT 0
);

CREATE INDEX ix_tarifa_data ON tarifa (data_cobranca);
