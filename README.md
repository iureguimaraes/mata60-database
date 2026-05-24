# PRJ4 — Sistema para Avaliação Quadrienal da Pós-Graduação (CAPES)

Projeto da disciplina **MATA60 — Banco de Dados** (UFBA) sob a orientação do Prof. Robespierre Pita.
Banco de dados relacional em **PostgreSQL** para gestão e análise dos dados de programas de pós-graduação no ciclo de avaliação quadrienal da CAPES.

## Visão geral

O banco modela a estrutura acadêmica (programas, docentes, discentes, egressos),
a produção científica e os projetos de pesquisa, o processo de avaliação
(critérios, indicadores, pareceres, relatórios) e uma trilha de auditoria.

- **19 tabelas**: 15 de negócio (`TB_`), 3 associativas (`RT_`) e 1 de auditoria (`AU_`)
- Nomenclatura segundo o padrão **MAD2** (DATASUS / ISO-IEC 11179-5)
- PKs `SERIAL` (`CO_SEQ_*`); FKs `INTEGER`; exclusão lógica via `ST_REGISTRO_ATIVO`
- **Auditoria** por trigger genérica (`FN_AUDITORIA`) gravando operações I/A/E em `AU_OPERACAO`
- Toda a manipulação é feita em **SQL nativo** (sem linguagem externa operando o banco)

## Pré-requisitos

- **PostgreSQL 14 ou superior** (testado em PostgreSQL 16)
- Cliente de linha de comando `psql`

Nenhuma dependência externa, biblioteca ou linguagem adicional é necessária.

## Estrutura do repositório

| Arquivo | Conteúdo |
|---|---|
| `prj4_ddl_postgresql.sql` | DDL completo: schema `prj4`, 19 tabelas, constraints, função e triggers de auditoria, comentários (`COMMENT ON`) |
| `prj4_comments.sql` | Complemento do dicionário de dados: `COMMENT ON COLUMN` das colunas restantes (cobertura 100%) |
| `prj4_acessos.sql` | Níveis de acesso (DCL): quatro perfis (DBA, sistema, análise, backup) com permissões, conforme a política de privacidade (PPP2) |
| `prj4_populacao_skew.sql` | Carga de dados em SQL nativo com distribuição enviesada (*skew*); `TB_EGRESSO` e `TB_PRODUCAO_CIENTIFICA` com 6.000 registros cada |
| `prj4_consultas_intermediarias.sql` | 10 consultas intermediárias (QI01–QI10) |
| `prj4_consultas_avancadas.sql` | 20 consultas avançadas (QA01–QA20) |
| `prj4_indices.sql` | 24 índices justificados (plano de indexação) |
| `prj4_benchmark.sql` | Benchmark auto-suficiente em PL/pgSQL: roda baseline e indexado num só comando, 8 consultas, 20 execuções, e calcula o *speedup* |
| `prj4_metadados.sql` | Exploração dos metadados via `information_schema`, `pg_catalog`, `obj_description`/`col_description` e funções `pg_*_size` |

## Alternativa: rodar com Docker

Caso você não tenha o PostgreSQL instalado localmente (ou prefira um ambiente
isolado), é possível subir um servidor PostgreSQL em um contêiner Docker. Requer
apenas o [Docker](https://docs.docker.com/get-docker/) instalado.

### 1. Subir o contêiner (já cria o banco `prj4db`)

```bash
docker run --name prj4-pg \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=prj4db \
  -p 5432:5432 \
  -d postgres:16
```

A variável `POSTGRES_DB=prj4db` faz o próprio contêiner criar o banco na
inicialização, portanto o passo `createdb` não é necessário neste caminho.

### 2. Executar os scripts dentro do contêiner

Copie os scripts para dentro do contêiner e execute-os na ordem:

```bash
# copia todos os .sql para o contêiner
docker cp . prj4-pg:/tmp/prj4/

# executa na ordem (DDL -> comentários -> acessos -> população -> índices)
docker exec -i prj4-pg psql -U postgres -d prj4db -v ON_ERROR_STOP=1 -f /tmp/prj4/prj4_ddl_postgresql.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -v ON_ERROR_STOP=1 -f /tmp/prj4/prj4_comments.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -v ON_ERROR_STOP=1 -f /tmp/prj4/prj4_acessos.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -v ON_ERROR_STOP=1 -f /tmp/prj4/prj4_populacao_skew.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -v ON_ERROR_STOP=1 -f /tmp/prj4/prj4_indices.sql
```

### 3. Consultas, metadados e benchmark

```bash
docker exec -i prj4-pg psql -U postgres -d prj4db -f /tmp/prj4/prj4_consultas_intermediarias.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -f /tmp/prj4/prj4_consultas_avancadas.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -f /tmp/prj4/prj4_metadados.sql
docker exec -i prj4-pg psql -U postgres -d prj4db -f /tmp/prj4/prj4_benchmark.sql
```

### Acessar o banco interativamente

```bash
docker exec -it prj4-pg psql -U postgres -d prj4db
```

### Encerrar e remover o contêiner

```bash
docker stop prj4-pg && docker rm prj4-pg
```

> Alternativamente, se você tiver o cliente `psql` na máquina, pode conectar ao
> contêiner pela porta publicada: `psql -h localhost -U postgres -d prj4db`
> (senha `postgres`), e seguir os mesmos comandos da seção abaixo.

## Reprodução passo a passo (PostgreSQL local)

### 1. Criar o banco

```bash
createdb prj4db
```

### 2. Executar os scripts na ordem

A ordem importa: o DDL cria a estrutura, os comentários completam o dicionário,
a população carrega os dados e os índices são criados sobre as tabelas já populadas.

```bash
# 1. Estrutura (schema, tabelas, constraints, auditoria)
psql -d prj4db -v ON_ERROR_STOP=1 -f prj4_ddl_postgresql.sql

# 2. Complemento do dicionário de dados
psql -d prj4db -v ON_ERROR_STOP=1 -f prj4_comments.sql

# 3. Níveis de acesso (perfis e permissões)
psql -d prj4db -v ON_ERROR_STOP=1 -f prj4_acessos.sql

# 4. População com skew
psql -d prj4db -v ON_ERROR_STOP=1 -f prj4_populacao_skew.sql

# 5. Plano de indexação
psql -d prj4db -v ON_ERROR_STOP=1 -f prj4_indices.sql
```

Após esses cinco passos, o banco está completo e pronto para consulta.

### 3. Executar as consultas (em qualquer ordem)

```bash
psql -d prj4db -f prj4_consultas_intermediarias.sql
psql -d prj4db -f prj4_consultas_avancadas.sql
```

### 4. Explorar os metadados

```bash
psql -d prj4db -f prj4_metadados.sql
```

### 5. Rodar o benchmark (opcional)

O benchmark é **auto-suficiente**: um único comando executa as duas fases
(baseline sem índices e indexado), independentemente do estado atual do banco.
O script remove os índices, mede 8 consultas representativas (20 execuções cada),
recria os índices, mede de novo e exibe o comparativo com o *speedup*.

```bash
psql -d prj4db -f prj4_benchmark.sql
```

Ao final, o banco permanece com os índices criados. Não é preciso seguir nenhuma
ordem especial — pode ser rodado a qualquer momento após a população.

## Notas de modelagem

- **Auditoria genérica**: em vez de uma tabela de auditoria espelhada por tabela,
  usa-se uma única `AU_OPERACAO` alimentada pela função `FN_AUDITORIA`, acionada
  por triggers `AFTER INSERT/UPDATE/DELETE` em todas as tabelas de negócio e
  associativas. O usuário de aplicação é propagado via `SET app.usuario`.
- **Exclusão lógica**: registros não são removidos fisicamente; a coluna
  `ST_REGISTRO_ATIVO` (`S`/`N`) marca o estado, preservando a trilha de auditoria.
- **Domínios controlados**: campos de tipo (`TP_*`) e status (`ST_*`) são
  `varchar` restritos por `CHECK`, formando vocabulário controlado conforme o MAD.
