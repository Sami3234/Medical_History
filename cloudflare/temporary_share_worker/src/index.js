const MAX_SHARE_SECONDS = 15 * 60;
const MAX_MANIFEST_BYTES = 2 * 1024 * 1024;
const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024;
const MAX_FAILED_ATTEMPTS = 5;
const LOCK_SECONDS = 15 * 60;
const ID_PATTERN = /^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/;
const FILE_TOKEN_PATTERN = /^[A-Za-z0-9_-]{20,32}$/;

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders(request, env) });
      }

      const url = new URL(request.url);
      const parts = url.pathname.split("/").filter(Boolean);
      if (parts[0] !== "v1" || parts[1] !== "shares") {
        return jsonError("Not found.", 404, request, env);
      }

      const temporaryId = (parts[2] || "").toUpperCase();
      if (!ID_PATTERN.test(temporaryId)) {
        return jsonError("The temporary access details are invalid.", 401, request, env);
      }

      if (request.method === "PUT" && parts[3] === "manifest" && parts.length === 4) {
        return uploadManifest(request, env, temporaryId);
      }
      if (
        request.method === "PUT" &&
        parts[3] === "files" &&
        parts.length === 5 &&
        FILE_TOKEN_PATTERN.test(parts[4])
      ) {
        return uploadFile(request, env, temporaryId, parts[4]);
      }
      if (request.method === "POST" && parts[3] === "redeem" && parts.length === 4) {
        return redeemManifest(request, env, temporaryId);
      }
      if (
        request.method === "POST" &&
        parts[3] === "files" &&
        parts[5] === "redeem" &&
        parts.length === 6 &&
        FILE_TOKEN_PATTERN.test(parts[4])
      ) {
        return redeemFile(request, env, temporaryId, parts[4]);
      }
      if (request.method === "DELETE" && parts.length === 3) {
        return revokeShare(request, env, temporaryId);
      }
      return jsonError("Not found.", 404, request, env);
    } catch {
      return jsonError("Unable to complete the request.", 500, request, env);
    }
  },
};

async function uploadManifest(request, env, temporaryId) {
  const user = await authenticateOwner(request, env);
  if (!user) return jsonError("Please sign in again and retry.", 401, request, env);

  const otp = request.headers.get("x-share-otp") || "";
  const revokeToken = request.headers.get("x-share-revoke-token") || "";
  const requestedLifetime = Number(request.headers.get("x-share-expires-in") || 0);
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (
    !/^\d{6}$/.test(otp) ||
    revokeToken.length < 32 ||
    requestedLifetime < 60 ||
    requestedLifetime > MAX_SHARE_SECONDS ||
    contentLength < 1 ||
    contentLength > MAX_MANIFEST_BYTES
  ) {
    return jsonError("The temporary share request is invalid.", 400, request, env);
  }

  const manifestKey = manifestObjectKey(temporaryId);
  if (await env.TEMPORARY_SHARES.head(manifestKey)) {
    return jsonError("Please generate a new temporary ID.", 409, request, env);
  }

  const expiresAt = Date.now() + requestedLifetime * 1000;
  const otpHash = await secretHash(env.OTP_PEPPER, temporaryId + ":" + otp);
  const revokeHash = await secretHash(env.OTP_PEPPER, temporaryId + ":" + revokeToken);
  await env.TEMPORARY_SHARES.put(manifestKey, request.body, {
    httpMetadata: {
      contentType: "application/octet-stream",
      cacheControl: "no-store, private",
    },
    customMetadata: {
      ownerId: user.id,
      otpHash,
      revokeHash,
      expiresAt: String(expiresAt),
    },
  });

  return jsonResponse({ ok: true, expiresAt }, 201, request, env);
}

async function uploadFile(request, env, temporaryId, fileToken) {
  const user = await authenticateOwner(request, env);
  if (!user) return jsonError("Please sign in again and retry.", 401, request, env);

  const manifest = await env.TEMPORARY_SHARES.head(manifestObjectKey(temporaryId));
  if (!manifest || isExpired(manifest)) {
    return jsonError("Temporary access is unavailable.", 410, request, env);
  }

  const revokeToken = request.headers.get("x-share-revoke-token") || "";
  const revokeHash = await secretHash(env.OTP_PEPPER, temporaryId + ":" + revokeToken);
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (
    manifest.customMetadata?.ownerId !== user.id ||
    !safeEqual(manifest.customMetadata?.revokeHash || "", revokeHash) ||
    contentLength < 1 ||
    contentLength > MAX_DOCUMENT_BYTES + 64
  ) {
    return jsonError("The file could not be added.", 403, request, env);
  }

  await env.TEMPORARY_SHARES.put(
    fileObjectKey(temporaryId, fileToken),
    request.body,
    {
      httpMetadata: {
        contentType: "application/octet-stream",
        cacheControl: "no-store, private",
      },
      customMetadata: {
        expiresAt: manifest.customMetadata.expiresAt,
      },
    },
  );
  return jsonResponse({ ok: true }, 201, request, env);
}

async function redeemManifest(request, env, temporaryId) {
  const access = await verifyOtp(request, env, temporaryId);
  if (!access.ok) return access.response;

  const object = await env.TEMPORARY_SHARES.get(manifestObjectKey(temporaryId));
  if (!object) {
    return jsonError("The temporary ID or passcode is invalid or expired.", 401, request, env);
  }

  const sessionToken = await createSessionToken(
    env,
    temporaryId,
    access.expiresAt,
  );
  const remainingSeconds = Math.max(
    60,
    Math.ceil((access.expiresAt - Date.now()) / 1000),
  );
  await env.RATE_LIMITS.put(sessionKey(temporaryId), "used", {
    expirationTtl: remainingSeconds,
  });
  return encryptedResponse(object.body, request, env, {
    "x-share-session": sessionToken,
  });
}

async function redeemFile(request, env, temporaryId, fileToken) {
  const access = await verifySession(request, env, temporaryId);
  if (!access.ok) return access.response;

  const object = await env.TEMPORARY_SHARES.get(
    fileObjectKey(temporaryId, fileToken),
  );
  if (!object) {
    return jsonError("This document is unavailable.", 404, request, env);
  }
  return encryptedResponse(object.body, request, env);
}

async function verifyOtp(request, env, temporaryId) {
  if (await env.RATE_LIMITS.get(sessionKey(temporaryId))) {
    return {
      ok: false,
      response: jsonError(
        "This one-time passcode has already been used.",
        409,
        request,
        env,
      ),
    };
  }
  const attemptKey = await rateLimitKey(request, temporaryId);
  const globalAttemptKey = "attempt:global:" + temporaryId;
  const failedAttempts = Number((await env.RATE_LIMITS.get(attemptKey)) || 0);
  const globalFailedAttempts = Number(
    (await env.RATE_LIMITS.get(globalAttemptKey)) || 0,
  );
  if (failedAttempts >= MAX_FAILED_ATTEMPTS || globalFailedAttempts >= 30) {
    return {
      ok: false,
      response: jsonError(
        "Too many attempts. Try again after 15 minutes.",
        429,
        request,
        env,
      ),
    };
  }

  const manifest = await env.TEMPORARY_SHARES.head(manifestObjectKey(temporaryId));
  if (!manifest || isExpired(manifest)) {
    if (manifest) await deleteShareObjects(env, temporaryId);
    await Promise.all([
      registerFailure(env, attemptKey, failedAttempts),
      registerFailure(env, globalAttemptKey, globalFailedAttempts),
    ]);
    return {
      ok: false,
      response: jsonError(
        "The temporary ID or passcode is invalid or expired.",
        401,
        request,
        env,
      ),
    };
  }

  const body = await readSmallJson(request);
  const otp = typeof body?.otp === "string" ? body.otp : "";
  const suppliedHash = await secretHash(env.OTP_PEPPER, temporaryId + ":" + otp);
  if (!/^\d{6}$/.test(otp) ||
      !safeEqual(manifest.customMetadata?.otpHash || "", suppliedHash)) {
    await Promise.all([
      registerFailure(env, attemptKey, failedAttempts),
      registerFailure(env, globalAttemptKey, globalFailedAttempts),
    ]);
    return {
      ok: false,
      response: jsonError(
        "The temporary ID or passcode is invalid or expired.",
        401,
        request,
        env,
      ),
    };
  }

  await Promise.all([
    env.RATE_LIMITS.delete(attemptKey),
    env.RATE_LIMITS.delete(globalAttemptKey),
  ]);
  return {
    ok: true,
    expiresAt: Number(manifest.customMetadata.expiresAt),
  };
}

async function verifySession(request, env, temporaryId) {
  const manifest = await env.TEMPORARY_SHARES.head(manifestObjectKey(temporaryId));
  if (!manifest || isExpired(manifest)) {
    if (manifest) await deleteShareObjects(env, temporaryId);
    return {
      ok: false,
      response: jsonError("Temporary access has expired.", 401, request, env),
    };
  }

  const sessionToken = request.headers.get("x-share-session") || "";
  if (!(await isSessionTokenValid(
    env,
    temporaryId,
    sessionToken,
    Number(manifest.customMetadata.expiresAt),
  ))) {
    return {
      ok: false,
      response: jsonError(
        "Temporary access is invalid or expired.",
        401,
        request,
        env,
      ),
    };
  }
  return { ok: true };
}
async function revokeShare(request, env, temporaryId) {
  const user = await authenticateOwner(request, env);
  if (!user) return jsonError("Please sign in again and retry.", 401, request, env);

  const manifest = await env.TEMPORARY_SHARES.head(manifestObjectKey(temporaryId));
  if (!manifest) return jsonResponse({ ok: true }, 200, request, env);

  const revokeToken = request.headers.get("x-share-revoke-token") || "";
  const suppliedHash = await secretHash(
    env.OTP_PEPPER,
    temporaryId + ":" + revokeToken,
  );
  if (
    manifest.customMetadata?.ownerId !== user.id ||
    !safeEqual(manifest.customMetadata?.revokeHash || "", suppliedHash)
  ) {
    return jsonError("Access could not be stopped.", 403, request, env);
  }

  await deleteShareObjects(env, temporaryId);
  return jsonResponse({ ok: true }, 200, request, env);
}

async function authenticateOwner(request, env) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) return null;
  const response = await fetch(env.SUPABASE_URL + "/auth/v1/user", {
    headers: {
      authorization,
      apikey: env.SUPABASE_ANON_KEY,
    },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user : null;
}

async function deleteShareObjects(env, temporaryId) {
  const prefix = "shares/" + temporaryId + "/";
  let cursor;
  do {
    const page = await env.TEMPORARY_SHARES.list({ prefix, cursor, limit: 1000 });
    if (page.objects.length) {
      await env.TEMPORARY_SHARES.delete(page.objects.map((item) => item.key));
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
}

async function rateLimitKey(request, temporaryId) {
  const address = request.headers.get("cf-connecting-ip") || "unknown";
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(temporaryId + ":" + address),
  );
  return "attempt:" + toHex(new Uint8Array(digest));
}

async function registerFailure(env, key, current) {
  await env.RATE_LIMITS.put(key, String(current + 1), {
    expirationTtl: LOCK_SECONDS,
  });
}

async function secretHash(secret, value) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(signature));
}

function safeEqual(left, right) {
  if (left.length !== right.length || left.length === 0) return false;
  let result = 0;
  for (let index = 0; index < left.length; index++) {
    result |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return result === 0;
}

async function readSmallJson(request) {
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > 1024) return null;
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function isExpired(object) {
  const expiresAt = Number(object.customMetadata?.expiresAt || 0);
  return !expiresAt || expiresAt <= Date.now();
}

function manifestObjectKey(temporaryId) {
  return "shares/" + temporaryId + "/manifest.enc";
}

function fileObjectKey(temporaryId, fileToken) {
  return "shares/" + temporaryId + "/files/" + fileToken + ".enc";
}

function encryptedResponse(body, request, env, extraHeaders = {}) {
  return new Response(body, {
    status: 200,
    headers: {
            ...extraHeaders,
...corsHeaders(request, env),
      "content-type": "application/octet-stream",
      "cache-control": "no-store, private",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
}

function jsonResponse(data, status, request, env) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(request, env),
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store, private",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
}

function jsonError(message, status, request, env) {
  return jsonResponse({ message }, status, request, env);
}

function corsHeaders(request, env) {
  const origin = request.headers.get("origin");
  const allowed = env.ALLOWED_ORIGIN || "";
  const headers = {
    "access-control-allow-methods": "PUT, POST, DELETE, OPTIONS",
    "access-control-allow-headers":
      "authorization, content-type, x-share-otp, x-share-revoke-token, x-share-expires-in, x-share-session",
    "access-control-max-age": "600",
    "access-control-expose-headers": "x-share-session",
  };
  if (origin && allowed && origin === allowed) {
    headers["access-control-allow-origin"] = origin;
    headers.vary = "Origin";
  }
  return headers;
}

async function createSessionToken(env, temporaryId, expiresAt) {
  const payload = base64UrlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        temporaryId,
        expiresAt,
        nonce: randomToken(),
      }),
    ),
  );
  const signature = await secretHash(env.OTP_PEPPER, "session:" + payload);
  return payload + "." + signature;
}

async function isSessionTokenValid(env, temporaryId, token, expiresAt) {
  const parts = token.split(".");
  if (parts.length !== 2 || expiresAt <= Date.now()) return false;
  const expectedSignature = await secretHash(
    env.OTP_PEPPER,
    "session:" + parts[0],
  );
  if (!safeEqual(expectedSignature, parts[1])) return false;
  try {
    const payload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(parts[0])),
    );
    return payload.temporaryId === temporaryId &&
      payload.expiresAt === expiresAt &&
      payload.expiresAt > Date.now();
  } catch {
    return false;
  }
}

function base64UrlEncode(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function base64UrlDecode(value) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}
function sessionKey(temporaryId) {
  return "session:" + temporaryId;
}

function randomToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function toHex(bytes) {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}
