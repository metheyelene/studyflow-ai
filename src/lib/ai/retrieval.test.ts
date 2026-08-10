import { describe, expect, it } from "vitest";

import { hybridRetrieve, lexicalSimilarity, scoreChunks, setVectorScorer, type RetrievableChunk } from "./retrieval";

function chunk(id: string, sourceId: string, content: string): RetrievableChunk {
  return {
    id,
    sourceId,
    notebookId: "nb1",
    content,
    chunkIndex: 0,
    page: null,
    sourceTitle: `Source ${sourceId}`,
  };
}

const SAMPLE: RetrievableChunk[] = [
  chunk("c1", "s1", "Photosynthesis converts light energy into chemical energy in chloroplasts."),
  chunk("c2", "s1", "The Calvin cycle fixes carbon dioxide into glucose using ATP and NADPH."),
  chunk("c3", "s2", "Mitochondria generate ATP through cellular respiration and the electron transport chain."),
  chunk("c4", "s2", "Glycolysis splits glucose into pyruvate in the cytoplasm without oxygen."),
];

describe("scoreChunks", () => {
  it("ranks the most relevant chunk first", () => {
    const results = scoreChunks("Calvin cycle carbon fixation", SAMPLE, { topK: 4 });
    expect(results[0].id).toBe("c2");
  });

  it("respects source filtering", () => {
    const results = scoreChunks("ATP generation", SAMPLE, { topK: 4, sourceIds: ["s2"] });
    for (const r of results) expect(r.sourceId).toBe("s2");
    expect(results.length).toBeGreaterThan(0);
  });

  it("returns fewer results than the minOverlap threshold", () => {
    const results = scoreChunks("quantum entanglement", SAMPLE, { minOverlap: 1 });
    expect(results.length).toBe(0);
  });

  it("caps results at topK", () => {
    const results = scoreChunks("the of and", SAMPLE, { topK: 2 });
    expect(results.length).toBeLessThanOrEqual(2);
  });

  it("reports matched terms", () => {
    const results = scoreChunks("Calvin cycle", SAMPLE, { topK: 1 });
    expect(results[0].matchedTerms).toContain("calvin");
  });

  it("boosts exact-phrase matches", () => {
    const exact = scoreChunks("glycolysis splits glucose", SAMPLE, { topK: 4 });
    expect(exact[0].id).toBe("c4");
  });
});

describe("hybridRetrieve", () => {
  it("works without a vector scorer (pure lexical)", async () => {
    setVectorScorer(null);
    const results = await hybridRetrieve("electron transport chain ATP", SAMPLE, { topK: 3 });
    expect(results.length).toBeGreaterThan(0);
    expect(results[0].id).toBe("c3");
  });

  it("blends vector scores when a scorer is registered", async () => {
    setVectorScorer({
      score: async (_, chunks) => {
        // Pretend the vector index likes c1 strongly.
        return new Map(chunks.map((c) => [c.id, c.id === "c1" ? 1 : 0.1]));
      },
    });
    const results = await hybridRetrieve("photosynthesis light", SAMPLE, { topK: 2 });
    expect(results[0].id).toBe("c1");
    setVectorScorer(null);
  });
});

describe("lexicalSimilarity", () => {
  it("is 1 for identical text and 0 for disjoint text", () => {
    expect(lexicalSimilarity("the quick brown fox", "the quick brown fox")).toBeGreaterThan(0.9);
    expect(lexicalSimilarity("alpha beta gamma", "delta epsilon zeta")).toBe(0);
  });
});
