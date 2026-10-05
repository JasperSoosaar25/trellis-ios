import hashlib
import json
import pathlib
import plistlib
import subprocess
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
    forbidden = ['aps-environment', 'com.apple.security.application-groups', 'com.apple.developer.associated-domains', 'keychain-access-groups']
    with tempfile.TemporaryDirectory() as temporary:
        binary = pathlib.Path(temporary) / info['CFBundleExecutable']
        binary.write_bytes(archive.read(prefix + info['CFBundleExecutable']))
        arch = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
        assert arch == 'arm64', f'Unexpected architecture: {arch}'
    report = {'ipa': ipa.name, 'bundleID': info['CFBundleIdentifier'], 'minimumOS': info['MinimumOSVersion'],
              'deviceFamilies': info['UIDeviceFamily'], 'architecture': arch, 'provisioningProfile': False,
              'extensions': False, 'entries': len(names), 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest()}
ipa.with_suffix('.verification.json').write_text(json.dumps(report, indent=2) + '\n')
ipa.with_suffix('.ipa.sha256').write_text(report['sha256'] + '  ' + ipa.name + '\n')
print(json.dumps(report, indent=2))
