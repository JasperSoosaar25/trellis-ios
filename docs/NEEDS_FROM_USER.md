# Manual setup

The app builds without an OAuth client ID and supports a pasted personal access token.

1. Download the published IPA to Files, import into KravaSign, sign, and install.
   Check that it opens on your iPhone 13; CI cannot verify your signing certificate.
2. Paste a PAT with the permissions you want. Organization access may additionally
   require SSO authorization or approval. This route needs no OAuth App.
3. For Device Flow instead, create an OAuth App under GitHub > Settings > Developer settings > OAuth Apps.
   Homepage: this repository's URL. Callback: any valid URL, e.g. https://github.com.
   Enable Device Flow. Do not create or share a client secret.
   Set the public Actions variable `GH_CLIENT_ID` to the client ID before a new build, or enter it in
   Trellis at runtime. See [GitHub device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow).
4. Sign into github.com once inside Trellis's browser for web-only screens. API
   tokens do not create browser login cookies.
5. If wanted, enable background notifications in Trellis Settings and allow the
   iOS prompt. Check your actual account operations and accessibility settings on
   the device; automated tests use fixtures, not your account.

No account identity, tokens, certificates, or personal data are included in the app.
