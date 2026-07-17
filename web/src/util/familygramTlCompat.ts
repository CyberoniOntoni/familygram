/**
 * FamilyGram TL interop for self-hosted stack.
 *
 * Upstream mytelegram/session-server only understands layer-224 constructors.
 * Force critical request IDs to 224 and alias 228 response IDs if any leak through.
 */
import { Api as GramJs } from '../lib/gramjs';
import { tlobjects } from '../lib/gramjs/tl/AllTLObjects';
import { writeUint32LE } from './encoding/buffer';
import { IS_FAMILYGRAM } from '../config';

const LAYER_224_SEND_MESSAGE_ID = 0x545cd15a;
const LAYER_224_EDIT_MESSAGE_ID = 0x51e842e1;
const LAYER_224_SAVE_DRAFT_ID = 0x54ae308e;
const LAYER_224_USER_ID = 0x31774388;
const LAYER_224_CHANNEL_ID = 0x1c32b11c;
const LAYER_224_MESSAGE_ID = 0x3ae56482;

// Layer 228 IDs (for aliases when reading mixed traffic)
const LAYER_228_USER_ID = 0xb1b8cc83;
const LAYER_228_CHANNEL_ID = 0xd49f34c6;
const LAYER_228_MESSAGE_ID = 0x7600b9d3;

function aliasConstructorId(
  cls: { CONSTRUCTOR_ID: number },
  aliasId: number,
) {
  if (!cls) return;
  if (tlobjects[aliasId] === cls) return;
  tlobjects[aliasId] = cls;
}

function patchRequestConstructorId(
  cls: { CONSTRUCTOR_ID: number; prototype: { getBytes: () => Uint8Array; CONSTRUCTOR_ID?: number } },
  layer224Id: number,
) {
  if (!cls || cls.CONSTRUCTOR_ID === layer224Id) return;

  const previousId = cls.CONSTRUCTOR_ID;
  delete tlobjects[previousId];
  cls.CONSTRUCTOR_ID = layer224Id;
  cls.prototype.CONSTRUCTOR_ID = layer224Id;
  tlobjects[layer224Id] = cls;

  const originalGetBytes = cls.prototype.getBytes;
  cls.prototype.getBytes = function patchedGetBytes(this: Record<string, unknown>) {
    // Layer 224 sendMessage has no rich_message field.
    delete this.richMessage;

    const bytes = originalGetBytes.call(this);
    const patched = new Uint8Array(bytes);
    writeUint32LE(patched, layer224Id);
    return patched;
  };
}

export function applyFamilyGramTlCompat(): void {
  if (!IS_FAMILYGRAM) return;

  // Outbound requests must use 224 IDs so session-server can deserialize msg_container.
  patchRequestConstructorId(GramJs.messages.SendMessage, LAYER_224_SEND_MESSAGE_ID);
  patchRequestConstructorId(GramJs.messages.EditMessage, LAYER_224_EDIT_MESSAGE_ID);
  patchRequestConstructorId(GramJs.messages.SaveDraft, LAYER_224_SAVE_DRAFT_ID);

  // Prefer 224 constructors for types session-server re-serializes.
  if (GramJs.User) {
    GramJs.User.CONSTRUCTOR_ID = LAYER_224_USER_ID;
    GramJs.User.prototype.CONSTRUCTOR_ID = LAYER_224_USER_ID;
    tlobjects[LAYER_224_USER_ID] = GramJs.User;
    aliasConstructorId(GramJs.User, LAYER_228_USER_ID);
  }
  if (GramJs.Channel) {
    GramJs.Channel.CONSTRUCTOR_ID = LAYER_224_CHANNEL_ID;
    GramJs.Channel.prototype.CONSTRUCTOR_ID = LAYER_224_CHANNEL_ID;
    tlobjects[LAYER_224_CHANNEL_ID] = GramJs.Channel;
    aliasConstructorId(GramJs.Channel, LAYER_228_CHANNEL_ID);
  }
  if (GramJs.Message) {
    GramJs.Message.CONSTRUCTOR_ID = LAYER_224_MESSAGE_ID;
    GramJs.Message.prototype.CONSTRUCTOR_ID = LAYER_224_MESSAGE_ID;
    tlobjects[LAYER_224_MESSAGE_ID] = GramJs.Message;
    aliasConstructorId(GramJs.Message, LAYER_228_MESSAGE_ID);
  }
}
