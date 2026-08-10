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
  // API routes: answer CORS preflights and tag responses so the Flutter
  // web build (dev previews on other ports/origins) can talk to the
  // backend. The API routes themselves enforce auth — never redirect here.
  if (request.nextUrl.pathname.startsWith("/api/")) {
    if (request.method === "OPTIONS") {
      return new NextResponse(null, {
        status: 204,
        headers: corsHeaders(request),
      });
    }
    const res = NextResponse.next();
    for (const [k, v] of Object.entries(corsHeaders(request))) {
      res.headers.set(k, v);
    }
    return res;
  }

  const sessionCookie = getSessionCookie(request);

  if (!sessionCookie) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

function corsHeaders(request: NextRequest): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": request.headers.get("origin") ?? "*",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Vary": "Origin",
  };
}

export const config = {
  // Protect the authenticated app area, onboarding, and (later) admin.
  // Each route also re-checks the session server-side in its layout —
  // this middleware adds the redirect + session refresh at the edge.
  // /api/* is only touched for CORS (never redirected).
  matcher: [
    "/api/:path*",
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
