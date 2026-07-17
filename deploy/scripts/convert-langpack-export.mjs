#!/usr/bin/env node
/**
 * Convert Telegram language exports to FamilyGram Server data-seeder JSON.
 *
 * Supports:
 *   - Android XML: <string name="Key">value</string>
 *   - WebA/WebK/iOS .strings: "Key" = "value";
 *
 * Usage (merge inputs left-to-right; later wins):
 *   node convert-langpack-export.mjs --lang en --pack weba --out out.json file1 [file2...]
 */
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

const PLURAL_SUFFIXES = ['zero', 'one', 'two', 'few', 'many', 'other'];
const PLURAL_RE = new RegExp(`^(.+)_(${PLURAL_SUFFIXES.join('|')})$`);
const XML_STRING_RE = /<string name="([^"]+)">([\s\S]*?)<\/string>/g;
const STRINGS_RE = /"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;/g;

const LANG_META = {
  en: { name: 'English', nativeName: 'English', pluralCode: 'en' },
  ru: { name: 'Russian', nativeName: 'Русский', pluralCode: 'ru' },
};

function decodeXml(value) {
  return value
    .replace(/\\'/g, "'")
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .trim();
}

function decodeStrings(value) {
  return value
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\'/g, "'")
    .replace(/\\\\/g, '\\');
}

function addEntry(simple, plural, rawKey, value) {
  const pluralMatch = rawKey.match(PLURAL_RE);
  if (pluralMatch) {
    const [, baseKey, suffix] = pluralMatch;
    const entry = plural.get(baseKey) || { key: baseKey, section: 'general' };
    entry[`${suffix}Value`] = value;
    plural.set(baseKey, entry);
    return;
  }
  simple.set(rawKey, { key: rawKey, section: 'general', value });
}

function parseXml(text) {
  const simple = new Map();
  const plural = new Map();
  for (const match of text.matchAll(XML_STRING_RE)) {
    addEntry(simple, plural, match[1], decodeXml(match[2]));
  }
  return { format: 'android-xml', simple, plural };
}

function parseStrings(text) {
  const simple = new Map();
  const plural = new Map();
  for (const match of text.matchAll(STRINGS_RE)) {
    addEntry(simple, plural, match[1], decodeStrings(match[2]));
  }
  return { format: 'strings', simple, plural };
}

function detectAndParse(text) {
  if (text.includes('<string name=')) {
    return parseXml(text);
  }
  return parseStrings(text);
}

function parseArgs(argv) {
  let lang;
  let pack = 'weba';
  let out;
  const files = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--lang') lang = argv[++i];
    else if (a === '--pack') pack = argv[++i];
    else if (a === '--out') out = argv[++i];
    else if (a.startsWith('-')) {
      console.error(`Unknown flag: ${a}`);
      process.exit(1);
    } else files.push(a);
  }
  if (!lang || !out || files.length === 0) {
    console.error(
      'Usage: convert-langpack-export.mjs --lang <code> --out <file.json> [--pack weba] <input...>',
    );
    process.exit(1);
  }
  return { lang, pack, out, files };
}

function main() {
  const { lang, pack, out, files } = parseArgs(process.argv.slice(2));
  const meta = LANG_META[lang];
  if (!meta) {
    console.error(`Unsupported langCode: ${lang}`);
    process.exit(1);
  }

  const simple = new Map();
  const plural = new Map();
  const formats = [];

  for (const inputPath of files) {
    const text = readFileSync(inputPath, 'utf8');
    const parsed = detectAndParse(text);
    formats.push(
      `${inputPath}:${parsed.format}:${parsed.simple.size + parsed.plural.size}`,
    );
    for (const [k, v] of parsed.simple) simple.set(k, v);
    for (const [k, v] of parsed.plural) {
      const existing = plural.get(k) || { key: k, section: 'general' };
      plural.set(k, { ...existing, ...v });
    }
  }

  const strings = [...simple.values(), ...plural.values()];
  strings.sort((a, b) => a.key.localeCompare(b.key));

  const hash = createHash('sha256')
    .update(JSON.stringify(strings))
    .digest('hex')
    .slice(0, 8);
  const version = Number.parseInt(hash.slice(0, 7), 16);

  const payload = {
    source: `https://translations.telegram.org/${lang}/${pack}/`,
    languageCode: lang,
    languagePack: pack,
    name: meta.name,
    nativeName: meta.nativeName,
    pluralCode: meta.pluralCode,
    version,
    sections: { general: strings.length },
    strings,
  };

  writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(
    `Wrote ${strings.length} strings → ${out} (version=${version}; ${formats.join('; ')})`,
  );
}

main();
