CREATE OR REPLACE FUNCTION public._team_safe_json(p_value jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO pg_catalog, public
AS $function$
DECLARE
  v_result jsonb;
  v_key text;
  v_item jsonb;
  v_normalized text;
BEGIN
  IF p_value IS NULL THEN
    RETURN NULL;
  END IF;

  IF jsonb_typeof(p_value) = 'object' THEN
    v_result := '{}'::jsonb;
    FOR v_key, v_item IN SELECT key, value FROM jsonb_each(p_value) LOOP
      v_normalized := regexp_replace(lower(v_key), '[^a-z0-9]', '', 'g');
      IF v_normalized = ANY (ARRAY[
        'totalbudget', 'budgetactual', 'budgetplanned', 'budgetrates',
        'amount', 'rate', 'cost', 'spend', 'expense', 'revenue', 'margin',
        'profit', 'financial', 'financials', 'finance', 'pendingapprovals',
        'ownerkey'
      ]) THEN
        CONTINUE;
      END IF;
      IF v_normalized = 'history' AND p_value ? 'rate' THEN
        CONTINUE;
      END IF;
      v_result := v_result || jsonb_build_object(v_key, public._team_safe_json(v_item));
    END LOOP;
    RETURN v_result;
  END IF;

  IF jsonb_typeof(p_value) = 'array' THEN
    SELECT COALESCE(jsonb_agg(public._team_safe_json(value)), '[]'::jsonb)
      INTO v_result
      FROM jsonb_array_elements(p_value) AS elements(value);
    RETURN v_result;
  END IF;

  RETURN p_value;
END
$function$;

REVOKE ALL ON FUNCTION public._team_safe_json(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.state_get(p_token text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_role text := public._session_role(p_token);
  r record;
BEGIN
  IF v_role IS NULL THEN
    RETURN json_build_object('ok', false, 'auth', false);
  END IF;

  SELECT data, updated_at INTO r FROM public.app_state WHERE id = 'default';
  RETURN json_build_object(
    'ok', true,
    'role', v_role,
    'data', CASE WHEN v_role = 'admin' THEN r.data ELSE public._team_safe_json(r.data) END,
    'updated_at', r.updated_at
  );
END
$function$;

CREATE OR REPLACE FUNCTION public.state_put(
  p_token text,
  p_data jsonb,
  p_base timestamp with time zone
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_role text := public._session_role(p_token);
  r record;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_role IS NULL THEN
    RETURN json_build_object('ok', false, 'auth', false);
  END IF;
  IF v_role <> 'admin' THEN
    RETURN json_build_object('ok', false, 'forbidden', true);
  END IF;
  IF p_data IS NULL OR jsonb_typeof(p_data->'projects') <> 'array' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid');
  END IF;

  SELECT data, updated_at INTO r FROM public.app_state WHERE id = 'default' FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.app_state(id, data, updated_at, updated_by)
      VALUES ('default', p_data, v_now, v_role);
    RETURN json_build_object('ok', true, 'updated_at', v_now);
  END IF;
  IF p_base IS NULL OR r.updated_at IS DISTINCT FROM p_base THEN
    RETURN json_build_object('ok', false, 'conflict', true, 'data', r.data, 'updated_at', r.updated_at);
  END IF;
  UPDATE public.app_state
    SET data = p_data, updated_at = v_now, updated_by = v_role
    WHERE id = 'default';
  RETURN json_build_object('ok', true, 'updated_at', v_now);
END
$function$;
