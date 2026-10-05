# Manual setup

The app builds without an OAuth client ID and supports a pasted personal access token.

1. Create an OAuth App under GitHub > Settings > Developer settings > OAuth Apps.
   Homepage: this repository's URL. Callback: any valid URL, e.g. https://github.com.
   Enable Device Flow. Do not create or share a client secret.
2. Set the public Actions variable `GH_CLIENT_ID` to the client ID, or enter it in
   Trellis at runtime. See [GitHub device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow).
3. Download the published IPA to Files, import into KravaSign, sign, and install.
   Actual certificate entitlements and on-device behavior need your verification.
4. Sign into github.com once inside Trellis's browser for web-only screens. API
   tokens do not create browser login cookies.

No account identity, tokens, certificates, or personal data are included in the app.
