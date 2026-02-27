/**
 * Shape of the payload embedded inside every JWT access token.
 *
 * Kept minimal to limit the size of the token and to avoid embedding
 * sensitive data (OWASP A02 / A09).
 */
export interface JwtPayload {
  /** User UUID — the subject claim (`sub`). */
  sub: string;

  /** User email — included for convenience in authenticated handlers. */
  email: string;
}

/**
 * Payload embedded inside the refresh token.
 *
 * Identical structure to {@link JwtPayload}, but signed with a distinct
 * secret (JWT_REFRESH_SECRET) to prevent a leaked access token from
 * being used to obtain a new session (OWASP A07).
 */
export interface JwtRefreshPayload extends JwtPayload {}