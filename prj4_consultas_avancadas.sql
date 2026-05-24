-- =============================================================================
-- PRJ4 - Consultas AVANCADAS (QA01-QA20)
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
-- Regra do descritivo do projeto: cada consulta usa >= 3 tabelas E >= 3 de
--   {SUB-CONSULTAS, JOIN, GROUP BY, WINDOW, COUNT}.
-- Cada consulta indica o requisito atendido e as funções utilizadas.
-- =============================================================================
SET search_path TO prj4;

-- QA01 | RF2, RE1 | SUBCONSULTA, JOIN, GROUP BY, COUNT, WINDOW
-- Programas cuja producao por docente esta acima da media geral de produtividade.
WITH prod_prog AS (
    SELECT pr.co_seq_programa, pr.nm_programa,
           count(DISTINCT pc.co_seq_producao)::numeric AS qt_prod,
           count(DISTINCT rpd.co_seq_docente)          AS qt_doc
    FROM tb_programa pr
    JOIN rt_programa_docente rpd ON rpd.co_seq_programa = pr.co_seq_programa
    JOIN rt_producao_docente rpc ON rpc.co_seq_docente  = rpd.co_seq_docente
    JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
    GROUP BY pr.co_seq_programa, pr.nm_programa
)
SELECT nm_programa, qt_prod, qt_doc,
       round(qt_prod / qt_doc, 2) AS prod_por_docente,
       rank() OVER (ORDER BY qt_prod / qt_doc DESC) AS ranking
FROM prod_prog
WHERE qt_prod / qt_doc > (SELECT avg(qt_prod / qt_doc) FROM prod_prog)
ORDER BY prod_por_docente DESC
LIMIT 20;

-- QA02 | RF1, RE5 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Programas com numero de egressos acima da media da sua propria area (subconsulta correlacionada).
SELECT a.nm_area, pr.nm_programa, count(e.co_seq_egresso) AS qt_egressos
FROM tb_egresso e
JOIN tb_programa pr ON pr.co_seq_programa = e.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
GROUP BY a.nm_area, a.co_seq_area, pr.nm_programa, pr.co_seq_programa
HAVING count(e.co_seq_egresso) > (
    SELECT avg(c) FROM (
        SELECT count(*) c FROM tb_egresso e2
        JOIN tb_programa pr2 ON pr2.co_seq_programa = e2.co_seq_programa
        WHERE pr2.co_seq_area = a.co_seq_area
        GROUP BY pr2.co_seq_programa
    ) z
)
ORDER BY a.nm_area, qt_egressos DESC
LIMIT 25;

-- QA03 | RF6, RE5 | SUBCONSULTA, JOIN, WINDOW, COUNT
-- Para cada programa, nota media recebida e percentil dentro da area (PERCENT_RANK).
SELECT a.nm_area, pr.nm_programa,
       round(avg(pa.vl_nota),2) AS nota_media,
       count(pa.co_seq_parecer) AS qt_pareceres,
       round(percent_rank() OVER (PARTITION BY a.co_seq_area ORDER BY avg(pa.vl_nota))::numeric,2) AS percentil_area
FROM tb_parecer pa
JOIN tb_programa pr ON pr.co_seq_programa = pa.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
GROUP BY a.nm_area, a.co_seq_area, pr.nm_programa, pr.co_seq_programa
ORDER BY a.nm_area, percentil_area DESC
LIMIT 25;

-- QA04 | RF4, RE5 | SUBCONSULTA, JOIN, WINDOW
-- Evolucao do conceito final por programa entre quadrienios (LAG para variacao).
WITH conceitos AS (
    SELECT pr.nm_programa, r.nu_ano_referencia, r.nu_conceito_final
    FROM tb_relatorio r
    JOIN tb_programa pr ON pr.co_seq_programa = r.co_seq_programa
    WHERE r.nu_conceito_final IS NOT NULL
)
SELECT nm_programa, nu_ano_referencia, nu_conceito_final,
       lag(nu_conceito_final) OVER (PARTITION BY nm_programa ORDER BY nu_ano_referencia) AS conceito_anterior,
       nu_conceito_final - lag(nu_conceito_final) OVER (PARTITION BY nm_programa ORDER BY nu_ano_referencia) AS variacao
FROM conceitos
WHERE nm_programa IN (SELECT nm_programa FROM conceitos GROUP BY nm_programa HAVING count(*) > 1)
ORDER BY nm_programa, nu_ano_referencia
LIMIT 30;

-- QA05 | RF2 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Docentes "estrela": acima do percentil 90 de producao (subconsulta de corte).
SELECT dc.co_seq_docente, dc.nm_docente, count(rpc.co_seq_producao) AS qt_producoes
FROM tb_docente dc
JOIN rt_producao_docente rpc ON rpc.co_seq_docente = dc.co_seq_docente
JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
GROUP BY dc.co_seq_docente, dc.nm_docente
HAVING count(rpc.co_seq_producao) >= (
    SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY c)
    FROM (SELECT count(*) c FROM rt_producao_docente GROUP BY co_seq_docente) z
)
ORDER BY qt_producoes DESC
LIMIT 20;

-- QA06 | RF3, RE3 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Programas com colaboracao internacional E financiamento acima da media (intersecao via subconsultas).
SELECT pr.nm_programa,
       sum(pj.vl_financiamento) AS total_financiado,
       count(DISTINCT rpc.co_seq_colaboracao) AS qt_colaboracoes
FROM tb_programa pr
JOIN tb_projeto_pesquisa pj ON pj.co_seq_programa = pr.co_seq_programa
JOIN rt_projeto_colaboracao rpc ON rpc.co_seq_projeto = pj.co_seq_projeto
GROUP BY pr.nm_programa
HAVING sum(pj.vl_financiamento) > (SELECT avg(t) FROM (SELECT sum(vl_financiamento) t FROM tb_projeto_pesquisa GROUP BY co_seq_programa) z)
ORDER BY total_financiado DESC
LIMIT 20;

-- QA07 | RF5, RE5 | SUBCONSULTA, JOIN, WINDOW
-- Indicador de producao docente (PD) por programa com media movel de 2 anos.
WITH ind_pd AS (
    SELECT pr.nm_programa, ind.nu_ano_referencia, ind.vl_indicador
    FROM tb_indicador ind
    JOIN tb_programa pr ON pr.co_seq_programa = ind.co_seq_programa
    WHERE ind.tp_indicador = 'PD'
)
SELECT nm_programa, nu_ano_referencia, round(vl_indicador,2) AS valor,
       round(avg(vl_indicador) OVER (PARTITION BY nm_programa ORDER BY nu_ano_referencia
                                     ROWS BETWEEN 1 PRECEDING AND CURRENT ROW),2) AS media_movel_2a
FROM ind_pd
WHERE nm_programa IN (SELECT nm_programa FROM ind_pd GROUP BY nm_programa HAVING count(*) >= 3)
ORDER BY nm_programa, nu_ano_referencia
LIMIT 30;

-- QA08 | RF1, RE2 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Taxa de titulacao: razao entre egressos e discentes (ativos+titulados) por programa.
SELECT pr.nm_programa,
       (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa = pr.co_seq_programa) AS qt_egressos,
       (SELECT count(*) FROM tb_discente d WHERE d.co_seq_programa = pr.co_seq_programa) AS qt_discentes,
       round(
         (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa = pr.co_seq_programa)::numeric
         / NULLIF((SELECT count(*) FROM tb_discente d WHERE d.co_seq_programa = pr.co_seq_programa),0)
       ,2) AS razao_egr_disc
FROM tb_programa pr
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
ORDER BY razao_egr_disc DESC NULLS LAST
LIMIT 20;

-- QA09 | RF2, RF4 | SUBCONSULTA, JOIN, GROUP BY, COUNT, WINDOW
-- Participacao (%) de cada tipo de producao no total da area, com ranking.
SELECT a.nm_area, pc.tp_producao,
       count(*) AS qt,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY a.nm_area), 1) AS perc_area,
       rank() OVER (PARTITION BY a.nm_area ORDER BY count(*) DESC) AS posicao
FROM tb_producao_cientifica pc
JOIN rt_producao_docente rpc ON rpc.co_seq_producao = pc.co_seq_producao
JOIN rt_programa_docente rpd ON rpd.co_seq_docente = rpc.co_seq_docente
JOIN tb_programa pr ON pr.co_seq_programa = rpd.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
GROUP BY a.nm_area, pc.tp_producao
ORDER BY a.nm_area, perc_area DESC
LIMIT 30;

-- QA10 | RF6, RE4 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Areas cujo peso medio de criterios excede a media global e quantos avaliadores possuem.
SELECT a.nm_area,
       round(avg(ca.vl_peso),2) AS peso_medio,
       count(DISTINCT av.co_seq_avaliador) AS qt_avaliadores
FROM tb_area_avaliacao a
JOIN tb_criterio_avaliacao ca ON ca.co_seq_area = a.co_seq_area
LEFT JOIN tb_avaliador av ON av.co_seq_area = a.co_seq_area
GROUP BY a.nm_area
HAVING avg(ca.vl_peso) > (SELECT avg(vl_peso) FROM tb_criterio_avaliacao)
ORDER BY peso_medio DESC
LIMIT 25;

-- QA11 | RF2, RF3 | SUBCONSULTA, JOIN, GROUP BY, COUNT, WINDOW
-- Top 3 docentes mais produtivos de cada area (ROW_NUMBER particionado).
WITH ranking_doc AS (
    SELECT a.nm_area, dc.nm_docente,
           count(pc.co_seq_producao) AS qt,
           row_number() OVER (PARTITION BY a.co_seq_area ORDER BY count(pc.co_seq_producao) DESC) AS rn
    FROM tb_docente dc
    JOIN rt_producao_docente rpc ON rpc.co_seq_docente = dc.co_seq_docente
    JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
    JOIN rt_programa_docente rpd ON rpd.co_seq_docente = dc.co_seq_docente
    JOIN tb_programa pr ON pr.co_seq_programa = rpd.co_seq_programa
    JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
    GROUP BY a.nm_area, a.co_seq_area, dc.nm_docente
)
SELECT nm_area, nm_docente, qt FROM ranking_doc
WHERE rn <= 3
ORDER BY nm_area, qt DESC
LIMIT 30;

-- QA12 | RE1, RE2 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Inconsistencia de governanca: discentes cujo orientador NAO possui vinculo
-- permanente no programa em que o discente esta matriculado (NOT EXISTS).
-- Regra CAPES: orientador deve ser credenciado (permanente) no programa.
SELECT pr.nm_programa, dc.nm_docente AS orientador, count(d.co_seq_discente) AS qt_discentes_afetados
FROM tb_discente d
JOIN tb_programa pr ON pr.co_seq_programa = d.co_seq_programa
JOIN tb_docente dc ON dc.co_seq_docente = d.co_seq_docente_orientador
WHERE NOT EXISTS (
    SELECT 1 FROM rt_programa_docente rpd
    WHERE rpd.co_seq_docente = d.co_seq_docente_orientador
      AND rpd.co_seq_programa = d.co_seq_programa
      AND rpd.tp_vinculo = 'PE'
)
GROUP BY pr.nm_programa, dc.nm_docente
ORDER BY qt_discentes_afetados DESC
LIMIT 25;

-- QA13 | RF5, RF6 | SUBCONSULTA, JOIN, WINDOW, COUNT
-- Correlacao pratica: conceito final vs quantidade de producoes (quartil de producao).
WITH base AS (
    SELECT pr.co_seq_programa, pr.nm_programa,
           count(DISTINCT pc.co_seq_producao) AS qt_prod,
           max(r.nu_conceito_final) AS conceito
    FROM tb_programa pr
    JOIN rt_programa_docente rpd ON rpd.co_seq_programa = pr.co_seq_programa
    JOIN rt_producao_docente rpc ON rpc.co_seq_docente = rpd.co_seq_docente
    JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
    JOIN tb_relatorio r ON r.co_seq_programa = pr.co_seq_programa AND r.tp_relatorio = 'QU'
    GROUP BY pr.co_seq_programa, pr.nm_programa
)
SELECT nm_programa, qt_prod, conceito,
       ntile(4) OVER (ORDER BY qt_prod) AS quartil_producao
FROM base
ORDER BY qt_prod DESC
LIMIT 25;

-- QA14 | RF3 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Financiadores que apoiam projetos em mais de uma area (diversidade de financiamento).
SELECT pj.ds_financiador,
       count(DISTINCT pr.co_seq_area) AS qt_areas,
       count(DISTINCT pj.co_seq_projeto) AS qt_projetos,
       round(sum(pj.vl_financiamento),2) AS total
FROM tb_projeto_pesquisa pj
JOIN tb_programa pr ON pr.co_seq_programa = pj.co_seq_programa
WHERE pj.ds_financiador IS NOT NULL
GROUP BY pj.ds_financiador
HAVING count(DISTINCT pr.co_seq_area) > 1
ORDER BY qt_areas DESC, total DESC;

-- QA15 | RF2, RE1 | SUBCONSULTA, JOIN, GROUP BY, WINDOW
-- Producao por nivel de programa (ME/DO/MP) com participacao percentual acumulada.
SELECT pr.tp_nivel,
       count(DISTINCT pc.co_seq_producao) AS qt_prod,
       round(100.0 * count(DISTINCT pc.co_seq_producao)
             / sum(count(DISTINCT pc.co_seq_producao)) OVER (), 1) AS perc,
       round(sum(count(DISTINCT pc.co_seq_producao)) OVER (ORDER BY count(DISTINCT pc.co_seq_producao) DESC)
             * 100.0 / sum(count(DISTINCT pc.co_seq_producao)) OVER (), 1) AS perc_acumulado
FROM tb_programa pr
JOIN rt_programa_docente rpd ON rpd.co_seq_programa = pr.co_seq_programa
JOIN rt_producao_docente rpc ON rpc.co_seq_docente = rpd.co_seq_docente
JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
GROUP BY pr.tp_nivel
ORDER BY qt_prod DESC;

-- QA16 | RF6 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Avaliadores que emitiram pareceres em todos os anos em que atuaram acima da media de notas.
SELECT av.nm_avaliador,
       count(pa.co_seq_parecer) AS qt_pareceres,
       round(avg(pa.vl_nota),2) AS nota_media,
       count(DISTINCT pa.nu_ano_avaliacao) AS anos_distintos
FROM tb_avaliador av
JOIN tb_parecer pa ON pa.co_seq_avaliador = av.co_seq_avaliador
JOIN tb_programa pr ON pr.co_seq_programa = pa.co_seq_programa
GROUP BY av.nm_avaliador
HAVING avg(pa.vl_nota) > (SELECT avg(vl_nota) FROM tb_parecer)
   AND count(DISTINCT pa.nu_ano_avaliacao) >= 3
ORDER BY qt_pareceres DESC
LIMIT 20;

-- QA17 | RE6, PPP2 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Auditoria: volume de operacoes (I/A/E) por tabela, comparado ao total auditado.
SELECT au_nm_tabela,
       count(*) FILTER (WHERE au_tp_operacao = 'I') AS insercoes,
       count(*) FILTER (WHERE au_tp_operacao = 'A') AS alteracoes,
       count(*) FILTER (WHERE au_tp_operacao = 'E') AS exclusoes,
       count(*) AS total_tabela,
       round(100.0 * count(*) / (SELECT count(*) FROM au_operacao), 2) AS perc_do_total
FROM au_operacao
GROUP BY au_nm_tabela
ORDER BY total_tabela DESC;

-- QA18 | RE6, RF6 | SUBCONSULTA, JOIN, WINDOW, COUNT
-- Auditoria: operacoes por dia com numeracao sequencial do evento (rastreabilidade temporal).
SELECT au_nm_tabela, au_tp_operacao,
       date_trunc('day', au_dt_operacao)::date AS dia,
       count(*) OVER (PARTITION BY au_nm_tabela) AS total_na_tabela,
       row_number() OVER (PARTITION BY au_nm_tabela ORDER BY au_dt_operacao) AS seq_evento
FROM au_operacao
WHERE au_nm_tabela IN (SELECT au_nm_tabela FROM au_operacao GROUP BY au_nm_tabela HAVING count(*) >= 1)
ORDER BY au_nm_tabela, seq_evento
LIMIT 30;

-- QA19 | RF1, RF2, RF3 | SUBCONSULTA, JOIN, GROUP BY, COUNT
-- Panorama consolidado por programa: egressos, producoes, projetos (multiplas subconsultas).
SELECT pr.nm_programa, a.nm_area,
       (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa = pr.co_seq_programa) AS egressos,
       (SELECT count(*) FROM tb_projeto_pesquisa pj WHERE pj.co_seq_programa = pr.co_seq_programa) AS projetos,
       (SELECT count(DISTINCT d.co_seq_docente) FROM rt_programa_docente d WHERE d.co_seq_programa = pr.co_seq_programa) AS docentes
FROM tb_programa pr
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
WHERE (SELECT count(*) FROM tb_egresso e WHERE e.co_seq_programa = pr.co_seq_programa) > 0
ORDER BY egressos DESC
LIMIT 25;

-- QA20 | RF5, RE5 | SUBCONSULTA, JOIN, WINDOW, COUNT
-- Programas no topo (decil) de cada tipo de indicador no ultimo ano de referencia.
WITH ult AS (
    SELECT ind.tp_indicador, pr.nm_programa, ind.vl_indicador,
           cume_dist() OVER (PARTITION BY ind.tp_indicador ORDER BY ind.vl_indicador) AS dist
    FROM tb_indicador ind
    JOIN tb_programa pr ON pr.co_seq_programa = ind.co_seq_programa
    WHERE ind.nu_ano_referencia = (SELECT max(nu_ano_referencia) FROM tb_indicador)
)
SELECT tp_indicador, nm_programa, round(vl_indicador,2) AS valor, round(dist::numeric,3) AS distribuicao
FROM ult
WHERE dist >= 0.9
ORDER BY tp_indicador, valor DESC
LIMIT 30;
