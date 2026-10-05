# Finish distribution in normal PowerShell

The resumed session can run local commands, but its restricted network cannot
connect to github.com:443. The confirmation fix is already pushed as 9c8f24f;
[its build](https://github.com/JasperSoosaar25/trellis-ios/actions/runs/37364416747)
runs independently on GitHub. No release tag has been pushed by this session.

Run these commands in normal PowerShell from the project directory. They verify
the already-pushed code before publishing the remaining documentation and tag.
No credentials are printed or added to the repository.

```powershell
Set-Location ~/Projects/Trellis
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
gh run watch 37364416747 --exit-status
$runResult = gh run view 37364416747 --json conclusion,headSha | ConvertFrom-Json
if ($runResult.conclusion -ne 'success') { throw 'Code validation has not passed.' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Main push failed.' }
git tag v1.0.0
if ($LASTEXITCODE -ne 0) { throw 'Tag creation failed; inspect any existing tag.' }
git push origin v1.0.0
if ($LASTEXITCODE -ne 0) { throw 'Tag push failed.' }
```

The main push and tag each start the full validation pipeline. The tag publishes
the unsigned IPA, SHA-256 and verification JSON only after its build succeeds.
Follow both new runs on [Actions](https://github.com/JasperSoosaar25/trellis-ios/actions),
then check [Releases](https://github.com/JasperSoosaar25/trellis-ios/releases).
If a tag already exists when these commands are run, inspect its run/release before
continuing; do not move or overwrite an existing published tag.

After release success, download the IPA and SHA-256. Compare its checksum in normal
PowerShell, then run the structural verifier (replace the path with your download):

```powershell
gh release download v1.0.0 --dir local-artifacts/release --pattern 'Trellis*'
$ipaPath = Join-Path (Get-Location) 'local-artifacts/release/Trellis.ipa'
$expectedHash = (Get-Content "$ipaPath.sha256").Split(' ')[0]
if ((Get-FileHash $ipaPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw 'IPA checksum mismatch.' }
python scripts/verify-ipa.py $ipaPath
```

Installation and authentication steps are in NEEDS_FROM_USER.md.
