# Conditional Ubuntu package

The package target is Ubuntu 24.04 amd64. The GTK runner is generated from
Flutter 3.38.5 with application ID `space.pokrov.linux`; the existing shared
Flutter application supplies the UI. This packaging source does not establish
a signed or accepted Linux release.

Build dependencies on Ubuntu 24.04 are `clang`, `lld-18`, `llvm-18`, `cmake`,
`ninja-build`, `pkg-config`, `libgtk-3-dev`, `libstdc++-12-dev` and
`libsecret-1-dev`. The Dart native-assets build requires LLVM's linker and archiver even
when clang was installed without recommended packages.

Build the UI with the pinned Flutter SDK and lockfile, production app/build/Git
identity defines, and the current emergency/support public signing pins used
by the other production shells. Build `daemon/cmd/pokrov-linuxd` with the
declared Go toolchain. The Core executable must come from a retained native
Linux build of the exact Linux Core source; Android/Windows artifact binding
does not prove that executable. Retain source archives, build commands,
toolchain versions and output hashes before assembly.

From the client root, assemble those exact outputs:

```sh
python3 apps/linux_shell/packaging/build-deb.py \
  --bundle apps/linux_shell/build/linux/x64/release/bundle \
  --daemon /path/to/retained/pokrov-linuxd \
  --core /path/to/retained/pokrov-core \
  --client-revision "$CLIENT_COMMIT" \
  --core-revision "$CORE_COMMIT" \
  --package-revision 1 \
  --output artifacts/candidate-staging/linux
```

The assembler accepts amd64 ELF inputs and produces a root-owned deb, retained
staging tree and SHA-256 receipt. Its revision arguments record the input
association; they do not independently prove compilation provenance. The
receipt explicitly says `UNSIGNED`. Package signing, signer pinning and
verification of the exact resulting artifact are separate acceptance steps.

The UI bundle resides in `/usr/lib/pokrov/ui`; `/usr/bin/pokrov` starts it as
the desktop user. The system service owns the fixed Core executable and private
state. Initial installation enables socket activation and the sleep hook.
Upgrade preserves the socket's enabled/disabled choice. Before upgrade or
removal, the package stops the sleep hook, socket and daemon and requires the
recovery journal to be gone. An unresolved journal aborts that operation, so
runtime code remains available for recovery. Removal disables the units.
The three Debian hooks have explicit LF attributes so Windows checkouts cannot
introduce CRLF shell interpreters into an assembled package.

Both remove and purge retain private profiles and user settings. There is no
profile schema migration in this package revision. Acceptance must verify
preservation across the exact package upgrade, native file/socket permissions,
real desktop polkit approval with non-root UI, clean-VM install/remove,
DNS/IPv6 and full/RU routing modes. Until that evidence exists, these gates
remain open under [the Linux lane owner](../README.md).
