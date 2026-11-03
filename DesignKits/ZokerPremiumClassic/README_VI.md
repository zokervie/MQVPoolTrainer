# Zoker Premium Classic — Download without uploading ZIP into Codex

**Working branch:** \`ci/native-0.19-workflow\`.

GitHub-provided **source-generation workflow** rather than committing the 21MB original binary. A branch push triggers \`.github/workflows/zoker-premium-assets.yml\` which builds a light ZIP entirely on Ubuntu and uploads an Actions artifact. If Actions is blocked, run locally or in Codex workspace:

\`\`\`sh
python3 DesignKits/ZokerPremiumClassic/generate_github_kit.py
\`\`\`

Output: \`DesignKits/ZokerPremiumClassic/Zoker_Premium_Classic_GitHub_Kit.zip\`.

**Important:** The GitHub-generated ZIP is a RECONSTRUCTED LITE variant, not byte-for-byte the earlier 20,986,906-byte ZIP attached in ChatGPT. It provides procedural texture maps, icons, 12 OBJ/MTL cue models, 18 geometric diamond reference sites, theme tokens and Codex prompt but **does not contain the AI concept screenshots, alpha button PNG or original 1024px PBR images**. Do not claim those files transferred. Full original requires an authenticated binary upload from a machine or GitHub browser.

Prior original ZIP SHA-256: \`e9bfac0cb6c76ba98e437a452c97cba836a93ee459d8e44a2a555a510ead0a78\`.

This source kit changes NO physics, no app code, no simulator build, and no iOS IPA. It only permits Codex to access assets without chat attachment limits. Keep B lower-left; Coach above B; H removed from HUD.
