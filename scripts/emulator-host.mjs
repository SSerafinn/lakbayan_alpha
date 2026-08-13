// Work out which address a phone should use to reach the Emulator Suite.
//
//   node emulator-host.mjs           # print the address and the run command
//   node emulator-host.mjs --write   # also update config/local.json
//
// Why this exists: the app cannot discover the host it should talk to, so a
// physical device needs your PC's LAN IP passed in at build time. That address
// comes from DHCP and changes — after which `config/local.json` still holds
// yesterday's, the app points at an address nothing is listening on, and every
// list in the app renders empty with no error. That has happened here already.
//
// Picking the interface by hand is the part people get wrong: a dev machine
// typically has half a dozen, and WSL, Docker, VirtualBox and Hyper-V all add
// plausible-looking private addresses that a phone cannot reach. So this
// scores the candidates and then *proves* the choice by asking the emulator to
// answer on it.

import { readFileSync, writeFileSync } from "node:fs";
import { request } from "node:http";
import { networkInterfaces } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..");
const LOCAL_CONFIG = join(REPO, "config", "local.json");
const FIRESTORE_PORT = 8080;

const write = process.argv.includes("--write");

/**
 * Interface names that belong to a virtual adapter.
 *
 * Their addresses are real and reachable *from this machine*, which is why a
 * naive "first private IPv4" pick pointed the app at a WSL bridge more than
 * once. Nothing on your Wi-Fi can route to them.
 */
const VIRTUAL = /vethernet|wsl|virtualbox|vmware|hyper-v|docker|loopback|npcap|tailscale|zerotier/i;

/** Ranges handed out by virtual adapters far more often than by a home router. */
function looksVirtual(name, address) {
  if (VIRTUAL.test(name)) return true;
  if (address.startsWith("169.254.")) return true; // APIPA — no DHCP answered
  if (address.startsWith("192.168.56.")) return true; // VirtualBox host-only
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(address)) return true; // Docker / WSL
  return false;
}

function candidates() {
  const found = [];
  for (const [name, addresses] of Object.entries(networkInterfaces())) {
    for (const a of addresses ?? []) {
      if (a.family !== "IPv4" || a.internal) continue;
      found.push({
        name,
        address: a.address,
        virtual: looksVirtual(name, a.address),
        // Wi-Fi first: a phone being tested against a dev machine is almost
        // always on the same wireless network.
        score: /wi-?fi|wireless|wlan/i.test(name) ? 2 : 1,
      });
    }
  }
  return found.sort(
    (x, y) => Number(x.virtual) - Number(y.virtual) || y.score - x.score,
  );
}

/**
 * Does the Firestore emulator actually answer at this address?
 *
 * It has to be a real HTTP response, not just an open socket. **Docker Desktop
 * keeps a published port bound after its container stops** — `com.docker.backend`
 * goes on accepting connections on 8080 with nothing behind it — so a bare TCP
 * connect reports success against an address where the emulator is not running.
 * That is precisely the false positive this script exists to prevent, and it is
 * the normal state of a machine where someone ran `docker compose down`.
 *
 * `node:http` rather than `fetch`: undici keeps its sockets pooled after the
 * response, and exiting while they are still being torn down trips a libuv
 * assertion on Windows. Here the request is destroyed the moment headers land.
 */
function emulatorAnswers(address) {
  return new Promise((resolve) => {
    const req = request(
      { host: address, port: FIRESTORE_PORT, path: "/", timeout: 2000 },
      (res) => {
        res.destroy();
        req.destroy();
        resolve(true);
      },
    );
    const fail = () => {
      req.destroy();
      resolve(false);
    };
    req.once("timeout", fail);
    req.once("error", fail);
    req.end();
  });
}

const all = candidates();
if (all.length === 0) {
  console.error("No external IPv4 address found. Are you on a network?");
  process.exit(1);
}

const checked = [];
for (const c of all) {
  checked.push({ ...c, live: await emulatorAnswers(c.address) });
}

const pick = checked.find((c) => c.live && !c.virtual);

console.log("Interfaces:\n");
for (const c of checked) {
  const flags = [
    c.virtual ? "virtual" : null,
    c.live ? "emulator answers" : "no answer",
  ]
    .filter(Boolean)
    .join(", ");
  console.log(
    `  ${c === pick ? "->" : "  "} ${c.address.padEnd(16)} ${c.name.padEnd(34)} ${flags}`,
  );
}

if (!pick) {
  const anyLive = checked.some((c) => c.live);
  console.error(
    anyLive
      ? "\nThe emulator only answered on a virtual adapter, which a phone " +
          "cannot reach. Check that your PC and phone are on the same Wi-Fi."
      : "\nNothing answered on port " +
          FIRESTORE_PORT +
          ". Start the suite first:\n  docker compose up -d emulators",
  );
  process.exit(1);
}

console.log(`\nUse ${pick.address}\n`);
console.log("  flutter run --dart-define-from-file=config/dev.json \\");
console.log(`      --dart-define=FIREBASE_EMULATOR_HOST=${pick.address}\n`);
console.log(
  "If the phone still cannot reach it, the next suspect is Windows Firewall — " +
    `load http://${pick.address}:4000 in the phone's browser to check before ` +
    "touching any code.",
);

if (!write) {
  console.log("\nRe-run with --write to put this into config/local.json.");
  process.exit(0);
}

// --write updates the per-developer config in place, preserving every other
// key. config/local.json is gitignored, so this never touches shared config.
let config;
try {
  config = JSON.parse(readFileSync(LOCAL_CONFIG, "utf8"));
} catch (err) {
  if (err.code !== "ENOENT") {
    console.error(`\nCould not read config/local.json: ${err.message}`);
    process.exit(1);
  }
  console.log("\nNo config/local.json — creating it from config/dev.json.");
  config = JSON.parse(readFileSync(join(REPO, "config", "dev.json"), "utf8"));
}

const before = config.FIREBASE_EMULATOR_HOST;
config.FIREBASE_EMULATOR_HOST = pick.address;
writeFileSync(LOCAL_CONFIG, `${JSON.stringify(config, null, 2)}\n`, "utf8");

console.log(
  before === pick.address
    ? "\nconfig/local.json was already correct."
    : `\nconfig/local.json: FIREBASE_EMULATOR_HOST ${before || "(unset)"} -> ${pick.address}`,
);
console.log(
  "Dart-defines are compiled in, so restart the app — a hot reload will not " +
    "pick this up.",
);
