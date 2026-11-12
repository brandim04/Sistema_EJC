-- RASCUNHO PARA REVISAO. NAO EXECUTAR EM PRODUCAO SEM BACKUP E APROVACAO.
-- Escopo: isolar dados por evento; manter equipes/circulos compartilhados.
-- Nao apaga linhas de negocio nem altera IDs existentes.
-- A identidade da administradora da plataforma deve ser marcada, fora deste SQL,
-- em Supabase Auth app_metadata: { "platform_admin": true }.

BEGIN;

-- 0. Falha antes de qualquer backfill se houver referencia orfa nos dados atuais.
DO $preflight$
BEGIN
  -- Baseline from the supplied exact COUNT(*) results. Any drift aborts safely
  -- so the data can be re-inspected before continuing.
  IF (SELECT count(*) FROM public.circulos) <> 6 THEN RAISE EXCEPTION 'Preflight: circulos nao corresponde ao baseline de 6'; END IF;
  IF (SELECT count(*) FROM public.equipes) <> 13 THEN RAISE EXCEPTION 'Preflight: equipes nao corresponde ao baseline de 13'; END IF;
  IF (SELECT count(*) FROM public.itens_venda) <> 1219 THEN RAISE EXCEPTION 'Preflight: itens_venda nao corresponde ao baseline de 1219'; END IF;
  IF (SELECT count(*) FROM public.pagamentos) <> 230 THEN RAISE EXCEPTION 'Preflight: pagamentos nao corresponde ao baseline de 230'; END IF;
  IF (SELECT count(*) FROM public.pessoas) <> 304 THEN RAISE EXCEPTION 'Preflight: pessoas nao corresponde ao baseline de 304'; END IF;
  IF (SELECT count(*) FROM public.produtos) <> 142 THEN RAISE EXCEPTION 'Preflight: produtos nao corresponde ao baseline de 142'; END IF;
  IF (SELECT count(*) FROM public.usuarios) <> 22 THEN RAISE EXCEPTION 'Preflight: usuarios nao corresponde ao baseline de 22'; END IF;
  IF (SELECT count(*) FROM public.vendas) <> 1082 THEN RAISE EXCEPTION 'Preflight: vendas nao corresponde ao baseline de 1082'; END IF;
  IF (SELECT count(*) FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename IN ('circulos','equipes','itens_venda','pessoas','produtos','usuarios','vendas','pagamentos')) <> 8 THEN
    RAISE EXCEPTION 'Preflight: esperadas 8 politicas atuais; revisar inventario antes da migracao';
  END IF;
  -- Oito assinaturas permissivas conhecidas. Os nomes das politicas nao
  -- constam no inventario textual recebido; por isso a validacao compara
  -- tabela, comando, papeis e expressoes sem inventar policyname.
  IF (SELECT count(*) FROM pg_policies p
      WHERE p.schemaname = 'public'
        AND (
          (p.tablename = 'circulos' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
           AND p.roles = ARRAY['anon']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
          OR (p.tablename = 'circulos' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
           AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
          OR (p.tablename = 'equipes' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
           AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
          OR (p.tablename IN ('itens_venda','pessoas','produtos','vendas') AND p.cmd = 'ALL'
           AND p.permissive = 'PERMISSIVE' AND p.roles = ARRAY['public']::name[]
           AND p.qual = 'true' AND p.with_check = 'true')
          OR (p.tablename = 'usuarios' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
           AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
        )) <> 8 THEN
    RAISE EXCEPTION 'Preflight: politicas conhecidas nao correspondem as definicoes documentadas';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename IN ('circulos','equipes','itens_venda','pessoas','produtos','usuarios','vendas','pagamentos')
      AND COALESCE(NOT (
        (p.tablename = 'circulos' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
         AND p.roles = ARRAY['anon']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
        OR (p.tablename = 'circulos' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
         AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
        OR (p.tablename = 'equipes' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
         AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
        OR (p.tablename IN ('itens_venda','pessoas','produtos','vendas') AND p.cmd = 'ALL'
         AND p.permissive = 'PERMISSIVE' AND p.roles = ARRAY['public']::name[]
         AND p.qual = 'true' AND p.with_check = 'true')
        OR (p.tablename = 'usuarios' AND p.cmd = 'SELECT' AND p.permissive = 'PERMISSIVE'
         AND p.roles = ARRAY['authenticated']::name[] AND p.qual = 'true' AND p.with_check IS NULL)
      ), true)
  ) THEN
    RAISE EXCEPTION 'Preflight: existe politica adicional nao documentada; nao sera removida sem revisao';
  END IF;

  IF EXISTS (SELECT 1 FROM public.pessoas p LEFT JOIN public.circulos c ON c.id = p.circulo_id WHERE p.circulo_id IS NOT NULL AND c.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: pessoas contem circulo_id sem circulo correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pessoas p LEFT JOIN public.equipes e ON e.id = p.equipe_id WHERE p.equipe_id IS NOT NULL AND e.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: pessoas contem equipe_id sem equipe correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.vendas v LEFT JOIN public.pessoas p ON p.id = v.pessoa_id WHERE v.pessoa_id IS NOT NULL AND p.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: vendas contem pessoa_id sem pessoa correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.vendas v LEFT JOIN public.usuarios u ON u.id = v.usuario_id WHERE v.usuario_id IS NOT NULL AND u.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: vendas contem usuario_id sem usuario correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.vendas v LEFT JOIN public.usuarios u ON u.id = v.excluida_por WHERE v.excluida_por IS NOT NULL AND u.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: vendas contem excluida_por sem usuario correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.itens_venda i LEFT JOIN public.vendas v ON v.id = i.venda_id WHERE i.venda_id IS NOT NULL AND v.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: itens_venda contem venda_id sem venda correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.itens_venda WHERE venda_id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: itens_venda tem venda_id NULL; preservar os itens e revisar origem antes de atribuir evento';
  END IF;
  IF EXISTS (SELECT 1 FROM public.itens_venda i LEFT JOIN public.produtos p ON p.id = i.produto_id WHERE i.produto_id IS NOT NULL AND p.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: itens_venda contem produto_id sem produto correspondente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pagamentos pg LEFT JOIN public.pessoas p ON p.id = pg.pessoa_id WHERE pg.pessoa_id IS NOT NULL AND p.id IS NULL) THEN
    RAISE EXCEPTION 'Preflight: pagamentos contem pessoa_id sem pessoa correspondente';
  END IF;
END;
$preflight$;

-- 1. Entidades de paróquia, evento e vínculo/permissões por usuário.
CREATE TABLE IF NOT EXISTS public.paroquias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  slug text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eventos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paroquia_id uuid NOT NULL REFERENCES public.paroquias(id),
  nome text NOT NULL,
  ano integer NOT NULL CHECK (ano BETWEEN 2000 AND 2200),
  slug text NOT NULL UNIQUE,
  configuracoes jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT eventos_paroquia_ano_key UNIQUE (paroquia_id, ano)
);

CREATE TABLE IF NOT EXISTS public.evento_usuarios (
  evento_id uuid NOT NULL REFERENCES public.eventos(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  perfil text NOT NULL CHECK (perfil IN ('ADMIN', 'VENDEDOR')),
  permissoes jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (evento_id, usuario_id)
);

-- 2. Criar/obter a edição inicial. ON CONFLICT nao sobrescreve configuracoes existentes.
INSERT INTO public.paroquias (nome, slug)
VALUES ('Paróquia Nossa Senhora de Guadalupe', 'nossa-senhora-de-guadalupe')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.eventos (paroquia_id, nome, ano, slug, configuracoes)
SELECT p.id,
       'VIII Encontro do EJC',
       2026,
       'ejc-guadalupe-2026',
       '{"nome_encontro":"VIII Encontro do EJC","nome_paroquia":"Paróquia Nossa Senhora de Guadalupe","ano":2026,"texto_lateral":"VIII ENCONTRO","lema":"TUA VONTADE É O MEU CÉU","identidade":"/img/logo-ejc.png"}'::jsonb
FROM public.paroquias p
WHERE p.slug = 'nossa-senhora-de-guadalupe'
ON CONFLICT (slug) DO NOTHING;

DO $event_identity_check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.paroquias p
    WHERE p.slug = 'nossa-senhora-de-guadalupe'
      AND p.nome = 'Paróquia Nossa Senhora de Guadalupe'
  ) THEN
    RAISE EXCEPTION 'Configuracao conflitante para a paroquia Guadalupe; revisar antes de migrar';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.eventos e
    JOIN public.paroquias p ON p.id = e.paroquia_id
    WHERE e.slug = 'ejc-guadalupe-2026'
      AND e.nome = 'VIII Encontro do EJC'
      AND e.ano = 2026
      AND p.slug = 'nossa-senhora-de-guadalupe'
  ) THEN
    RAISE EXCEPTION 'Configuracao conflitante para EJC Guadalupe 2026; revisar antes de migrar';
  END IF;
END;
$event_identity_check$;

-- 3. Adicionar escopo aos dados de negócio. Equipes e círculos permanecem globais.
ALTER TABLE public.pessoas ADD COLUMN IF NOT EXISTS evento_id uuid;
ALTER TABLE public.pessoas ADD COLUMN IF NOT EXISTS ativo boolean NOT NULL DEFAULT true;
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS evento_id uuid;
ALTER TABLE public.vendas ADD COLUMN IF NOT EXISTS evento_id uuid;
ALTER TABLE public.itens_venda ADD COLUMN IF NOT EXISTS evento_id uuid;
ALTER TABLE public.pagamentos ADD COLUMN IF NOT EXISTS evento_id uuid;

-- O preflight acima confirma que nao ha itens sem venda associada.
ALTER TABLE public.itens_venda ALTER COLUMN venda_id SET NOT NULL;

UPDATE public.pessoas SET evento_id = e.id
FROM public.eventos e WHERE e.slug = 'ejc-guadalupe-2026' AND pessoas.evento_id IS NULL;
UPDATE public.produtos SET evento_id = e.id
FROM public.eventos e WHERE e.slug = 'ejc-guadalupe-2026' AND produtos.evento_id IS NULL;
UPDATE public.vendas SET evento_id = e.id
FROM public.eventos e WHERE e.slug = 'ejc-guadalupe-2026' AND vendas.evento_id IS NULL;
UPDATE public.pagamentos SET evento_id = e.id
FROM public.eventos e WHERE e.slug = 'ejc-guadalupe-2026' AND pagamentos.evento_id IS NULL;
UPDATE public.itens_venda i SET evento_id = v.evento_id
FROM public.vendas v WHERE i.venda_id = v.id AND i.evento_id IS NULL;

DO $backfill_check$
BEGIN
  IF EXISTS (SELECT 1 FROM public.pessoas WHERE evento_id IS NULL)
     OR EXISTS (SELECT 1 FROM public.produtos WHERE evento_id IS NULL)
     OR EXISTS (SELECT 1 FROM public.vendas WHERE evento_id IS NULL)
     OR EXISTS (SELECT 1 FROM public.itens_venda WHERE evento_id IS NULL)
     OR EXISTS (SELECT 1 FROM public.pagamentos WHERE evento_id IS NULL) THEN
    RAISE EXCEPTION 'Backfill incompleto: existe registro sem evento_id; transacao cancelada';
  END IF;
END;
$backfill_check$;

-- Vincula os 22 perfis existentes ao evento atual, preservando ADMIN/VENDEDOR.
-- As permissoes iniciais mantem o acesso operacional atual dos vendedores;
-- administradores locais recebem todas as areas pela funcao has_event_permission.
INSERT INTO public.evento_usuarios (evento_id, usuario_id, perfil, permissoes, ativo)
SELECT e.id,
       u.id,
       u.perfil,
       CASE WHEN u.perfil = 'ADMIN' THEN '{}'::jsonb
       ELSE '{"people":{"read":true,"write":true},"products":{"read":true,"write":true,"inventory_write":true},"sales":{"read":true,"write":true},"payments":{"read":true,"write":true},"reports":{"read":false,"write":false},"users":{"read":false,"write":false}}'::jsonb
       END,
       COALESCE(u.ativo, false)
FROM public.usuarios u
CROSS JOIN public.eventos e
WHERE e.slug = 'ejc-guadalupe-2026'
ON CONFLICT (evento_id, usuario_id) DO NOTHING;

-- 4. Indices e garantias de integridade entre linhas do mesmo evento.
CREATE INDEX IF NOT EXISTS idx_pessoas_evento_nome ON public.pessoas (evento_id, nome);
CREATE INDEX IF NOT EXISTS idx_produtos_evento_codigo ON public.produtos (evento_id, codigo);
CREATE INDEX IF NOT EXISTS idx_vendas_evento_created ON public.vendas (evento_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vendas_evento_pessoa ON public.vendas (evento_id, pessoa_id);
CREATE INDEX IF NOT EXISTS idx_itens_venda_evento_venda ON public.itens_venda (evento_id, venda_id);
CREATE INDEX IF NOT EXISTS idx_pagamentos_evento_pessoa ON public.pagamentos (evento_id, pessoa_id);
CREATE INDEX IF NOT EXISTS idx_evento_usuarios_usuario ON public.evento_usuarios (usuario_id, ativo);

CREATE UNIQUE INDEX IF NOT EXISTS pessoas_id_evento_uidx ON public.pessoas (id, evento_id);
CREATE UNIQUE INDEX IF NOT EXISTS produtos_id_evento_uidx ON public.produtos (id, evento_id);
CREATE UNIQUE INDEX IF NOT EXISTS vendas_id_evento_uidx ON public.vendas (id, evento_id);

-- Unicidade do codigo passa a ser por evento. Mantem os valores atuais intactos.
ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_codigo_unique;
CREATE UNIQUE INDEX IF NOT EXISTS produtos_evento_codigo_key ON public.produtos (evento_id, codigo);

ALTER TABLE public.pessoas ALTER COLUMN evento_id SET NOT NULL;
ALTER TABLE public.produtos ALTER COLUMN evento_id SET NOT NULL;
ALTER TABLE public.vendas ALTER COLUMN evento_id SET NOT NULL;
ALTER TABLE public.itens_venda ALTER COLUMN evento_id SET NOT NULL;
ALTER TABLE public.pagamentos ALTER COLUMN evento_id SET NOT NULL;

ALTER TABLE public.pessoas ADD CONSTRAINT pessoas_evento_fk
  FOREIGN KEY (evento_id) REFERENCES public.eventos(id) NOT VALID;
ALTER TABLE public.produtos ADD CONSTRAINT produtos_evento_fk
  FOREIGN KEY (evento_id) REFERENCES public.eventos(id) NOT VALID;
ALTER TABLE public.vendas ADD CONSTRAINT vendas_evento_fk
  FOREIGN KEY (evento_id) REFERENCES public.eventos(id) NOT VALID;
ALTER TABLE public.itens_venda ADD CONSTRAINT itens_venda_evento_fk
  FOREIGN KEY (evento_id) REFERENCES public.eventos(id) NOT VALID;
ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_evento_fk
  FOREIGN KEY (evento_id) REFERENCES public.eventos(id) NOT VALID;

ALTER TABLE public.vendas ADD CONSTRAINT vendas_pessoa_mesmo_evento_fk
  FOREIGN KEY (pessoa_id, evento_id) REFERENCES public.pessoas(id, evento_id) ON DELETE CASCADE NOT VALID;
ALTER TABLE public.itens_venda ADD CONSTRAINT itens_venda_venda_mesmo_evento_fk
  FOREIGN KEY (venda_id, evento_id) REFERENCES public.vendas(id, evento_id) ON DELETE CASCADE NOT VALID;
ALTER TABLE public.itens_venda ADD CONSTRAINT itens_venda_produto_mesmo_evento_fk
  FOREIGN KEY (produto_id, evento_id) REFERENCES public.produtos(id, evento_id) NOT VALID;
ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_pessoa_mesmo_evento_fk
  FOREIGN KEY (pessoa_id, evento_id) REFERENCES public.pessoas(id, evento_id) NOT VALID;

ALTER TABLE public.pessoas VALIDATE CONSTRAINT pessoas_evento_fk;
ALTER TABLE public.produtos VALIDATE CONSTRAINT produtos_evento_fk;
ALTER TABLE public.vendas VALIDATE CONSTRAINT vendas_evento_fk;
ALTER TABLE public.itens_venda VALIDATE CONSTRAINT itens_venda_evento_fk;
ALTER TABLE public.pagamentos VALIDATE CONSTRAINT pagamentos_evento_fk;
ALTER TABLE public.vendas VALIDATE CONSTRAINT vendas_pessoa_mesmo_evento_fk;
ALTER TABLE public.itens_venda VALIDATE CONSTRAINT itens_venda_venda_mesmo_evento_fk;
ALTER TABLE public.itens_venda VALIDATE CONSTRAINT itens_venda_produto_mesmo_evento_fk;
ALTER TABLE public.pagamentos VALIDATE CONSTRAINT pagamentos_pessoa_mesmo_evento_fk;

-- 5. Funcoes auxiliares para politicas RLS. SECURITY DEFINER evita recursao
-- ao consultar evento_usuarios; search_path fixo e nomes qualificados.
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT COALESCE((auth.jwt() -> 'app_metadata' ->> 'platform_admin') = 'true', false)
$$;

CREATE OR REPLACE FUNCTION public.has_any_event_membership()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.evento_usuarios eu
    WHERE eu.usuario_id = auth.uid() AND eu.ativo
  )
$$;

CREATE OR REPLACE FUNCTION public.has_event_permission(p_evento_id uuid, p_area text, p_action text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
    SELECT 1 FROM public.evento_usuarios eu
    WHERE eu.evento_id = p_evento_id
      AND eu.usuario_id = auth.uid()
      AND eu.ativo
      AND (eu.perfil = 'ADMIN' OR COALESCE(eu.permissoes -> p_area ->> p_action, 'false') = 'true')
  )
$$;

CREATE OR REPLACE FUNCTION public.can_manage_event(p_evento_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
    SELECT 1 FROM public.evento_usuarios eu
    WHERE eu.evento_id = p_evento_id
      AND eu.usuario_id = auth.uid()
      AND eu.ativo AND eu.perfil = 'ADMIN'
  )
$$;

CREATE OR REPLACE FUNCTION public.can_read_parish(p_paroquia_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
    SELECT 1
    FROM public.eventos e
    JOIN public.evento_usuarios eu ON eu.evento_id = e.id
    WHERE e.paroquia_id = p_paroquia_id
      AND eu.usuario_id = auth.uid() AND eu.ativo
  )
$$;

CREATE OR REPLACE FUNCTION public.can_view_user_profile(p_usuario_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT public.is_platform_admin()
    OR p_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.evento_usuarios current_eu
      JOIN public.evento_usuarios target_eu ON target_eu.evento_id = current_eu.evento_id
      WHERE current_eu.usuario_id = auth.uid()
        AND current_eu.ativo AND current_eu.perfil = 'ADMIN'
        AND target_eu.usuario_id = p_usuario_id AND target_eu.ativo
    )
$$;

-- quantidade positiva impede decrementos nulos/negativos. SECURITY DEFINER e
-- necessario para a movimentacao pontual de estoque sem conceder ao vendedor
-- permissao geral para editar produtos; o evento e a permissao sao verificados aqui.
CREATE OR REPLACE FUNCTION public.baixar_estoque(produto_id_param uuid, quantidade_param integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  evento_do_produto uuid;
BEGIN
  IF quantidade_param IS NULL OR quantidade_param <= 0 THEN
    RAISE EXCEPTION 'Quantidade deve ser maior que zero';
  END IF;

  SELECT p.evento_id INTO evento_do_produto
  FROM public.produtos p
  WHERE p.id = produto_id_param;

  IF evento_do_produto IS NULL THEN
    RAISE EXCEPTION 'Produto nao encontrado';
  END IF;

  IF NOT public.has_event_permission(evento_do_produto, 'sales', 'write') THEN
    RAISE EXCEPTION 'Sem permissao para movimentar estoque deste evento';
  END IF;

  UPDATE public.produtos p
  SET estoque = p.estoque - quantidade_param
  WHERE p.id = produto_id_param
    AND p.evento_id = evento_do_produto
    AND p.estoque >= quantidade_param;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estoque insuficiente para este produto';
  END IF;
END;
$function$;

-- Operacao atomica usada pela tela de edicao de produto. O vendedor pode editar
-- metadados conforme products.write; alterar estoque tambem exige inventory_write.
CREATE OR REPLACE FUNCTION public.editar_produto_com_estoque(
  produto_id_param uuid,
  nome_param text,
  categoria_param text,
  preco_param numeric,
  estoque_novo_param integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  evento_produto uuid;
  estoque_atual integer;
BEGIN
  SELECT p.evento_id, p.estoque INTO evento_produto, estoque_atual
  FROM public.produtos p
  WHERE p.id = produto_id_param
  FOR UPDATE;

  IF evento_produto IS NULL THEN
    RAISE EXCEPTION 'Produto nao encontrado';
  END IF;
  IF NOT public.has_event_permission(evento_produto, 'products', 'write') THEN
    RAISE EXCEPTION 'Sem permissao para editar produtos deste evento';
  END IF;
  IF estoque_novo_param IS NULL OR estoque_novo_param < 0 THEN
    RAISE EXCEPTION 'Estoque deve ser zero ou maior';
  END IF;
  IF estoque_novo_param IS DISTINCT FROM estoque_atual
     AND NOT public.has_event_permission(evento_produto, 'products', 'inventory_write') THEN
    RAISE EXCEPTION 'Sem permissao para alterar estoque deste evento';
  END IF;

  UPDATE public.produtos p
  SET nome = nome_param,
      categoria = categoria_param,
      preco = preco_param,
      estoque = estoque_novo_param
  WHERE p.id = produto_id_param AND p.evento_id = evento_produto;
END;
$function$;

REVOKE ALL ON FUNCTION public.is_platform_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_any_event_membership() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_event_permission(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_manage_event(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_parish(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_view_user_profile(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.baixar_estoque(uuid, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.editar_produto_com_estoque(uuid, text, text, numeric, integer) FROM PUBLIC, anon;

-- 6. Recriar politicas nas tabelas do escopo. A inspeção documentou as politicas
-- atuais como permissivas; este bloco remove politicas somente destas tabelas.
DO $drop_old_policies$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('circulos','equipes','itens_venda','pessoas','produtos','usuarios','vendas','pagamentos',
                        'paroquias','eventos','evento_usuarios')
  LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END;
$drop_old_policies$;

ALTER TABLE public.paroquias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pessoas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_venda ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagamentos ENABLE ROW LEVEL SECURITY;

-- Dados globais: leitura somente por autenticados vinculados a algum evento.
CREATE POLICY circulos_read_event_users ON public.circulos FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.has_any_event_membership());
CREATE POLICY equipes_read_event_users ON public.equipes FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.has_any_event_membership());

-- Paroquias e eventos: membro consulta apenas o proprio ambiente; plataforma administra.
CREATE POLICY paroquias_read_scoped ON public.paroquias FOR SELECT TO authenticated
  USING (public.can_read_parish(id));
CREATE POLICY paroquias_platform_insert ON public.paroquias FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY paroquias_platform_update ON public.paroquias FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY eventos_read_scoped ON public.eventos FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.has_event_permission(id, 'users', 'read') OR public.can_manage_event(id)
         OR EXISTS (SELECT 1 FROM public.evento_usuarios eu WHERE eu.evento_id = id AND eu.usuario_id = auth.uid() AND eu.ativo));
CREATE POLICY eventos_platform_insert ON public.eventos FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY eventos_platform_update ON public.eventos FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

-- Associacoes: usuario ve a propria; admin local ve usuarios do seu evento.
CREATE POLICY evento_usuarios_read_scoped ON public.evento_usuarios FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR usuario_id = auth.uid() OR public.can_manage_event(evento_id));
CREATE POLICY evento_usuarios_platform_insert ON public.evento_usuarios FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY evento_usuarios_admin_add_vendedor ON public.evento_usuarios FOR INSERT TO authenticated
  WITH CHECK (public.can_manage_event(evento_id) AND perfil = 'VENDEDOR');
CREATE POLICY evento_usuarios_admin_update_vendedor ON public.evento_usuarios FOR UPDATE TO authenticated
  USING (public.can_manage_event(evento_id) AND perfil = 'VENDEDOR')
  WITH CHECK (public.can_manage_event(evento_id) AND perfil = 'VENDEDOR');
CREATE POLICY evento_usuarios_admin_remove_vendedor ON public.evento_usuarios FOR DELETE TO authenticated
  USING (public.can_manage_event(evento_id) AND perfil = 'VENDEDOR');
CREATE POLICY evento_usuarios_platform_update ON public.evento_usuarios FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY evento_usuarios_platform_delete ON public.evento_usuarios FOR DELETE TO authenticated
  USING (public.is_platform_admin());

CREATE POLICY usuarios_read_scoped ON public.usuarios FOR SELECT TO authenticated
  USING (public.can_view_user_profile(id));
CREATE POLICY usuarios_platform_insert ON public.usuarios FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY usuarios_platform_update ON public.usuarios FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY pessoas_read_scoped ON public.pessoas FOR SELECT TO authenticated
  USING (public.has_event_permission(evento_id, 'people', 'read') OR public.has_event_permission(evento_id, 'sales', 'read'));
CREATE POLICY pessoas_insert_scoped ON public.pessoas FOR INSERT TO authenticated
  WITH CHECK (public.has_event_permission(evento_id, 'people', 'write'));
CREATE POLICY pessoas_update_scoped ON public.pessoas FOR UPDATE TO authenticated
  USING (public.has_event_permission(evento_id, 'people', 'write'))
  WITH CHECK (public.has_event_permission(evento_id, 'people', 'write'));

CREATE POLICY produtos_read_scoped ON public.produtos FOR SELECT TO authenticated
  USING (public.has_event_permission(evento_id, 'products', 'read') OR public.has_event_permission(evento_id, 'sales', 'read'));
CREATE POLICY produtos_insert_scoped ON public.produtos FOR INSERT TO authenticated
  WITH CHECK (public.has_event_permission(evento_id, 'products', 'write')
              AND (estoque = 0 OR public.has_event_permission(evento_id, 'products', 'inventory_write')));
CREATE POLICY produtos_update_scoped ON public.produtos FOR UPDATE TO authenticated
  USING (public.has_event_permission(evento_id, 'products', 'write'))
  WITH CHECK (public.has_event_permission(evento_id, 'products', 'write'));

CREATE POLICY vendas_read_scoped ON public.vendas FOR SELECT TO authenticated
  USING (public.has_event_permission(evento_id, 'sales', 'read'));
CREATE POLICY vendas_insert_scoped ON public.vendas FOR INSERT TO authenticated
  WITH CHECK (public.has_event_permission(evento_id, 'sales', 'write')
              AND (usuario_id IS NULL OR usuario_id = auth.uid())
              AND (excluida_por IS NULL OR excluida_por = auth.uid()));
CREATE POLICY vendas_update_scoped ON public.vendas FOR UPDATE TO authenticated
  USING (public.can_manage_event(evento_id))
  WITH CHECK (public.can_manage_event(evento_id)
              AND (excluida_por IS NULL OR excluida_por = auth.uid()));

CREATE POLICY itens_venda_read_scoped ON public.itens_venda FOR SELECT TO authenticated
  USING (public.has_event_permission(evento_id, 'sales', 'read'));
CREATE POLICY itens_venda_insert_scoped ON public.itens_venda FOR INSERT TO authenticated
  WITH CHECK (public.has_event_permission(evento_id, 'sales', 'write'));

CREATE POLICY pagamentos_read_scoped ON public.pagamentos FOR SELECT TO authenticated
  USING (public.has_event_permission(evento_id, 'payments', 'read') OR public.has_event_permission(evento_id, 'sales', 'read'));
CREATE POLICY pagamentos_insert_scoped ON public.pagamentos FOR INSERT TO authenticated
  WITH CHECK (public.has_event_permission(evento_id, 'payments', 'write') OR public.has_event_permission(evento_id, 'sales', 'write'));

-- Retira grants amplos herdados e concede somente operacoes/colunas necessarias.
DO $revoke_old_column_grants$
DECLARE
  g record;
  grantee_sql text;
BEGIN
  FOR g IN
    SELECT table_schema, table_name, column_name, grantee, privilege_type
    FROM information_schema.column_privileges
    WHERE table_schema = 'public'
      AND table_name IN ('paroquias','eventos','evento_usuarios','circulos','equipes','usuarios',
                         'pessoas','produtos','vendas','itens_venda','pagamentos')
      AND grantee IN ('PUBLIC','anon','authenticated')
  LOOP
    grantee_sql := CASE WHEN g.grantee = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g.grantee) END;
    EXECUTE format('REVOKE %s (%I) ON TABLE %I.%I FROM %s',
                   g.privilege_type, g.column_name, g.table_schema, g.table_name, grantee_sql);
  END LOOP;
END;
$revoke_old_column_grants$;

REVOKE ALL ON public.paroquias, public.eventos, public.evento_usuarios,
  public.circulos, public.equipes, public.usuarios, public.pessoas, public.produtos,
  public.vendas, public.itens_venda, public.pagamentos
  FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT ON public.paroquias, public.eventos TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.evento_usuarios TO authenticated;
GRANT UPDATE (nome, slug) ON public.paroquias TO authenticated;
GRANT UPDATE (paroquia_id, nome, ano, slug, configuracoes, ativo) ON public.eventos TO authenticated;
GRANT UPDATE (perfil, permissoes, ativo) ON public.evento_usuarios TO authenticated;
REVOKE SELECT ON public.circulos, public.equipes FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, nome) ON public.circulos, public.equipes TO authenticated;
GRANT SELECT ON public.usuarios TO authenticated;
GRANT INSERT (id, nome, perfil, ativo, email) ON public.usuarios TO authenticated;
GRANT UPDATE (nome, perfil, ativo, email) ON public.usuarios TO authenticated;
GRANT SELECT ON public.pessoas, public.produtos, public.vendas TO authenticated;
GRANT INSERT (evento_id, nome, telefone, tipo, circulo_id, equipe_id, responsavel, observacao)
  ON public.pessoas TO authenticated;
GRANT INSERT (evento_id, nome, categoria, preco, estoque, codigo, ativo)
  ON public.produtos TO authenticated;
GRANT INSERT (evento_id, pessoa_id, status_pagamento, forma_pagamento, valor_total, observacao, usuario_id)
  ON public.vendas TO authenticated;
GRANT UPDATE (nome, telefone, tipo, circulo_id, equipe_id, responsavel, observacao, saldo_pendente, ativo)
  ON public.pessoas TO authenticated;
GRANT UPDATE (nome, categoria, preco, ativo)
  ON public.produtos TO authenticated;
GRANT UPDATE (ativo, excluida_em, excluida_por)
  ON public.vendas TO authenticated;
GRANT SELECT ON public.itens_venda, public.pagamentos TO authenticated;
GRANT INSERT (evento_id, venda_id, produto_id, quantidade, preco_unitario, subtotal)
  ON public.itens_venda TO authenticated;
GRANT INSERT (evento_id, pessoa_id, valor, forma_pagamento, observacao)
  ON public.pagamentos TO authenticated;
REVOKE ALL ON SEQUENCE public.produtos_codigo_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SEQUENCE public.produtos_codigo_seq TO authenticated;

GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_any_event_membership() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_event_permission(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_event(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_parish(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_user_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.baixar_estoque(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.editar_produto_com_estoque(uuid, text, text, numeric, integer) TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

COMMIT;

-- POS-MIGRACAO (executar depois, com identidade de plataforma configurada):
-- 1. Conferir que as contagens permanecem: circulos 6, equipes 13, itens_venda 1219,
--    pagamentos 230, pessoas 304, produtos 142, usuarios 22, vendas 1082.
-- 2. Conferir evento_id em todas as linhas e ausencia de referencias cruzadas entre eventos.
-- 3. Testar com duas contas comuns de eventos diferentes e uma conta plataforma.
-- 4. Validar escrita e bloqueio por RLS e exclusao logica (UPDATE ativo=false), sem DELETE.
