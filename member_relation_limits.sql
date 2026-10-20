-- Run once in the Supabase SQL editor.
-- Limits are per family and relations are stored relative to the family owner.

CREATE OR REPLACE FUNCTION public.enforce_member_relation_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  normalized_relation TEXT := lower(trim(NEW.relation));
  relation_count INTEGER;
  relation_limit INTEGER;
  relation_group TEXT;
BEGIN
  CASE
    WHEN normalized_relation = 'father' THEN
      relation_limit := 1;
      relation_group := 'father';
    WHEN normalized_relation = 'mother' THEN
      relation_limit := 3;
      relation_group := 'mother';
    WHEN normalized_relation = 'grandfather' THEN
      relation_limit := 1;
      relation_group := 'grandfather';
    WHEN normalized_relation = 'grandmother' THEN
      relation_limit := 1;
      relation_group := 'grandmother';
    WHEN normalized_relation IN ('brother', 'sister') THEN
      relation_limit := 10;
      relation_group := 'siblings';
    WHEN normalized_relation IN ('son', 'daughter') THEN
      relation_limit := 10;
      relation_group := 'children';
    ELSE
      RETURN NEW;
  END CASE;

  SELECT count(*)
  INTO relation_count
  FROM public.members AS member
  WHERE member.family_id = NEW.family_id
    AND member.id IS DISTINCT FROM NEW.id
    AND CASE relation_group
      WHEN 'siblings' THEN lower(trim(member.relation)) IN ('brother', 'sister')
      WHEN 'children' THEN lower(trim(member.relation)) IN ('son', 'daughter')
      ELSE lower(trim(member.relation)) = relation_group
    END;

  IF relation_count >= relation_limit THEN
    RAISE EXCEPTION 'member_relation_limit: maximum % % allowed per family',
      relation_limit,
      relation_group
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_member_relation_limits_trigger
ON public.members;

CREATE TRIGGER enforce_member_relation_limits_trigger
BEFORE INSERT OR UPDATE OF relation, family_id
ON public.members
FOR EACH ROW
EXECUTE FUNCTION public.enforce_member_relation_limits();
