/**
 * Ambient background — soft drifting light fields behind every screen.
 * Pure radial gradients (no backdrop-filter, GPU-cheap). Drift is
 * disabled under prefers-reduced-motion via globals.css.
 */
export function AmbientBackground() {
  return (
    <div aria-hidden className="ambient-bg">
      <div className="ambient-blob ambient-blob-1" />
      <div className="ambient-blob ambient-blob-2" />
      <div className="ambient-blob ambient-blob-3" />
    </div>
  );
}
