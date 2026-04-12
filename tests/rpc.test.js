const assert = require("assert");

const BASE_URL = "http://localhost:12004";
let requestId = 0;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function rpc(method, params = {}) {
  const res = await fetch(`${BASE_URL}/rpc`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method,
      params,
      id: ++requestId,
    }),
  });
  return res.json();
}

function returnsResult(response) {
  assert.strictEqual(response.jsonrpc, "2.0");
  assert.ok(response.result !== undefined, "expected result, got error: " + JSON.stringify(response.error));
  return response.result;
}

function returnsError(response) {
  assert.strictEqual(response.jsonrpc, "2.0");
  assert.ok(response.error !== undefined, "expected error, got result");
  return response.error;
}

// ---------------------------------------------------------------------------
// device.info
// ---------------------------------------------------------------------------
describe("device.info", function () {
  it("returns screen size and scale", async function () {
    const result = returnsResult(await rpc("device.info"));
    assert.ok(result.screenSize);
    assert.ok(typeof result.screenSize.width === "number");
    assert.ok(typeof result.screenSize.height === "number");
    assert.ok(result.screenSize.width > 0);
    assert.ok(result.screenSize.height > 0);
    assert.ok(typeof result.scale === "number");
    assert.ok(result.scale > 0);
  });

  it("ignores extra params", async function () {
    const result = returnsResult(await rpc("device.info", { foo: "bar" }));
    assert.ok(result.screenSize);
  });
});

// ---------------------------------------------------------------------------
// device.apps.foreground
// ---------------------------------------------------------------------------
describe("device.apps.foreground", function () {
  it("returns foreground app info", async function () {
    const result = returnsResult(await rpc("device.apps.foreground"));
    assert.ok("bundleId" in result);
    assert.ok("name" in result);
    assert.ok("pid" in result);
  });
});

// ---------------------------------------------------------------------------
// device.apps.launch & device.apps.terminate
// ---------------------------------------------------------------------------
describe("device.apps.launch and device.apps.terminate", function () {
  it("fails to launch without bundleId", async function () {
    const error = returnsError(await rpc("device.apps.launch"));
    assert.ok(error.code);
  });

  it("fails to terminate without bundleId", async function () {
    const error = returnsError(await rpc("device.apps.terminate"));
    assert.ok(error.code);
  });

  it("terminating a non-running app returns terminated false", async function () {
    const result = returnsResult(await rpc("device.apps.terminate", {
      bundleId: "com.invalid.nonexistent",
    }));
    assert.strictEqual(result.terminated, false);
  });

  it("launch settings, verify foreground, terminate, verify springboard, terminate again returns false", async function () {
    returnsResult(await rpc("device.apps.launch", { bundleId: "com.apple.Preferences" }));
    await sleep(1000);

    const afterLaunch = returnsResult(await rpc("device.apps.foreground"));
    assert.strictEqual(afterLaunch.bundleId, "com.apple.Preferences");

    const first = returnsResult(await rpc("device.apps.terminate", { bundleId: "com.apple.Preferences" }));
    assert.strictEqual(first.terminated, true);
    await sleep(1000);

    const afterTerminate = returnsResult(await rpc("device.apps.foreground"));
    assert.strictEqual(afterTerminate.bundleId, "com.apple.springboard");

    const second = returnsResult(await rpc("device.apps.terminate", { bundleId: "com.apple.Preferences" }));
    assert.strictEqual(second.terminated, false);
  });
});

// ---------------------------------------------------------------------------
// device.io.tap
// ---------------------------------------------------------------------------
describe("device.io.tap", function () {
  it("taps at coordinates", async function () {
    const result = returnsResult(await rpc("device.io.tap", { x: 100, y: 100 }));
    assert.ok(result);
  });

  it("fails without coordinates", async function () {
    const error = returnsError(await rpc("device.io.tap"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.swipe
// ---------------------------------------------------------------------------
describe("device.io.swipe", function () {
  it("swipes between two points", async function () {
    const result = returnsResult(await rpc("device.io.swipe", {
      x1: 200, y1: 400, x2: 200, y2: 200,
    }));
    assert.ok(result);
  });

  it("fails without coordinates", async function () {
    const error = returnsError(await rpc("device.io.swipe"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.longpress
// ---------------------------------------------------------------------------
describe("device.io.longpress", function () {
  it("long presses at coordinates", async function () {
    const result = returnsResult(await rpc("device.io.longpress", {
      x: 100, y: 100, duration: 0.5,
    }));
    assert.ok(result);
  });

  it("fails without params", async function () {
    const error = returnsError(await rpc("device.io.longpress"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.gesture
// ---------------------------------------------------------------------------
describe("device.io.gesture", function () {
  it("performs a tap gesture via actions", async function () {
    const result = returnsResult(await rpc("device.io.gesture", {
      actions: [
        { type: "press", x: 150, y: 150, duration: 0, button: 0 },
        { type: "release", x: 150, y: 150, duration: 0.1, button: 0 },
      ],
    }));
    assert.ok(result);
  });

  it("fails without actions", async function () {
    const error = returnsError(await rpc("device.io.gesture"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.text
// ---------------------------------------------------------------------------
describe("device.io.text", function () {
  it("types text", async function () {
    const result = returnsResult(await rpc("device.io.text", { text: "hello" }));
    assert.ok(result);
  });

  it("fails without text", async function () {
    const error = returnsError(await rpc("device.io.text"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.button
// ---------------------------------------------------------------------------
describe("device.io.button", function () {
  it("pressing home returns to springboard", async function () {
    await rpc("device.apps.launch", { bundleId: "com.apple.Preferences" });
    await sleep(1000);
    const before = returnsResult(await rpc("device.apps.foreground"));
    assert.strictEqual(before.bundleId, "com.apple.Preferences");

    returnsResult(await rpc("device.io.button", { button: "home" }));
    await sleep(1000);

    const after = returnsResult(await rpc("device.apps.foreground"));
    assert.strictEqual(after.bundleId, "com.apple.springboard");
  });

  it("fails without button param", async function () {
    const error = returnsError(await rpc("device.io.button"));
    assert.ok(error.code);
  });

  it("fails with uppercase HOME", async function () {
    const error = returnsError(await rpc("device.io.button", { button: "HOME" }));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.io.orientation
// ---------------------------------------------------------------------------
describe("device.io.orientation", function () {
  it("sets orientation to landscape and back", async function () {
    returnsResult(await rpc("device.io.orientation.set", { orientation: "LANDSCAPE" }));
    const landscape = returnsResult(await rpc("device.io.orientation.get"));
    assert.strictEqual(landscape.orientation, "LANDSCAPE");

    returnsResult(await rpc("device.io.orientation.set", { orientation: "PORTRAIT" }));
    const portrait = returnsResult(await rpc("device.io.orientation.get"));
    assert.strictEqual(portrait.orientation, "PORTRAIT");
  });

  it("fails without orientation param", async function () {
    const error = returnsError(await rpc("device.io.orientation.set"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.screenshot
// ---------------------------------------------------------------------------
describe("device.screenshot", function () {
  it("captures a png screenshot", async function () {
    const result = returnsResult(await rpc("device.screenshot", { format: "png" }));
    assert.ok(typeof result.data === "string");
    assert.ok(result.data.length > 0);
  });

  it("captures a jpeg screenshot", async function () {
    const result = returnsResult(await rpc("device.screenshot", {
      format: "jpeg",
      quality: 50,
    }));
    assert.ok(typeof result.data === "string");
    assert.ok(result.data.length > 0);
  });

  it("fails without format", async function () {
    const error = returnsError(await rpc("device.screenshot"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// device.dump.ui
// ---------------------------------------------------------------------------
describe("device.dump.ui", function () {
  it("dumps the UI hierarchy", async function () {
    const result = returnsResult(await rpc("device.dump.ui"));
    assert.ok(result);
  });

  it("dumps the UI hierarchy as json", async function () {
    const result = returnsResult(await rpc("device.dump.ui", { format: "json" }));
    assert.ok(result);
  });
});

// ---------------------------------------------------------------------------
// device.url
// ---------------------------------------------------------------------------
describe("device.url", function () {
  it("opens an https url", async function () {
    const result = returnsResult(await rpc("device.url", {
      url: "https://www.apple.com",
    }));
    assert.ok(result);
  });

  it("fails without url param", async function () {
    const error = returnsError(await rpc("device.url"));
    assert.ok(error.code);
  });
});

// ---------------------------------------------------------------------------
// error handling
// ---------------------------------------------------------------------------
describe("error handling", function () {
  it("returns method not found for unknown method", async function () {
    const error = returnsError(await rpc("nonexistent.method"));
    assert.strictEqual(error.code, -32601);
  });
});

// ---------------------------------------------------------------------------
// health check
// ---------------------------------------------------------------------------
describe("GET /health", function () {
  it("returns OK", async function () {
    const res = await fetch(`${BASE_URL}/health`);
    assert.strictEqual(res.status, 200);
    const body = await res.text();
    assert.strictEqual(body, "OK");
  });
});

// ---------------------------------------------------------------------------
// teardown
// ---------------------------------------------------------------------------
after(async function () {
  await rpc("device.io.button", { button: "home" });
});
