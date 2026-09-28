// Does the renderer load and draw anything at all?
//
// Separate from rasterise.mjs on purpose. MapLibre Native is a compiled
// OpenGL renderer behind a .node binary, and when its runtime libraries are
// missing it fails at *import* with a bare "cannot open shared object file".
// Running this first tells you whether the image is wrong or your arguments
// are, which are very different problems.
//
//   docker compose --profile tiles run --rm tiles npm run smoke

import { writeFile } from "node:fs/promises";

import mbgl from "@maplibre/maplibre-gl-native";
import { PNG } from "pngjs";

console.log("renderer loaded:", typeof mbgl.Map === "function");

// A style with no sources: nothing to fetch, so this isolates the renderer
// from the network and from PMTiles entirely.
const style = {
  version: 8,
  sources: {},
  layers: [
    {
      id: "background",
      type: "background",
      paint: { "background-color": "#8ec7a0" },
    },
  ],
};

const map = new mbgl.Map({
  ratio: 1,
  request: (_req, callback) => callback(new Error("no sources expected")),
});
map.load(style);

const size = 256;
const buffer = await new Promise((resolve, reject) => {
  map.render(
    { zoom: 4, width: size, height: size, center: [121.7, 17.6] },
    (err, buf) => (err ? reject(err) : resolve(buf)),
  );
});
map.release();

// The buffer is raw RGBA. Prove it is the right size and not simply zeroed —
// an all-black image is what a half-initialised GL context produces, and it is
// indistinguishable from success if you only check the length.
const expected = size * size * 4;
if (buffer.length !== expected) {
  throw new Error(`expected ${expected} bytes of RGBA, got ${buffer.length}`);
}
const [r, g, b] = buffer;
console.log(`first pixel rgb(${r}, ${g}, ${b}) — expected about (142, 199, 160)`);
if (r === 0 && g === 0 && b === 0) {
  throw new Error(
    "rendered black. The GL context is not drawing; check the image's " +
      "libegl1 / libgles2 / libgbm1 packages.",
  );
}

const png = new PNG({ width: size, height: size });
buffer.copy(png.data);
await writeFile("/app/out/smoke.png", PNG.sync.write(png));
console.log("wrote /app/out/smoke.png");
