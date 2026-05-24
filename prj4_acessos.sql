-- =============================================================================
-- PRJ4 - Niveis de Acesso e Permissoes (DCL do PostgreSQL)
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
--
-- Implementa os quatro niveis de acesso definidos na Politica de Privacidade
-- e Auditoria (PPP2), em conformidade com a LGPD, usando os recursos nativos
-- de controle de acesso do PostgreSQL (CREATE ROLE + GRANT/REVOKE - DCL).
--
-- Modelo adotado: ROLES DE GRUPO (NOLOGIN) que representam os PERFIS de acesso.
-- Usuarios nominais (com login e senha) sao criados pelo DBA e vinculados ao
-- perfil correspondente via GRANT <perfil> TO <usuario>. Nao se embutem senhas
-- neste script, por seguranca.
--
-- Aplicar APOS o prj4_ddl.sql (as tabelas precisam existir).
-- =============================================================================
SET search_path TO prj4;

-- ----------------------------------------------------------------------------
-- Criacao dos perfis (roles de grupo, sem login proprio)
-- Idempotente: cria cada perfil apenas se ainda nao existir. Evita falhas de
-- DROP quando o role ja possui privilegios concedidos em outros bancos.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='prj4_dba')     THEN CREATE ROLE prj4_dba     NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='prj4_sistema') THEN CREATE ROLE prj4_sistema NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='prj4_analise') THEN CREATE ROLE prj4_analise NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='prj4_backup')  THEN CREATE ROLE prj4_backup  NOLOGIN; END IF;
END $$;

COMMENT ON ROLE prj4_dba     IS 'Perfil DBA: acesso total (DDL, DML, DCL) e gerenciamento.';
COMMENT ON ROLE prj4_sistema IS 'Perfil Sistema: DML (INSERT/UPDATE/DELETE) e execucao de rotinas.';
COMMENT ON ROLE prj4_analise IS 'Perfil Analise: somente leitura (SELECT) de tabelas e views.';
COMMENT ON ROLE prj4_backup  IS 'Perfil Backup: somente leitura, para rotinas de copia de seguranca.';

-- ----------------------------------------------------------------------------
-- Acesso ao schema
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA prj4 TO prj4_sistema, prj4_analise, prj4_backup;
GRANT ALL   ON SCHEMA prj4 TO prj4_dba;

-- ----------------------------------------------------------------------------
-- DBA - acesso total ao schema e aos objetos
-- ----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA prj4 TO prj4_dba;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA prj4 TO prj4_dba;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA prj4 TO prj4_dba;

-- ----------------------------------------------------------------------------
-- SISTEMA - DML completo (sem DDL); usa sequences e rotinas
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA prj4 TO prj4_sistema;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA prj4 TO prj4_sistema;
GRANT EXECUTE                        ON ALL FUNCTIONS IN SCHEMA prj4 TO prj4_sistema;

-- Auditoria a prova de adulteracao (RE6 / PPP2 / LGPD):
-- AU_OPERACAO e append-only, alimentada SO pela trigger FN_AUDITORIA, que e
-- SECURITY DEFINER e grava com os privilegios do dono. Por isso revogamos a
-- escrita direta do perfil operacional - o sistema NAO pode inserir, alterar
-- nem apagar linhas de auditoria por fora da trigger. Mantem apenas o SELECT.
REVOKE INSERT, UPDATE, DELETE ON au_operacao FROM prj4_sistema;

-- ----------------------------------------------------------------------------
-- ANALISE - somente leitura (SELECT) de tabelas e views
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA prj4 TO prj4_analise;

-- ----------------------------------------------------------------------------
-- BACKUP - somente leitura (cobre o dump logico via pg_dump)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA prj4 TO prj4_backup;

-- ----------------------------------------------------------------------------
-- Privilegios padrao para objetos FUTUROS (tabelas/sequences criadas depois
-- herdam automaticamente as permissoes do perfil correspondente)
-- ----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA prj4
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO prj4_sistema;
ALTER DEFAULT PRIVILEGES IN SCHEMA prj4
    GRANT SELECT ON TABLES TO prj4_analise, prj4_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA prj4
    GRANT USAGE, SELECT ON SEQUENCES TO prj4_sistema;

-- =============================================================================
-- Como vincular um usuario real a um perfil (executado pelo DBA):
--   CREATE ROLE app_servico LOGIN PASSWORD '***';
--   GRANT prj4_sistema TO app_servico;
--
--   CREATE ROLE maria_analista LOGIN PASSWORD '***';
--   GRANT prj4_analise TO maria_analista;
-- =============================================================================
