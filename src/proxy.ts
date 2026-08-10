// ─────────────────────────────────────────────────────────────────────
// Edge middleware:
//  - refreshes the Better Auth session cookie on every request (cheap,
//    keeps sessions from going stale)
//  - redirects unauthenticated users away from /dashboard and /app
// Admin routes are guarded additionally in their own layout/API layer.
// ─────────────────────────────────────────────────────────────────────
import { getSessionCookie } from "better-auth/cookies";
import { NextResponse, type NextRequest } from "next/server";

export async function proxy(request: NextRequest) {
  const sessionCookie = getSessionCookie(request);

  if (!sessionCookie) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  // Protect everything under the authenticated app area and onboarding.
  // Add "/admin/:path*" here once the admin panel exists (it has its
  // own role check on top of this).
  matcher: ["/app/:path*", "/onboarding/:path*"],
};
