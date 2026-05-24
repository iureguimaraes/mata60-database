-- =============================================================================
-- PRJ4 - Plano de Indexacao - PostgreSQL
-- Aluno: Iure Vieira Guimaraes | MATA60 - UFBA
--
-- Justificativa geral:
--   No PostgreSQL, chaves estrangeiras NAO recebem indice automaticamente
--   (apenas PK e UNIQUE recebem). Como praticamente todas as 30 consultas
--   fazem JOIN pelas colunas de FK, o baseline executa Seq Scan + Hash Join
--   nessas tabelas. Os indices abaixo cobrem (a) as FKs usadas em JOIN,
--   (b) colunas de filtro recorrente (WHERE) e (c) colunas de agrupamento/
--   ordenacao. Indices compostos e parciais sao usados onde o padrao de
--   acesso justifica.
--
-- Convencao de nome: IX_<tabela>_<colunas>  (MAD nao define prefixo de indice;
--   adota-se IX_ por clareza, alinhado ao estilo CO_/TB_/RT_).
-- =============================================================================
SET search_path TO prj4;

-- ----------------------------------------------------------------------------
-- GRUPO 1 - Indices de FK nas tabelas associativas (JOINs mais pesados)
-- A PK composta ja cobre a 1a coluna; falta indexar a 2a para o JOIN reverso.
-- ----------------------------------------------------------------------------
-- rt_programa_docente: PK (programa,docente) cobre programa; indexar docente.
CREATE INDEX IX_rt_prog_doc_docente   ON rt_programa_docente (co_seq_docente);
-- rt_producao_docente: PK (producao,docente) cobre producao; indexar docente.
CREATE INDEX IX_rt_prod_doc_docente   ON rt_producao_docente (co_seq_docente);
-- rt_projeto_colaboracao: PK (projeto,colab) cobre projeto; indexar colaboracao.
CREATE INDEX IX_rt_proj_colab_colab   ON rt_projeto_colaboracao (co_seq_colaboracao);

-- ----------------------------------------------------------------------------
-- GRUPO 2 - Indices de FK nas tabelas de negocio
-- Usados nos JOINs de quase todas as consultas (QI01-10, QA01-20).
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- GRUPO 3 - Indices compostos para padroes de filtro+agrupamento
-- ----------------------------------------------------------------------------
-- QI06, QA07, QA20: indicador filtrado por tipo e/ou ano, agrupado por ambos.
CREATE INDEX IX_indicador_prog_ano_tipo ON tb_indicador (co_seq_programa, nu_ano_referencia, tp_indicador);
-- QI10, QA04, QA13: relatorio filtrado por tipo (QU) e agrupado por ano.
CREATE INDEX IX_relatorio_prog_tipo_ano ON tb_relatorio (co_seq_programa, tp_relatorio, nu_ano_referencia);
-- QA03, QA16: parecer agregado por programa/avaliador com nota e ano.
CREATE INDEX IX_parecer_prog_ano       ON tb_parecer (co_seq_programa, nu_ano_avaliacao);

-- ----------------------------------------------------------------------------
-- GRUPO 4 - Indices parciais (cobrem subconjunto filtrado por WHERE)
-- ----------------------------------------------------------------------------
-- QI03: discentes filtrados por status ativo. Indice parcial reduz tamanho.
CREATE INDEX IX_discente_ativo ON tb_discente (co_seq_programa)
    WHERE tp_status = 'AT';
-- QI04, QA09: producao filtrada por Qualis nao-nulo.
CREATE INDEX IX_producao_qualis ON tb_producao_cientifica (ds_qualis)
    WHERE ds_qualis IS NOT NULL;
-- Registros logicamente ativos (exclusao logica) - padrao comum de filtro.
CREATE INDEX IX_egresso_ativo ON tb_egresso (co_seq_programa)
    WHERE st_registro_ativo = 'S';

-- ----------------------------------------------------------------------------
-- GRUPO 5 - Auditoria (QA17, QA18): filtro/agrupamento por tabela e tempo.
-- ----------------------------------------------------------------------------
CREATE INDEX IX_auditoria_tabela ON au_operacao (au_nm_tabela);
CREATE INDEX IX_auditoria_data   ON au_operacao (au_dt_operacao);

-- ----------------------------------------------------------------------------
-- Atualiza estatisticas do otimizador apos criar os indices.
-- ----------------------------------------------------------------------------
ANALYZE;

-- ----------------------------------------------------------------------------
-- Conferencia: indices criados (alem de PK/UNIQUE)
-- ----------------------------------------------------------------------------
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'prj4' AND indexname LIKE 'ix\_%'
ORDER BY tablename, indexname;
