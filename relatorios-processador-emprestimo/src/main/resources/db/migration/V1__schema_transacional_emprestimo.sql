-- Schema transacional do Produto Empréstimo.
--
-- Padrão do ticket 40: autossuficiente (ticket 04 dá SELECT apenas em
-- `transacional_emprestimo`), sem junção com outro Produto.
--
-- Este é o domínio mais naturalmente SAZONAL do mapa: vencimentos se concentram
-- nos dias 5, 10, 15 e 20. A sazonalidade está modelada (ver `parcela`), mas foi
-- posta onde não dirige a duração — o pico alimenta o EMPRESTIMO-0002, cujo
-- tempo é dominado por custo fixo. Ver ticket 44.

CREATE SCHEMA IF NOT EXISTS transacional_emprestimo;
SET search_path TO transacional_emprestimo;

CREATE TABLE produto_credito (
    codigo          SMALLINT      PRIMARY KEY,
    nome            VARCHAR(60)   NOT NULL,
    modalidade      VARCHAR(20)   NOT NULL
        CHECK (modalidade IN ('CONSIGNADO', 'PESSOAL', 'VEICULO', 'IMOBILIARIO', 'CAPITAL_GIRO')),
    taxa_juros_mes  NUMERIC(6, 4) NOT NULL,
    prazo_maximo    SMALLINT      NOT NULL
);

CREATE TABLE contrato (
    id                 BIGINT         PRIMARY KEY,
    numero             VARCHAR(20)    NOT NULL UNIQUE,
    produto_codigo     SMALLINT       NOT NULL REFERENCES produto_credito (codigo),
    tomador_id         BIGINT         NOT NULL,
    tomador_nome       VARCHAR(120)   NOT NULL,
    data_contratacao   DATE           NOT NULL,
    valor_contratado   NUMERIC(15, 2) NOT NULL,
    saldo_devedor      NUMERIC(15, 2) NOT NULL,
    prazo_meses        SMALLINT       NOT NULL,
    dia_vencimento     SMALLINT       NOT NULL CHECK (dia_vencimento BETWEEN 1 AND 28),
    situacao           VARCHAR(14)    NOT NULL
        CHECK (situacao IN ('ATIVO', 'LIQUIDADO', 'RENEGOCIADO', 'BAIXADO'))
);

CREATE INDEX ix_contrato_situacao ON contrato (situacao, produto_codigo, id);

CREATE TABLE parcela (
    id              BIGINT         PRIMARY KEY,
    contrato_id     BIGINT         NOT NULL REFERENCES contrato (id),
    numero          SMALLINT       NOT NULL,
    data_vencimento DATE           NOT NULL,
    valor_principal NUMERIC(15, 2) NOT NULL,
    valor_juros     NUMERIC(15, 2) NOT NULL,
    situacao        VARCHAR(10)    NOT NULL
        CHECK (situacao IN ('ABERTA', 'PAGA', 'PARCIAL', 'BAIXADA')),
    UNIQUE (contrato_id, numero)
);

-- O EMPRESTIMO-0002 recorta pelos vencimentos do dia, e é aqui que a
-- sazonalidade aparece: a distribuição de `data_vencimento` é concentrada.
CREATE INDEX ix_parcela_vencimento ON parcela (data_vencimento);
CREATE INDEX ix_parcela_aberta ON parcela (contrato_id) WHERE situacao IN ('ABERTA', 'PARCIAL');

-- Tabela SEPARADA de `parcela` de propósito: uma parcela aceita pagamento
-- parcial e mais de um. Colapsar os dois numa coluna `valor_pago` faria o
-- relatório de inadimplência mentir na primeira amortização parcial.
CREATE TABLE pagamento (
    id             BIGINT         PRIMARY KEY,
    parcela_id     BIGINT         NOT NULL REFERENCES parcela (id),
    data_pagamento DATE           NOT NULL,
    valor          NUMERIC(15, 2) NOT NULL,
    origem         VARCHAR(12)    NOT NULL
        CHECK (origem IN ('DEBITO', 'BOLETO', 'PIX', 'CONSIGNACAO'))
);

CREATE INDEX ix_pagamento_parcela ON pagamento (parcela_id);

CREATE TABLE garantia (
    id           BIGINT         PRIMARY KEY,
    contrato_id  BIGINT         NOT NULL REFERENCES contrato (id),
    tipo         VARCHAR(15)    NOT NULL
        CHECK (tipo IN ('ALIENACAO', 'HIPOTECA', 'AVAL', 'CONSIGNACAO')),
    descricao    VARCHAR(120)   NOT NULL,
    valor_avaliado NUMERIC(15, 2) NOT NULL
);

-- Guarda o contrato de ORIGEM: sem isso a carteira cresce e ninguém sabe se é
-- originação de crédito novo ou dívida rolada. É o substrato próprio deste
-- Produto — papel de `remuneracao_mensal`, `segmentacao`, `limite_uso`/`tarifa`
-- e `lance` nos anteriores.
CREATE TABLE renegociacao (
    id                  BIGINT         PRIMARY KEY,
    contrato_origem_id  BIGINT         NOT NULL REFERENCES contrato (id),
    contrato_destino_id BIGINT         NOT NULL REFERENCES contrato (id),
    data_renegociacao   DATE           NOT NULL,
    saldo_transferido   NUMERIC(15, 2) NOT NULL,
    desconto_concedido  NUMERIC(15, 2) NOT NULL DEFAULT 0
);

CREATE INDEX ix_renegociacao_destino ON renegociacao (contrato_destino_id);
