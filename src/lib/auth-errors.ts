// Maps Better Auth error codes to friendly, human copy. Never show raw
// error objects to users.

const FRIENDLY: Record<string, string> = {
  INVALID_EMAIL_OR_PASSWORD:
    "That email or password isn't right. Double-check and try again.",
  USER_ALREADY_EXISTS:
    "An account with that email already exists — log in instead.",
  PASSWORD_TOO_SHORT: "Your password needs to be at least 8 characters.",
  INVALID_EMAIL: "That email doesn't look right. Check for typos.",
  EMAIL_NOT_VERIFIED: "Please verify your email address first.",
  ACCOUNT_NOT_FOUND: "No account found with that email.",
  RATE_LIMITED: "Too many attempts. Wait a minute and try again.",
  UNKNOWN_ERROR: "Something went wrong. Please try again.",
};

export function friendlyAuthError(error: unknown): string {
  // Normalizes both the { data, error } result shape and thrown errors.
  const err = error as
    | { error?: { code?: string }; code?: string }
    | null
    | undefined;
  const code = err?.error?.code ?? err?.code;
  if (code && FRIENDLY[code]) return FRIENDLY[code];
  return FRIENDLY.UNKNOWN_ERROR;
}
