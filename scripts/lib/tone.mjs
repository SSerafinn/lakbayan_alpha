// A short tone as a WAV file, so the emulator can hold a *recorded* narration
// without a recording being committed to the repo.
//
// The seeded stops otherwise carry only `ttsText`, which the phone reads aloud
// itself. That exercises none of what a recording does: the Storage path, the
// download, the file on disk, the scrubber. A few seconds of sine wave is
// enough to send a real audio file down every one of those paths — and when
// it plays with the network off, it is unmistakably a file and not the
// device's own voice.
//
// Pure, so it can be tested without an emulator.

/**
 * 16-bit mono PCM in a canonical 44-byte RIFF/WAVE header.
 *
 * @param {object} [options]
 * @param {number} [options.seconds] Length. Whole or fractional.
 * @param {number} [options.rate] Samples per second.
 * @param {number} [options.hz] Pitch.
 * @returns {Buffer}
 */
export function toneWav({ seconds = 3, rate = 16000, hz = 440 } = {}) {
  const samples = Math.round(seconds * rate);
  const data = Buffer.alloc(samples * 2);
  // A short ramp at each end. Without it the tone starts and stops mid-wave,
  // which a speaker renders as a click.
  const ramp = Math.min(Math.round(rate * 0.05), Math.floor(samples / 2));

  for (let i = 0; i < samples; i++) {
    const edge = ramp === 0 ? 1 : Math.min(1, i / ramp, (samples - 1 - i) / ramp);
    const value = Math.sin((2 * Math.PI * hz * i) / rate) * 9000 * edge;
    data.writeInt16LE(Math.round(value), i * 2);
  }

  const header = Buffer.alloc(44);
  header.write("RIFF", 0, "ascii");
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8, "ascii");
  header.write("fmt ", 12, "ascii");
  header.writeUInt32LE(16, 16); // fmt chunk size
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28); // bytes per second
  header.writeUInt16LE(2, 32); // bytes per sample frame
  header.writeUInt16LE(16, 34); // bits per sample
  header.write("data", 36, "ascii");
  header.writeUInt32LE(data.length, 40);

  return Buffer.concat([header, data]);
}
