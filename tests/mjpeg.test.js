const assert = require("assert");
const http = require("http");

const BASE_URL = "http://localhost:12004";
const BOUNDARY = "--mjpeg-frame-boundary";
const JPEG_SOI = Buffer.from([0xff, 0xd8]); // JPEG Start Of Image marker

/**
 * Connects to the MJPEG stream and collects data for `durationMs`,
 * then destroys the socket and returns the response + accumulated buffer.
 */
function collectStreamBytes(path, { durationMs = 2000 } = {}) {
  const url = `${BASE_URL}${path}`;
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      const chunks = [];
      let resolved = false;

      const finish = () => {
        if (resolved) return;
        resolved = true;
        req.destroy();
        resolve({ res, body: Buffer.concat(chunks) });
      };

      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", finish);
      res.on("error", (err) => {
        if (err.code === "ECONNRESET") return finish();
        if (!resolved) { resolved = true; reject(err); }
      });

      setTimeout(finish, durationMs);
    });

    req.on("error", (err) => {
      if (err.code === "ECONNRESET") return;
      reject(err);
    });
  });
}

/**
 * Parses MJPEG frames from a raw buffer.
 * Each frame starts with "--mjpeg-frame-boundary\r\n" followed by headers and JPEG data.
 */
function parseMjpegFrames(buffer) {
  const text = buffer.toString("binary");
  const frames = [];
  let searchStart = 0;

  while (true) {
    const boundaryIndex = text.indexOf(BOUNDARY, searchStart);
    if (boundaryIndex === -1) break;

    const headerStart = boundaryIndex + BOUNDARY.length + 2; // skip boundary + \r\n
    const headerEnd = text.indexOf("\r\n\r\n", headerStart);
    if (headerEnd === -1) break;

    const headerBlock = text.slice(headerStart, headerEnd);
    const headers = {};
    for (const line of headerBlock.split("\r\n")) {
      const colon = line.indexOf(":");
      if (colon !== -1) {
        headers[line.slice(0, colon).trim().toLowerCase()] = line.slice(colon + 1).trim();
      }
    }

    const contentLength = parseInt(headers["content-length"], 10);
    const jpegStart = headerEnd + 4; // skip \r\n\r\n
    const jpegEnd = jpegStart + contentLength;

    if (jpegEnd > text.length) break; // incomplete frame

    const jpegData = Buffer.from(text.slice(jpegStart, jpegEnd), "binary");
    frames.push({ headers, jpegData });

    searchStart = jpegEnd + 2; // skip trailing \r\n
  }

  return frames;
}

// ---------------------------------------------------------------------------
// GET /mjpeg
// ---------------------------------------------------------------------------
describe("GET /mjpeg", function () {
  this.timeout(15000);

  it("returns multipart content type with correct boundary", async function () {
    const { res } = await collectStreamBytes("/mjpeg");
    const contentType = res.headers["content-type"];
    assert.strictEqual(contentType, "multipart/x-mixed-replace; boundary=mjpeg-frame-boundary");
  });

  it("returns no-cache headers", async function () {
    const { res } = await collectStreamBytes("/mjpeg");
    assert.strictEqual(res.headers["cache-control"], "no-cache, no-store, must-revalidate");
    assert.strictEqual(res.headers["pragma"], "no-cache");
    assert.strictEqual(res.headers["expires"], "0");
  });

  it("returns server header", async function () {
    const { res } = await collectStreamBytes("/mjpeg");
    assert.strictEqual(res.headers["server"], "DeviceKit-iOS");
  });

  it("streams valid MJPEG frames", async function () {
    const { body } = await collectStreamBytes("/mjpeg");
    const frames = parseMjpegFrames(body);

    assert.ok(frames.length >= 1, `expected at least 1 frame, got ${frames.length}`);

    for (const frame of frames) {
      assert.strictEqual(frame.headers["content-type"], "image/jpeg");
      assert.ok(frame.headers["content-length"], "frame missing Content-Length");
      assert.strictEqual(frame.jpegData.length, parseInt(frame.headers["content-length"], 10));
    }
  });

  it("each frame contains valid JPEG data", async function () {
    const { body } = await collectStreamBytes("/mjpeg");
    const frames = parseMjpegFrames(body);

    assert.ok(frames.length >= 1, "no frames received");

    for (const frame of frames) {
      const startsWithJpegMagic = frame.jpegData[0] === JPEG_SOI[0] && frame.jpegData[1] === JPEG_SOI[1];
      assert.ok(startsWithJpegMagic, "frame data does not start with JPEG SOI marker (0xFF 0xD8)");
      assert.ok(frame.jpegData.length > 100, "JPEG data suspiciously small");
    }
  });

  it("streams multiple frames over time", async function () {
    const { body } = await collectStreamBytes("/mjpeg");
    const frames = parseMjpegFrames(body);
    assert.ok(frames.length >= 2, `expected at least 2 frames, got ${frames.length}`);
  });

  it("accepts custom fps parameter", async function () {
    const { res, body } = await collectStreamBytes("/mjpeg?fps=1", { durationMs: 3000 });
    assert.strictEqual(res.statusCode, 200);
    const frames = parseMjpegFrames(body);
    assert.ok(frames.length >= 1, "no frames received with fps=1");
  });

  it("accepts custom quality parameter", async function () {
    const { body: lowQ } = await collectStreamBytes("/mjpeg?quality=1");
    const { body: highQ } = await collectStreamBytes("/mjpeg?quality=100");

    const lowFrames = parseMjpegFrames(lowQ);
    const highFrames = parseMjpegFrames(highQ);

    assert.ok(lowFrames.length >= 1, "no frames at quality=1");
    assert.ok(highFrames.length >= 1, "no frames at quality=100");

    // Higher quality should produce larger JPEG data on average
    const avgLow = lowFrames.reduce((sum, f) => sum + f.jpegData.length, 0) / lowFrames.length;
    const avgHigh = highFrames.reduce((sum, f) => sum + f.jpegData.length, 0) / highFrames.length;
    assert.ok(avgHigh > avgLow, `expected quality=100 (avg ${avgHigh}B) to produce larger frames than quality=1 (avg ${avgLow}B)`);
  });

  it("accepts custom scale parameter", async function () {
    const { body: fullScale } = await collectStreamBytes("/mjpeg?scale=100");
    const { body: halfScale } = await collectStreamBytes("/mjpeg?scale=50");

    const fullFrames = parseMjpegFrames(fullScale);
    const halfFrames = parseMjpegFrames(halfScale);

    assert.ok(fullFrames.length >= 1, "no frames at scale=100");
    assert.ok(halfFrames.length >= 1, "no frames at scale=50");

    // Smaller scale should produce smaller JPEG data on average
    const avgFull = fullFrames.reduce((sum, f) => sum + f.jpegData.length, 0) / fullFrames.length;
    const avgHalf = halfFrames.reduce((sum, f) => sum + f.jpegData.length, 0) / halfFrames.length;
    assert.ok(avgFull > avgHalf, `expected scale=100 (avg ${avgFull}B) to produce larger frames than scale=50 (avg ${avgHalf}B)`);
  });

  it("clamps out-of-range fps values", async function () {
    // fps=0 should be clamped to 1, fps=999 should be clamped to 60 — both should still stream
    const { res: lowRes } = await collectStreamBytes("/mjpeg?fps=0");
    assert.strictEqual(lowRes.statusCode, 200);

    const { res: highRes } = await collectStreamBytes("/mjpeg?fps=999");
    assert.strictEqual(highRes.statusCode, 200);
  });

  it("clamps out-of-range quality values", async function () {
    const { res: lowRes } = await collectStreamBytes("/mjpeg?quality=0");
    assert.strictEqual(lowRes.statusCode, 200);

    const { res: highRes } = await collectStreamBytes("/mjpeg?quality=999");
    assert.strictEqual(highRes.statusCode, 200);
  });

  it("clamps out-of-range scale values", async function () {
    const { res: lowRes } = await collectStreamBytes("/mjpeg?scale=0");
    assert.strictEqual(lowRes.statusCode, 200);

    const { res: highRes } = await collectStreamBytes("/mjpeg?scale=999");
    assert.strictEqual(highRes.statusCode, 200);
  });
});
