-- RASCUNHO PARA REVISAO. NAO EXECUTAR SEM BACKUP E APROVACAO.
-- Nao altera custos historicos: preco_custo e custo_unitario permanecem NULL
-- para dados antigos ate que haja uma origem confiavel para preenchimento.
-- preco continua sendo o preco de venda usado pelo sistema atual.

BEGIN;

ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS preco_custo numeric(12,2);

ALTER TABLE public.itens_venda
  ADD COLUMN IF NOT EXISTS custo_unitario numeric(12,2);

-- Remove SELECT de tabela para que a nova coluna nao fique exposta pela API.
-- Os campos operacionais consumidos pelo frontend permanecem disponiveis.
REVOKE SELECT ON TABLE public.produtos FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, codigo, nome, categoria, preco, estoque, ativo)
  ON TABLE public.produtos TO authenticated;

-- custo_unitario tambem fica fora das leituras operacionais de itens.
REVOKE SELECT ON TABLE public.itens_venda FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, venda_id, produto_id, quantidade, preco_unitario, subtotal)
  ON TABLE public.itens_venda TO authenticated;

-- Os custos nao sao lidos pela consulta comum de produtos. A funcao retorna
-- custos apenas para perfis ADMIN; a verificacao ocorre no banco.
CREATE OR REPLACE FUNCTION public.listar_custos_produtos()
RETURNS TABLE (produto_id uuid, preco_custo numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
  SELECT p.id, p.preco_custo
  FROM public.produtos p
  WHERE EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.perfil = 'ADMIN' AND COALESCE(u.ativo, true)
  )
$function$;

CREATE OR REPLACE FUNCTION public.definir_custo_produto(
  p_produto_id uuid,
  p_preco_custo numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.perfil = 'ADMIN' AND COALESCE(u.ativo, true)
  ) THEN
    RAISE EXCEPTION 'Somente administradores podem alterar custos';
  END IF;

  IF p_preco_custo IS NOT NULL AND p_preco_custo < 0 THEN
    RAISE EXCEPTION 'O custo nao pode ser negativo';
  END IF;

  UPDATE public.produtos
  SET preco_custo = p_preco_custo
  WHERE id = p_produto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Produto nao encontrado';
  END IF;
END;
$function$;

-- Grava no item o custo cadastrado no instante da venda. Nao estima custos
-- ausentes: itens anteriores e produtos sem custo definido ficam NULL.
CREATE OR REPLACE FUNCTION public.registrar_custo_item_venda()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT p.preco_custo
    INTO NEW.custo_unitario
    FROM public.produtos p
    WHERE p.id = NEW.produto_id;
  ELSIF NEW.produto_id IS DISTINCT FROM OLD.produto_id THEN
    SELECT p.preco_custo
    INTO NEW.custo_unitario
    FROM public.produtos p
    WHERE p.id = NEW.produto_id;
  END IF;

  RETURN NEW;
END;
$function$;

DO $trigger_setup$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'itens_venda'
      AND t.tgname = 'itens_venda_registrar_custo'
      AND NOT t.tgisinternal
      AND pg_get_triggerdef(t.oid) NOT LIKE '%UPDATE%'
  ) THEN
    EXECUTE 'DROP TRIGGER itens_venda_registrar_custo ON public.itens_venda';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'itens_venda'
      AND t.tgname = 'itens_venda_registrar_custo'
      AND NOT t.tgisinternal
  ) THEN
    EXECUTE 'CREATE TRIGGER itens_venda_registrar_custo
      BEFORE INSERT OR UPDATE ON public.itens_venda
      FOR EACH ROW EXECUTE FUNCTION public.registrar_custo_item_venda()';
  END IF;
END;
$trigger_setup$;

-- Indicadores financeiros internos. Itens sem custo ficam fora do lucro
-- calculado e são apresentados separadamente para deixar explícita a lacuna.
CREATE OR REPLACE FUNCTION public.resumo_financeiro_produtos()
RETURNS TABLE (
  total_investido numeric,
  receita_vendas numeric,
  lucro_bruto numeric,
  itens_sem_custo bigint,
  produtos_sem_custo bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.perfil = 'ADMIN' AND COALESCE(u.ativo, true)
  ) THEN
    RAISE EXCEPTION 'Somente administradores podem consultar indicadores de custo';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE((SELECT SUM(p.estoque * p.preco_custo) FROM public.produtos p WHERE p.preco_custo IS NOT NULL), 0)::numeric,
    COALESCE((SELECT SUM(i.subtotal)
      FROM public.itens_venda i
      JOIN public.vendas v ON v.id = i.venda_id
      WHERE COALESCE(v.ativo, true)), 0)::numeric,
    COALESCE((SELECT SUM(i.subtotal - (i.quantidade * i.custo_unitario))
      FROM public.itens_venda i
      JOIN public.vendas v ON v.id = i.venda_id
      WHERE COALESCE(v.ativo, true) AND i.custo_unitario IS NOT NULL), 0)::numeric,
    (SELECT COUNT(*)
      FROM public.itens_venda i
      JOIN public.vendas v ON v.id = i.venda_id
      WHERE COALESCE(v.ativo, true) AND i.custo_unitario IS NULL)::bigint,
    (SELECT COUNT(*) FROM public.produtos p WHERE p.estoque > 0 AND p.preco_custo IS NULL)::bigint;
END;
$function$;

CREATE OR REPLACE FUNCTION public.lucro_por_produto()
RETURNS TABLE (
  produto_id uuid,
  produto_nome text,
  quantidade_vendida numeric,
  receita numeric,
  custo_conhecido numeric,
  lucro_bruto numeric,
  itens_sem_custo bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.perfil = 'ADMIN' AND COALESCE(u.ativo, true)
  ) THEN
    RAISE EXCEPTION 'Somente administradores podem consultar lucro por produto';
  END IF;

  RETURN QUERY
  SELECT p.id, p.nome,
    COALESCE(SUM(i.quantidade), 0)::numeric,
    COALESCE(SUM(i.subtotal), 0)::numeric,
    COALESCE(SUM(i.quantidade * i.custo_unitario), 0)::numeric,
    COALESCE(SUM(i.subtotal - (i.quantidade * i.custo_unitario))
      FILTER (WHERE i.custo_unitario IS NOT NULL), 0)::numeric,
    COUNT(*) FILTER (WHERE i.id IS NOT NULL AND i.custo_unitario IS NULL)::bigint
  FROM public.produtos p
  LEFT JOIN public.itens_venda i ON i.produto_id = p.id
  LEFT JOIN public.vendas v ON v.id = i.venda_id AND COALESCE(v.ativo, true)
  WHERE i.id IS NULL OR v.id IS NOT NULL
  GROUP BY p.id, p.nome
  ORDER BY p.nome;
END;
$function$;

REVOKE ALL ON FUNCTION public.listar_custos_produtos() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.definir_custo_produto(uuid, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_custo_item_venda() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resumo_financeiro_produtos() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lucro_por_produto() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_custos_produtos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.definir_custo_produto(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resumo_financeiro_produtos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lucro_por_produto() TO authenticated;

COMMIT;
