#!/usr/bin/env node
/**
 * Convert translations.telegram.org Android XML export to Testgram langpack JSON.
 * Usage:
 *   node deploy/scripts/convert-android-langpack-export.mjs <input.xml> <output.json> <langCode>
 */
import { readFileSync, writeFileSync } from 'node:fs';

const PLURAL_SUFFIXES = ['zero', 'one', 'two', 'few', 'many', 'other'];
const PLURAL_RE = new RegExp(`^(.+)_(${PLURAL_SUFFIXES.join('|')})$`);
const STRING_RE = /<string name="([^"]+)">([\s\S]*?)<\/string>/g;

const LANG_META = {
  en: {
    name: 'English',
    nativeName: 'English',
    pluralCode: 'en',
    source: 'https://translations.telegram.org/en/android/',
  },
  ru: {
    name: 'Russian',
    nativeName: 'Русский',
    pluralCode: 'ru',
    source: 'https://translations.telegram.org/ru/android/',
  },
};

function decodeXml(value) {
  return value
    .replace(/\\'/g, "'")
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

function main() {
  const [inputPath, outputPath, langCode = 'en'] = process.argv.slice(2);
  if (!inputPath || !outputPath) {
    console.error('Usage: node convert-android-langpack-export.mjs <input.xml> <output.json> [langCode]');
    process.exit(1);
  }

  const meta = LANG_META[langCode];
  if (!meta) {
    console.error(`Unsupported langCode: ${langCode}`);
    process.exit(1);
  }

  const xml = readFileSync(inputPath, 'utf8');
  const simple = new Map();
  const plural = new Map();

  for (const match of xml.matchAll(STRING_RE)) {
    const rawKey = match[1];
    const value = decodeXml(match[2].trim());
    const pluralMatch = rawKey.match(PLURAL_RE);
    if (pluralMatch) {
      const [, baseKey, suffix] = pluralMatch;
      const entry = plural.get(baseKey) || { key: baseKey, section: 'general' };
      entry[`${suffix}Value`] = value;
      plural.set(baseKey, entry);
      continue;
    }
    simple.set(rawKey, { key: rawKey, section: 'general', value });
  }

  const strings = [...simple.values(), ...plural.values()];
  strings.sort((a, b) => a.key.localeCompare(b.key));

  const pack = {
    source: meta.source,
    languageCode: langCode,
    languagePack: 'android',
    name: meta.name,
    nativeName: meta.nativeName,
    pluralCode: meta.pluralCode,
    version: 1410686278,
    sections: { general: strings.length },
    strings,
  };

  writeFileSync(outputPath, `${JSON.stringify(pack, null, 2)}\n`, 'utf8');
  console.log(`Wrote ${strings.length} strings to ${outputPath}`);
}

main();