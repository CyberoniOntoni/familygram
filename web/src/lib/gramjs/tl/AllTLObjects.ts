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

// FamilyGram-Server production is layer 224. Web TL packaging is closer to 227–228;
// familygramTlCompat patches known 224 mismatches. Do not set 228 until the server
// dual-registers 228 constructors (docs/LAYER_228_UPGRADE.md on FamilyGram-Server).
// Override with TG_GRAMJS_LAYER only for experimental builds.
export const LAYER = Number(import.meta.env.TG_GRAMJS_LAYER || 224);

export { tlobjects };
