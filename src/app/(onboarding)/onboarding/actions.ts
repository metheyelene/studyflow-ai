"use server";

import { headers } from "next/headers";

import { auth } from "@/lib/auth";
import {
  completeOnboarding as completeOnboardingForUser,
  GOAL_OPTIONS,
  type OnboardingResult,
} from "@/lib/onboarding";

export { GOAL_OPTIONS };

export type { OnboardingResult };

export async function completeOnboarding(
  input: unknown,
): Promise<OnboardingResult> {
  const session = await auth.api.getSession({ headers: await headers() });
  if (!session) {
    return { error: "Your session expired. Please log in again." };
  }
  return completeOnboardingForUser(session.user.id, input);
}
