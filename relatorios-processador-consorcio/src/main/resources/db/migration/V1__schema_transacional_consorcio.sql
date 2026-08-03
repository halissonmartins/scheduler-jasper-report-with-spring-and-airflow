-- Schema transacional do Produto Consórcio.
--
-- Padrão do ticket 40: autossuficiente (ticket 04 dá SELECT apenas em
-- `transacional_consorcio`), sem junção com outro Produto.
--
-- O ciclo do negócio é MENSAL (assembleia), mas o agendamento é diário. A
-- tensão se dissolve porque a assembleia é propriedade do GRUPO, não da
-- carteira: com centenas de grupos há assembleia todo dia útil. O evento mensal
-- entra como coluna datada no CONSORCIO-0002, e não como frequência própria.

CREATE SCHEMA IF NOT EXISTS transacional_consorcio;
SET search_path TO transacional_consorcio;

CREATE TABLE grupo (
    codigo             INTEGER        PRIMARY KEY,
    bem_referencia     VARCHAR(80)    NOT NULL,
    valor_credito      NUMERIC(15, 2) NOT NULL,
    prazo_meses        SMALLINT       NOT NULL,
    taxa_administracao NUMERIC(6, 4)  NOT NULL,
    data_constituicao  DATE           NOT NULL,
    dia_assembleia     SMALLINT       NOT NULL CHECK (dia_assembleia BETWEEN 1 AND 28),
    situacao           VARCHAR(12)    NOT NULL
        CHECK (situacao IN ('EM_FORMACAO', 'ATIVO', 'ENCERRADO'))
);

CREATE TABLE cota (
    id               BIGINT       PRIMARY KEY,
    grupo_codigo     INTEGER      NOT NULL REFERENCES grupo (codigo),
    numero           INTEGER      NOT NULL,
    consorciado_id   BIGINT       NOT NULL,
    consorciado_nome VARCHAR(120) NOT NULL,
    data_adesao      DATE         NOT NULL,
    situacao         VARCHAR(12)  NOT NULL
        CHECK (situacao IN ('ATIVA', 'CONTEMPLADA', 'CANCELADA', 'QUITADA')),
    percentual_pago  NUMERIC(6, 3) NOT NULL DEFAULT 0,
    UNIQUE (grupo_codigo, numero)
);

CREATE INDEX ix_cota_situacao ON cota (situacao, grupo_codigo, numero);

CREATE TABLE parcela (
    id              BIGINT         PRIMARY KEY,
    cota_id         BIGINT         NOT NULL REFERENCES cota (id),
    numero          SMALLINT       NOT NULL,
    data_vencimento DATE           NOT NULL,
    data_pagamento  DATE,
    valor_devido    NUMERIC(15, 2) NOT NULL,
    valor_pago      NUMERIC(15, 2),
    UNIQUE (cota_id, numero)
);

CREATE INDEX ix_parcela_cota ON parcela (cota_id) WHERE data_pagamento IS NOT NULL;

CREATE TABLE assembleia (
    id              BIGINT         PRIMARY KEY,
    grupo_codigo    INTEGER        NOT NULL REFERENCES grupo (codigo),
    numero          SMALLINT       NOT NULL,
    data_realizacao DATE           NOT NULL,
    fundo_comum     NUMERIC(15, 2) NOT NULL,
    fundo_reserva   NUMERIC(15, 2) NOT NULL,
    UNIQUE (grupo_codigo, numero)
);

-- O CONSORCIO-0002 recorta a assembleia pelo dia; sem este índice ele varre
-- todas as assembleias já realizadas do histórico.
CREATE INDEX ix_assembleia_data ON assembleia (data_realizacao);

CREATE TABLE contemplacao (
    id             BIGINT         PRIMARY KEY,
    assembleia_id  BIGINT         NOT NULL REFERENCES assembleia (id),
    cota_id        BIGINT         NOT NULL REFERENCES cota (id),
    modalidade     VARCHAR(12)    NOT NULL
        CHECK (modalidade IN ('SORTEIO', 'LANCE_LIVRE', 'LANCE_FIXO')),
    valor_lance    NUMERIC(15, 2),
    percentual_lance NUMERIC(6, 3)
);

CREATE INDEX ix_contemplacao_assembleia ON contemplacao (assembleia_id);

-- Guarda os lances PERDEDORES, não só o vencedor. Sem eles a assembleia
-- registra o resultado e apaga a disputa — e é a disputa que explica o
-- percentual de contemplação por lance no sintético.
CREATE TABLE lance (
    id            BIGINT         PRIMARY KEY,
    assembleia_id BIGINT         NOT NULL REFERENCES assembleia (id),
    cota_id       BIGINT         NOT NULL REFERENCES cota (id),
    valor         NUMERIC(15, 2) NOT NULL,
    percentual    NUMERIC(6, 3)  NOT NULL,
    vencedor      BOOLEAN        NOT NULL DEFAULT false
);

CREATE INDEX ix_lance_assembleia ON lance (assembleia_id);
