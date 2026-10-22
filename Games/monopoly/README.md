# Monopoly chooser

This module presents two independent choices: Monopoly Classic and the existing
Monopoly Deal. Its `game_choices` manifest groups their menu presentation while
retaining each child's stable ID, controller route, profiles, settings and limits.
Deal is still limited to five players; Classic permits six total seats. With six
humans Deal is visibly disabled. The host chooses; phones wait through the SDK.

The locked lobby party survives child/chooser navigation. An offline member
remains part of that party; reconnect before choosing another variant or return
to the lobby to change the lineup. Back returns to the full game selection menu.

The splash uses the user's city/table reference, an independent red/gold vector
wordmark, a Classic illustration and the actual current Deal card faces with live
names. Shared `GameChoiceCard` provides pointer/focus glow with a breathing pulse.
Reduced motion uses a static highlight. No hover text or tooltip is added.
The entrance fades this independent module layer; shutdown cancels its tween.

Artwork and prompts: [`asset/monopoly/PROMPTS.md`](../../asset/monopoly/PROMPTS.md).
The background stem `art/terrace` accepts shared image/video replacements.
No source file inside `Games/monopoly-deal` is changed, moved or renamed.
