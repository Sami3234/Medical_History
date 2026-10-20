-- Run once in the Supabase SQL editor after supabase_schema.sql.
-- Keeps one permanent Self owner per family and synchronizes profile identity.

CREATE UNIQUE INDEX IF NOT EXISTS members_one_self_per_family
ON public.members (family_id)
WHERE lower(trim(relation)) = 'self';

CREATE OR REPLACE FUNCTION public.sync_profile_to_owner_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.full_name IS DISTINCT FROM OLD.full_name
      OR NEW.avatar_url IS DISTINCT FROM OLD.avatar_url THEN
    UPDATE public.members AS member
    SET name = COALESCE(NULLIF(trim(NEW.full_name), ''), member.name),
        avatar_url = COALESCE(NEW.avatar_url, member.avatar_url)
    FROM public.families AS family
    WHERE member.family_id = family.id
      AND family.user_id = NEW.id
      AND lower(trim(member.relation)) = 'self';

    IF NEW.full_name IS DISTINCT FROM OLD.full_name THEN
      UPDATE public.families
      SET name = trim(NEW.full_name) || ' Family'
      WHERE user_id = NEW.id
        AND lower(trim(name)) IN (
          lower(trim(OLD.full_name)),
          lower(trim(OLD.full_name) || ' Family')
        );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_to_owner_member_trigger
ON public.profiles;

CREATE TRIGGER sync_profile_to_owner_member_trigger
AFTER UPDATE OF full_name, avatar_url
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_to_owner_member();
