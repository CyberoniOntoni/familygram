/**
 * FamilyGram TL interop for self-hosted stack — full layer 228 wire only.
 * Ensures primary constructor IDs match server Latest (228); no legacy aliases.
 */
import { Api as GramJs } from '../lib/gramjs';
import { tlobjects } from '../lib/gramjs/tl/AllTLObjects';
import { IS_FAMILYGRAM } from '../config';

const LAYER_228_SEND_MESSAGE_ID = 0xfef48f62;
const LAYER_228_EDIT_MESSAGE_ID = 0xb106e66c;
const LAYER_228_SAVE_DRAFT_ID = 0xad0fa15c;
const LAYER_228_USER_ID = 0xb1b8cc83;
const LAYER_228_CHANNEL_ID = 0xd49f34c6;
const LAYER_228_MESSAGE_ID = 0x7600b9d3;

function ensurePrimaryConstructorId(
  cls: { CONSTRUCTOR_ID: number; prototype?: { CONSTRUCTOR_ID?: number } },
  primaryId: number,
) {
  if (!cls) return;
  cls.CONSTRUCTOR_ID = primaryId;
  if (cls.prototype) {
    cls.prototype.CONSTRUCTOR_ID = primaryId;
  }
  tlobjects[primaryId] = cls;
}

export function applyFamilyGramTlCompat(): void {
  if (!IS_FAMILYGRAM) return;

  if (GramJs.messages?.SendMessage) {
    ensurePrimaryConstructorId(GramJs.messages.SendMessage, LAYER_228_SEND_MESSAGE_ID);
  }
  if (GramJs.messages?.EditMessage) {
    ensurePrimaryConstructorId(GramJs.messages.EditMessage, LAYER_228_EDIT_MESSAGE_ID);
  }
  if (GramJs.messages?.SaveDraft) {
    ensurePrimaryConstructorId(GramJs.messages.SaveDraft, LAYER_228_SAVE_DRAFT_ID);
  }
  if (GramJs.User) {
    ensurePrimaryConstructorId(GramJs.User, LAYER_228_USER_ID);
  }
  if (GramJs.Channel) {
    ensurePrimaryConstructorId(GramJs.Channel, LAYER_228_CHANNEL_ID);
  }
  if (GramJs.Message) {
    ensurePrimaryConstructorId(GramJs.Message, LAYER_228_MESSAGE_ID);
  }
}
