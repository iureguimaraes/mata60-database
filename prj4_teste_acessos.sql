-- =============================================================================
-- PRJ4 - Teste dos Niveis de Acesso (evidencia experimental da Secao 3.3)
-- Aluno: Iure Vieira Guimaraes | MATA60 - Banco de Dados (UFBA)
--
-- Objetivo: comprovar, no proprio SGBD, que os perfis definidos em
-- prj4_acessos.sql restringem a escrita conforme a PPP2/LGPD.
--
-- Pre-requisitos (nesta ordem):
--   1. prj4_ddl.sql   (cria schema, tabelas e a trigger SECURITY DEFINER)
--   2. prj4_populacao.sql   (opcional, para o SELECT retornar linhas)
--   3. prj4_acessos.sql          (cria os 4 perfis e suas permissoes)
--
-- Como rodar: conectado como o DONO do schema / superuser (ex.: postgres).
-- O SET ROLE so funciona se o usuario atual for membro do role ou superuser.
-- Cada bloco usa savepoint/rollback para nao sujar o banco.
-- =============================================================================
SET search_path TO prj4;

-- Tudo dentro de UMA transacao desfeita no final (ROLLBACK): o teste nao
-- deixa residuo no banco, e o SET ROLE/RESET ROLE funciona normalmente.
BEGIN;

-- =============================================================================
-- TESTE 1 - Perfil ANALISE: leitura permitida, escrita recusada
-- =============================================================================

-- 1a) Leitura: deve FUNCIONAR
SET ROLE prj4_analise;
SELECT count(*) AS programas_visiveis FROM tb_programa;   -- esperado: retorna numero
RESET ROLE;

-- 1b) Escrita: deve FALHAR com "permission denied for table tb_instituicao"
SET ROLE prj4_analise;
DO $$
BEGIN
    INSERT INTO tb_instituicao (nm_instituicao, nu_cnpj, sg_uf, nm_cidade)
    VALUES ('Instituicao Teste', '00000000000191', 'BA', 'Salvador');
    RAISE EXCEPTION 'FALHA DO TESTE: o perfil analise NAO deveria conseguir inserir.';
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK (1b): escrita do perfil analise recusada pelo SGBD (%).', SQLERRM;
END $$;
RESET ROLE;

-- =============================================================================
-- TESTE 2 - Perfil SISTEMA: DML normal nas tabelas de negocio FUNCIONA
--           e a trigger registra a operacao em AU_OPERACAO automaticamente.
-- =============================================================================
SET ROLE prj4_sistema;
INSERT INTO tb_instituicao (nm_instituicao, nu_cnpj, sg_uf, nm_cidade)
VALUES ('Instituicao Sistema OK', '00000000000272', 'BA', 'Salvador');
-- a linha de auditoria correspondente foi gravada pela trigger (SECURITY DEFINER),
-- mesmo o perfil sistema NAO tendo INSERT direto em au_operacao.
RESET ROLE;

-- =============================================================================
-- TESTE 3 - Perfil SISTEMA NAO consegue adulterar a trilha de auditoria
--           (este e o ponto sensivel: auditoria a prova de adulteracao)
-- =============================================================================

-- 3a) DELETE direto em au_operacao: deve FALHAR
SET ROLE prj4_sistema;
DO $$
BEGIN
    DELETE FROM au_operacao WHERE 1=1;
    RAISE EXCEPTION 'FALHA DO TESTE: o perfil sistema NAO deveria apagar auditoria.';
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK (3a): DELETE do perfil sistema em au_operacao recusado (%).', SQLERRM;
END $$;
RESET ROLE;

-- 3b) INSERT/UPDATE direto em au_operacao: tambem deve FALHAR
SET ROLE prj4_sistema;
DO $$
BEGIN
    UPDATE au_operacao SET au_tp_operacao = 'X' WHERE 1=1;
    RAISE EXCEPTION 'FALHA DO TESTE: o perfil sistema NAO deveria alterar auditoria.';
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK (3b): UPDATE do perfil sistema em au_operacao recusado (%).', SQLERRM;
END $$;
RESET ROLE;

-- =============================================================================
-- Resumo esperado ao executar este script:
--   1a -> retorna a contagem de programas         (leitura liberada)
--   1b -> NOTICE OK: escrita do analise recusada
--   2  -> INSERT do sistema executa sem erro       (DML liberado)
--   3a -> NOTICE OK: DELETE em auditoria recusado
--   3b -> NOTICE OK: UPDATE em auditoria recusado
-- Nenhuma linha "FALHA DO TESTE" deve aparecer.
-- =============================================================================

ROLLBACK;   -- desfaz tudo: o teste nao persiste nenhuma alteracao
