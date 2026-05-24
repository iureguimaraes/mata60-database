-- =============================================================================
-- PRJ4 - Exploracao de Metadados do Banco - PostgreSQL
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
-- Nomenclatura: MAD2 (DATASUS / ISO-IEC 11179-5)
--
-- Objetivo (atende ao item P2-Q2 do barema da Entrega 1: "o relatorio contem
--   uma exploracao dos metadados conforme apresentado em uma das aulas
--   expositivas"). Toda a exploracao usa o catalogo do SGBD via:
--     - information_schema  (visao padrao ANSI/ISO do dicionario de dados)
--     - pg_catalog          (catalogo nativo do PostgreSQL, mais rico)
--     - obj_description / col_description  (recuperam os COMMENT ON do MAD)
--     - funcoes pg_*_size   (ocupacao fisica de dados e indices)
--
-- Cada bloco demonstra que uma decisao de modelagem/governanca esta de fato
-- materializada no dicionario de dados do SGBD. Tudo em SQL nativo, sem uso
-- de linguagem externa, conforme a regra do projeto.
--
-- Pre-requisito: schema prj4 implantado (DDL), populado e indexado.
-- =============================================================================
SET search_path TO prj4;

-- =============================================================================
-- BLOCO 1 - DICIONARIO DE TABELAS
-- Classifica cada relacao pela convencao MAD (TB/RT/AU), traz o volume e o
-- comentario de tabela (COMMENT ON TABLE recuperado por obj_description).
-- Evidencia: o catalogo conhece o proposito de cada tabela e o requisito que ela atende.
-- =============================================================================
SELECT
    c.relname                                   AS tabela,
    CASE
        WHEN c.relname LIKE 'tb\_%' THEN 'Negocio (TB)'
        WHEN c.relname LIKE 'rt\_%' THEN 'Associativa (RT)'
        WHEN c.relname LIKE 'au\_%' THEN 'Auditoria (AU)'
        ELSE 'Outra'
    END                                         AS classe_mad,
    obj_description(c.oid, 'pg_class')          AS comentario_mad
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'prj4' AND c.relkind = 'r'
ORDER BY classe_mad, c.relname;

-- =============================================================================
-- BLOCO 2 - DICIONARIO DE COLUNAS (todas as tabelas)
-- Para cada coluna: tipo formatado, obrigatoriedade, valor default e o
-- comentario de coluna (COMMENT ON COLUMN via col_description).
-- O default 'nextval(...seq)' evidencia as PKs SERIAL (CO_SEQ_*).
-- =============================================================================
SELECT
    cols.table_name                                   AS tabela,
    cols.ordinal_position                             AS pos,
    cols.column_name                                  AS coluna,
    CASE
      WHEN cols.data_type = 'character varying' THEN 'varchar(' || cols.character_maximum_length || ')'
      WHEN cols.data_type = 'numeric'           THEN 'numeric(' || cols.numeric_precision || ',' || cols.numeric_scale || ')'
      ELSE cols.data_type
    END                                               AS tipo,
    cols.is_nullable                                  AS aceita_nulo,
    COALESCE(cols.column_default, '-')                AS valor_default,
    col_description(('prj4.' || cols.table_name)::regclass, cols.ordinal_position) AS comentario_mad
FROM information_schema.columns cols
WHERE cols.table_schema = 'prj4'
ORDER BY cols.table_name, cols.ordinal_position;

-- =============================================================================
-- BLOCO 3 - CONSTRAINTS POR TIPO (PK / FK / UNIQUE / CHECK)
-- Panorama quantitativo das restricoes declaradas, agrupadas por tabela.
-- Evidencia que as restricoes do minimundo viraram restricoes no modelo fisico.
-- =============================================================================
SELECT
    rel.relname                                                 AS tabela,
    count(*) FILTER (WHERE con.contype = 'p')                   AS pk,
    count(*) FILTER (WHERE con.contype = 'f')                   AS fk,
    count(*) FILTER (WHERE con.contype = 'u')                   AS uniq,
    count(*) FILTER (WHERE con.contype = 'c')                   AS chk
FROM pg_constraint con
JOIN pg_class rel   ON rel.oid = con.conrelid
JOIN pg_namespace n ON n.oid = rel.relnamespace
WHERE n.nspname = 'prj4'
GROUP BY rel.relname
ORDER BY rel.relname;

-- =============================================================================
-- BLOCO 4 - MAPA DE CHAVES ESTRANGEIRAS (origem -> destino)
-- Reconstrucao explicita de cada FK coluna a coluna. O unnest WITH ORDINALITY
-- pareia conkey/confkey e cobre corretamente as PKs compostas das associativas.
-- Evidencia direta da estrategia de traducao MER -> Relacional.
-- =============================================================================
SELECT
    con.conname                                   AS constraint_fk,
    src.relname || '(' || a_src.attname || ')'    AS origem,
    tgt.relname || '(' || a_tgt.attname || ')'    AS destino
FROM pg_constraint con
JOIN pg_class src      ON src.oid = con.conrelid
JOIN pg_class tgt      ON tgt.oid = con.confrelid
JOIN pg_namespace n    ON n.oid = src.relnamespace
JOIN LATERAL unnest(con.conkey)  WITH ORDINALITY AS sk(attnum, ord) ON true
JOIN LATERAL unnest(con.confkey) WITH ORDINALITY AS tk(attnum, ord) ON tk.ord = sk.ord
JOIN pg_attribute a_src ON a_src.attrelid = src.oid AND a_src.attnum = sk.attnum
JOIN pg_attribute a_tgt ON a_tgt.attrelid = tgt.oid AND a_tgt.attnum = tk.attnum
WHERE con.contype = 'f' AND n.nspname = 'prj4'
ORDER BY src.relname, con.conname;

-- =============================================================================
-- BLOCO 5 - DICIONARIO DE DOMINIOS (CHECK constraints)
-- pg_get_constraintdef reconstroi cada CHECK. Os dominios fechados de codigo
-- (TP_*, ST_*, DS_QUALIS, NU_CONCEITO_FINAL ...) ficam visiveis como vocabulario
-- controlado - o "dicionario de dominios" exigido pela documentacao MAD.
-- =============================================================================
SELECT
    rel.relname                          AS tabela,
    con.conname                          AS constraint_check,
    pg_get_constraintdef(con.oid)        AS definicao_dominio
FROM pg_constraint con
JOIN pg_class rel   ON rel.oid = con.conrelid
JOIN pg_namespace n ON n.oid = rel.relnamespace
WHERE con.contype = 'c' AND n.nspname = 'prj4'
ORDER BY rel.relname, con.conname;

-- =============================================================================
-- BLOCO 6 - INDICES (tipo, unicidade, parcialidade, tamanho)
-- Lista os indices do plano de indexacao (IX_*) com seu metodo de acesso,
-- se sao unicos, se sao PARCIAIS (indpred) e o espaco ocupado.
-- Confirma que os indices parciais do Grupo 4 do plano existem como tais.
-- =============================================================================
SELECT
    t.relname                               AS tabela,
    i.relname                               AS indice,
    am.amname                               AS metodo,
    ix.indisunique                          AS unico,
    (ix.indpred IS NOT NULL)                AS parcial,
    pg_get_indexdef(i.oid)                  AS definicao,
    pg_size_pretty(pg_relation_size(i.oid)) AS tamanho
FROM pg_index ix
JOIN pg_class i      ON i.oid = ix.indexrelid
JOIN pg_class t      ON t.oid = ix.indrelid
JOIN pg_namespace n  ON n.oid = t.relnamespace
JOIN pg_am am        ON am.oid = i.relam
WHERE n.nspname = 'prj4' AND i.relname LIKE 'ix\_%'
ORDER BY t.relname, i.relname;

-- =============================================================================
-- BLOCO 7 - OCUPACAO FISICA (dados vs indices vs total)
-- Mede o custo de armazenamento de cada relacao. Util para discutir o
-- trade-off do plano de indexacao (espaco extra dos indices x ganho de tempo).
-- =============================================================================
SELECT
    c.relname                                       AS tabela,
    pg_size_pretty(pg_table_size(c.oid))            AS tam_dados,
    pg_size_pretty(pg_indexes_size(c.oid))          AS tam_indices,
    pg_size_pretty(pg_total_relation_size(c.oid))   AS tam_total,
    CASE WHEN pg_table_size(c.oid) > 0
         THEN round(100.0 * pg_indexes_size(c.oid) / pg_table_size(c.oid), 0) || '%'
         ELSE '-' END                               AS indices_sobre_dados
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'prj4' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

-- =============================================================================
-- BLOCO 8 - SEQUENCES (suporte ao SERIAL / CO_SEQ_*)
-- Cada PK SERIAL gera uma sequence. O last_value indica o ultimo id atribuido,
-- coerente com os volumes carregados.
-- =============================================================================
SELECT
    sequencename                  AS sequence,
    last_value                    AS ultimo_valor,
    increment_by                  AS incremento
FROM pg_sequences
WHERE schemaname = 'prj4'
ORDER BY sequencename;

-- =============================================================================
-- BLOCO 9 - TRIGGERS DE AUDITORIA (TRA_*)
-- Confirma que toda tabela de negocio/associativa tem uma trigger AFTER para
-- I/U/D apontando para a funcao generica FN_AUDITORIA (mecanismo do PPP2/RE6).
-- Agrupa os tres eventos numa linha por trigger.
-- =============================================================================
SELECT
    event_object_table                                              AS tabela,
    trigger_name                                                    AS trigger,
    string_agg(event_manipulation, '/' ORDER BY event_manipulation) AS eventos,
    action_timing                                                   AS momento
FROM information_schema.triggers
WHERE trigger_schema = 'prj4'
GROUP BY event_object_table, trigger_name, action_timing
ORDER BY event_object_table;

-- =============================================================================
-- BLOCO 10 - COBERTURA DE DOCUMENTACAO MAD (governanca)
-- Metrica de governanca: percentual de colunas com COMMENT por tabela. Permite
-- ao Administrador de Dados localizar lacunas no dicionario de dados e prioriza-las.
-- (As colunas autoexplicativas - NM_, DT_ triviais - foram comentadas seletivamente;
--  esta consulta torna essa decisao mensuravel e auditavel.)
-- =============================================================================
WITH cols AS (
    SELECT c.relname AS tabela,
           a.attname AS coluna,
           col_description(c.oid, a.attnum) AS cmt
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE n.nspname = 'prj4' AND c.relkind = 'r'
)
SELECT
    tabela,
    count(*)                                     AS total_colunas,
    count(cmt)                                   AS colunas_documentadas,
    round(100.0 * count(cmt) / count(*), 0) || '%' AS cobertura,
    obj_description(('prj4.' || tabela)::regclass, 'pg_class') IS NOT NULL AS tabela_documentada
FROM cols
GROUP BY tabela
ORDER BY round(100.0 * count(cmt) / count(*), 0), tabela;

-- =============================================================================
-- FIM DA EXPLORACAO DE METADADOS
-- =============================================================================
