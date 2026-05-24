-- =============================================================================
-- PRJ4 - Populacao do banco (dados sinteticos) - PostgreSQL / SQL nativo
-- Aluno: Iure Vieira Guimaraes | MATA60 - UFBA
--
-- Estrategia (sem linguagem externa, apenas SQL/PLpgSQL no servidor):
--   * INSERT ... SELECT sobre generate_series para volume.
--   * FKs resolvidas por (1 + floor(random()*N)) sobre a contagem do pai,
--     valido porque os ids sao contiguos a partir de 1 (TRUNCATE RESTART IDENTITY).
--   * Dominios fechados sorteados de arrays literais.
--   * Colunas UNIQUE (CPF, CNPJ, codigos) derivadas da serie -> unicidade garantida.
--   * Triggers de auditoria desabilitadas durante a carga: o seed nao e operacao
--     de negocio e geraria dezenas de milhares de linhas em AU_OPERACAO, alem de
--     frear o load. As FKs continuam validadas (DISABLE TRIGGER USER nao afeta
--     as system triggers de integridade referencial).
--   * setseed fixa a aleatoriedade -> carga reprodutivel.
-- =============================================================================

SET search_path TO prj4;
SELECT setseed(0.42);

-- ----------------------------------------------------------------------------
-- Funcao auxiliar de SKEW: concentra os sorteios nos primeiros ids.
-- expoente > 1 => mais assimetria. Imita programas/docentes "grandes" e "pequenos".
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_skew(n_max int, expoente double precision DEFAULT 2.5)
RETURNS int LANGUAGE sql AS $f$
    SELECT 1 + floor(power(random(), expoente) * n_max)::int;
$f$;

-- ----------------------------------------------------------------------------
-- 0. Zera o banco e reinicia os contadores SERIAL (carga idempotente)
-- ----------------------------------------------------------------------------
TRUNCATE
    TB_INSTITUICAO, TB_AREA_AVALIACAO, TB_DOCENTE, TB_EVENTO,
    TB_COLABORACAO_INTERNACIONAL, TB_PROGRAMA, TB_DISCENTE, TB_EGRESSO,
    TB_PRODUCAO_CIENTIFICA, TB_PROJETO_PESQUISA, TB_CRITERIO_AVALIACAO,
    TB_INDICADOR, TB_AVALIADOR, TB_PARECER, TB_RELATORIO,
    RT_PROGRAMA_DOCENTE, RT_PRODUCAO_DOCENTE, RT_PROJETO_COLABORACAO,
    AU_OPERACAO
RESTART IDENTITY CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Desabilita as triggers de auditoria durante a carga
-- ----------------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
    FOR t IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'prj4'
          AND (tablename LIKE 'tb\_%' OR tablename LIKE 'rt\_%')
    LOOP
        EXECUTE format('ALTER TABLE prj4.%I DISABLE TRIGGER USER', t);
    END LOOP;
END $$;

-- ============================================================================
-- 2. TABELAS INDEPENDENTES
-- ============================================================================

-- 2.1 Instituicoes (30)
INSERT INTO TB_INSTITUICAO (NM_INSTITUICAO, NU_CNPJ, SG_UF, NM_CIDADE)
SELECT
    'Universidade ' || (ARRAY['Federal','Estadual'])[1 + (g % 2)] || ' ' || g,
    lpad(g::text, 14, '0'),
    (ARRAY['BA','SP','RJ','MG','RS','PE','CE','DF','PR','SC'])[1 + floor(random()*10)::int],
    (ARRAY['Salvador','Sao Paulo','Rio de Janeiro','Belo Horizonte','Porto Alegre',
           'Recife','Fortaleza','Brasilia','Curitiba','Florianopolis'])[1 + floor(random()*10)::int]
FROM generate_series(1, 30) g;

-- 2.2 Areas de avaliacao (49 areas CAPES)
INSERT INTO TB_AREA_AVALIACAO (NM_AREA, CO_AREA_CAPES)
SELECT 'Area de Avaliacao ' || g, lpad(g::text, 8, '0')
FROM generate_series(1, 49) g;

-- 2.3 Docentes (500)
INSERT INTO TB_DOCENTE (NM_DOCENTE, NU_CPF, DS_TITULACAO, NM_AREA_ATUACAO)
SELECT
    'Docente ' || (ARRAY['Ana','Bruno','Carla','Diego','Elena','Felipe','Gabriela','Hugo'])[1 + (g % 8)] || ' ' || g,
    lpad(g::text, 11, '0'),
    (ARRAY['DO','PD','DO','ME'])[1 + (g % 4)],
    (ARRAY['Inteligencia Artificial','Banco de Dados','Redes','Engenharia de Software',
           'Sistemas Distribuidos','Teoria da Computacao'])[1 + floor(random()*6)::int]
FROM generate_series(1, 500) g;

-- 2.4 Eventos (60)
INSERT INTO TB_EVENTO (NM_EVENTO, TP_EVENTO, NM_LOCAL, DT_INICIO, DT_FIM)
SELECT
    'Evento Academico ' || g,
    (ARRAY['CO','SE','WO','SI'])[1 + (g % 4)],
    (ARRAY['Salvador, Brasil','Sao Paulo, Brasil','Lisboa, Portugal',
           'Boston, EUA','Berlim, Alemanha'])[1 + floor(random()*5)::int],
    x.ini,
    x.ini + (1 + floor(random()*5)::int)
FROM generate_series(1, 60) g
CROSS JOIN LATERAL (SELECT DATE '2015-01-01' + floor(random()*3000)::int AS ini) x;

-- 2.5 Colaboracoes internacionais (200)
INSERT INTO TB_COLABORACAO_INTERNACIONAL (NM_INSTITUICAO_PARCEIRA, NM_PAIS, TP_COLABORACAO, DT_INICIO, DT_FIM)
SELECT
    (ARRAY['MIT','Stanford','Oxford','Sorbonne','TU Munich','Tokyo University'])[1 + floor(random()*6)::int] || ' ' || g,
    (ARRAY['EUA','Reino Unido','Franca','Alemanha','Japao','Canada','Portugal'])[1 + floor(random()*7)::int],
    (ARRAY['MO','CT','PJ'])[1 + (g % 3)],
    x.ini,
    CASE WHEN random() < 0.4 THEN NULL ELSE x.ini + (200 + floor(random()*1200)::int) END
FROM generate_series(1, 200) g
CROSS JOIN LATERAL (SELECT DATE '2016-01-01' + floor(random()*2500)::int AS ini) x;

-- ============================================================================
-- 3. PROGRAMA (FK instituicao, area)
-- ============================================================================
INSERT INTO TB_PROGRAMA (NM_PROGRAMA, CO_PROGRAMA_CAPES, TP_NIVEL, CO_SEQ_INSTITUICAO, CO_SEQ_AREA)
SELECT
    'PPG ' || (ARRAY['em Computacao','em Engenharia','em Medicina','em Fisica',
                     'em Direito','em Educacao','em Quimica','em Biologia'])[1 + (g % 8)] || ' ' || g,
    'PROG' || lpad(g::text, 9, '0'),
    (ARRAY['ME','DO','MP'])[1 + (g % 3)],
    1 + floor(random()*x.ninst)::int,
    1 + floor(random()*x.nare)::int
FROM generate_series(1, 80) g
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_INSTITUICAO) AS ninst,
                           (SELECT count(*)::int FROM TB_AREA_AVALIACAO) AS nare) x;

-- ============================================================================
-- 4. TABELAS QUE DEPENDEM DE AREA / PROGRAMA / EVENTO
-- ============================================================================

-- 4.1 Criterios de avaliacao (5 por area = 245) - via cross join (deterministico)
INSERT INTO TB_CRITERIO_AVALIACAO (CO_SEQ_AREA, NM_CRITERIO, VL_PESO, DS_CRITERIO)
SELECT
    a.CO_SEQ_AREA,
    (ARRAY['Producao intelectual qualificada','Formacao de recursos humanos',
           'Insercao social','Internacionalizacao','Proposta do programa'])[k],
    round((random()*100)::numeric, 2),
    'Criterio ' || k || ' aplicavel a area ' || a.CO_SEQ_AREA
FROM TB_AREA_AVALIACAO a
CROSS JOIN generate_series(1, 5) k;

-- 4.2 Avaliadores (150) - FK area
INSERT INTO TB_AVALIADOR (NM_AVALIADOR, NU_CPF, CO_SEQ_AREA, NM_INSTITUICAO_ORIGEM)
SELECT
    'Avaliador ' || g,
    lpad(g::text, 11, '0'),
    1 + floor(random()*x.nare)::int,
    (ARRAY['UFBA','USP','UFMG','UFRGS','UFPE'])[1 + floor(random()*5)::int]
FROM generate_series(1, 150) g
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_AREA_AVALIACAO) AS nare) x;

-- 4.3 Discentes (2000) - FK programa, orientador docente
INSERT INTO TB_DISCENTE (NM_DISCENTE, NU_CPF, TP_NIVEL, CO_SEQ_PROGRAMA,
                         CO_SEQ_DOCENTE_ORIENTADOR, DT_INGRESSO, DT_PREVISAO_DEFESA, TP_STATUS)
SELECT
    'Discente ' || g,
    lpad(g::text, 11, '0'),
    (ARRAY['ME','DO'])[1 + (g % 2)],
    fn_skew(x.npr),
    fn_skew(x.ndoc),
    x.ing,
    x.ing + (730 + floor(random()*730)::int),
    (ARRAY['AT','TI','DE'])[1 + floor(random()*3)::int]
FROM generate_series(1, 2000) g
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_PROGRAMA) AS npr,
                           (SELECT count(*)::int FROM TB_DOCENTE)  AS ndoc,
                           DATE '2018-01-01' + floor(random()*2000)::int AS ing) x;

-- 4.4 Egressos (6000) - FK programa  *** tabela 5.000+ ***
INSERT INTO TB_EGRESSO (NM_EGRESSO, NU_CPF, CO_SEQ_PROGRAMA, DT_TITULACAO,
                        DS_ATUACAO_PROFISSIONAL, NM_INSTITUICAO_ATUAL)
SELECT
    'Egresso ' || g,
    lpad(g::text, 11, '0'),
    fn_skew(x.npr),
    DATE '2010-01-01' + floor(random()*5000)::int,
    (ARRAY['Professor Adjunto','Pesquisador','Analista de Dados','Consultor',
           'Professor Titular','Pos-doutorando'])[1 + floor(random()*6)::int],
    (ARRAY['UFBA','USP','UFRJ','Empresa Privada','Instituto de Pesquisa','UNICAMP'])[1 + floor(random()*6)::int]
FROM generate_series(1, 6000) g
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_PROGRAMA) AS npr) x;

-- 4.5 Producao cientifica (6000) - FK evento (apenas para tipo 'AN')  *** 5.000+ ***
INSERT INTO TB_PRODUCAO_CIENTIFICA (NM_TITULO, TP_PRODUCAO, NM_VEICULO, DS_QUALIS,
                                    NU_ANO_PUBLICACAO, DS_DOI, CO_SEQ_EVENTO)
SELECT
    'Producao Cientifica ' || g,
    x.tp,
    (ARRAY['Journal of ML Research','IEEE Transactions','SBBD Proceedings',
           'Springer LNCS','Revista Brasileira de Computacao'])[1 + floor(random()*5)::int],
    CASE WHEN x.tp = 'AN' THEN NULL
         ELSE (ARRAY['A1','A2','A3','A4','B1','B2','B3','B4'])[1 + (g % 8)] END,
    2008 + floor(random()*17)::int,
    CASE WHEN random() < 0.6
         THEN '10.' || (1000 + floor(random()*9000)::int)::text || '/prj4.' || g
         ELSE NULL END,
    CASE WHEN x.tp = 'AN' THEN 1 + floor(random()*x.nev)::int ELSE NULL END
FROM generate_series(1, 6000) g
CROSS JOIN LATERAL (SELECT (ARRAY['AR','LI','CA','AN'])[1 + (g % 4)] AS tp,
                           (SELECT count(*)::int FROM TB_EVENTO) AS nev) x;

-- 4.6 Projetos de pesquisa (400) - FK programa
INSERT INTO TB_PROJETO_PESQUISA (NM_PROJETO, DS_FINANCIADOR, VL_FINANCIAMENTO,
                                 CO_SEQ_PROGRAMA, DT_INICIO, DT_FIM, TP_STATUS)
SELECT
    'Projeto de Pesquisa ' || g,
    (ARRAY['CNPq','CAPES','FAPESB','FAPESP','FINEP'])[1 + floor(random()*5)::int],
    round((random()*2000000)::numeric, 2),
    fn_skew(x.npr),
    x.ini,
    CASE WHEN x.st = 'AT' THEN NULL ELSE x.ini + (180 + floor(random()*1000)::int) END,
    x.st
FROM generate_series(1, 400) g
CROSS JOIN LATERAL (SELECT (ARRAY['AT','CO','CA'])[1 + (g % 3)] AS st,
                           DATE '2017-01-01' + floor(random()*2200)::int AS ini,
                           (SELECT count(*)::int FROM TB_PROGRAMA) AS npr) x;

-- 4.7 Indicadores (programa x ano x tipo = 80*4*4 = 1280) - cross join deterministico
INSERT INTO TB_INDICADOR (CO_SEQ_PROGRAMA, NU_ANO_REFERENCIA, TP_INDICADOR, VL_INDICADOR)
SELECT pr.CO_SEQ_PROGRAMA, y.ano, t.tp, round((random()*1000)::numeric, 4)
FROM TB_PROGRAMA pr
CROSS JOIN (VALUES (2021),(2022),(2023),(2024)) AS y(ano)
CROSS JOIN (VALUES ('PD'),('FE'),('II'),('IS')) AS t(tp);

-- 4.8 Relatorios (programa x ano = 80*4 = 320) - cross join deterministico
INSERT INTO TB_RELATORIO (CO_SEQ_PROGRAMA, NU_ANO_REFERENCIA, TP_RELATORIO,
                          NU_CONCEITO_FINAL, DT_GERACAO)
SELECT
    pr.CO_SEQ_PROGRAMA,
    y.ano,
    CASE WHEN y.ano = 2024 THEN 'QU' ELSE 'AN' END,
    3 + floor(random()*5)::int,
    make_date(y.ano, 12, 15)
FROM TB_PROGRAMA pr
CROSS JOIN (VALUES (2021),(2022),(2023),(2024)) AS y(ano);

-- ============================================================================
-- 5. PARECER (FK avaliador, programa)
-- ============================================================================
INSERT INTO TB_PARECER (CO_SEQ_AVALIADOR, CO_SEQ_PROGRAMA, NU_ANO_AVALIACAO,
                        VL_NOTA, DS_PARECER, DT_EMISSAO)
SELECT
    1 + floor(random()*x.nav)::int,
    fn_skew(x.npr),
    2020 + floor(random()*5)::int,
    round((random()*10)::numeric, 2),
    CASE WHEN random() < 0.7 THEN 'Parecer tecnico de avaliacao numero ' || s ELSE NULL END,
    DATE '2020-01-01' + floor(random()*1800)::int
FROM generate_series(1, 1000) s
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_AVALIADOR) AS nav,
                           (SELECT count(*)::int FROM TB_PROGRAMA)  AS npr) x;

-- ============================================================================
-- 6. TABELAS ASSOCIATIVAS (PK composta; ON CONFLICT descarta pares repetidos)
-- ============================================================================

-- 6.1 RT_PROGRAMA_DOCENTE: ate 3 vinculos por docente
INSERT INTO RT_PROGRAMA_DOCENTE (CO_SEQ_PROGRAMA, CO_SEQ_DOCENTE, TP_VINCULO,
                                 DT_INICIO_VINCULO, DT_FIM_VINCULO)
SELECT
    fn_skew(x.npr),
    d,
    (ARRAY['PE','CO','VI'])[1 + floor(random()*3)::int],
    x.ini,
    CASE WHEN random() < 0.5 THEN NULL ELSE x.ini + (200 + floor(random()*1500)::int) END
FROM generate_series(1, 500) d
CROSS JOIN generate_series(1, 3) k
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_PROGRAMA) AS npr,
                           DATE '2012-01-01' + floor(random()*3000)::int AS ini) x
ON CONFLICT DO NOTHING;

-- 6.2 RT_PRODUCAO_DOCENTE: 1 autor principal garantido por producao + coautores
INSERT INTO RT_PRODUCAO_DOCENTE (CO_SEQ_PRODUCAO, CO_SEQ_DOCENTE, TP_PARTICIPACAO)
SELECT p, fn_skew((SELECT count(*)::int FROM TB_DOCENTE)), 'AP'
FROM generate_series(1, 6000) p
ON CONFLICT DO NOTHING;

INSERT INTO RT_PRODUCAO_DOCENTE (CO_SEQ_PRODUCAO, CO_SEQ_DOCENTE, TP_PARTICIPACAO)
SELECT p, fn_skew((SELECT count(*)::int FROM TB_DOCENTE)), 'CA'
FROM generate_series(1, 6000) p
CROSS JOIN generate_series(1, 2) c
ON CONFLICT DO NOTHING;

-- 6.3 RT_PROJETO_COLABORACAO
INSERT INTO RT_PROJETO_COLABORACAO (CO_SEQ_PROJETO, CO_SEQ_COLABORACAO)
SELECT 1 + floor(random()*x.nproj)::int, 1 + floor(random()*x.ncol)::int
FROM generate_series(1, 800) s
CROSS JOIN LATERAL (SELECT (SELECT count(*)::int FROM TB_PROJETO_PESQUISA) AS nproj,
                           (SELECT count(*)::int FROM TB_COLABORACAO_INTERNACIONAL) AS ncol) x
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 7. Reabilita as triggers de auditoria e atualiza estatisticas do otimizador
-- ============================================================================
DO $$
DECLARE t text;
BEGIN
    FOR t IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'prj4'
          AND (tablename LIKE 'tb\_%' OR tablename LIKE 'rt\_%')
    LOOP
        EXECUTE format('ALTER TABLE prj4.%I ENABLE TRIGGER USER', t);
    END LOOP;
END $$;

ANALYZE;

-- ============================================================================
-- 8. Conferencia de volumes
-- ============================================================================
SELECT 'TB_INSTITUICAO'               AS tabela, count(*) FROM TB_INSTITUICAO
UNION ALL SELECT 'TB_AREA_AVALIACAO',            count(*) FROM TB_AREA_AVALIACAO
UNION ALL SELECT 'TB_DOCENTE',                   count(*) FROM TB_DOCENTE
UNION ALL SELECT 'TB_EVENTO',                    count(*) FROM TB_EVENTO
UNION ALL SELECT 'TB_COLABORACAO_INTERNACIONAL', count(*) FROM TB_COLABORACAO_INTERNACIONAL
UNION ALL SELECT 'TB_PROGRAMA',                  count(*) FROM TB_PROGRAMA
UNION ALL SELECT 'TB_DISCENTE',                  count(*) FROM TB_DISCENTE
UNION ALL SELECT 'TB_EGRESSO',                   count(*) FROM TB_EGRESSO
UNION ALL SELECT 'TB_PRODUCAO_CIENTIFICA',       count(*) FROM TB_PRODUCAO_CIENTIFICA
UNION ALL SELECT 'TB_PROJETO_PESQUISA',          count(*) FROM TB_PROJETO_PESQUISA
UNION ALL SELECT 'TB_CRITERIO_AVALIACAO',        count(*) FROM TB_CRITERIO_AVALIACAO
UNION ALL SELECT 'TB_INDICADOR',                 count(*) FROM TB_INDICADOR
UNION ALL SELECT 'TB_AVALIADOR',                 count(*) FROM TB_AVALIADOR
UNION ALL SELECT 'TB_PARECER',                   count(*) FROM TB_PARECER
UNION ALL SELECT 'TB_RELATORIO',                 count(*) FROM TB_RELATORIO
UNION ALL SELECT 'RT_PROGRAMA_DOCENTE',          count(*) FROM RT_PROGRAMA_DOCENTE
UNION ALL SELECT 'RT_PRODUCAO_DOCENTE',          count(*) FROM RT_PRODUCAO_DOCENTE
UNION ALL SELECT 'RT_PROJETO_COLABORACAO',       count(*) FROM RT_PROJETO_COLABORACAO
ORDER BY tabela;
