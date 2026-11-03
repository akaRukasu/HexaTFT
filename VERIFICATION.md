# Verification — Hexa 0.2

Local content checks pass for 48 bundled compositions, 539 French reference entries from one set, source board positions, known units/items, and all bundled champion/item images. The project graph and shared scheme also pass validation.

The CI workflow runs native catalogue and persistence tests, bundled meta decoding/reference checks, native comp pinning and board persistence, and a UI smoke test covering Méta → composition → Partie → Codex → Sources. Native tests and the unsigned device build must pass before the IPA is described as compiled.

A physical iPhone installation and signing are separate from an unsigned build. Full third-party websites require network access and remain subject to their own availability, login, cookie and subscription behavior.

The captured source screens show rendered Blitz and MetaTFT content. Mobalytics shows a Cloudflare verification screen in the hosted simulator; this is an external access limitation, not evidence that its composition pages loaded. The UI check verifies embedded navigation and visible web content, including such provider verification pages.
