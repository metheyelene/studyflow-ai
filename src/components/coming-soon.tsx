import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";

export function ComingSoon({
  title,
  description,
  week,
}: {
  title: string;
  description: string;
  week: string;
}) {
  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      <Card className="mt-6 items-center justify-center gap-3 py-16 text-center">
        <p className="text-muted-foreground max-w-md">{description}</p>
        <Badge variant="secondary">This opens in {week}</Badge>
      </Card>
    </div>
  );
}
