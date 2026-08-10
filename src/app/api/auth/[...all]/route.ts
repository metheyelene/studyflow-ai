import { toNextJsHandler } from "better-auth/next-js";

import { auth } from "@/lib/auth";

const { GET, POST: rawPOST } = toNextJsHandler(auth);

// Better Auth's router converts internal errors (e.g. an unreachable
// database) into a bare 5xx with an empty body — the client can't parse
// that into friendly copy. Normalize both that case and any thrown error
// into a JSON error body the client's error mapper understands.
const INTERNAL_ERROR = {
  error: {
    code: "UNKNOWN_ERROR",
    message: "Something went wrong. Please try again.",
  },
} as const;

const withErrorHandling = (handler: typeof rawPOST): typeof rawPOST =>
  (async (request: Request) => {
    try {
      const res = await handler(request);
      if (
        res.status >= 500 &&
        !res.headers.get("content-type")?.includes("application/json")
      ) {
        console.error(
          "[auth] internal error (bare 5xx):",
          request.url,
          res.status,
        );
        return Response.json(INTERNAL_ERROR, { status: res.status });
      }
      return res;
    } catch (err) {
      console.error("[auth] unexpected error:", err);
      return Response.json(INTERNAL_ERROR, { status: 500 });
    }
  }) as typeof rawPOST;

export { GET };
export const POST = withErrorHandling(rawPOST);
