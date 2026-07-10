/**
 * Testgram negotiates MTProto layer 224 while telegram-tt ships layer 227 TL schema.
 * Patch known constructor ID mismatches so the session server can deserialize requests.
 */
import { Api as GramJs } from '../lib/gramjs';
import { tlobjects } from '../lib/gramjs/tl/AllTLObjects';
import { writeUint32LE } from './encoding/buffer';
import { IS_FAMILYGRAM } from '../config';

const LAYER_224_SEND_MESSAGE_ID = 0x545cd15a;
// Testgram serializes message#3ae56482; telegram-tt expects message#7600b9d3.
// Extra layer-227 fields are behind unset flag bits, so the same parser works.
const TESTGRAM_MESSAGE_ID = 0x3ae56482;

function aliasConstructorId(
  cls: { CONSTRUCTOR_ID: number },
  aliasId: number,
) {
  if (tlobjects[aliasId] === cls) return;
  tlobjects[aliasId] = cls;
}

function patchRequestConstructorId(
  cls: { CONSTRUCTOR_ID: number; prototype: { getBytes: () => Uint8Array; CONSTRUCTOR_ID?: number } },
  layer224Id: number,
) {
  const layer227Id = cls.CONSTRUCTOR_ID;
  if (layer227Id === layer224Id) return;

  delete tlobjects[layer227Id];
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

  patchRequestConstructorId(GramJs.messages.SendMessage, LAYER_224_SEND_MESSAGE_ID);
  aliasConstructorId(GramJs.Message, TESTGRAM_MESSAGE_ID);
}