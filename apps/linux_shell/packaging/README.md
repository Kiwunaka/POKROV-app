# Ubuntu engineering package

The target is Ubuntu 24.04 amd64. Build the GTK host with the pinned Flutter SDK and lockfile. It uses the application ID `space.pokrov.linux`. Install the Flutter Linux build prerequisites plus `clang`, `lld-18`, `llvm-18` and `libsecret-1-dev`. Build `daemon/cmd/pokrov-linuxd` with the declared Go toolchain and use a matching Linux Core executable.

From the client root run [build-deb.py](build-deb.py) with the release bundle, daemon and Core paths, their checked source revisions, package revision and output folder. The assembler accepts amd64 ELF inputs and writes an unsigned package.

Use the reviewed [pinned public key](signing-key.v1.json) and [public key file](linux-packages-public.asc) to verify the detached package signature with `gpgv` before installing the unchanged deb with `apt`. This signer is separate from support signing.

The package installs the UI under `/usr/lib/pokrov/ui`, the desktop launcher under `/usr/bin` and the daemon's systemd socket and service. Install enables socket activation and the sleep hook. Upgrade preserves the socket's enablement. Upgrade and removal stop the owned units and require recovery to have settled before replacing runtime files. Package hook sources use LF.
