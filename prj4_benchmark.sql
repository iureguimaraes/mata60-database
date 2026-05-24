-- =============================================================================
-- PRJ4 - Benchmark de desempenho (baseline vs indices) - PostgreSQL / PLpgSQL
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
--
-- Exigencia do descritivo: tempo medio de >= 20 execucoes + desvio padrao,
-- avaliando o speedup entre baseline (sem indices) e o plano de indexacao.
--
-- VERSAO AUTO-SUFICIENTE: este unico arquivo executa as DUAS fases sozinho,
-- independentemente do estado inicial do banco. Ele:
--   1. Remove os indices IX_* (se existirem)          -> estado BASELINE
--   2. Mede as 8 consultas representativas (20x cada)  -> grava 'BASELINE'
--   3. Recria os 24 indices do plano + ANALYZE         -> estado INDEXADO
--   4. Mede as mesmas 8 consultas (20x cada)           -> grava 'INDEXADO'
--   5. Exibe o comparativo final com o speedup
--
-- Basta: psql -d prj4db -f prj4_benchmark.sql
-- Tudo em SQL/PLpgSQL no servidor; nenhuma linguagem externa e usada.
--
-- Observacao metodologica: mede-se um conjunto representativo de 8 consultas
-- (as de maior custo), nao as 30, para evitar o vies de cache quente de uma
-- medicao em lote. As 30 consultas existem e retornam resultado; a medicao de
-- desempenho e seletiva por rigor metodologico.
-- =============================================================================
SET search_path TO prj4;

-- ----------------------------------------------------------------------------
-- Tabela de resultados do benchmark
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bench_resultado (
    et_fase        VARCHAR(10)   NOT NULL,
    co_consulta    VARCHAR(10)   NOT NULL,
    nu_execucao    INTEGER       NOT NULL,
    vl_tempo_ms    NUMERIC(12,3) NOT NULL,
    dt_registro    TIMESTAMP     NOT NULL DEFAULT clock_timestamp()
);

TRUNCATE bench_resultado;

-- ----------------------------------------------------------------------------
-- Procedimento: executa uma query N vezes e grava cada tempo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_bench(p_fase text, p_codigo text, p_sql text, p_repeticoes int DEFAULT 20)
LANGUAGE plpgsql AS $$
DECLARE
    i        int;
    t_ini    timestamptz;
    t_fim    timestamptz;
    v_ms     numeric;
    v_dummy  bigint;
BEGIN
    EXECUTE 'SELECT count(*) FROM (' || p_sql || ') _w' INTO v_dummy;
    FOR i IN 1..p_repeticoes LOOP
        t_ini := clock_timestamp();
        EXECUTE 'SELECT count(*) FROM (' || p_sql || ') _x' INTO v_dummy;
        t_fim := clock_timestamp();
        v_ms := extract(epoch FROM (t_fim - t_ini)) * 1000.0;
        INSERT INTO bench_resultado (et_fase, co_consulta, nu_execucao, vl_tempo_ms)
        VALUES (p_fase, p_codigo, i, v_ms);
    END LOOP;
END;
$$;

-- ----------------------------------------------------------------------------
-- Procedimento: roda as 8 consultas representativas para uma dada fase.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_rodar_fase(p_fase text)
LANGUAGE plpgsql AS $$
BEGIN
    CALL pr_bench(p_fase, 'QI01',
    $q$ SELECT pr.co_seq_programa, count(DISTINCT pc.co_seq_producao) qt
        FROM tb_programa pr
        JOIN rt_programa_docente rpd ON rpd.co_seq_programa=pr.co_seq_programa
        JOIN rt_producao_docente rpc ON rpc.co_seq_docente=rpd.co_seq_docente
        JOIN tb_producao_cientifica pc ON pc.co_seq_producao=rpc.co_seq_producao
        GROUP BY pr.co_seq_programa $q$);

    CALL pr_bench(p_fase, 'QI02',
    $q$ SELECT i.co_seq_instituicao, pr.co_seq_programa, count(e.co_seq_egresso) q
        FROM tb_egresso e
        JOIN tb_programa pr ON pr.co_seq_programa=e.co_seq_programa
        JOIN tb_instituicao i ON i.co_seq_instituicao=pr.co_seq_instituicao
        GROUP BY 1,2 $q$);

    CALL pr_bench(p_fase, 'QI03',
    $q$ SELECT pr.co_seq_programa, d.tp_nivel, count(*) q
        FROM tb_discente d
        JOIN tb_programa pr ON pr.co_seq_programa=d.co_seq_programa
        JOIN tb_area_avaliacao a ON a.co_seq_area=pr.co_seq_area
        WHERE d.tp_status='AT' GROUP BY 1,2 $q$);

    CALL pr_bench(p_fase, 'QI07',
    $q$ SELECT pr.co_seq_programa, count(DISTINCT ci.co_seq_colaboracao) q
        FROM tb_programa pr
        JOIN tb_projeto_pesquisa pj ON pj.co_seq_programa=pr.co_seq_programa
        JOIN rt_projeto_colaboracao rpc ON rpc.co_seq_projeto=pj.co_seq_projeto
        JOIN tb_colaboracao_internacional ci ON ci.co_seq_colaboracao=rpc.co_seq_colaboracao
        GROUP BY 1 $q$);

    CALL pr_bench(p_fase, 'QA01',
    $q$ WITH pp AS (
          SELECT pr.co_seq_programa, count(DISTINCT pc.co_seq_producao)::numeric qp,
                 count(DISTINCT rpd.co_seq_docente) qd
          FROM tb_programa pr
          JOIN rt_programa_docente rpd ON rpd.co_seq_programa=pr.co_seq_programa
          JOIN rt_producao_docente rpc ON rpc.co_seq_docente=rpd.co_seq_docente
          JOIN tb_producao_cientifica pc ON pc.co_seq_producao=rpc.co_seq_producao
          GROUP BY pr.co_seq_programa)
        SELECT * FROM pp WHERE qp/qd > (SELECT avg(qp/qd) FROM pp) $q$);

    CALL pr_bench(p_fase, 'QA05',
    $q$ SELECT dc.co_seq_docente, count(rpc.co_seq_producao) q
        FROM tb_docente dc
        JOIN rt_producao_docente rpc ON rpc.co_seq_docente=dc.co_seq_docente
        JOIN tb_producao_cientifica pc ON pc.co_seq_producao=rpc.co_seq_producao
        GROUP BY dc.co_seq_docente
        HAVING count(rpc.co_seq_producao) >= (
          SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY c)
          FROM (SELECT count(*) c FROM rt_producao_docente GROUP BY co_seq_docente) z) $q$);

    CALL pr_bench(p_fase, 'QA11',
    $q$ WITH r AS (
          SELECT a.co_seq_area, dc.co_seq_docente, count(pc.co_seq_producao) qt,
                 row_number() OVER (PARTITION BY a.co_seq_area ORDER BY count(pc.co_seq_producao) DESC) rn
          FROM tb_docente dc
          JOIN rt_producao_docente rpc ON rpc.co_seq_docente=dc.co_seq_docente
          JOIN tb_producao_cientifica pc ON pc.co_seq_producao=rpc.co_seq_producao
          JOIN rt_programa_docente rpd ON rpd.co_seq_docente=dc.co_seq_docente
          JOIN tb_programa pr ON pr.co_seq_programa=rpd.co_seq_programa
          JOIN tb_area_avaliacao a ON a.co_seq_area=pr.co_seq_area
          GROUP BY a.co_seq_area, dc.co_seq_docente)
        SELECT * FROM r WHERE rn<=3 $q$);

    CALL pr_bench(p_fase, 'QA19',
    $q$ SELECT pr.co_seq_programa,
          (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa=pr.co_seq_programa) eg,
          (SELECT count(*) FROM tb_projeto_pesquisa pj WHERE pj.co_seq_programa=pr.co_seq_programa) pj,
          (SELECT count(DISTINCT d.co_seq_docente) FROM rt_programa_docente d WHERE d.co_seq_programa=pr.co_seq_programa) dc
        FROM tb_programa pr
        JOIN tb_area_avaliacao a ON a.co_seq_area=pr.co_seq_area
        WHERE (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa=pr.co_seq_programa) > 0 $q$);
END;
$$;

-- ----------------------------------------------------------------------------
-- Procedimento: remove todos os indices IX_* (volta ao baseline).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_drop_indices()
LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT indexname FROM pg_indexes
        WHERE schemaname='prj4' AND indexname LIKE 'ix\_%'
    LOOP
        EXECUTE 'DROP INDEX prj4.' || quote_ident(r.indexname);
    END LOOP;
END;
$$;

-- ----------------------------------------------------------------------------
-- Procedimento: cria os 24 indices do plano + ANALYZE (sincronizado com prj4_indices.sql).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_criar_indices()
LANGUAGE plpgsql AS $$
BEGIN
    CREATE INDEX IX_rt_prog_doc_docente   ON rt_programa_docente (co_seq_docente);
    CREATE INDEX IX_rt_prod_doc_docente   ON rt_producao_docente (co_seq_docente);
    CREATE INDEX IX_rt_proj_colab_colab   ON rt_projeto_colaboracao (co_seq_colaboracao);
    CREATE INDEX IX_programa_instituicao  ON tb_programa (co_seq_instituicao);
    CREATE INDEX IX_programa_area         ON tb_programa (co_seq_area);
    CREATE INDEX IX_discente_programa     ON tb_discente (co_seq_programa);
    CREATE INDEX IX_discente_orientador   ON tb_discente (co_seq_docente_orientador);
    CREATE INDEX IX_egresso_programa      ON tb_egresso (co_seq_programa);
    CREATE INDEX IX_producao_evento       ON tb_producao_cientifica (co_seq_evento);
    CREATE INDEX IX_projeto_programa      ON tb_projeto_pesquisa (co_seq_programa);
    CREATE INDEX IX_criterio_area         ON tb_criterio_avaliacao (co_seq_area);
    CREATE INDEX IX_indicador_programa    ON tb_indicador (co_seq_programa);
    CREATE INDEX IX_avaliador_area        ON tb_avaliador (co_seq_area);
    CREATE INDEX IX_parecer_avaliador     ON tb_parecer (co_seq_avaliador);
    CREATE INDEX IX_parecer_programa      ON tb_parecer (co_seq_programa);
    CREATE INDEX IX_relatorio_programa    ON tb_relatorio (co_seq_programa);
    CREATE INDEX IX_indicador_prog_ano_tipo ON tb_indicador (co_seq_programa, nu_ano_referencia, tp_indicador);
    CREATE INDEX IX_relatorio_prog_tipo_ano ON tb_relatorio (co_seq_programa, tp_relatorio, nu_ano_referencia);
    CREATE INDEX IX_parecer_prog_ano       ON tb_parecer (co_seq_programa, nu_ano_avaliacao);
    CREATE INDEX IX_discente_ativo ON tb_discente (co_seq_programa) WHERE tp_status = 'AT';
    CREATE INDEX IX_producao_qualis ON tb_producao_cientifica (ds_qualis) WHERE ds_qualis IS NOT NULL;
    CREATE INDEX IX_egresso_ativo ON tb_egresso (co_seq_programa) WHERE st_registro_ativo = 'S';
    CREATE INDEX IX_auditoria_tabela ON au_operacao (au_nm_tabela);
    CREATE INDEX IX_auditoria_data   ON au_operacao (au_dt_operacao);
    ANALYZE;
END;
$$;

-- ============================================================================
-- EXECUCAO DAS DUAS FASES
-- ============================================================================
CALL pr_drop_indices();
ANALYZE;
CALL pr_rodar_fase('BASELINE');

CALL pr_criar_indices();
CALL pr_rodar_fase('INDEXADO');

-- Resumo por fase
SELECT et_fase, co_consulta,
       count(*)                      AS execucoes,
       round(avg(vl_tempo_ms), 3)    AS media_ms,
       round(stddev(vl_tempo_ms), 3) AS desvio_ms,
       round(min(vl_tempo_ms), 3)    AS min_ms,
       round(max(vl_tempo_ms), 3)    AS max_ms
FROM bench_resultado
GROUP BY et_fase, co_consulta
ORDER BY et_fase, co_consulta;

-- Comparativo final com speedup
SELECT b.co_consulta,
       round(avg(b.vl_tempo_ms), 3)  AS baseline_ms,
       round(avg(x.vl_tempo_ms), 3)  AS indexado_ms,
       round(avg(b.vl_tempo_ms) / NULLIF(avg(x.vl_tempo_ms), 0), 2) AS speedup
FROM bench_resultado b
JOIN bench_resultado x ON x.co_consulta = b.co_consulta
WHERE b.et_fase = 'BASELINE' AND x.et_fase = 'INDEXADO'
GROUP BY b.co_consulta
ORDER BY speedup DESC;
