#!/usr/bin/env python3
"""Assemble the conditional amd64 deb from retained, exact build outputs."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True, type=pathlib.Path)
    parser.add_argument('--daemon', required=True, type=pathlib.Path)
    parser.add_argument('--core', required=True, type=pathlib.Path)
    parser.add_argument('--client-revision', required=True)
    parser.add_argument('--core-revision', required=True)
    parser.add_argument('--package-revision', required=True, type=int)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    for revision in (args.client_revision, args.core_revision):
        if not re.fullmatch('[0-9a-f]{40}', revision):
            parser.error('Source revisions must be complete Git commit IDs.')
    if args.package_revision < 1:
        parser.error('Package revision must be positive.')
    packaging = pathlib.Path(__file__).resolve().parent
    client = packaging.parents[2]
    pubspec = (packaging.parent / 'pubspec.yaml').read_text()
    match = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', pubspec, re.M)
    if not match:
        parser.error('Linux pubspec must contain the client version and build number.')
    version = f'{match[1]}~beta.{match[2]}-{args.package_revision}'
    args.output.mkdir(parents=True, exist_ok=True)
    stage = args.output / f'pokrov_{version}_amd64'
    stage.mkdir()  # Never overwrite an earlier retained candidate.
    lib = stage / 'usr/lib/pokrov'
    lib.mkdir(parents=True)
    for executable in (args.bundle / 'pokrov', args.daemon, args.core):
        with executable.open('rb') as stream:
            header = stream.read(20)
        if header[:6] != b'\x7fELF\x02\x01' or header[18:20] != b'\x3e\x00':
            parser.error(f'Expected an amd64 ELF executable: {executable.name}')
    shutil.copytree(args.bundle, lib / 'ui', symlinks=True)
    for source, name in ((args.daemon, 'pokrov-linuxd'), (args.core, 'pokrov-core')):
        shutil.copyfile(source, lib / name)
        (lib / name).chmod(0o755)
    (lib / 'ui/pokrov').chmod(0o755)

    def copy(source, destination, mode=0o644):
        target = stage / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(mode)

    for unit in ('pokrov-linuxd.service', 'pokrov-linuxd.socket', 'pokrov-linux-sleep.service'):
        copy(packaging / 'systemd' / unit, 'usr/lib/systemd/system/' + unit)
    copy(packaging / 'polkit/space.pokrov.linux.policy',
         'usr/share/polkit-1/actions/space.pokrov.linux.policy')
    copy(packaging / 'space.pokrov.linux.desktop',
         'usr/share/applications/space.pokrov.linux.desktop')
    copy(client / 'packages/app_shell/assets/brand/pokrov_mark_256.png',
         'usr/share/icons/hicolor/256x256/apps/space.pokrov.linux.png')
    copy(client / 'packages/app_shell/assets/licenses/native-go-NOTICES.txt',
         'usr/share/doc/pokrov/native-go-NOTICES.txt')
    (stage / 'usr/bin').mkdir(parents=True)
    (stage / 'usr/bin/pokrov').symlink_to('../lib/pokrov/ui/pokrov')

    manifest = {
        'schema': 'pokrov-linux-package-v1', 'version': version,
        'client_revision': args.client_revision, 'core_revision': args.core_revision,
        'input_provenance': 'Source associations require the retained build receipts.',
        'binaries': {name: sha256(path) for name, path in (
            ('ui', args.bundle / 'pokrov'), ('daemon', args.daemon), ('core', args.core))},
    }
    manifest_path = stage / 'usr/share/doc/pokrov/build.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    control = stage / 'DEBIAN'
    control.mkdir()
    installed_size = sum(p.stat().st_size for p in stage.rglob('*') if p.is_file()) // 1024
    (control / 'control').write_text(
        f'Package: pokrov\nVersion: {version}\nArchitecture: amd64\n'
        'Maintainer: POKROV <support@pokrov.space>\nSection: net\nPriority: optional\n'
        f'Installed-Size: {installed_size}\n'
        'Depends: libc6 (>= 2.39), libstdc++6, libgtk-3-0t64, libsecret-1-0, '
        'systemd, systemd-resolved, network-manager, '
        'nftables, iproute2, polkitd, pkexec\n'
        'Recommends: gnome-keyring, policykit-1-gnome\n'
        'Homepage: https://pokrov.space/\n'
        'Description: POKROV conditional Linux VPN beta\n'
        ' Non-root desktop client with a polkit-authorized system runtime.\n'
        ' Supported package target: Ubuntu 24.04 amd64.\n')
    for hook in ('postinst', 'prerm', 'postrm'):
        copy(packaging / 'debian' / hook, 'DEBIAN/' + hook, 0o755)
    executable_paths = {lib / 'pokrov-linuxd', lib / 'pokrov-core', lib / 'ui/pokrov'}
    executable_paths.update(control / hook for hook in ('postinst', 'prerm', 'postrm'))
    # Build-user umask must not make root-owned package paths group-writable.
    for path in (stage, *stage.rglob('*')):
        if not path.is_symlink():
            path.chmod(0o755 if path.is_dir() or path in executable_paths else 0o644)
    artifact = args.output / f'pokrov_{version}_amd64.deb'
    if artifact.exists():
        parser.error('Refusing to overwrite an existing deb.')
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage), str(artifact)], check=True)
    receipt = {**manifest, 'artifact': artifact.name, 'bytes': artifact.stat().st_size,
               'sha256': sha256(artifact), 'signature': 'UNSIGNED'}
    artifact.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
