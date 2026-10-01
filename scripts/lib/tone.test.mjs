import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { toneWav } from "./tone.mjs";

describe("toneWav", () => {
  const wav = toneWav({ seconds: 2, rate: 8000, hz: 440 });

  it("is a RIFF/WAVE file a player will recognise", () => {
    assert.equal(wav.toString("ascii", 0, 4), "RIFF");
    assert.equal(wav.toString("ascii", 8, 12), "WAVE");
    assert.equal(wav.toString("ascii", 12, 16), "fmt ");
    assert.equal(wav.toString("ascii", 36, 40), "data");
  });

  it("declares 16-bit mono PCM at the rate asked for", () => {
    assert.equal(wav.readUInt16LE(20), 1, "PCM");
    assert.equal(wav.readUInt16LE(22), 1, "mono");
    assert.equal(wav.readUInt32LE(24), 8000);
    assert.equal(wav.readUInt32LE(28), 16000, "bytes per second");
    assert.equal(wav.readUInt16LE(34), 16, "bits per sample");
  });

  it("has sizes that agree with each other and with the file", () => {
    // A header that claims more data than follows is what makes a player
    // refuse a file or stall at the end of it.
    const dataBytes = wav.readUInt32LE(40);
    assert.equal(dataBytes, 2 * 8000 * 2);
    assert.equal(wav.length, 44 + dataBytes);
    assert.equal(wav.readUInt32LE(4), wav.length - 8);
  });

  it("lasts as long as it says", () => {
    const seconds = wav.readUInt32LE(40) / wav.readUInt32LE(28);
    assert.equal(seconds, 2);
  });

  it("starts and ends on silence, so it does not click", () => {
    assert.equal(wav.readInt16LE(44), 0);
    assert.equal(wav.readInt16LE(wav.length - 2), 0);
  });

  it("is actually a tone in between, not silence", () => {
    let peak = 0;
    for (let i = 44; i < wav.length; i += 2) {
      peak = Math.max(peak, Math.abs(wav.readInt16LE(i)));
    }
    assert.ok(peak > 8000, `peak was ${peak}`);
    assert.ok(peak <= 9000, "and never clips past its amplitude");
  });

  it("copes with a clip too short to ramp", () => {
    const blip = toneWav({ seconds: 0.001, rate: 8000 });
    assert.equal(blip.length, 44 + blip.readUInt32LE(40));
  });
});
