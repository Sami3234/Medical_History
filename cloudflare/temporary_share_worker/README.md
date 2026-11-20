# Temporary Medical Share Worker

This Worker adds a temporary encrypted sharing layer. Supabase remains the
application authentication and primary data backend. The Worker stores only
client-encrypted temporary objects in a private R2 bucket.

## Security model

- Flutter encrypts every manifest and document with AES-256-GCM before upload.
- Upload and revocation require the current Supabase access token.
- The Worker stores only an HMAC of the six-digit passcode.
- A random 12-character temporary ID must accompany the passcode.
- Five failed attempts from one network address lock access for 15 minutes.
- The passcode is exchanged once for a signed session that expires with the share.
- Access expires after at most 15 minutes.
- R2 responses are private and use Cache-Control no-store.
- Documents are downloaded only when the viewer opens them.
- No medical payload, temporary ID, passcode, or IP address is logged by code.

A viewer can still photograph or screenshot information after it is displayed.
No software can make viewed information fully retractable.

## Cloudflare setup

Use Node.js 22 or newer for the current Wrangler toolchain.

1. Create a private R2 bucket named medical-history-temporary-shares.
2. Create Workers KV namespaces for production and preview rate limits.
3. Copy wrangler.toml.example to wrangler.toml and fill the KV IDs and
   Supabase project URL.
4. Create a long random pepper and store secrets:

    npx wrangler secret put SUPABASE_ANON_KEY
    npx wrangler secret put OTP_PEPPER

5. Add an R2 lifecycle rule that deletes the shares/ prefix after one day.
   Logical access still stops exactly after 15 minutes; lifecycle is delayed
   physical cleanup.
6. Run npm install, npm run check, then npm run deploy.
7. Build Flutter with:

    flutter run --dart-define=TEMP_SHARE_API_URL=https://YOUR-WORKER.workers.dev

Do not put R2 credentials, the OTP pepper, or Worker secrets in Flutter.
Do not enable public r2.dev access for the bucket.
