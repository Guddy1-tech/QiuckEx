ALTER TABLE telegram_user_mappings
  ADD COLUMN verification_expires_at TIMESTAMPTZ,
  ADD COLUMN verification_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN verification_locked_until TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION verify_telegram_link(
  p_telegram_id BIGINT,
  p_verification_code TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mapping telegram_user_mappings%ROWTYPE;
  next_attempts INTEGER;
BEGIN
  SELECT * INTO mapping
  FROM telegram_user_mappings
  WHERE telegram_id = p_telegram_id
  FOR UPDATE;

  IF NOT FOUND OR mapping.is_verified THEN
    RETURN 'invalid';
  END IF;

  IF mapping.verification_locked_until > now() THEN
    RETURN 'locked';
  END IF;

  IF mapping.verification_code IS NULL
    OR mapping.verification_expires_at IS NULL
    OR mapping.verification_expires_at <= now() THEN
    UPDATE telegram_user_mappings
    SET verification_code = NULL,
        verification_expires_at = NULL
    WHERE telegram_id = p_telegram_id;
    RETURN 'expired';
  END IF;

  IF upper(mapping.verification_code) = upper(btrim(p_verification_code)) THEN
    UPDATE telegram_user_mappings
    SET is_verified = true,
        verification_code = NULL,
        verification_expires_at = NULL,
        verification_attempts = 0,
        verification_locked_until = NULL
    WHERE telegram_id = p_telegram_id;
    RETURN 'verified';
  END IF;

  next_attempts := mapping.verification_attempts + 1;
  UPDATE telegram_user_mappings
  SET verification_attempts = next_attempts,
      verification_locked_until = CASE
        WHEN next_attempts >= 5 THEN now() + interval '15 minutes'
        ELSE NULL
      END
  WHERE telegram_id = p_telegram_id;

  IF next_attempts >= 5 THEN
    RETURN 'locked';
  END IF;

  RETURN 'invalid';
END;
$$;

REVOKE ALL ON FUNCTION verify_telegram_link(BIGINT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION verify_telegram_link(BIGINT, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_telegram_link(BIGINT, TEXT) TO service_role;