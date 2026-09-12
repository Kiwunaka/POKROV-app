# Core880 Wintun follow-up: source and Windows package

Client `c06cab7776dd3db5282535ba6c5309bf0119f6bb`; Core
`880bff65ad665844828fe50fc395e9cfc1cd81b4`. This is partial development evidence,
not release clearance. [Capture index](receipt.json) binds the raw files.

- Windows installer build, 9 native CTest cases and independent extraction pass;
  all 304 staged/extracted files match. The extractor VM is powered off.
- Client PR119 and Core PR14 merged with verified signatures and exact trees.
  Four exact PR/main CI runs pass; conditional replay-ref steps remain skipped.
  Initial coordination failures are retained. Branch protections did not change.
- The private Core source packet has 3902 verified entries and five offline
  dependency graphs. Its bytes remain on the owned DE host; metadata is retained
  here. Full licensing/corresponding-source delivery is still open.
- Two Android builds stopped at the storage guard. The first briefly undershot
  the 40 GiB floor by about 27 MiB; the second stopped above it. Previous valid
  outputs were preserved remotely. No completed Core880 APK/AAB is claimed.
  Five historical source ZIPs were subsequently relocated only after remote
  SHA-256 verification; original historical records were not rewritten.
- Invalid-config canaries are absent from the FFI return, stdout/stderr and five
  generated files. A separate marker placed in the setup working path DOES leak
  through stderr with debug disabled. This remains FAIL_PRIVACY for Core880.
  Earlier harness startup failures occurred before DLL loading and are retained.

The later Core6b271de fix removes caller paths/listen address from setup logs.
Its tests and new binary acceptance belong to separate evidence. The phone was
withdrawn; no new installed TUN/recovery or publication/deploy occurred here.
