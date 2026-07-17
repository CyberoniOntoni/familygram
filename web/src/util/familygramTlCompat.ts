/**
 * FamilyGram TL interop: alias legacy constructor IDs the server may still emit
 * (persisted blobs / dual-layer), and ensure critical layer-228 IDs resolve.
 *
 * Primary fix for login: server Latest serializes user#b1b8cc83; web scheme must
 * register that ID (see apiTl.ts). Aliases below are defense-in-depth.
 */
import { Api as GramJs } from '../lib/gramjs';
import { tlobjects } from '../lib/gramjs/tl/AllTLObjects';
import { IS_FAMILYGRAM } from '../config';

function aliasConstructorId(
  cls: { CONSTRUCTOR_ID: number },
  aliasId: number,
) {
  if (tlobjects[aliasId] === cls) return;
  tlobjects[aliasId] = cls;
}

export function applyFamilyGramTlCompat(): void {
  if (!IS_FAMILYGRAM) return;

  // Layer-224 constructor IDs → current classes (bit-compatible or legacy blobs)
  aliasConstructorId(GramJs.User, 0x31774388);
  aliasConstructorId(GramJs.Channel, 0x1c32b11c);
  aliasConstructorId(GramJs.BotCommand, 0xc27ac8c7);

  // Ensure layer-228 primary IDs are registered (in case of stale bundles)
  if (GramJs.User?.CONSTRUCTOR_ID) {
    tlobjects[GramJs.User.CONSTRUCTOR_ID] = GramJs.User;
  }
  if (GramJs.Channel?.CONSTRUCTOR_ID) {
    tlobjects[GramJs.Channel.CONSTRUCTOR_ID] = GramJs.Channel;
  }
}
