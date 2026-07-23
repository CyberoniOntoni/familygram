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

// FamilyGram open session-server speaks layer 228. Override with TG_GRAMJS_LAYER if needed.
export const LAYER = Number(import.meta.env.TG_GRAMJS_LAYER || 228);

export { tlobjects };
