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

// FamilyGram-Server LayerLatest is 228 with dual-registration of layer-224 IDs.
// Override with TG_GRAMJS_LAYER only for experimental builds.
export const LAYER = Number(import.meta.env.TG_GRAMJS_LAYER || 228);

export { tlobjects };
