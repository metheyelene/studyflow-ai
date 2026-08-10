"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { UsageMeter } from "@/components/usage-meter";
import { PaywallDialog } from "@/components/paywall-dialog";
import { Card, CardContent } from "@/components/ui/card";
import type { AiUsage } from "@/lib/usage";

/** Dashboard AI-usage card: shows the real meter and, when the user is
 *  near/over the limit, offers the paywall contextually. */
export function AiUsageWidget({ usage }: { usage: AiUsage }) {
  const router = useRouter();
  const [paywallOpen, setPaywallOpen] = useState(false);

  return (
    <Card>
      <CardContent className="gap-3">
        <UsageMeter usage={usage} onUpgrade={() => setPaywallOpen(true)} />
        <p className="text-muted-foreground text-xs">
          Resets on the 1st of each month.
        </p>
      </CardContent>
      <PaywallDialog
        open={paywallOpen}
        onOpenChange={setPaywallOpen}
        onUpgrade={() => {
          setPaywallOpen(false);
          router.push("/pricing");
        }}
      />
    </Card>
  );
}
