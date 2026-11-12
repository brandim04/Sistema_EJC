-- Inspecao somente de leitura para preparar a migracao multi-paroquia/edicao.
-- Execute cada bloco separadamente no SQL Editor do Supabase.
-- Os resultados podem conter nomes de colunas sensiveis; nao compartilhe valores de linhas.

-- 1. Tabelas e colunas: tipo, nulabilidade, default e ordem.
SELECT
  c.table_schema,
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.character_maximum_length,
  c.numeric_precision,
  c.numeric_scale
FROM information_schema.columns AS c
WHERE c.table_schema IN ('public', 'auth')
  AND (c.table_schema = 'public' OR c.table_name = 'users')
ORDER BY c.table_schema, c.table_name, c.ordinal_position;

-- 2. Chaves primarias, unicas e estrangeiras; inclui a definicao completa das FKs.
SELECT
  ns.nspname AS table_schema,
  tbl.relname AS table_name,
  con.conname AS constraint_name,
  CASE con.contype
    WHEN 'p' THEN 'PRIMARY KEY'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 'c' THEN 'CHECK'
    WHEN 'x' THEN 'EXCLUSION'
  END AS constraint_type,
  pg_get_constraintdef(con.oid, true) AS definition,
  ref_ns.nspname AS referenced_schema,
  ref_tbl.relname AS referenced_table
FROM pg_constraint AS con
JOIN pg_class AS tbl ON tbl.oid = con.conrelid
JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
LEFT JOIN pg_class AS ref_tbl ON ref_tbl.oid = con.confrelid
LEFT JOIN pg_namespace AS ref_ns ON ref_ns.oid = ref_tbl.relnamespace
WHERE ns.nspname = 'public'
  AND con.contype IN ('p', 'f', 'u', 'c', 'x')
ORDER BY ns.nspname, tbl.relname, con.contype, con.conname;

-- 3. Situacao de RLS por tabela no schema public.
SELECT
  n.nspname AS table_schema,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
ORDER BY c.relname;

-- 4. Politicas existentes (roles, comandos e expressoes USING/WITH CHECK).
SELECT
  schemaname AS table_schema,
  tablename AS table_name,
  policyname,
  permissive,
  roles,
  cmd AS command,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 5. Triggers nao internos em tabelas public, com definicao e funcao chamada.
SELECT
  trigger_ns.nspname AS table_schema,
  table_class.relname AS table_name,
  trigger_row.tgname AS trigger_name,
  pg_get_triggerdef(trigger_row.oid, true) AS trigger_definition,
  function_ns.nspname AS function_schema,
  function_row.proname AS function_name,
  pg_get_function_identity_arguments(function_row.oid) AS function_arguments
FROM pg_trigger AS trigger_row
JOIN pg_class AS table_class ON table_class.oid = trigger_row.tgrelid
JOIN pg_namespace AS trigger_ns ON trigger_ns.oid = table_class.relnamespace
JOIN pg_proc AS function_row ON function_row.oid = trigger_row.tgfoid
JOIN pg_namespace AS function_ns ON function_ns.oid = function_row.pronamespace
WHERE trigger_ns.nspname = 'public'
  AND NOT trigger_row.tgisinternal
ORDER BY table_class.relname, trigger_row.tgname;

-- 6. Funcoes publicas relacionadas a tabelas e funcoes de negocio, incluindo baixar_estoque.
-- A definicao e exibida para leitura; esta consulta nao executa as funcoes.
SELECT
  function_ns.nspname AS function_schema,
  function_row.proname AS function_name,
  pg_get_function_identity_arguments(function_row.oid) AS arguments,
  pg_get_function_result(function_row.oid) AS result_type,
  language_row.lanname AS language,
  function_row.prosecdef AS security_definer,
  function_row.provolatile AS volatility,
  function_row.proconfig AS settings,
  pg_get_functiondef(function_row.oid) AS function_definition
FROM pg_proc AS function_row
JOIN pg_namespace AS function_ns ON function_ns.oid = function_row.pronamespace
JOIN pg_language AS language_row ON language_row.oid = function_row.prolang
WHERE function_ns.nspname = 'public'
  AND (
    function_row.proname = 'baixar_estoque'
    OR function_row.prorettype = 'trigger'::regtype
    OR function_row.prokind IN ('f', 'p')
  )
ORDER BY function_row.proname, arguments;

-- 7. Contagens estimadas de linhas por tabela public (estatisticas do PostgreSQL).
-- n_live_tup e uma estimativa; nao le os dados das tabelas nem substitui contagem exata.
SELECT
  schemaname AS table_schema,
  relname AS table_name,
  n_live_tup AS estimated_live_rows,
  n_dead_tup AS estimated_dead_rows,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY relname;

-- 8. Gera uma consulta SELECT count(*) exata para cada tabela-base public.
-- Copie as consultas geradas e execute-as separadamente; a geracao nao le nem altera dados.
SELECT
  format(
    'SELECT %L AS table_name, count(*) AS exact_rows FROM %I.%I;',
    schemaname || '.' || tablename,
    schemaname,
    tablename
  ) AS exact_count_query
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 9. Mapa explicito dos relacionamentos entre as entidades de interesse.
-- Lista FKs cujo lado de origem ou destino envolve usuarios, vendas, pessoas,
-- pagamentos, produtos, itens_venda, equipes ou circulos.
SELECT
  source_ns.nspname AS source_schema,
  source_table.relname AS source_table,
  source_column.attname AS source_column,
  constraint_row.conname AS foreign_key_name,
  target_ns.nspname AS target_schema,
  target_table.relname AS target_table,
  target_column.attname AS target_column,
  pg_get_constraintdef(constraint_row.oid, true) AS definition
FROM pg_constraint AS constraint_row
JOIN pg_class AS source_table ON source_table.oid = constraint_row.conrelid
JOIN pg_namespace AS source_ns ON source_ns.oid = source_table.relnamespace
JOIN pg_class AS target_table ON target_table.oid = constraint_row.confrelid
JOIN pg_namespace AS target_ns ON target_ns.oid = target_table.relnamespace
JOIN LATERAL unnest(constraint_row.conkey) WITH ORDINALITY AS source_key(attnum, ord) ON true
JOIN LATERAL unnest(constraint_row.confkey) WITH ORDINALITY AS target_key(attnum, ord)
  ON target_key.ord = source_key.ord
JOIN pg_attribute AS source_column
  ON source_column.attrelid = source_table.oid AND source_column.attnum = source_key.attnum
JOIN pg_attribute AS target_column
  ON target_column.attrelid = target_table.oid AND target_column.attnum = target_key.attnum
WHERE constraint_row.contype = 'f'
  AND source_ns.nspname = 'public'
  AND (
    source_table.relname IN ('usuarios', 'vendas', 'pessoas', 'pagamentos', 'produtos', 'itens_venda', 'equipes', 'circulos')
    OR target_table.relname IN ('usuarios', 'vendas', 'pessoas', 'pagamentos', 'produtos', 'itens_venda', 'equipes', 'circulos')
  )
ORDER BY source_table.relname, constraint_row.conname, source_key.ord;

-- 10. Indices publicos: ajuda a verificar unicidade e indices de FKs/consultas.
SELECT
  schemaname AS table_schema,
  tablename AS table_name,
  indexname AS index_name,
  indexdef AS index_definition
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
