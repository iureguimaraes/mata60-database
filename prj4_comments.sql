-- =============================================================================
-- PRJ4 - Complemento de Dicionario de Dados (COMMENT ON COLUMN)
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
--
-- Objetivo: elevar a cobertura de documentacao das colunas
-- completando o dicionario de dados exigido pela metodologia MAD.
-- Os COMMENT ON ja presentes no DDL principal permanecem; este arquivo
-- apenas preenche as colunas que ainda nao tinham descricao.
--
-- Aplicar APOS o prj4_ddl.sql. COMMENT ON sobrescreve.
-- =============================================================================
SET search_path TO prj4;

-- ----------------------------------------------------------------------------
-- TB_INSTITUICAO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_INSTITUICAO.NM_INSTITUICAO IS 'Nome oficial da instituicao de ensino superior.';
COMMENT ON COLUMN TB_INSTITUICAO.NM_CIDADE      IS 'Municipio sede da instituicao.';

-- ----------------------------------------------------------------------------
-- TB_AREA_AVALIACAO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_AREA_AVALIACAO.CO_SEQ_AREA IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_AREA_AVALIACAO.NM_AREA     IS 'Nome da area de avaliacao CAPES.';

-- ----------------------------------------------------------------------------
-- TB_DOCENTE
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_DOCENTE.CO_SEQ_DOCENTE   IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_DOCENTE.NM_DOCENTE       IS 'Nome completo do docente.';
COMMENT ON COLUMN TB_DOCENTE.NM_AREA_ATUACAO  IS 'Area de atuacao/especializacao declarada pelo docente.';
COMMENT ON COLUMN TB_DOCENTE.ST_REGISTRO_ATIVO IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_EVENTO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_EVENTO.CO_SEQ_EVENTO IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_EVENTO.NM_EVENTO     IS 'Nome do evento academico.';
COMMENT ON COLUMN TB_EVENTO.NM_LOCAL      IS 'Local de realizacao (cidade/pais).';
COMMENT ON COLUMN TB_EVENTO.DT_INICIO     IS 'Data de inicio do evento.';
COMMENT ON COLUMN TB_EVENTO.DT_FIM        IS 'Data de encerramento do evento. Deve ser >= DT_INICIO.';

-- ----------------------------------------------------------------------------
-- TB_COLABORACAO_INTERNACIONAL
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.CO_SEQ_COLABORACAO      IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.NM_INSTITUICAO_PARCEIRA IS 'Nome da instituicao estrangeira parceira.';
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.NM_PAIS                 IS 'Pais da instituicao parceira.';
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.DT_INICIO               IS 'Data de inicio da colaboracao.';
COMMENT ON COLUMN TB_COLABORACAO_INTERNACIONAL.DT_FIM                  IS 'Data de termino da colaboracao. NULL se vigente.';

-- ----------------------------------------------------------------------------
-- TB_PROGRAMA
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_PROGRAMA.CO_SEQ_PROGRAMA   IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_PROGRAMA.NM_PROGRAMA       IS 'Nome do programa de pos-graduacao.';
COMMENT ON COLUMN TB_PROGRAMA.ST_REGISTRO_ATIVO IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_DISCENTE
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_DISCENTE.CO_SEQ_DISCENTE     IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_DISCENTE.NM_DISCENTE         IS 'Nome completo do discente.';
COMMENT ON COLUMN TB_DISCENTE.TP_NIVEL            IS 'Nivel do curso. Dominio: ME (mestrado), DO (doutorado).';
COMMENT ON COLUMN TB_DISCENTE.CO_SEQ_PROGRAMA     IS 'FK -> TB_PROGRAMA. Programa em que o discente esta matriculado.';
COMMENT ON COLUMN TB_DISCENTE.DT_INGRESSO         IS 'Data de ingresso do discente no programa.';
COMMENT ON COLUMN TB_DISCENTE.DT_PREVISAO_DEFESA  IS 'Data prevista para defesa. NULL se nao definida.';
COMMENT ON COLUMN TB_DISCENTE.ST_REGISTRO_ATIVO   IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_EGRESSO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_EGRESSO.CO_SEQ_EGRESSO          IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_EGRESSO.NM_EGRESSO              IS 'Nome completo do egresso.';
COMMENT ON COLUMN TB_EGRESSO.CO_SEQ_PROGRAMA         IS 'FK -> TB_PROGRAMA. Programa que titulou o egresso.';
COMMENT ON COLUMN TB_EGRESSO.DT_TITULACAO            IS 'Data de obtencao do titulo.';
COMMENT ON COLUMN TB_EGRESSO.DS_ATUACAO_PROFISSIONAL IS 'Descricao da atuacao profissional atual do egresso.';
COMMENT ON COLUMN TB_EGRESSO.NM_INSTITUICAO_ATUAL    IS 'Instituicao/empresa onde o egresso atua atualmente.';
COMMENT ON COLUMN TB_EGRESSO.ST_REGISTRO_ATIVO       IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_PRODUCAO_CIENTIFICA
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.CO_SEQ_PRODUCAO    IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.NM_TITULO          IS 'Titulo da producao cientifica.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.NM_VEICULO         IS 'Veiculo de publicacao (periodico, editora, anais).';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.NU_ANO_PUBLICACAO  IS 'Ano de publicacao da producao.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.DS_DOI             IS 'Digital Object Identifier da producao, se houver.';
COMMENT ON COLUMN TB_PRODUCAO_CIENTIFICA.ST_REGISTRO_ATIVO  IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_PROJETO_PESQUISA
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_PROJETO_PESQUISA.CO_SEQ_PROJETO    IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.NM_PROJETO        IS 'Titulo do projeto de pesquisa.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.DS_FINANCIADOR    IS 'Agencia ou orgao financiador (CNPq, CAPES, FAPESB etc.).';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.CO_SEQ_PROGRAMA   IS 'FK -> TB_PROGRAMA. Programa responsavel pelo projeto.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.DT_INICIO         IS 'Data de inicio do projeto.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.DT_FIM            IS 'Data de termino do projeto. NULL se em andamento.';
COMMENT ON COLUMN TB_PROJETO_PESQUISA.ST_REGISTRO_ATIVO IS 'Exclusao logica. Dominio: S (ativo) / N (inativo).';

-- ----------------------------------------------------------------------------
-- TB_CRITERIO_AVALIACAO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_CRITERIO_AVALIACAO.CO_SEQ_CRITERIO IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_CRITERIO_AVALIACAO.CO_SEQ_AREA     IS 'FK -> TB_AREA_AVALIACAO. Area a que o criterio se aplica.';
COMMENT ON COLUMN TB_CRITERIO_AVALIACAO.NM_CRITERIO     IS 'Nome do criterio de avaliacao CAPES.';
COMMENT ON COLUMN TB_CRITERIO_AVALIACAO.DS_CRITERIO     IS 'Descricao detalhada do criterio.';

-- ----------------------------------------------------------------------------
-- TB_INDICADOR
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_INDICADOR.CO_SEQ_INDICADOR  IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_INDICADOR.CO_SEQ_PROGRAMA   IS 'FK -> TB_PROGRAMA. Programa ao qual o indicador se refere.';
COMMENT ON COLUMN TB_INDICADOR.NU_ANO_REFERENCIA IS 'Ano de referencia do indicador.';
COMMENT ON COLUMN TB_INDICADOR.VL_INDICADOR      IS 'Valor numerico apurado do indicador.';

-- ----------------------------------------------------------------------------
-- TB_AVALIADOR
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_AVALIADOR.CO_SEQ_AVALIADOR      IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_AVALIADOR.NM_AVALIADOR          IS 'Nome completo do avaliador.';
COMMENT ON COLUMN TB_AVALIADOR.CO_SEQ_AREA           IS 'FK -> TB_AREA_AVALIACAO. Area de especialidade do avaliador.';
COMMENT ON COLUMN TB_AVALIADOR.NM_INSTITUICAO_ORIGEM IS 'Instituicao de origem do avaliador.';

-- ----------------------------------------------------------------------------
-- TB_PARECER
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_PARECER.CO_SEQ_PARECER    IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_PARECER.CO_SEQ_AVALIADOR  IS 'FK -> TB_AVALIADOR. Avaliador que emitiu o parecer.';
COMMENT ON COLUMN TB_PARECER.CO_SEQ_PROGRAMA   IS 'FK -> TB_PROGRAMA. Programa avaliado.';
COMMENT ON COLUMN TB_PARECER.NU_ANO_AVALIACAO  IS 'Ano de referencia da avaliacao.';
COMMENT ON COLUMN TB_PARECER.DS_PARECER        IS 'Texto do parecer tecnico. NULL se nao registrado.';
COMMENT ON COLUMN TB_PARECER.DT_EMISSAO        IS 'Data de emissao do parecer.';

-- ----------------------------------------------------------------------------
-- TB_RELATORIO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN TB_RELATORIO.CO_SEQ_RELATORIO  IS 'Chave primaria sequencial, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN TB_RELATORIO.CO_SEQ_PROGRAMA   IS 'FK -> TB_PROGRAMA. Programa objeto do relatorio.';
COMMENT ON COLUMN TB_RELATORIO.NU_ANO_REFERENCIA IS 'Ano de referencia do relatorio.';
COMMENT ON COLUMN TB_RELATORIO.DT_GERACAO        IS 'Data de geracao do relatorio.';

-- ----------------------------------------------------------------------------
-- RT_PROGRAMA_DOCENTE
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN RT_PROGRAMA_DOCENTE.CO_SEQ_PROGRAMA   IS 'FK -> TB_PROGRAMA. Parte da PK composta.';
COMMENT ON COLUMN RT_PROGRAMA_DOCENTE.CO_SEQ_DOCENTE    IS 'FK -> TB_DOCENTE. Parte da PK composta.';
COMMENT ON COLUMN RT_PROGRAMA_DOCENTE.DT_INICIO_VINCULO IS 'Data de inicio do vinculo do docente ao programa.';

-- ----------------------------------------------------------------------------
-- RT_PRODUCAO_DOCENTE
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN RT_PRODUCAO_DOCENTE.CO_SEQ_PRODUCAO IS 'FK -> TB_PRODUCAO_CIENTIFICA. Parte da PK composta.';
COMMENT ON COLUMN RT_PRODUCAO_DOCENTE.CO_SEQ_DOCENTE  IS 'FK -> TB_DOCENTE. Parte da PK composta.';

-- ----------------------------------------------------------------------------
-- RT_PROJETO_COLABORACAO
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN RT_PROJETO_COLABORACAO.CO_SEQ_PROJETO     IS 'FK -> TB_PROJETO_PESQUISA. Parte da PK composta.';
COMMENT ON COLUMN RT_PROJETO_COLABORACAO.CO_SEQ_COLABORACAO IS 'FK -> TB_COLABORACAO_INTERNACIONAL. Parte da PK composta.';

-- ----------------------------------------------------------------------------
-- AU_OPERACAO (auditoria)
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN AU_OPERACAO.CO_SEQ_AUDITORIA        IS 'Chave primaria sequencial da trilha de auditoria, controlada pelo datatype SERIAL.';
COMMENT ON COLUMN AU_OPERACAO.AU_DT_OPERACAO          IS 'Timestamp da operacao (clock_timestamp no momento do trigger).';
COMMENT ON COLUMN AU_OPERACAO.AU_NM_TABELA            IS 'Nome da tabela de origem da operacao auditada.';
COMMENT ON COLUMN AU_OPERACAO.AU_DS_USUARIO_SESSAO    IS 'Usuario de banco (session_user) que executou a operacao.';
COMMENT ON COLUMN AU_OPERACAO.AU_NU_IP_SESSAO         IS 'Endereco IP de origem da sessao (ou "local").';
COMMENT ON COLUMN AU_OPERACAO.AU_DS_USUARIO_APLICACAO IS 'Login da aplicacao informado via SET app.usuario.';
