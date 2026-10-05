import hashlib
import json
import pathlib
import plistlib
import subprocess
import struct
import sys
import tempfile
import zipfile

ipa = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(ipa) as archive:
    names = archive.namelist()
    prefix = 'Payload/Trellis.app/'
    assert prefix + 'Info.plist' in names, 'Missing Payload/Trellis.app'
    assert not any(n.endswith('embedded.mobileprovision') for n in names), 'Provisioning profile present'
    assert not any('/PlugIns/' in n for n in names), 'Unexpected app extension'
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'dev.trellis.client'
    assert info['MinimumOSVersion'] == '26.0'
    assert sorted(info['UIDeviceFamily']) == [1, 2]
    assert not info.get('UIDesignRequiresCompatibility', False)
    executable = archive.read(prefix + info['CFBundleExecutable'])
    assert struct.unpack_from('<II', executable) == (0xFEEDFACF, 0x0100000C), 'Expected thin arm64 Mach-O'
    arch = 'arm64'
    # A linker ad-hoc signature is allowed, but signing entitlements are not.
    ncmds = struct.unpack_from('<I', executable, 16)[0]
    command_offset = 32
    for _ in range(ncmds):
        command, size = struct.unpack_from('<II', executable, command_offset)
        assert size >= 8 and command_offset + size <= len(executable), 'Invalid Mach-O command'
        if command == 0x1D:  # LC_CODE_SIGNATURE
            offset, length = struct.unpack_from('<II', executable, command_offset + 8)
            signature = executable[offset:offset + length]
            if signature:
                magic, total, count = struct.unpack_from('>III', signature)
                assert magic == 0xFADE0CC0 and total <= len(signature), 'Invalid signature container'
                for index in range(count):
                    slot, _ = struct.unpack_from('>II', signature, 12 + index * 8)
                    assert slot not in (5, 7), 'Unexpected embedded signing entitlements'
        command_offset += size
    if sys.platform == 'darwin':
        with tempfile.TemporaryDirectory() as temporary:
            binary = pathlib.Path(temporary) / info['CFBundleExecutable']
            binary.write_bytes(executable)
            assert subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() == arch
    report = {'ipa': ipa.name, 'bundleID': info['CFBundleIdentifier'], 'minimumOS': info['MinimumOSVersion'],
              'deviceFamilies': info['UIDeviceFamily'], 'architecture': arch, 'provisioningProfile': False,
              'extensions': False, 'embeddedEntitlements': False, 'entries': len(names), 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest()}
ipa.with_suffix('.verification.json').write_text(json.dumps(report, indent=2) + '\n')
ipa.with_suffix('.ipa.sha256').write_text(report['sha256'] + '  ' + ipa.name + '\n')
print(json.dumps(report, indent=2))
