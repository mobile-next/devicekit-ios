import {
  test,
  expect,
  request as playwrightRequest,
  type APIRequestContext,
} from "@playwright/test";

const BASE_URL = "http://localhost:12004";

type RpcError = { code: number; message?: string };
type RpcResponse = {
  jsonrpc: string;
  id: number;
  result?: any;
  error?: RpcError;
};

let requestId = 0;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function rpc(
  request: APIRequestContext,
  method: string,
  params: Record<string, any> = {},
): Promise<RpcResponse> {
  const res = await request.post(`${BASE_URL}/rpc`, {
    headers: { "Content-Type": "application/json" },
    data: {
      jsonrpc: "2.0",
      method,
      params,
      id: ++requestId,
    },
  });
  return (await res.json()) as RpcResponse;
}

function returnsResult(response: RpcResponse): any {
  expect(response.jsonrpc).toBe("2.0");
  expect(
    response.result,
    "expected result, got error: " + JSON.stringify(response.error),
  ).toBeDefined();
  return response.result;
}

function returnsError(response: RpcResponse): RpcError {
  expect(response.jsonrpc).toBe("2.0");
  expect(response.error, "expected error, got result").toBeDefined();
  return response.error!;
}

// ---------------------------------------------------------------------------
// device.info
// ---------------------------------------------------------------------------
test.describe("device.info", () => {
  test("returns screen size and scale", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.info"));
    expect(result.screenSize).toBeTruthy();
    expect(typeof result.screenSize.width).toBe("number");
    expect(typeof result.screenSize.height).toBe("number");
    expect(result.screenSize.width).toBeGreaterThan(0);
    expect(result.screenSize.height).toBeGreaterThan(0);
    expect(typeof result.scale).toBe("number");
    expect(result.scale).toBeGreaterThan(0);
  });

  test("ignores extra params", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.info", { foo: "bar" }));
    expect(result.screenSize).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.apps.foreground
// ---------------------------------------------------------------------------
test.describe("device.apps.foreground", () => {
  test("returns foreground app info", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.apps.foreground"));
    expect(result).toHaveProperty("bundleId");
    expect(result).toHaveProperty("name");
    expect(result).toHaveProperty("pid");
  });
});

// ---------------------------------------------------------------------------
// device.apps.launch & device.apps.terminate
// ---------------------------------------------------------------------------
test.describe("device.apps.launch and device.apps.terminate", () => {
  test("fails to launch without bundleId", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.apps.launch"));
    expect(error.code).toBeTruthy();
  });

  test("fails to terminate without bundleId", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.apps.terminate"));
    expect(error.code).toBeTruthy();
  });

  test("terminating a non-running app returns terminated false", async ({ request }) => {
    const result = returnsResult(
      await rpc(request, "device.apps.terminate", { bundleId: "com.invalid.nonexistent" }),
    );
    expect(result.terminated).toBe(false);
  });

  test("launch settings, verify foreground, terminate, verify springboard, terminate again returns false", async ({ request }) => {
    returnsResult(await rpc(request, "device.apps.launch", { bundleId: "com.apple.Preferences" }));
    await sleep(1000);

    const afterLaunch = returnsResult(await rpc(request, "device.apps.foreground"));
    expect(afterLaunch.bundleId).toBe("com.apple.Preferences");

    const first = returnsResult(await rpc(request, "device.apps.terminate", { bundleId: "com.apple.Preferences" }));
    expect(first.terminated).toBe(true);
    await sleep(1000);

    const afterTerminate = returnsResult(await rpc(request, "device.apps.foreground"));
    expect(afterTerminate.bundleId).toBe("com.apple.springboard");

    const second = returnsResult(await rpc(request, "device.apps.terminate", { bundleId: "com.apple.Preferences" }));
    expect(second.terminated).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// device.io.tap
// ---------------------------------------------------------------------------
test.describe("device.io.tap", () => {
  test("taps at coordinates", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.io.tap", { x: 100, y: 100 }));
    expect(result).toBeTruthy();
  });

  test("fails without coordinates", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.tap"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.swipe
// ---------------------------------------------------------------------------
test.describe("device.io.swipe", () => {
  test("swipes between two points", async ({ request }) => {
    const result = returnsResult(
      await rpc(request, "device.io.swipe", { x1: 200, y1: 400, x2: 200, y2: 200 }),
    );
    expect(result).toBeTruthy();
  });

  test("swipes over an explicit duration", async ({ request }) => {
    const started = Date.now();
    const result = returnsResult(
      await rpc(request, "device.io.swipe", {
        x1: 200,
        y1: 400,
        x2: 200,
        y2: 200,
        duration: 1.5,
      }),
    );
    expect(result).toBeTruthy();
    expect(Date.now() - started).toBeGreaterThanOrEqual(1400);
  });

  test("fails without coordinates", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.swipe"));
    expect(error.code).toBeTruthy();
  });

  test("rejects a negative duration", async ({ request }) => {
    const error = returnsError(
      await rpc(request, "device.io.swipe", {
        x1: 200,
        y1: 400,
        x2: 200,
        y2: 200,
        duration: -1,
      }),
    );
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.longpress
// ---------------------------------------------------------------------------
test.describe("device.io.longpress", () => {
  test("long presses at coordinates", async ({ request }) => {
    const result = returnsResult(
      await rpc(request, "device.io.longpress", { x: 100, y: 100, duration: 0.5 }),
    );
    expect(result).toBeTruthy();
  });

  test("fails without params", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.longpress"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.gesture
// ---------------------------------------------------------------------------
test.describe("device.io.gesture", () => {
  test("performs a tap gesture via actions", async ({ request }) => {
    const result = returnsResult(
      await rpc(request, "device.io.gesture", {
        actions: [
          { type: "press", x: 150, y: 150, duration: 0, button: 0 },
          { type: "release", x: 150, y: 150, duration: 0.1, button: 0 },
        ],
      }),
    );
    expect(result).toBeTruthy();
  });

  test("fails without actions", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.gesture"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.text
// ---------------------------------------------------------------------------
test.describe("device.io.text", () => {
  test("types text", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.io.text", { text: "hello" }));
    expect(result).toBeTruthy();
  });

  test("fails without text", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.text"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.button
// ---------------------------------------------------------------------------
test.describe("device.io.button", () => {
  test("pressing home returns to springboard", async ({ request }) => {
    await rpc(request, "device.apps.launch", { bundleId: "com.apple.Preferences" });
    await sleep(1000);
    const before = returnsResult(await rpc(request, "device.apps.foreground"));
    expect(before.bundleId).toBe("com.apple.Preferences");

    returnsResult(await rpc(request, "device.io.button", { button: "home" }));
    await sleep(1000);

    const after = returnsResult(await rpc(request, "device.apps.foreground"));
    expect(after.bundleId).toBe("com.apple.springboard");
  });

  test("fails without button param", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.button"));
    expect(error.code).toBeTruthy();
  });

  test("fails with uppercase HOME", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.button", { button: "HOME" }));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.io.orientation
// ---------------------------------------------------------------------------
test.describe("device.io.orientation", () => {
  test("sets orientation to landscape and back", async ({ request }) => {
    returnsResult(await rpc(request, "device.io.orientation.set", { orientation: "LANDSCAPE" }));
    const landscape = returnsResult(await rpc(request, "device.io.orientation.get"));
    expect(landscape.orientation).toBe("LANDSCAPE");

    returnsResult(await rpc(request, "device.io.orientation.set", { orientation: "PORTRAIT" }));
    const portrait = returnsResult(await rpc(request, "device.io.orientation.get"));
    expect(portrait.orientation).toBe("PORTRAIT");
  });

  test("fails without orientation param", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.io.orientation.set"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.screenshot
// ---------------------------------------------------------------------------
test.describe("device.screenshot", () => {
  test("captures a png screenshot", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.screenshot", { format: "png" }));
    expect(typeof result.data).toBe("string");
    expect(result.data.length).toBeGreaterThan(0);
  });

  test("captures a jpeg screenshot", async ({ request }) => {
    const result = returnsResult(
      await rpc(request, "device.screenshot", { format: "jpeg", quality: 50 }),
    );
    expect(typeof result.data).toBe("string");
    expect(result.data.length).toBeGreaterThan(0);
  });

  test("fails without format", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.screenshot"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.dump.ui
// ---------------------------------------------------------------------------
test.describe("device.dump.ui", () => {
  test("dumps the UI hierarchy without params", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.dump.ui"));
    expect(result).toBeTruthy();
  });

  test("returns source tree format for json", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.dump.ui", { format: "json" }));
    expect(typeof result.type, "expected type to be a string").toBe("string");
    expect(result.rect, "expected rect").toBeTruthy();
    expect(typeof result.rect.x, "expected rect.x").toBe("number");
    expect(typeof result.rect.y, "expected rect.y").toBe("number");
    expect(typeof result.rect.width, "expected rect.width").toBe("number");
    expect(typeof result.rect.height, "expected rect.height").toBe("number");
    expect("elementType" in result, "should not have elementType").toBe(false);
    expect("frame" in result, "should not have frame").toBe(false);
    expect("isVisible" in result, "should not have isVisible").toBe(false);
  });

  test("json children follow the same source tree format", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.dump.ui", { format: "json" }));
    expect(Array.isArray(result.children), "expected children array").toBe(true);
    expect(result.children.length, "expected at least one child").toBeGreaterThan(0);
    const child = result.children[0];
    expect(typeof child.type, "child should have string type").toBe("string");
    expect(child.rect, "child should have rect").toBeTruthy();
    expect(typeof child.rect.x, "child rect.x should be number").toBe("number");
  });

  test("dumps the UI hierarchy as raw", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.dump.ui", { format: "raw" }));
    expect(typeof result.elementType, "raw format should have numeric elementType").toBe("number");
    expect(result.frame, "raw format should have frame").toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// device.url
// ---------------------------------------------------------------------------
test.describe("device.url", () => {
  test("opens an https url", async ({ request }) => {
    const result = returnsResult(await rpc(request, "device.url", { url: "https://www.apple.com" }));
    expect(result).toBeTruthy();
  });

  test("fails without url param", async ({ request }) => {
    const error = returnsError(await rpc(request, "device.url"));
    expect(error.code).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// error handling
// ---------------------------------------------------------------------------
test.describe("error handling", () => {
  test("returns method not found for unknown method", async ({ request }) => {
    const error = returnsError(await rpc(request, "nonexistent.method"));
    expect(error.code).toBe(-32601);
  });
});

// ---------------------------------------------------------------------------
// health check
// ---------------------------------------------------------------------------
test.describe("GET /health", () => {
  test("returns OK", async ({ request }) => {
    const res = await request.get(`${BASE_URL}/health`);
    expect(res.status()).toBe(200);
    const body = await res.text();
    expect(body).toBe("OK");
  });
});

// ---------------------------------------------------------------------------
// teardown
// ---------------------------------------------------------------------------
test.afterAll(async () => {
  const context = await playwrightRequest.newContext();
  await rpc(context, "device.io.button", { button: "home" });
  await context.dispose();
});
