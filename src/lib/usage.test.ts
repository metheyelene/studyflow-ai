import { describe, expect, it } from "vitest";

import { nextPeriodStart, percentUsed, periodKey, usageState } from "./usage";

describe("usage metering", () => {
  it("builds YYYY-MM period keys in UTC", () => {
    expect(periodKey(new Date("2026-08-10T12:00:00Z"))).toBe("2026-08");
    expect(periodKey(new Date("2026-12-31T23:59:00Z"))).toBe("2026-12");
    expect(periodKey(new Date("2027-01-01T00:00:00Z"))).toBe("2027-01");
  });

  it("computes the next period start", () => {
    expect(nextPeriodStart(new Date("2026-08-10T12:00:00Z")).toISOString()).toBe(
      "2026-09-01T00:00:00.000Z",
    );
    expect(nextPeriodStart(new Date("2026-12-15T00:00:00Z")).toISOString()).toBe(
      "2027-01-01T00:00:00.000Z",
    );
  });

  it("clamps percent to 100 and guards zero limits", () => {
    expect(percentUsed(5, 20)).toBe(25);
    expect(percentUsed(20, 20)).toBe(100);
    expect(percentUsed(30, 20)).toBe(100);
    expect(percentUsed(0, 0)).toBe(100);
  });

  it("maps usage to the correct UX state at the 70/90/100 thresholds", () => {
    expect(usageState(0, 20)).toBe("ok");
    expect(usageState(13, 20)).toBe("ok"); // 65%
    expect(usageState(14, 20)).toBe("warning"); // 70%
    expect(usageState(17, 20)).toBe("warning"); // 85%
    expect(usageState(18, 20)).toBe("critical"); // 90%
    expect(usageState(19, 20)).toBe("critical"); // 95%
    expect(usageState(20, 20)).toBe("exhausted"); // 100%
    expect(usageState(21, 20)).toBe("exhausted");
    expect(usageState(0, 0)).toBe("exhausted");
  });
});
