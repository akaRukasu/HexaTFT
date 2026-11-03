# Verification — Hexa 0.3

Local content checks pass for 48 bundled compositions, 539 French reference entries from one set, source board positions, known units/items, and all bundled champion/item images. The project graph and shared scheme also pass validation.

The CI workflow runs native catalogue and persistence tests, bundled meta decoding/reference checks, native comp pinning and board persistence, and a UI smoke test covering Méta → composition → Partie → Codex → Sources. Native tests and the unsigned device build must pass before the IPA is described as compiled.

A physical iPhone installation and signing are separate from an unsigned build. Full third-party websites require network access and remain subject to their own availability, login, cookie and subscription behavior.

The captured source screens show rendered Blitz and MetaTFT content. Mobalytics shows a Cloudflare verification screen in the hosted simulator; this is an external access limitation, not evidence that its composition pages loaded. The UI check verifies embedded navigation and visible web content, including such provider verification pages.

The 0.3 guide tests cover nonempty stage fallback, exact unit-to-position correspondence, inconsistent provider boards, item projection versus observed equipment, recipe component references and compatibility with older reference entries. The additional UI path selects a level board, the final board, opens a champion from the board, inspects equipment recipes and switches back to a stage.

55 item recipes are supplied as structured component identifiers. Missing source coordinates are not invented; recipe-free items are labelled explicitly. Target equipment is visually marked with a dashed frame, including source-supported temporary holders when unambiguous.
