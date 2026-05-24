-- =============================================================================
-- PRJ4 - Sistema para Avaliacao Quadrienal da Pos-Graduacao
-- Script DDL - PostgreSQL
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
-- Nomenclatura: MAD2 (DATASUS / ISO-IEC 11179-5)
--
-- Convencoes aplicadas:
--   TB_  tabela de negocio          RT_  tabela associativa (relac. N:N)
--   AU_  tabela de auditoria        PK_/FK_/CK_/UK_  constraints nomeadas
--   ST_REGISTRO_ATIVO  exclusao logica ('S'/'N')
--   Auditoria alimentada por trigger AFTER FOR EACH ROW -> AU_OPERACAO
--
-- Notas de modelagem (decisoes forcadas pelas cardinalidades do minimundo):
--   * TB_PROGRAMA recebe CO_SEQ_INSTITUICAO e CO_SEQ_AREA (FK NOT NULL).
--   * TB_PRODUCAO_CIENTIFICA recebe CO_SEQ_EVENTO (FK nullable, 0..1).
--   * UNIQUE adicionado nas chaves naturais (CPF, CNPJ, codigos CAPES/area).
-- =============================================================================

-- =============================================================================
-- 0. SCHEMA
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS prj4;
SET search_path TO prj4;

-- =============================================================================
-- 1. TABELAS INDEPENDENTES (sem FK de saida)
-- =============================================================================

-- 1.1 TB_INSTITUICAO --------------------------------------------------------
CREATE TABLE TB_INSTITUICAO (
    CO_SEQ_INSTITUICAO   SERIAL,
    NM_INSTITUICAO       VARCHAR(200)  NOT NULL,
    NU_CNPJ              VARCHAR(14)   NOT NULL,
    SG_UF                VARCHAR(2)    NOT NULL,
    NM_CIDADE            VARCHAR(100)  NOT NULL,
    ST_REGISTRO_ATIVO    VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_INSTITUICAO        PRIMARY KEY (CO_SEQ_INSTITUICAO),
    CONSTRAINT UK_TB_INSTITUICAO_CNPJ   UNIQUE (NU_CNPJ),
    CONSTRAINT CK_TB_INSTITUICAO_ATIVO  CHECK (ST_REGISTRO_ATIVO IN ('S','N'))
);

COMMENT ON TABLE  TB_INSTITUICAO IS 'Instituicoes de ensino superior que abrigam os programas de pos-graduacao. Atende RF4, RE5.';
COMMENT ON COLUMN TB_INSTITUICAO.CO_SEQ_INSTITUICAO IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_INSTITUICAO.NU_CNPJ IS 'CNPJ da instituicao (14 digitos).';
COMMENT ON COLUMN TB_INSTITUICAO.SG_UF IS 'Sigla da UF conforme IBGE.';
COMMENT ON COLUMN TB_INSTITUICAO.ST_REGISTRO_ATIVO IS 'Exclusao logica. Dominio: S (ativo) / N (inativo). Controle de uso pela aplicacao.';

-- 1.2 TB_AREA_AVALIACAO -----------------------------------------------------
CREATE TABLE TB_AREA_AVALIACAO (
    CO_SEQ_AREA          SERIAL,
    NM_AREA              VARCHAR(100)  NOT NULL,
    CO_AREA_CAPES        VARCHAR(10)   NOT NULL,
    CONSTRAINT PK_TB_AREA_AVALIACAO       PRIMARY KEY (CO_SEQ_AREA),
    CONSTRAINT UK_TB_AREA_AVALIACAO_CAPES UNIQUE (CO_AREA_CAPES)
);

COMMENT ON TABLE  TB_AREA_AVALIACAO IS 'Areas de avaliacao definidas pela CAPES, cada uma com criterios e pesos proprios. Atende RF4, RF6, RE4.';
COMMENT ON COLUMN TB_AREA_AVALIACAO.CO_AREA_CAPES IS 'Codigo da area no sistema CAPES.';

-- 1.3 TB_DOCENTE ------------------------------------------------------------
CREATE TABLE TB_DOCENTE (
    CO_SEQ_DOCENTE       SERIAL,
    NM_DOCENTE           VARCHAR(200)  NOT NULL,
    NU_CPF               VARCHAR(11)   NOT NULL,
    DS_TITULACAO         VARCHAR(2)    NOT NULL,
    NM_AREA_ATUACAO      VARCHAR(100),
    ST_REGISTRO_ATIVO    VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_DOCENTE              PRIMARY KEY (CO_SEQ_DOCENTE),
    CONSTRAINT UK_TB_DOCENTE_CPF          UNIQUE (NU_CPF),
    CONSTRAINT CK_TB_DOCENTE_TITULACAO    CHECK (DS_TITULACAO IN ('GR','ES','ME','DO','PD')),
    CONSTRAINT CK_TB_DOCENTE_ATIVO        CHECK (ST_REGISTRO_ATIVO IN ('S','N'))
);

COMMENT ON TABLE  TB_DOCENTE IS 'Docentes/pesquisadores que compoem o corpo academico dos programas. Atende RE1.';
COMMENT ON COLUMN TB_DOCENTE.NU_CPF IS 'CPF do docente. Dado pessoal protegido conforme LGPD/PPP2.';
COMMENT ON COLUMN TB_DOCENTE.DS_TITULACAO IS 'Maior titulacao. Dominio: GR, ES, ME, DO, PD.';

-- 1.4 TB_EVENTO -------------------------------------------------------------
CREATE TABLE TB_EVENTO (
    CO_SEQ_EVENTO        SERIAL,
    NM_EVENTO            VARCHAR(200)  NOT NULL,
    TP_EVENTO            VARCHAR(2)    NOT NULL,
    NM_LOCAL             VARCHAR(200),
    DT_INICIO            DATE,
    DT_FIM               DATE,
    CONSTRAINT PK_TB_EVENTO         PRIMARY KEY (CO_SEQ_EVENTO),
    CONSTRAINT CK_TB_EVENTO_TIPO    CHECK (TP_EVENTO IN ('CO','SE','WO','SI')),
    CONSTRAINT CK_TB_EVENTO_PERIODO CHECK (DT_FIM IS NULL OR DT_INICIO IS NULL OR DT_FIM >= DT_INICIO)
);

COMMENT ON TABLE  TB_EVENTO IS 'Eventos academicos (congressos, seminarios, workshops, simposios) onde producoes foram apresentadas. Atende RF2.';
COMMENT ON COLUMN TB_EVENTO.TP_EVENTO IS 'Tipo do evento. Dominio: CO, SE, WO, SI.';

-- 1.5 TB_COLABORACAO_INTERNACIONAL -----------------------------------------
CREATE TABLE TB_COLABORACAO_INTERNACIONAL (
    CO_SEQ_COLABORACAO       SERIAL,
    NM_INSTITUICAO_PARCEIRA  VARCHAR(200)  NOT NULL,
    NM_PAIS                  VARCHAR(100)  NOT NULL,
    TP_COLABORACAO           VARCHAR(2)    NOT NULL,
    DT_INICIO                DATE,
    DT_FIM                   DATE,
    CONSTRAINT PK_TB_COLABORACAO_INTERNACIONAL   PRIMARY KEY (CO_SEQ_COLABORACAO),
    CONSTRAINT CK_TB_COLABORACAO_TIPO            CHECK (TP_COLABORACAO IN ('MO','CT','PJ')),
    CONSTRAINT CK_TB_COLABORACAO_PERIODO         CHECK (DT_FIM IS NULL OR DT_INICIO IS NULL OR DT_FIM >= DT_INICIO)
);

COMMENT ON TABLE  TB_COLABORACAO_INTERNACIONAL IS 'Colaboracoes internacionais mantidas pelos programas via projetos. Atende RE3.';
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.TP_COLABORACAO IS 'Tipo. Dominio: MO (mobilidade), CT (cotutela), PJ (projeto conjunto).';

-- =============================================================================
-- 2. TABELAS COM FK
-- =============================================================================

-- 2.1 TB_PROGRAMA (entidade central) ---------------------------------------
CREATE TABLE TB_PROGRAMA (
    CO_SEQ_PROGRAMA      SERIAL,
    NM_PROGRAMA          VARCHAR(200)  NOT NULL,
    CO_PROGRAMA_CAPES    VARCHAR(20)   NOT NULL,
    TP_NIVEL             VARCHAR(2)    NOT NULL,
    CO_SEQ_INSTITUICAO   INTEGER       NOT NULL,
    CO_SEQ_AREA          INTEGER       NOT NULL,
    ST_REGISTRO_ATIVO    VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_PROGRAMA            PRIMARY KEY (CO_SEQ_PROGRAMA),
    CONSTRAINT UK_TB_PROGRAMA_CAPES      UNIQUE (CO_PROGRAMA_CAPES),
    CONSTRAINT CK_TB_PROGRAMA_NIVEL      CHECK (TP_NIVEL IN ('ME','DO','MP')),
    CONSTRAINT CK_TB_PROGRAMA_ATIVO      CHECK (ST_REGISTRO_ATIVO IN ('S','N')),
    CONSTRAINT FK_TB_PROGRAMA_INSTITUICAO
        FOREIGN KEY (CO_SEQ_INSTITUICAO) REFERENCES TB_INSTITUICAO (CO_SEQ_INSTITUICAO),
    CONSTRAINT FK_TB_PROGRAMA_AREA
        FOREIGN KEY (CO_SEQ_AREA)        REFERENCES TB_AREA_AVALIACAO (CO_SEQ_AREA)
);

COMMENT ON TABLE  TB_PROGRAMA IS 'Programas de pos-graduacao avaliados pela CAPES. Entidade central do sistema. Atende RF4, RF5, RE5.';
COMMENT ON COLUMN TB_PROGRAMA.CO_PROGRAMA_CAPES IS 'Codigo no sistema CAPES/Plataforma Sucupira.';
COMMENT ON COLUMN TB_PROGRAMA.TP_NIVEL IS 'Nivel. Dominio: ME (mestrado academico), DO (doutorado), MP (mestrado profissional).';
COMMENT ON COLUMN TB_PROGRAMA.CO_SEQ_INSTITUICAO IS 'FK -> TB_INSTITUICAO. Cada programa pertence a exatamente uma instituicao.';
COMMENT ON COLUMN TB_PROGRAMA.CO_SEQ_AREA IS 'FK -> TB_AREA_AVALIACAO. Cada programa pertence a exatamente uma area.';

-- 2.2 TB_DISCENTE -----------------------------------------------------------
CREATE TABLE TB_DISCENTE (
    CO_SEQ_DISCENTE              SERIAL,
    NM_DISCENTE                  VARCHAR(200)  NOT NULL,
    NU_CPF                       VARCHAR(11)   NOT NULL,
    TP_NIVEL                     VARCHAR(2)    NOT NULL,
    CO_SEQ_PROGRAMA              INTEGER       NOT NULL,
    CO_SEQ_DOCENTE_ORIENTADOR    INTEGER       NOT NULL,
    DT_INGRESSO                  DATE          NOT NULL,
    DT_PREVISAO_DEFESA           DATE,
    TP_STATUS                    VARCHAR(2)    NOT NULL,
    ST_REGISTRO_ATIVO            VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_DISCENTE          PRIMARY KEY (CO_SEQ_DISCENTE),
    CONSTRAINT UK_TB_DISCENTE_CPF      UNIQUE (NU_CPF),
    CONSTRAINT CK_TB_DISCENTE_NIVEL    CHECK (TP_NIVEL IN ('ME','DO')),
    CONSTRAINT CK_TB_DISCENTE_STATUS   CHECK (TP_STATUS IN ('AT','TI','DE')),
    CONSTRAINT CK_TB_DISCENTE_ATIVO    CHECK (ST_REGISTRO_ATIVO IN ('S','N')),
    CONSTRAINT FK_TB_DISCENTE_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA)           REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA),
    CONSTRAINT FK_TB_DISCENTE_ORIENTADOR
        FOREIGN KEY (CO_SEQ_DOCENTE_ORIENTADOR) REFERENCES TB_DOCENTE (CO_SEQ_DOCENTE)
);

COMMENT ON TABLE  TB_DISCENTE IS 'Alunos matriculados nos programas, com orientador e status academico. Atende RE2.';
COMMENT ON COLUMN TB_DISCENTE.NU_CPF IS 'CPF do discente. Dado pessoal protegido conforme LGPD/PPP2.';
COMMENT ON COLUMN TB_DISCENTE.TP_STATUS IS 'Situacao academica. Dominio: AT (ativo), TI (titulado), DE (desligado).';
COMMENT ON COLUMN TB_DISCENTE.CO_SEQ_DOCENTE_ORIENTADOR IS 'FK -> TB_DOCENTE. Docente orientador do discente.';

-- 2.3 TB_EGRESSO ------------------------------------------------------------
CREATE TABLE TB_EGRESSO (
    CO_SEQ_EGRESSO              SERIAL,
    NM_EGRESSO                  VARCHAR(200)  NOT NULL,
    NU_CPF                      VARCHAR(11)   NOT NULL,
    CO_SEQ_PROGRAMA             INTEGER       NOT NULL,
    DT_TITULACAO                DATE          NOT NULL,
    DS_ATUACAO_PROFISSIONAL     VARCHAR(200),
    NM_INSTITUICAO_ATUAL        VARCHAR(200),
    ST_REGISTRO_ATIVO           VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_EGRESSO        PRIMARY KEY (CO_SEQ_EGRESSO),
    CONSTRAINT UK_TB_EGRESSO_CPF    UNIQUE (NU_CPF),
    CONSTRAINT CK_TB_EGRESSO_ATIVO  CHECK (ST_REGISTRO_ATIVO IN ('S','N')),
    CONSTRAINT FK_TB_EGRESSO_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA) REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA)
);

COMMENT ON TABLE  TB_EGRESSO IS 'Egressos titulados e sua trajetoria profissional. Volume alvo: 5.000+ registros. Atende RF1.';
COMMENT ON COLUMN TB_EGRESSO.NU_CPF IS 'CPF do egresso. Dado pessoal protegido conforme LGPD/PPP2.';

-- 2.4 TB_PRODUCAO_CIENTIFICA ------------------------------------------------
CREATE TABLE TB_PRODUCAO_CIENTIFICA (
    CO_SEQ_PRODUCAO      SERIAL,
    NM_TITULO            VARCHAR(500)  NOT NULL,
    TP_PRODUCAO          VARCHAR(2)    NOT NULL,
    NM_VEICULO           VARCHAR(200),
    DS_QUALIS            VARCHAR(2),
    NU_ANO_PUBLICACAO    INTEGER       NOT NULL,
    DS_DOI               VARCHAR(100),
    CO_SEQ_EVENTO        INTEGER,
    ST_REGISTRO_ATIVO    VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_PRODUCAO_CIENTIFICA    PRIMARY KEY (CO_SEQ_PRODUCAO),
    CONSTRAINT CK_TB_PRODUCAO_TIPO          CHECK (TP_PRODUCAO IN ('AR','LI','CA','AN')),
    CONSTRAINT CK_TB_PRODUCAO_QUALIS        CHECK (DS_QUALIS IS NULL OR DS_QUALIS IN ('A1','A2','A3','A4','B1','B2','B3','B4')),
    CONSTRAINT CK_TB_PRODUCAO_ATIVO         CHECK (ST_REGISTRO_ATIVO IN ('S','N')),
    CONSTRAINT FK_TB_PRODUCAO_EVENTO
        FOREIGN KEY (CO_SEQ_EVENTO) REFERENCES TB_EVENTO (CO_SEQ_EVENTO)
);

COMMENT ON TABLE  TB_PRODUCAO_CIENTIFICA IS 'Producao cientifica (artigos, livros, capitulos, anais) vinculada aos docentes. Volume alvo: 5.000+ registros. Atende RF2.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.TP_PRODUCAO IS 'Tipo. Dominio: AR (artigo), LI (livro), CA (capitulo), AN (anais).';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.DS_QUALIS IS 'Classificacao Qualis/CAPES. Dominio: A1..A4, B1..B4.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.CO_SEQ_EVENTO IS 'FK -> TB_EVENTO (0..1). Evento onde a producao foi apresentada, se houver.';

-- 2.5 TB_PROJETO_PESQUISA ---------------------------------------------------
CREATE TABLE TB_PROJETO_PESQUISA (
    CO_SEQ_PROJETO       SERIAL,
    NM_PROJETO           VARCHAR(300)  NOT NULL,
    DS_FINANCIADOR       VARCHAR(100),
    VL_FINANCIAMENTO     NUMERIC(15,2),
    CO_SEQ_PROGRAMA      INTEGER       NOT NULL,
    DT_INICIO            DATE          NOT NULL,
    DT_FIM               DATE,
    TP_STATUS            VARCHAR(2)    NOT NULL,
    ST_REGISTRO_ATIVO    VARCHAR(1)    NOT NULL DEFAULT 'S',
    CONSTRAINT PK_TB_PROJETO_PESQUISA      PRIMARY KEY (CO_SEQ_PROJETO),
    CONSTRAINT CK_TB_PROJETO_STATUS        CHECK (TP_STATUS IN ('AT','CO','CA')),
    CONSTRAINT CK_TB_PROJETO_VALOR         CHECK (VL_FINANCIAMENTO IS NULL OR VL_FINANCIAMENTO >= 0),
    CONSTRAINT CK_TB_PROJETO_PERIODO       CHECK (DT_FIM IS NULL OR DT_FIM >= DT_INICIO),
    CONSTRAINT CK_TB_PROJETO_ATIVO         CHECK (ST_REGISTRO_ATIVO IN ('S','N')),
    CONSTRAINT FK_TB_PROJETO_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA) REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA)
);

COMMENT ON TABLE  TB_PROJETO_PESQUISA IS 'Projetos de pesquisa dos programas, incluindo financiamento. Atende RF3.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.VL_FINANCIAMENTO IS 'Valor total do financiamento em reais.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.TP_STATUS IS 'Situacao. Dominio: AT (ativo), CO (concluido), CA (cancelado).';

-- 2.6 TB_CRITERIO_AVALIACAO -------------------------------------------------
CREATE TABLE TB_CRITERIO_AVALIACAO (
    CO_SEQ_CRITERIO      SERIAL,
    CO_SEQ_AREA          INTEGER       NOT NULL,
    NM_CRITERIO          VARCHAR(100)  NOT NULL,
    VL_PESO              NUMERIC(5,2)  NOT NULL,
    DS_CRITERIO          TEXT,
    CONSTRAINT PK_TB_CRITERIO_AVALIACAO  PRIMARY KEY (CO_SEQ_CRITERIO),
    CONSTRAINT CK_TB_CRITERIO_PESO       CHECK (VL_PESO >= 0 AND VL_PESO <= 100),
    CONSTRAINT FK_TB_CRITERIO_AREA
        FOREIGN KEY (CO_SEQ_AREA) REFERENCES TB_AREA_AVALIACAO (CO_SEQ_AREA)
);

COMMENT ON TABLE  TB_CRITERIO_AVALIACAO IS 'Criterios de avaliacao CAPES com pesos configuraveis por area. Atende RE4.';
COMMENT ON COLUMN TB_CRITERIO_AVALIACAO.VL_PESO IS 'Peso do criterio na nota final (0 a 100).';

-- 2.7 TB_INDICADOR ----------------------------------------------------------
CREATE TABLE TB_INDICADOR (
    CO_SEQ_INDICADOR     SERIAL,
    CO_SEQ_PROGRAMA      INTEGER         NOT NULL,
    NU_ANO_REFERENCIA    INTEGER         NOT NULL,
    TP_INDICADOR         VARCHAR(2)      NOT NULL,
    VL_INDICADOR         NUMERIC(10,4),
    CONSTRAINT PK_TB_INDICADOR        PRIMARY KEY (CO_SEQ_INDICADOR),
    CONSTRAINT CK_TB_INDICADOR_TIPO   CHECK (TP_INDICADOR IN ('PD','FE','II','IS')),
    CONSTRAINT FK_TB_INDICADOR_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA) REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA)
);

COMMENT ON TABLE  TB_INDICADOR IS 'Indicadores de desempenho por programa e ano de referencia. Atende RF5.';
COMMENT ON COLUMN TB_INDICADOR.TP_INDICADOR IS 'Tipo. Dominio: PD (producao docente), FE (formacao egressos), II (insercao internacional), IS (impacto social).';

-- 2.8 TB_AVALIADOR ----------------------------------------------------------
CREATE TABLE TB_AVALIADOR (
    CO_SEQ_AVALIADOR        SERIAL,
    NM_AVALIADOR            VARCHAR(200)  NOT NULL,
    NU_CPF                  VARCHAR(11)   NOT NULL,
    CO_SEQ_AREA             INTEGER       NOT NULL,
    NM_INSTITUICAO_ORIGEM   VARCHAR(200),
    CONSTRAINT PK_TB_AVALIADOR     PRIMARY KEY (CO_SEQ_AVALIADOR),
    CONSTRAINT UK_TB_AVALIADOR_CPF UNIQUE (NU_CPF),
    CONSTRAINT FK_TB_AVALIADOR_AREA
        FOREIGN KEY (CO_SEQ_AREA) REFERENCES TB_AREA_AVALIACAO (CO_SEQ_AREA)
);

COMMENT ON TABLE  TB_AVALIADOR IS 'Avaliadores designados pela CAPES, especialistas por area. Atende RF6.';
COMMENT ON COLUMN TB_AVALIADOR.NU_CPF IS 'CPF do avaliador. Dado pessoal protegido conforme LGPD/PPP2.';

-- 2.9 TB_PARECER ------------------------------------------------------------
CREATE TABLE TB_PARECER (
    CO_SEQ_PARECER       SERIAL,
    CO_SEQ_AVALIADOR     INTEGER       NOT NULL,
    CO_SEQ_PROGRAMA      INTEGER       NOT NULL,
    NU_ANO_AVALIACAO     INTEGER       NOT NULL,
    VL_NOTA              NUMERIC(4,2)  NOT NULL,
    DS_PARECER           TEXT,
    DT_EMISSAO           DATE          NOT NULL,
    CONSTRAINT PK_TB_PARECER     PRIMARY KEY (CO_SEQ_PARECER),
    CONSTRAINT CK_TB_PARECER_NOTA CHECK (VL_NOTA >= 0 AND VL_NOTA <= 10),
    CONSTRAINT FK_TB_PARECER_AVALIADOR
        FOREIGN KEY (CO_SEQ_AVALIADOR) REFERENCES TB_AVALIADOR (CO_SEQ_AVALIADOR),
    CONSTRAINT FK_TB_PARECER_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA)  REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA)
);

COMMENT ON TABLE  TB_PARECER IS 'Pareceres emitidos pelos avaliadores por programa e ciclo. Atende RF6.';
COMMENT ON COLUMN TB_PARECER.VL_NOTA IS 'Nota atribuida ao programa (0 a 10).';

-- 2.10 TB_RELATORIO ---------------------------------------------------------
CREATE TABLE TB_RELATORIO (
    CO_SEQ_RELATORIO     SERIAL,
    CO_SEQ_PROGRAMA      INTEGER       NOT NULL,
    NU_ANO_REFERENCIA    INTEGER       NOT NULL,
    TP_RELATORIO         VARCHAR(2)    NOT NULL,
    NU_CONCEITO_FINAL    INTEGER,
    DT_GERACAO           DATE          NOT NULL,
    CONSTRAINT PK_TB_RELATORIO       PRIMARY KEY (CO_SEQ_RELATORIO),
    CONSTRAINT CK_TB_RELATORIO_TIPO  CHECK (TP_RELATORIO IN ('AN','QU')),
    CONSTRAINT CK_TB_RELATORIO_CONCEITO CHECK (NU_CONCEITO_FINAL IS NULL OR (NU_CONCEITO_FINAL BETWEEN 1 AND 7)),
    CONSTRAINT FK_TB_RELATORIO_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA) REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA)
);

COMMENT ON TABLE  TB_RELATORIO IS 'Relatorios gerados para a CAPES consolidando indicadores e conceito final. Atende RF4, RE5.';
COMMENT ON COLUMN TB_RELATORIO.TP_RELATORIO IS 'Tipo. Dominio: AN (anual/coleta), QU (quadrienal).';
COMMENT ON COLUMN TB_RELATORIO.NU_CONCEITO_FINAL IS 'Conceito CAPES de 1 a 7 (3 = minimo, 7 = excelencia internacional).';

-- =============================================================================
-- 3. TABELAS ASSOCIATIVAS (PK composta)
-- =============================================================================

-- 3.1 RT_PROGRAMA_DOCENTE ---------------------------------------------------
CREATE TABLE RT_PROGRAMA_DOCENTE (
    CO_SEQ_PROGRAMA      INTEGER       NOT NULL,
    CO_SEQ_DOCENTE       INTEGER       NOT NULL,
    TP_VINCULO           VARCHAR(2)    NOT NULL,
    DT_INICIO_VINCULO    DATE          NOT NULL,
    DT_FIM_VINCULO       DATE,
    CONSTRAINT PK_RT_PROGRAMA_DOCENTE  PRIMARY KEY (CO_SEQ_PROGRAMA, CO_SEQ_DOCENTE),
    CONSTRAINT CK_RT_PROGRAMA_DOCENTE_VINCULO CHECK (TP_VINCULO IN ('PE','CO','VI')),
    CONSTRAINT CK_RT_PROGRAMA_DOCENTE_PERIODO CHECK (DT_FIM_VINCULO IS NULL OR DT_FIM_VINCULO >= DT_INICIO_VINCULO),
    CONSTRAINT FK_RT_PROGRAMA_DOCENTE_PROGRAMA
        FOREIGN KEY (CO_SEQ_PROGRAMA) REFERENCES TB_PROGRAMA (CO_SEQ_PROGRAMA),
    CONSTRAINT FK_RT_PROGRAMA_DOCENTE_DOCENTE
        FOREIGN KEY (CO_SEQ_DOCENTE)  REFERENCES TB_DOCENTE (CO_SEQ_DOCENTE)
);

COMMENT ON TABLE  RT_PROGRAMA_DOCENTE IS 'Associativa N:N entre programas e docentes, com tipo de vinculo e vigencia. Atende RE1.';
COMMENT ON COLUMN RT_PROGRAMA_DOCENTE.TP_VINCULO IS 'Dominio: PE (permanente), CO (colaborador), VI (visitante).';
COMMENT ON COLUMN RT_PROGRAMA_DOCENTE.DT_FIM_VINCULO IS 'Fim do vinculo. NULL se ainda ativo.';

-- 3.2 RT_PRODUCAO_DOCENTE ---------------------------------------------------
CREATE TABLE RT_PRODUCAO_DOCENTE (
    CO_SEQ_PRODUCAO      INTEGER       NOT NULL,
    CO_SEQ_DOCENTE       INTEGER       NOT NULL,
    TP_PARTICIPACAO      VARCHAR(2)    NOT NULL,
    CONSTRAINT PK_RT_PRODUCAO_DOCENTE  PRIMARY KEY (CO_SEQ_PRODUCAO, CO_SEQ_DOCENTE),
    CONSTRAINT CK_RT_PRODUCAO_DOCENTE_PART CHECK (TP_PARTICIPACAO IN ('AP','CA')),
    CONSTRAINT FK_RT_PRODUCAO_DOCENTE_PRODUCAO
        FOREIGN KEY (CO_SEQ_PRODUCAO) REFERENCES TB_PRODUCAO_CIENTIFICA (CO_SEQ_PRODUCAO),
    CONSTRAINT FK_RT_PRODUCAO_DOCENTE_DOCENTE
        FOREIGN KEY (CO_SEQ_DOCENTE)  REFERENCES TB_DOCENTE (CO_SEQ_DOCENTE)
);

COMMENT ON TABLE  RT_PRODUCAO_DOCENTE IS 'Associativa N:N entre producoes e docentes (autoria). Atende RF2.';
COMMENT ON COLUMN RT_PRODUCAO_DOCENTE.TP_PARTICIPACAO IS 'Dominio: AP (autor principal), CA (coautor).';

-- 3.3 RT_PROJETO_COLABORACAO ------------------------------------------------
CREATE TABLE RT_PROJETO_COLABORACAO (
    CO_SEQ_PROJETO       INTEGER       NOT NULL,
    CO_SEQ_COLABORACAO   INTEGER       NOT NULL,
    CONSTRAINT PK_RT_PROJETO_COLABORACAO  PRIMARY KEY (CO_SEQ_PROJETO, CO_SEQ_COLABORACAO),
    CONSTRAINT FK_RT_PROJETO_COLABORACAO_PROJETO
        FOREIGN KEY (CO_SEQ_PROJETO)     REFERENCES TB_PROJETO_PESQUISA (CO_SEQ_PROJETO),
    CONSTRAINT FK_RT_PROJETO_COLABORACAO_COLAB
        FOREIGN KEY (CO_SEQ_COLABORACAO) REFERENCES TB_COLABORACAO_INTERNACIONAL (CO_SEQ_COLABORACAO)
);

COMMENT ON TABLE RT_PROJETO_COLABORACAO IS 'Associativa N:N entre projetos de pesquisa e colaboracoes internacionais. Atende RE3.';

-- =============================================================================
-- 4. AUDITORIA (padrao MAD - alimentada por trigger)
--    Tabela de auditoria sem constraints de integridade (alem da PK tecnica),
--    conforme MAD: as restricoes sao garantidas pelas tabelas de origem.
-- =============================================================================
CREATE TABLE AU_OPERACAO (
    CO_SEQ_AUDITORIA         SERIAL,
    AU_DT_OPERACAO           TIMESTAMP     NOT NULL,
    AU_TP_OPERACAO           VARCHAR(1)    NOT NULL,
    AU_NM_TABELA             VARCHAR(30)   NOT NULL,
    AU_DS_CHAVE_REGISTRO     VARCHAR(100),
    AU_DS_USUARIO_SESSAO     VARCHAR(50),
    AU_NU_IP_SESSAO          VARCHAR(45),
    AU_DS_USUARIO_APLICACAO  VARCHAR(50),
    AU_DS_DADOS_ANTERIORES   TEXT,
    AU_DS_DADOS_NOVOS        TEXT,
    CONSTRAINT PK_AU_OPERACAO PRIMARY KEY (CO_SEQ_AUDITORIA)
);

COMMENT ON TABLE  AU_OPERACAO IS 'Auditoria de todas as operacoes de manipulacao de dados (PPP2/RE6). Alimentada por trigger AFTER FOR EACH ROW.';
COMMENT ON COLUMN AU_OPERACAO.AU_TP_OPERACAO IS 'Tipo da operacao. Dominio: I (insercao), A (alteracao), E (exclusao).';
COMMENT ON COLUMN AU_OPERACAO.AU_DS_CHAVE_REGISTRO IS 'Valor da PK do registro afetado (col=val;...).';
COMMENT ON COLUMN AU_OPERACAO.AU_DS_DADOS_ANTERIORES IS 'Imagem JSON do registro antes da operacao (UPDATE/DELETE).';
COMMENT ON COLUMN AU_OPERACAO.AU_DS_DADOS_NOVOS IS 'Imagem JSON do registro apos a operacao (INSERT/UPDATE).';

-- 4.1 Funcao generica de auditoria ------------------------------------------
-- A coluna (ou colunas) de PK e informada como argumento da trigger (TG_ARGV),
-- permitindo reutilizar a mesma funcao para PKs simples e compostas.
-- Usuario/IP da aplicacao seguem o padrao MAD (informados pela aplicacao):
--   a aplicacao deve executar  SET app.usuario = '<login>';  por sessao.
CREATE OR REPLACE FUNCTION FN_AUDITORIA()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER                    -- a funcao insere em AU_OPERACAO com os
                                    -- privilegios do DONO, nao de quem disparou.
                                    -- Permite revogar a escrita direta na auditoria
                                    -- dos perfis operacionais (trilha a prova de
                                    -- adulteracao - RE6 / PPP2 / LGPD).
SET search_path = prj4, pg_temp     -- obrigatorio em SECURITY DEFINER: fixa o
                                    -- caminho de busca e evita escalonamento de
                                    -- privilegio via objetos plantados em outros
                                    -- schemas.
AS $$
DECLARE
    v_tp_operacao   VARCHAR(1);
    v_dados_ant     TEXT;
    v_dados_novos   TEXT;
    v_chave         TEXT := '';
    v_rec           JSONB;
    v_col           TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_tp_operacao := 'I';
        v_dados_ant   := NULL;
        v_dados_novos := to_jsonb(NEW)::TEXT;
        v_rec         := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_tp_operacao := 'A';
        v_dados_ant   := to_jsonb(OLD)::TEXT;
        v_dados_novos := to_jsonb(NEW)::TEXT;
        v_rec         := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_tp_operacao := 'E';
        v_dados_ant   := to_jsonb(OLD)::TEXT;
        v_dados_novos := NULL;
        v_rec         := to_jsonb(OLD);
    END IF;

    -- monta a chave do registro a partir das colunas de PK passadas a trigger
    IF TG_ARGV IS NOT NULL THEN
        FOREACH v_col IN ARRAY TG_ARGV LOOP
            v_chave := v_chave || v_col || '=' || COALESCE(v_rec ->> v_col, 'NULL') || ';';
        END LOOP;
    END IF;

    INSERT INTO AU_OPERACAO (
        AU_DT_OPERACAO, AU_TP_OPERACAO, AU_NM_TABELA, AU_DS_CHAVE_REGISTRO,
        AU_DS_USUARIO_SESSAO, AU_NU_IP_SESSAO, AU_DS_USUARIO_APLICACAO,
        AU_DS_DADOS_ANTERIORES, AU_DS_DADOS_NOVOS
    ) VALUES (
        clock_timestamp(),
        v_tp_operacao,
        TG_TABLE_NAME,
        v_chave,
        session_user,
        COALESCE(host(inet_client_addr()), 'local'),
        current_setting('app.usuario', true),
        v_dados_ant,
        v_dados_novos
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

-- 4.2 Triggers de auditoria (TRA_<tabela>) ----------------------------------
CREATE TRIGGER TRA_TB_INSTITUICAO  AFTER INSERT OR UPDATE OR DELETE ON TB_INSTITUICAO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_instituicao');
CREATE TRIGGER TRA_TB_AREA_AVALIACAO AFTER INSERT OR UPDATE OR DELETE ON TB_AREA_AVALIACAO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_area');
CREATE TRIGGER TRA_TB_DOCENTE      AFTER INSERT OR UPDATE OR DELETE ON TB_DOCENTE
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_docente');
CREATE TRIGGER TRA_TB_EVENTO       AFTER INSERT OR UPDATE OR DELETE ON TB_EVENTO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_evento');
CREATE TRIGGER TRA_TB_COLABORACAO  AFTER INSERT OR UPDATE OR DELETE ON TB_COLABORACAO_INTERNACIONAL
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_colaboracao');
CREATE TRIGGER TRA_TB_PROGRAMA     AFTER INSERT OR UPDATE OR DELETE ON TB_PROGRAMA
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_programa');
CREATE TRIGGER TRA_TB_DISCENTE     AFTER INSERT OR UPDATE OR DELETE ON TB_DISCENTE
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_discente');
CREATE TRIGGER TRA_TB_EGRESSO      AFTER INSERT OR UPDATE OR DELETE ON TB_EGRESSO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_egresso');
CREATE TRIGGER TRA_TB_PRODUCAO     AFTER INSERT OR UPDATE OR DELETE ON TB_PRODUCAO_CIENTIFICA
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_producao');
CREATE TRIGGER TRA_TB_PROJETO      AFTER INSERT OR UPDATE OR DELETE ON TB_PROJETO_PESQUISA
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_projeto');
CREATE TRIGGER TRA_TB_CRITERIO     AFTER INSERT OR UPDATE OR DELETE ON TB_CRITERIO_AVALIACAO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_criterio');
CREATE TRIGGER TRA_TB_INDICADOR    AFTER INSERT OR UPDATE OR DELETE ON TB_INDICADOR
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_indicador');
CREATE TRIGGER TRA_TB_AVALIADOR    AFTER INSERT OR UPDATE OR DELETE ON TB_AVALIADOR
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_avaliador');
CREATE TRIGGER TRA_TB_PARECER      AFTER INSERT OR UPDATE OR DELETE ON TB_PARECER
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_parecer');
CREATE TRIGGER TRA_TB_RELATORIO    AFTER INSERT OR UPDATE OR DELETE ON TB_RELATORIO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_relatorio');
CREATE TRIGGER TRA_RT_PROGRAMA_DOCENTE AFTER INSERT OR UPDATE OR DELETE ON RT_PROGRAMA_DOCENTE
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_programa','co_seq_docente');
CREATE TRIGGER TRA_RT_PRODUCAO_DOCENTE AFTER INSERT OR UPDATE OR DELETE ON RT_PRODUCAO_DOCENTE
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_producao','co_seq_docente');
CREATE TRIGGER TRA_RT_PROJETO_COLABORACAO AFTER INSERT OR UPDATE OR DELETE ON RT_PROJETO_COLABORACAO
    FOR EACH ROW EXECUTE FUNCTION FN_AUDITORIA('co_seq_projeto','co_seq_colaboracao');

-- =============================================================================
-- 5. NIVEIS DE ACESSO (DCL)
--    Os perfis de acesso (DBA, sistema, analise, backup) e suas permissoes
--    estao no script dedicado prj4_acessos.sql, aplicado APOS este DDL.
--    A tabela de auditoria AU_OPERACAO e append-only: alimentada apenas pela
--    trigger FN_AUDITORIA (SECURITY DEFINER); nenhum perfil operacional tem
--    INSERT/UPDATE/DELETE direto sobre ela.
-- =============================================================================
