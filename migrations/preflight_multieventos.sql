-- Consultas exclusivamente de leitura para validar o baseline antes da migracao.
-- Execute no SQL Editor do Supabase e confira os resultados antes de revisar/aplicar DDL.

-- 1. Contagens atuais versus inventario fornecido.
SELECT 'circulos' AS tabela, 6 AS esperado, count(*) AS atual FROM public.circulos
UNION ALL SELECT 'equipes', 13, count(*) FROM public.equipes
UNION ALL SELECT 'itens_venda', 1219, count(*) FROM public.itens_venda
UNION ALL SELECT 'pagamentos', 230, count(*) FROM public.pagamentos
UNION ALL SELECT 'pessoas', 304, count(*) FROM public.pessoas
UNION ALL SELECT 'produtos', 142, count(*) FROM public.produtos
UNION ALL SELECT 'usuarios', 22, count(*) FROM public.usuarios
UNION ALL SELECT 'vendas', 1082, count(*) FROM public.vendas
ORDER BY tabela;

-- 2. Referencias potencialmente orfas. Todos os valores devem retornar zero.
SELECT 'pessoas.circulo_id sem circulo' AS verificacao, count(*) AS registros
FROM public.pessoas p LEFT JOIN public.circulos c ON c.id = p.circulo_id
WHERE p.circulo_id IS NOT NULL AND c.id IS NULL
UNION ALL
SELECT 'pessoas.equipe_id sem equipe', count(*)
FROM public.pessoas p LEFT JOIN public.equipes e ON e.id = p.equipe_id
WHERE p.equipe_id IS NOT NULL AND e.id IS NULL
UNION ALL
SELECT 'vendas.pessoa_id sem pessoa', count(*)
FROM public.vendas v LEFT JOIN public.pessoas p ON p.id = v.pessoa_id
WHERE v.pessoa_id IS NOT NULL AND p.id IS NULL
UNION ALL
SELECT 'vendas.usuario_id sem usuario', count(*)
FROM public.vendas v LEFT JOIN public.usuarios u ON u.id = v.usuario_id
WHERE v.usuario_id IS NOT NULL AND u.id IS NULL
UNION ALL
SELECT 'vendas.excluida_por sem usuario', count(*)
FROM public.vendas v LEFT JOIN public.usuarios u ON u.id = v.excluida_por
WHERE v.excluida_por IS NOT NULL AND u.id IS NULL
UNION ALL
SELECT 'itens_venda.venda_id sem venda', count(*)
FROM public.itens_venda i LEFT JOIN public.vendas v ON v.id = i.venda_id
WHERE i.venda_id IS NOT NULL AND v.id IS NULL
UNION ALL
SELECT 'itens_venda.produto_id sem produto', count(*)
FROM public.itens_venda i LEFT JOIN public.produtos p ON p.id = i.produto_id
WHERE i.produto_id IS NOT NULL AND p.id IS NULL
UNION ALL
SELECT 'pagamentos.pessoa_id sem pessoa', count(*)
FROM public.pagamentos pg LEFT JOIN public.pessoas p ON p.id = pg.pessoa_id
WHERE pg.pessoa_id IS NOT NULL AND p.id IS NULL
ORDER BY verificacao;

-- 3. Itens de venda sem venda associada. Nao atribuir venda_id por inferencia.
SELECT id, venda_id, produto_id, quantidade, preco_unitario, subtotal
FROM public.itens_venda
WHERE venda_id IS NULL
ORDER BY id;

-- 4. Sinais que devem ser revisados antes do backfill. NULL de usuario_id em venda
-- e permitido e deve permanecer NULL; demais contagens sao apenas informativas.
SELECT
  count(*) FILTER (WHERE usuario_id IS NULL) AS vendas_sem_usuario,
  count(*) FILTER (WHERE ativo = false) AS vendas_com_exclusao_logica,
  count(*) FILTER (WHERE ativo = false AND excluida_em IS NULL) AS vendas_inativas_sem_data,
  count(*) FILTER (WHERE ativo = false AND excluida_por IS NULL) AS vendas_inativas_sem_autor
FROM public.vendas;

-- 5. Verificar valores de perfil e estado dos usuarios que serao associados.
SELECT perfil, ativo, count(*) AS quantidade
FROM public.usuarios
GROUP BY perfil, ativo
ORDER BY perfil, ativo;

-- 6. Politicas ativas nas tabelas que a migracao substituira; compare com
-- o inventario documentado e confira se nenhuma politica nova surgiu desde entao.
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('circulos','equipes','itens_venda','pessoas','produtos','usuarios','vendas','pagamentos')
ORDER BY tablename, policyname;
