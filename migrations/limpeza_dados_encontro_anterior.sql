-- RASCUNHO PARA REVISAO. NAO EXECUTAR SEM BACKUP E CONFERENCIA DO SCHEMA.
-- Limpa dados operacionais do encontro encerrado.
-- Preserva usuarios, equipes, circulos, Auth, IDs das estruturas e sequences.
-- A transacao aborta se houver FK de outra tabela apontando para uma tabela
-- operacional que nao esteja nesta lista, evitando apagar/alterar dependencias
-- nao previstas por cascata.

BEGIN;

-- Inventario das FKs que chegam às tabelas previstas para limpeza.
-- Este SELECT e informativo; executar o arquivo inteiro nao pausa aqui.
SELECT
  source_ns.nspname AS schema_origem,
  source_table.relname AS tabela_origem,
  constraint_row.conname AS chave_estrangeira,
  target_table.relname AS tabela_destino,
  pg_get_constraintdef(constraint_row.oid, true) AS definicao
FROM pg_constraint AS constraint_row
JOIN pg_class AS source_table ON source_table.oid = constraint_row.conrelid
JOIN pg_namespace AS source_ns ON source_ns.oid = source_table.relnamespace
JOIN pg_class AS target_table ON target_table.oid = constraint_row.confrelid
WHERE constraint_row.contype = 'f'
  AND target_table.oid IN (
    'public.itens_venda'::regclass,
    'public.pagamentos'::regclass,
    'public.vendas'::regclass,
    'public.pessoas'::regclass,
    'public.produtos'::regclass
  )
ORDER BY target_table.relname, source_ns.nspname, source_table.relname;

DO $limpeza$
DECLARE
  vendas_antes bigint;
  itens_antes bigint;
  pagamentos_antes bigint;
  pessoas_antes bigint;
  produtos_antes bigint;
  usuarios_antes bigint;
  equipes_antes bigint;
  circulos_antes bigint;
  fk_inesperada record;
  vendas_depois bigint;
  itens_depois bigint;
  pagamentos_depois bigint;
  pessoas_depois bigint;
  produtos_depois bigint;
  usuarios_depois bigint;
  equipes_depois bigint;
  circulos_depois bigint;
BEGIN
  IF to_regclass('public.vendas') IS NULL
     OR to_regclass('public.itens_venda') IS NULL
     OR to_regclass('public.pagamentos') IS NULL
     OR to_regclass('public.pessoas') IS NULL
     OR to_regclass('public.produtos') IS NULL
     OR to_regclass('public.usuarios') IS NULL
     OR to_regclass('public.equipes') IS NULL
     OR to_regclass('public.circulos') IS NULL THEN
    RAISE EXCEPTION 'Limpeza cancelada: falta uma ou mais tabelas esperadas no schema public';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('itens_venda','pagamentos','vendas','pessoas','produtos')
      AND column_name = 'evento_id'
  ) THEN
    RAISE EXCEPTION 'Limpeza cancelada: tabelas ja possuem evento_id; limite a limpeza a um evento especifico antes de continuar';
  END IF;

  -- Uma tabela não listada pode ter referências que impeçam a limpeza ou
  -- ativem cascatas. Nesse caso, aborta para revisão manual das dependências.
  SELECT source_ns.nspname AS source_schema,
         source_table.relname AS source_table,
         constraint_row.conname AS constraint_name,
         target_table.relname AS target_table
    INTO fk_inesperada
  FROM pg_constraint AS constraint_row
  JOIN pg_class AS source_table ON source_table.oid = constraint_row.conrelid
  JOIN pg_namespace AS source_ns ON source_ns.oid = source_table.relnamespace
  JOIN pg_class AS target_table ON target_table.oid = constraint_row.confrelid
  JOIN pg_namespace AS target_ns ON target_ns.oid = target_table.relnamespace
  WHERE constraint_row.contype = 'f'
    AND target_ns.nspname = 'public'
    AND target_table.relname IN ('itens_venda','pagamentos','vendas','pessoas','produtos')
    AND NOT (
      source_ns.nspname = 'public'
      AND source_table.relname IN ('itens_venda','pagamentos','vendas','pessoas','produtos')
    )
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'Limpeza cancelada: FK inesperada %.% (% ) referencia public.%; revisar dependencias',
      fk_inesperada.source_schema, fk_inesperada.source_table,
      fk_inesperada.constraint_name, fk_inesperada.target_table;
  END IF;

  -- Impede novas gravacoes durante a captura das contagens e a limpeza.
  -- As leituras continuam permitidas; os locks sao liberados no COMMIT.
  LOCK TABLE public.circulos, public.equipes, public.usuarios,
    public.produtos, public.pessoas, public.vendas,
    public.pagamentos, public.itens_venda
    IN SHARE ROW EXCLUSIVE MODE;

  SELECT count(*) INTO vendas_antes FROM public.vendas;
  SELECT count(*) INTO itens_antes FROM public.itens_venda;
  SELECT count(*) INTO pagamentos_antes FROM public.pagamentos;
  SELECT count(*) INTO pessoas_antes FROM public.pessoas;
  SELECT count(*) INTO produtos_antes FROM public.produtos;
  SELECT count(*) INTO usuarios_antes FROM public.usuarios;
  SELECT count(*) INTO equipes_antes FROM public.equipes;
  SELECT count(*) INTO circulos_antes FROM public.circulos;

  RAISE NOTICE 'ANTES: vendas %, itens_venda %, pagamentos %, pessoas %, produtos %, usuarios %, equipes %, circulos %',
    vendas_antes, itens_antes, pagamentos_antes, pessoas_antes,
    produtos_antes, usuarios_antes, equipes_antes, circulos_antes;

  -- Ordem de dependência: itens e pagamentos antes dos registros-pai.
  DELETE FROM public.itens_venda;
  DELETE FROM public.pagamentos;
  DELETE FROM public.vendas;
  DELETE FROM public.pessoas;
  DELETE FROM public.produtos;

  SELECT count(*) INTO vendas_depois FROM public.vendas;
  SELECT count(*) INTO itens_depois FROM public.itens_venda;
  SELECT count(*) INTO pagamentos_depois FROM public.pagamentos;
  SELECT count(*) INTO pessoas_depois FROM public.pessoas;
  SELECT count(*) INTO produtos_depois FROM public.produtos;
  SELECT count(*) INTO usuarios_depois FROM public.usuarios;
  SELECT count(*) INTO equipes_depois FROM public.equipes;
  SELECT count(*) INTO circulos_depois FROM public.circulos;

  RAISE NOTICE 'DEPOIS: vendas %, itens_venda %, pagamentos %, pessoas %, produtos %, usuarios %, equipes %, circulos %',
    vendas_depois, itens_depois, pagamentos_depois, pessoas_depois,
    produtos_depois, usuarios_depois, equipes_depois, circulos_depois;

  IF vendas_depois <> 0 OR itens_depois <> 0 OR pagamentos_depois <> 0
     OR pessoas_depois <> 0 OR produtos_depois <> 0 THEN
    RAISE EXCEPTION 'Limpeza cancelada: ainda ha registros em tabelas operacionais';
  END IF;

  IF usuarios_depois <> usuarios_antes
     OR equipes_depois <> equipes_antes
     OR circulos_depois <> circulos_antes THEN
    RAISE EXCEPTION 'Limpeza cancelada: a contagem de usuarios, equipes ou circulos foi alterada';
  END IF;
END;
$limpeza$;

COMMIT;
