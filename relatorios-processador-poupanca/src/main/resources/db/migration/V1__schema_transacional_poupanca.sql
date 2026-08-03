-- Schema transacional do Produto Poupança.
--
-- Autossuficiente por decisão do ticket 04: a credencial deste módulo tem SELECT
-- apenas em `transacional_poupanca`, então não há junção com o Produto Cliente.
-- `titular` é cópia denormalizada, e não uma FK para outro schema.

CREATE SCHEMA IF NOT EXISTS transacional_poupanca;
SET search_path TO transacional_poupanca;

CREATE TABLE agencia (
    codigo    SMALLINT     PRIMARY KEY,
    nome      VARCHAR(60)  NOT NULL,
    municipio VARCHAR(60)  NOT NULL,
    uf        CHAR(2)      NOT NULL
);

CREATE TABLE titular (
    id              BIGINT       PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    cpf_cnpj        VARCHAR(14)  NOT NULL,
    data_nascimento DATE         NOT NULL
);

CREATE TABLE conta_poupanca (
    id              BIGINT      PRIMARY KEY,
    numero          INTEGER     NOT NULL,
    digito          SMALLINT    NOT NULL,
    agencia_codigo  SMALLINT    NOT NULL REFERENCES agencia (codigo),
    titular_id      BIGINT      NOT NULL REFERENCES titular (id),
    data_abertura   DATE        NOT NULL,
    situacao        VARCHAR(10) NOT NULL
        CHECK (situacao IN ('ATIVA', 'BLOQUEADA', 'ENCERRADA')),
    -- Dia do mês em que a conta rende. É o que faz este schema ser Poupança e
    -- não um razão genérico, e é a dimensão que o POUPANCA-0002 agrega.
    dia_aniversario SMALLINT    NOT NULL CHECK (dia_aniversario BETWEEN 1 AND 28),
    UNIQUE (agencia_codigo, numero)
);

CREATE TABLE lancamento (
    id             BIGINT         PRIMARY KEY,
    conta_id       BIGINT         NOT NULL REFERENCES conta_poupanca (id),
    data_movimento DATE           NOT NULL,
    tipo           VARCHAR(10)    NOT NULL
        CHECK (tipo IN ('DEPOSITO', 'SAQUE', 'RENDIMENTO', 'TARIFA')),
    valor          NUMERIC(15, 2) NOT NULL,
    historico      VARCHAR(80)    NOT NULL,
    documento      VARCHAR(20)
);

-- O POUPANCA-0001 recorta exatamente por esta coluna, e a ordenação do relatório
-- é (agência, conta). Sem este índice a Coleta de alto volume vira seq scan da
-- tabela inteira mais sort em disco.
CREATE INDEX ix_lancamento_data ON lancamento (data_movimento, conta_id);

CREATE TABLE remuneracao_mensal (
    id               BIGINT         PRIMARY KEY,
    conta_id         BIGINT         NOT NULL REFERENCES conta_poupanca (id),
    data_aniversario DATE           NOT NULL,
    base_calculo     NUMERIC(15, 2) NOT NULL,
    taxa_tr          NUMERIC(9, 6)  NOT NULL,
    taxa_juros       NUMERIC(9, 6)  NOT NULL,
    valor_creditado  NUMERIC(15, 2) NOT NULL,
    UNIQUE (conta_id, data_aniversario)
);

CREATE INDEX ix_remuneracao_data ON remuneracao_mensal (data_aniversario);

CREATE TABLE saldo_diario (
    conta_id BIGINT         NOT NULL REFERENCES conta_poupanca (id),
    data     DATE           NOT NULL,
    saldo    NUMERIC(15, 2) NOT NULL,
    PRIMARY KEY (conta_id, data)
);

CREATE INDEX ix_saldo_diario_data ON saldo_diario (data);
