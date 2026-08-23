# Support Bundle

`pokrov_support_bundle` turns the fixed virtual files from
`pokrov_diagnostics_collectors` into a canonical manifest, exact preview and an
encryption-only container.

Properties:

- profiles `summary`, `standard`, `extended` and `crash` have hard byte caps;
- `extended` requires a valid signed policy with a lifetime of at most 30
  minutes;
- per-file SHA-256, redaction counts, categories, sizes and diagnostic ID in the
  preview are derived from the same prepared payload that is encrypted;
- unsafe paths, planted credential/request material, IP addresses and email
  addresses fail closed before encryption;
- recipient X25519 keys and extended policies must arrive in an Ed25519-signed
  contract rooted in an explicitly pinned platform signing key;
- the public API exposes encrypted bytes only. It has no plaintext ZIP/export,
  arbitrary filesystem collector or raw support-chat attachment path.
- `SupportBundleDeliveryCoordinator` writes the encrypted envelope to an
  injected private outbox before network use, creates an idempotent case-bound
  upload, follows the server-authoritative resume offset, retries interrupted
  chunks and removes the outbox object only after queued/validated completion.

Production support keys, key custody, deployed remote upload/storage and a
successful exact-candidate transfer are external `I4` evidence and are not
claimed by package tests.
