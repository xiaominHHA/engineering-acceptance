# Release Checklist

## Source

- [ ] Working tree is clean and the intended release commit/tag is checked out.
- [ ] Tag、APK versionName/versionCode、JAR version、Docker tag/OCI labels 和 CI artifact version 一致。
- [ ] `scripts/check-secrets.sh` passes; no production secret or private key is tracked.
- [ ] Release keystore is external and mode `600`; `apksigner verify --print-certs` matches the recorded certificate fingerprint.

## Automated gates

- [ ] `./check.sh` passes: lint, real-DB backend tests, Flutter tests, production-like smoke, APK/JAR build.
- [ ] `scripts/integration-test.sh <android-emulator-id>` passes against its isolated Docker backend.
- [ ] GitHub Actions is green for the exact release commit.
- [ ] API error contract and old-response compatibility tests pass.
- [ ] Versioned APK/JAR are the intended artifacts for the exact release tag and commit.
- [ ] `/actuator/info` reports the intended version, commit and build time without branch/path/secret data.

## Deploy verification

- [ ] Actuator and API smoke checks pass through the production domain.
- [ ] Backend, MySQL, and MongoDB containers are healthy with configured memory limits.
- [ ] This project's backend and database host ports remain loopback-only.
- [ ] Shared Nginx container identity and other projects' server blocks remain untouched.
- [ ] Production `APP_AUTH_SIGNING_KEY` exists in the protected server env and is not a local/test value.
- [ ] HTTPS certificate/domain prerequisite is verified before switching the release APK to HTTPS.

## Manual APK smoke

- [ ] Install the exact release APK and confirm its production API URL.
- [ ] Register; verify duplicate-register and wrong-password messages; then log in.
- [ ] Read and save profile data; publish and read a forum post.
- [ ] Disable network, verify the error and retry after reconnecting.
- [ ] Check small screen, large text, portrait/landscape, keyboard, and Android back behavior.
