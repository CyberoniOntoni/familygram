import type { LangPackStringValue } from '../../api/types';

import readStrings from './readStrings';

export default async function readFamilyGramOverrides(): Promise<Record<string, LangPackStringValue>> {
  const file = await import('../../assets/localization/familygram.strings?raw');
  return readStrings(file.default);
}