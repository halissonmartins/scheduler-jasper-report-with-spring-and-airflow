-- Schema transacional do Produto Cliente.
--
-- Segue o padrão fixado pelo ticket 40: autossuficiente (ticket 04 dá SELECT
-- apenas em `transacional_cliente`), sem junção com outro Produto.
--
-- Este é o primeiro Produto CADASTRAL do mapa: não há movimento diário. O
-- volume do relatório analítico vem da base inteira, não do recorte do dia.

CREATE SCHEMA IF NOT EXISTS transacional_cliente;
SET search_path TO transacional_cliente;

CREATE TABLE cliente (
    id             BIGINT       PRIMARY KEY,
    tipo_pessoa    CHAR(1)      NOT NULL CHECK (tipo_pessoa IN ('F', 'J')),
    nome           VARCHAR(120) NOT NULL,
    cpf_cnpj       VARCHAR(14)  NOT NULL UNIQUE,
    data_nascimento DATE,
    data_cadastro  DATE         NOT NULL,
    situacao       VARCHAR(12)  NOT NULL
        CHECK (situacao IN ('ATIVO', 'INATIVO', 'BLOQUEADO'))
);

-- O analítico recorta por situação sobre a base inteira; sem este índice a
-- Coleta lê e descarta os inativos linha a linha.
CREATE INDEX ix_cliente_situacao ON cliente (situacao, id);

CREATE TABLE endereco (
    id          BIGINT      PRIMARY KEY,
    cliente_id  BIGINT      NOT NULL REFERENCES cliente (id),
    tipo        VARCHAR(15) NOT NULL
        CHECK (tipo IN ('RESIDENCIAL', 'COMERCIAL', 'CORRESPONDENCIA')),
    logradouro  VARCHAR(120) NOT NULL,
    numero      VARCHAR(10),
    complemento VARCHAR(40),
    bairro      VARCHAR(60) NOT NULL,
    municipio   VARCHAR(60) NOT NULL,
    uf          CHAR(2)     NOT NULL,
    cep         CHAR(8)     NOT NULL,
    principal   BOOLEAN     NOT NULL DEFAULT false
);

CREATE INDEX ix_endereco_cliente ON endereco (cliente_id) WHERE principal;

CREATE TABLE contato (
    id         BIGINT       PRIMARY KEY,
    cliente_id BIGINT       NOT NULL REFERENCES cliente (id),
    tipo       VARCHAR(10)  NOT NULL CHECK (tipo IN ('EMAIL', 'TELEFONE', 'CELULAR')),
    valor      VARCHAR(120) NOT NULL,
    principal  BOOLEAN      NOT NULL DEFAULT false,
    verificado BOOLEAN      NOT NULL DEFAULT false
);

CREATE INDEX ix_contato_cliente ON contato (cliente_id) WHERE principal;

CREATE TABLE documento (
    id             BIGINT      PRIMARY KEY,
    cliente_id     BIGINT      NOT NULL REFERENCES cliente (id),
    tipo           VARCHAR(12) NOT NULL
        CHECK (tipo IN ('RG', 'CNH', 'PASSAPORTE', 'CONTRATO')),
    numero         VARCHAR(20) NOT NULL,
    orgao_emissor  VARCHAR(20),
    data_emissao   DATE,
    data_validade  DATE
);

-- É o que dá ao CLIENTE-0002 algo próprio para agregar — o papel que
-- `remuneracao_mensal` cumpre no Produto Poupança.
CREATE TABLE segmentacao (
    id             BIGINT         PRIMARY KEY,
    cliente_id     BIGINT         NOT NULL REFERENCES cliente (id),
    data_apuracao  DATE           NOT NULL,
    segmento       VARCHAR(15)    NOT NULL
        CHECK (segmento IN ('VAREJO', 'EXCLUSIVO', 'PRIVATE', 'EMPRESARIAL')),
    faixa_renda    VARCHAR(12)    NOT NULL,
    renda_estimada NUMERIC(15, 2) NOT NULL,
    score          SMALLINT       NOT NULL CHECK (score BETWEEN 0 AND 1000),
    UNIQUE (cliente_id, data_apuracao)
);

CREATE INDEX ix_segmentacao_data ON segmentacao (data_apuracao);

CREATE TABLE situacao_historico (
    id                BIGINT      PRIMARY KEY,
    cliente_id        BIGINT      NOT NULL REFERENCES cliente (id),
    data_mudanca      DATE        NOT NULL,
    situacao_anterior VARCHAR(12) NOT NULL,
    situacao_nova     VARCHAR(12) NOT NULL,
    motivo            VARCHAR(80) NOT NULL
);

CREATE INDEX ix_situacao_historico_data ON situacao_historico (data_mudanca);
