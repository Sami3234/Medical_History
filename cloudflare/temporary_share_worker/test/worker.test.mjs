import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

class MemoryR2 {
  constructor() {
    this.objects = new Map();
  }

  async put(key, body, options = {}) {
    const bytes = new Uint8Array(await new Response(body).arrayBuffer());
    this.objects.set(key, {
      bytes,
      customMetadata: options.customMetadata || {},
      httpMetadata: options.httpMetadata || {},
    });
  }

  async head(key) {
    const object = this.objects.get(key);
    if (!object) return null;
    return {
      customMetadata: object.customMetadata,
      httpMetadata: object.httpMetadata,
    };
  }

  async get(key) {
    const object = this.objects.get(key);
    if (!object) return null;
    return {
      body: object.bytes,
      customMetadata: object.customMetadata,
      httpMetadata: object.httpMetadata,
    };
  }

  async list({ prefix }) {
    return {
      objects: [...this.objects.keys()]
        .filter((key) => key.startsWith(prefix))
        .map((key) => ({ key })),
      truncated: false,
    };
  }

  async delete(keys) {
    for (const key of Array.isArray(keys) ? keys : [keys]) {
      this.objects.delete(key);
    }
  }
}

class MemoryKv {
  constructor() {
    this.values = new Map();
  }

  async get(key) {
    return this.values.get(key) ?? null;
  }

  async put(key, value) {
    this.values.set(key, value);
  }

  async delete(key) {
    this.values.delete(key);
  }
}

function request(path, { method, headers = {}, body } = {}) {
  return new Request("https://share.example.test" + path, {
    method,
    headers: {
      "cf-connecting-ip": "203.0.113.10",
      ...headers,
    },
    body,
  });
}

test("temporary share supports one-use OTP, document session, and revoke", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ id: "owner-1" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });

  const env = {
    TEMPORARY_SHARES: new MemoryR2(),
    RATE_LIMITS: new MemoryKv(),
    SUPABASE_URL: "https://project.supabase.co",
    SUPABASE_ANON_KEY: "public-anon-key",
    OTP_PEPPER: "test-only-pepper-with-enough-randomness",
    ALLOWED_ORIGIN: "",
  };
  const temporaryId = "ABCD-EFGH-2345";
  const otp = "123456";
  const revokeToken = "r".repeat(43);
  const fileToken = "A".repeat(24);
  const ownerHeaders = {
    authorization: "Bearer owner-session",
    "content-type": "application/octet-stream",
    "x-share-revoke-token": revokeToken,
  };

  try {
    const manifestBytes = new Uint8Array([1, 2, 3, 4]);
    const manifestUpload = await worker.fetch(
      request("/v1/shares/" + temporaryId + "/manifest", {
        method: "PUT",
        headers: {
          ...ownerHeaders,
          "content-length": String(manifestBytes.length),
          "x-share-otp": otp,
          "x-share-expires-in": "900",
        },
        body: manifestBytes,
      }),
      env,
    );
    assert.equal(manifestUpload.status, 201);

    const documentBytes = new Uint8Array([5, 6, 7, 8]);
    const documentUpload = await worker.fetch(
      request("/v1/shares/" + temporaryId + "/files/" + fileToken, {
        method: "PUT",
        headers: {
          ...ownerHeaders,
          "content-length": String(documentBytes.length),
        },
        body: documentBytes,
      }),
      env,
    );
    assert.equal(documentUpload.status, 201);

    const redeem = await worker.fetch(
      request("/v1/shares/" + temporaryId + "/redeem", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ otp }),
      }),
      env,
    );
    assert.equal(redeem.status, 200);
    assert.deepEqual(new Uint8Array(await redeem.arrayBuffer()), manifestBytes);
    const sessionToken = redeem.headers.get("x-share-session");
    assert.ok(sessionToken);

    const secondRedeem = await worker.fetch(
      request("/v1/shares/" + temporaryId + "/redeem", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ otp }),
      }),
      env,
    );
    assert.equal(secondRedeem.status, 409);

    const document = await worker.fetch(
      request(
        "/v1/shares/" + temporaryId + "/files/" + fileToken + "/redeem",
        {
          method: "POST",
          headers: { "x-share-session": sessionToken },
        },
      ),
      env,
    );
    assert.equal(document.status, 200);
    assert.deepEqual(new Uint8Array(await document.arrayBuffer()), documentBytes);

    const revoke = await worker.fetch(
      request("/v1/shares/" + temporaryId, {
        method: "DELETE",
        headers: ownerHeaders,
      }),
      env,
    );
    assert.equal(revoke.status, 200);

    const afterRevoke = await worker.fetch(
      request(
        "/v1/shares/" + temporaryId + "/files/" + fileToken + "/redeem",
        {
          method: "POST",
          headers: { "x-share-session": sessionToken },
        },
      ),
      env,
    );
    assert.equal(afterRevoke.status, 401);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
