"use client";

// Client-side auth helpers. Use in components:
//   const { data: session } = useSession();
//   await signIn.email({ email, password });
//   await signUp.email({ email, password, name });
import { createAuthClient } from "better-auth/react";

export const authClient = createAuthClient();

export const { signIn, signUp, signOut, useSession } = authClient;
