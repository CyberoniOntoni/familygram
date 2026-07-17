/**
 * FamilyGram TL interop shims.
 * Server LayerLatest is 228 with dual-registration of 224 constructor IDs.
 * Kept as a no-op hook so call sites continue to work; re-add patches only if
 * a temporary layer skew is needed.
 */
import { IS_FAMILYGRAM } from '../config';

export function applyFamilyGramTlCompat(): void {
  if (!IS_FAMILYGRAM) return;
  // Layer 228 is the negotiated default; no forced 224 constructor rewrites.
}
