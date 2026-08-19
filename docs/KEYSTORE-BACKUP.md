# Android Keystore Backup Guide

## What
The StudyFlow release keystore (`studyflow-release.jks`) is used to sign all APK/AAB releases. Losing it means you can never update the app on the Play Store under the same identity.

## Where it lives
- **CI**: GitHub Secrets (`STUDYFLOW_KEYSTORE_B64`, `STUDYFLOW_KEYSTORE_PASSWORD`)
- **Local**: `.freebuff/studyflow-release.jks` (gitignored, never committed)

## Backup procedure (run once, store offline)

```bash
# 1. Create an encrypted copy
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in .freebuff/studyflow-release.jks \
  -out ~/Desktop/studyflow-release-encrypted.jks

# You'll be prompted for a backup password. WRITE IT DOWN.

# 2. Copy to a second location (USB drive, cloud storage, etc.)
cp ~/Desktop/studyflow-release-encrypted.jks /path/to/backup/

# 3. Verify the backup can be decrypted
openssl enc -aes-256-cbc -d -pbkdf2 \
  -in ~/Desktop/studyflow-release-encrypted.jks \
  -out /tmp/verify.jks
file /tmp/verify.jks  # Should show "data" (Java Keystore)
rm /tmp/verify.jks
```

## What to store offline (in a password manager)
1. The encrypted `.jks` file
2. The encryption password (for `openssl`)
3. The keystore password (for `keytool` — the one in `STUDYFLOW_KEYSTORE_PASSWORD`)
4. The key alias (`studyflow`)
5. Your GitHub token with `repo` + `workflow` scope (to access CI secrets)

## Recovery
If the GitHub secrets are lost:
1. Decrypt the backup: `openssl enc -aes-256-cbc -d -pbkdf2 -in backup.jks -out studyflow-release.jks`
2. Re-encode: `base64 studyflow-release.jks` → paste into `STUDYFLOW_KEYSTORE_B64`
3. Set `STUDYFLOW_KEYSTORE_PASSWORD` to the keystore password
4. Verify: trigger a release build and check the APK signature
