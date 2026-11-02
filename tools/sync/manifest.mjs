// Lists every script under src/ with its Studio path and an FNV-1a hash of its source.
// Usage:
//   node tools/sync/manifest.mjs                 print the local manifest
//   node tools/sync/manifest.mjs studio.json     compare with hashes exported from Studio
// studio.json is the output of tools/sync/StudioHashes.luau (run it via MCP or the command bar).

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(fileURLToPath(import.meta.url), "..", "..", "..");
const srcRoot = join(root, "src");

function fnv1a(text) {
  let h = 0x811c9dc5;
  for (const byte of Buffer.from(text.replace(/\r\n/g, "\n"), "utf8")) {
    h ^= byte;
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h.toString(16).padStart(8, "0");
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full, out);
    else if (name.endsWith(".luau")) out.push(full);
  }
  return out;
}

function studioPath(file) {
  const parts = relative(srcRoot, file).split(sep);
  const last = parts.pop().replace(/\.(server|client)?\.?luau$/, "").replace(/\.luau$/, "");
  return [...parts, last].join(".");
}

const local = {};
for (const file of walk(srcRoot)) {
  local[studioPath(file)] = fnv1a(readFileSync(file, "utf8"));
}

const compareWith = process.argv[2];
if (!compareWith) {
  console.log(JSON.stringify(local, null, 2));
  process.exit(0);
}

const studio = JSON.parse(readFileSync(compareWith, "utf8"));
let drift = 0;
for (const [path, hash] of Object.entries(local)) {
  if (studio[path] !== hash) {
    drift++;
    console.log(`${studio[path] ? "DIFFERENT" : "MISSING IN STUDIO"}  ${path}`);
  }
}
for (const path of Object.keys(studio)) {
  if (!(path in local)) {
    drift++;
    console.log(`ONLY IN STUDIO  ${path}`);
  }
}
console.log(drift === 0 ? `In sync: ${Object.keys(local).length} scripts.` : `${drift} script(s) out of sync.`);
process.exit(drift === 0 ? 0 : 1);
