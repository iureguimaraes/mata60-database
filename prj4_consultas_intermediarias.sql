-- =============================================================================
-- PRJ4 - Consultas INTERMEDIARIAS (10) - PostgreSQL
-- Regra do descritivo: >= 3 tabelas E >= 2 de {JOIN, GROUP BY, WINDOW, COUNT}.
-- Cada consulta indica o requisito atendido e as funções utilizadas.
-- =============================================================================
SET search_path TO prj4;

-- QI01 | RF2, RE1 | JOIN, GROUP BY, COUNT
-- Quantidade de producoes cientificas por programa (via autoria dos docentes).
SELECT pr.co_seq_programa, pr.nm_programa, count(DISTINCT pc.co_seq_producao) AS qt_producoes
FROM tb_programa pr
JOIN rt_programa_docente rpd ON rpd.co_seq_programa = pr.co_seq_programa
JOIN rt_producao_docente rpc ON rpc.co_seq_docente  = rpd.co_seq_docente
JOIN tb_producao_cientifica pc ON pc.co_seq_producao = rpc.co_seq_producao
GROUP BY pr.co_seq_programa, pr.nm_programa
ORDER BY qt_producoes DESC
LIMIT 20;

-- QI02 | RF1 | JOIN, GROUP BY, COUNT
-- Numero de egressos titulados por programa e instituicao.
SELECT i.nm_instituicao, pr.nm_programa, count(e.co_seq_egresso) AS qt_egressos
FROM tb_egresso e
JOIN tb_programa pr   ON pr.co_seq_programa = e.co_seq_programa
JOIN tb_instituicao i ON i.co_seq_instituicao = pr.co_seq_instituicao
GROUP BY i.nm_instituicao, pr.nm_programa
ORDER BY qt_egressos DESC
LIMIT 20;

-- QI03 | RE2 | JOIN, GROUP BY, COUNT
-- Discentes ativos por programa e nivel (mestrado/doutorado).
SELECT pr.nm_programa, d.tp_nivel, count(*) AS qt_discentes
FROM tb_discente d
JOIN tb_programa pr ON pr.co_seq_programa = d.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
WHERE d.tp_status = 'AT'
GROUP BY pr.nm_programa, d.tp_nivel
ORDER BY qt_discentes DESC
LIMIT 20;

-- QI04 | RF2 | JOIN, GROUP BY, COUNT
-- Distribuicao de producoes por classificacao Qualis em cada area de avaliacao.
SELECT a.nm_area, pc.ds_qualis, count(*) AS qt
FROM tb_producao_cientifica pc
JOIN rt_producao_docente rpc ON rpc.co_seq_producao = pc.co_seq_producao
JOIN rt_programa_docente rpd ON rpd.co_seq_docente = rpc.co_seq_docente
JOIN tb_programa pr ON pr.co_seq_programa = rpd.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
WHERE pc.ds_qualis IS NOT NULL
GROUP BY a.nm_area, pc.ds_qualis
ORDER BY a.nm_area, pc.ds_qualis
LIMIT 30;

-- QI05 | RF6 | JOIN, GROUP BY (AVG/COUNT)
-- Nota media e numero de pareceres recebidos por programa.
SELECT pr.nm_programa, count(pa.co_seq_parecer) AS qt_pareceres, round(avg(pa.vl_nota),2) AS nota_media
FROM tb_parecer pa
JOIN tb_programa pr ON pr.co_seq_programa = pa.co_seq_programa
JOIN tb_avaliador av ON av.co_seq_avaliador = pa.co_seq_avaliador
GROUP BY pr.nm_programa
HAVING count(pa.co_seq_parecer) > 0
ORDER BY nota_media DESC
LIMIT 20;

-- QI06 | RF5 | JOIN, GROUP BY
-- Valor medio de cada tipo de indicador por ano de referencia.
SELECT ind.nu_ano_referencia, ind.tp_indicador, round(avg(ind.vl_indicador),2) AS media
FROM tb_indicador ind
JOIN tb_programa pr ON pr.co_seq_programa = ind.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
GROUP BY ind.nu_ano_referencia, ind.tp_indicador
ORDER BY ind.nu_ano_referencia, ind.tp_indicador;

-- QI07 | RF3, RE3 | JOIN, GROUP BY, COUNT
-- Numero de colaboracoes internacionais por programa, atraves dos projetos.
SELECT pr.nm_programa, count(DISTINCT ci.co_seq_colaboracao) AS qt_colaboracoes
FROM tb_programa pr
JOIN tb_projeto_pesquisa pj ON pj.co_seq_programa = pr.co_seq_programa
JOIN rt_projeto_colaboracao rpc ON rpc.co_seq_projeto = pj.co_seq_projeto
JOIN tb_colaboracao_internacional ci ON ci.co_seq_colaboracao = rpc.co_seq_colaboracao
GROUP BY pr.nm_programa
ORDER BY qt_colaboracoes DESC
LIMIT 20;

-- QI08 | RF3 | JOIN, GROUP BY, WINDOW
-- Financiamento total por programa e o ranking (window) entre todos os programas.
SELECT pr.nm_programa,
       sum(pj.vl_financiamento) AS total_financiado,
       rank() OVER (ORDER BY sum(pj.vl_financiamento) DESC) AS ranking
FROM tb_projeto_pesquisa pj
JOIN tb_programa pr ON pr.co_seq_programa = pj.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
GROUP BY pr.nm_programa
ORDER BY ranking
LIMIT 20;

-- QI09 | RF2 | JOIN, WINDOW, COUNT
-- Producoes por ano com total acumulado (running total) ao longo do tempo.
SELECT ano, qt_ano,
       sum(qt_ano) OVER (ORDER BY ano) AS acumulado
FROM (
    SELECT pc.nu_ano_publicacao AS ano, count(*) AS qt_ano
    FROM tb_producao_cientifica pc
    JOIN rt_producao_docente rpc ON rpc.co_seq_producao = pc.co_seq_producao
    JOIN tb_docente dc ON dc.co_seq_docente = rpc.co_seq_docente
    GROUP BY pc.nu_ano_publicacao
) t
ORDER BY ano;

-- QI10 | RF6, RE5 | JOIN, GROUP BY
-- Conceito final medio por area de avaliacao nos relatorios quadrienais.
SELECT a.nm_area, count(r.co_seq_relatorio) AS qt_relatorios, round(avg(r.nu_conceito_final),2) AS conceito_medio
FROM tb_relatorio r
JOIN tb_programa pr ON pr.co_seq_programa = r.co_seq_programa
JOIN tb_area_avaliacao a ON a.co_seq_area = pr.co_seq_area
WHERE r.tp_relatorio = 'QU'
GROUP BY a.nm_area
ORDER BY conceito_medio DESC
LIMIT 20;
