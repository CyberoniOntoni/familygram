import { Api } from '.';

const tlobjects: Record<number, any> = {};

for (const tl of Object.values(Api)) {
    if ('CONSTRUCTOR_ID' in tl) {
        tlobjects[tl.CONSTRUCTOR_ID] = tl;
    } else {
        for (const sub of Object.values(tl)) {
            tlobjects[sub.CONSTRUCTOR_ID] = sub;
        }
    }
}

// Must stay 224 while FamilyGram uses upstream mytelegram/session-server (layer-224 schema only).
// Layer 228 wire IDs break sendMessage (0xfef48f62) at session-server deserialize.
// Override with TG_GRAMJS_LAYER only when a 228-capable session-server is deployed.
export const LAYER = Number(import.meta.env.TG_GRAMJS_LAYER || 224);

export { tlobjects };
