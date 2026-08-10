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
  // Protect the authenticated app area, onboarding, and (later) admin.
  // Each route also re-checks the session server-side in its layout —
  // this middleware adds the redirect + session refresh at the edge.
  matcher: [
    "/dashboard/:path*",
    "/notebooks/:path*",
    "/notes/:path*",
    "/flashcards/:path*",
    "/quizzes/:path*",
    "/planner/:path*",
    "/settings/:path*",
    "/onboarding/:path*",
    "/admin/:path*",
  ],
};
