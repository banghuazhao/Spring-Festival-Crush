# Board scouting and focused retry advice

## Scouting before Play

The level briefing now includes a visible board scout before the rule lessons. It copies the selected level's authored layout into an immutable value without creating symbols or dealing random tiles. Normal cells have a neutral dot, and the caption explains that their tile colors are chosen when play starts.

The map shows playable spaces, holes, lock strengths, starting power-ups, gifts, chocolate, ice, gold frames and moon blossom layers. Authored rows use the same top-to-bottom display order as the live board. Delivery arrows appear under actual bottom-row cells when the level has an active gift goal; higher ledges and holes are not exits. Ice and armor follow the engine's effective starting rules, and invalid layouts are omitted safely.

The diagram scales proportionally inside the briefing and does not receive input. Its VoiceOver summary reports the dimensions, playable/random spaces, holes and present fixed features. The caption and summary are localized in English, Simplified Chinese and Traditional Chinese.

## One useful retry tip

The defeat screen selects one short tip from the remaining goals and any living guardian. It prioritizes gift delivery, then power activation goals, then the guardian's weakness, then locks, blossoms and ordinary collection colors. Completed, negative and unknown goals do not generate advice. Missing data and demo attempts hide the tip.

Gift advice explains both gravity and direct collection. Activation advice distinguishes firing a power from creating it. Guardian advice follows the existing damage rules; Rat advice refers to the shown tribute rather than carrying the final attempt's tribute color into a fresh retry.

Selection is deterministic and reads an attempt snapshot. Showing the advice does not spend inventory, change goals or start a new attempt. The copy wraps with Dynamic Type inside the existing scrollable defeat panel. At accessibility sizes the advice icon sits above the text, and retry/map buttons stack their icons above centered labels so words retain the available width. Goal names also honor the SwiftUI presentation locale alongside the advice.

## Verification

Seven pure scouting tests cover row orientation, every authored feature, effective protection rules, bottom exits and higher ledges, inactive gift goals, independent snapshots, unknown tile fallback, malformed layouts and out-of-bounds lookup. Six retry-policy tests cover mixed-goal priority, every supported goal, completed/unsupported data and living/defeated guardian behavior. Localization tests check all new strings and preserve format arguments in every shipped language.

The complete simulator suite passed **180 tests with zero failures**. The opt-in balance report was skipped in that suite and then passed separately with **1,200 games**. Native scouts and retry screens were inspected at 320-point and 375-point phone widths and 768-point tablet width, in English and both Chinese translations, with Dynamic Type through accessibility5. Visual review caught and corrected Chinese goal-label lookup and awkward large-text button wrapping; the corrected screenshots retain whole words and reachable controls.

Project/translation validation and whitespace checks pass. The final unsigned Release build passes with code signing disabled. Capstone content, migration and balance details are recorded in [capstone-levels.md](capstone-levels.md).
