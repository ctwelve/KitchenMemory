# Global language support: evidence and staged plan

<!-- Kitchen Memory; Copyright © 2026 the Kitchen Memory contributors; SPDX-License-Identifier: MIT -->

**Status:** Draft recommendation for maintainer selection under [#192](https://github.com/ctwelve/KitchenMemory/issues/192). Researched 2026-10-07. No expanded locale is selected, implemented, shipped, or linguistically accepted by this document. The selected expanded set remains a separate delivery requirement before 1.0.

## Recommendation and limits

Keep the current six locales. Recommend a first language expansion of **`pt-BR` and `ja-JP`**, with **`es-ES` and `fr-FR`** as a separately selectable regional part of the same wave. This makes the complete proposed first wave ten locales covering seven languages; it does not make ten languages. Evaluate all four with the same acceptance rubric. Do not accept Portuguese, Spanish, or French merely because they resemble English or existing translations.

Recommend a later global wave of **`zh-Hans`, `zh-Hant`, `ar`, `ko-KR`, `hi-IN`, and `id-ID`**, independently reviewable and deliverable in small slices rather than a single all-or-nothing import. Start its engineering probes now; a later placement is not a claim that the generating model cannot translate those languages. Do not defer all script diversity until the end: Japanese is in the first wave, and Arabic/mixed-script probes belong to the first wave's infrastructure work.

This is a bounded stewardship recommendation, not an optimized estimate of Apple-device customers. We have no Kitchen Memory audience telemetry, locale-specific demand evidence, or measured acquisition forecast. The synthetic corpus below is an inspectable first generation with concrete risk observations. It is not a linguistic proficiency benchmark or a native-speaker sign-off.

## Current coverage and evidence

The source of truth is `Configurations/LocalizationContract.json`: `en-US`, `en-GB`, `es-MX`, `fr-CA`, `de-DE`, `it-IT`, with `en-US` as source and universal fallback. These are five languages and six regional locales. At scaling commit `807dde0` (2026-10-07), the app catalog has 543 semantic keys, including eight source plural entries; the metadata catalog has three keys. This is a pinned planning inventory, not a submitted release inventory.

The resource obligations are distinct:

| Concern | Current boundary | Expansion obligation |
| --- | --- | --- |
| Interface and metadata | App-owned String Catalogs; generated resource symbols and translator comments | Complete reviewed values, named operands, locale-specific plurals, localized product name decision |
| Launch and Credits | Per-locale launch `.strings` and complete `Credits.rtf` | Include and inspect each new locale's actual bundle resources |
| Authored samples | Manifest chooses coherent versioned recipe-document variants | Explicit variant identities, provenance, complete documents and accessibility descriptions; no replacement of installed recipes |
| Ingredient recognition | Bounded implemented grammar, selected language words/units | Publish the existing grammar limits; translated UI does not promise newly recognized ingredient languages |
| Formatting | Explicit presentation locale; rational quantities and authored units stay durable | Decimal/digit/date/measurement display probes with unchanged domain values |
| Search and collation | Locale-aware presentation ordering, preserved stored names | Explicit mixed-script ordering and search expectations; translation does not imply transliteration search |
| Assistive presentation | Semantic labels and native platform speech | Inspect actual localized labels, pronunciation, order, and action meaning |

These boundaries come from `docs/localization-architecture.md`, `KitchenMemoryTests/Resources/LocalizationCatalogTests.swift`, and `Tools/check-localization.rb`, read in this checkout. The completed parser contract includes unambiguous dot/comma decimal quantities and selected whole-number words and units in English, French, Spanish, German, and Italian. Spell-out recognition is bounded to whole numbers 0–100 that round-trip through the locale formatter. It does not claim Arabic-Indic or Devanagari digit recognition, arbitrary CJK quantities, or exhaustive parsing of those five languages. Imported and person-authored Recipes retain their language and spelling. French recipes may use cups/tablespoons; American recipes may use grams/deciliters. There is no automatic unit conversion or stored-recipe translation in this plan.

For audience evidence, the W3Techs primary survey on 2026-10-07 reports website content-language use: English 49.5%, Spanish 6.0%, German 5.9%, Japanese 4.9%, French 4.5%, Portuguese 4.1%, Italian 2.8%, Chinese 1.3%, Indonesian 1.2%, Korean 0.9%, Arabic 0.6%, Hindi below 0.1%. Its unit is relevant websites whose language is known, not people, usage time, recipe demand, or Apple ownership; regional Portuguese/Spanish/French markets are not separated. Thus the figures support investigating Japanese and Portuguese, not a summed population-coverage claim. [W3Techs survey](https://w3techs.com/technologies/overview/content_language), [survey methodology](https://w3techs.com/technologies).

ITU's latest available Facts and Figures edition here is 2025, reporting almost three quarters of the world online and 2.2 billion people offline. Connectivity is an additional access boundary; it does not assign users to languages or predict this app's reach. [ITU Facts and Figures 2025](https://www.itu.int/en/ITU-D/Statistics/Pages/facts/default.aspx).

The first-wave regional codes are concrete editorial choices: Brazilian Portuguese, Japanese for Japan, Spanish for Spain, and French for France. Existing `es-MX` and `fr-CA` already supply Spanish/French interface coverage; adding `es-ES`/`fr-FR` primarily permits reviewed regional culinary vocabulary and register. It is not a way to count those languages twice. If the maintainer prioritizes new-language breadth over regional refinement, select only `pt-BR`/`ja-JP` first and bring the Chinese/Arabic wave forward.

## Locale roster and fallback policy for selection

| Wave | Proposed addition | Purpose and review focus |
| --- | --- | --- |
| First language expansion | `pt-BR` | New Portuguese coverage; Brazilian vocabulary; 0/1 and large-count forms; long recovery instructions |
| First language expansion | `ja-JP` | New Japanese coverage; CJK line breaking, counter words, concise but explicit actions, Latin units embedded in Japanese |
| First regional expansion, optional | `es-ES` | Spain vocabulary and register; compare with retained `es-MX` rather than copying it blindly |
| First regional expansion, optional | `fr-FR` | France vocabulary and register; compare with retained `fr-CA`; long copy, typography and plural counts |
| Later global expansion | `zh-Hans` | Simplified Chinese interface; review independently of Traditional Chinese; authored content may carry more precise regional tags |
| Later global expansion | `zh-Hant` | Traditional Chinese interface; independent wording/register review, not character conversion |
| Later global expansion | `ar` | Reviewed Modern Standard Arabic interface; mixed direction, plural forms, localized digits and Latin recipe/unit text |
| Later global expansion | `ko-KR` | Korean interface; counters, agglutinated endings, compact controls and native reading |
| Later global expansion | `hi-IN` | Hindi interface; Devanagari marks, digit display, terminology and English-authored recipe coexistence |
| Later global expansion | `id-ID` | Indonesian interface; concise control language, culinary ambiguity, plural-neutral count copy |

`ar`, `zh-Hans`, and `zh-Hant` intentionally use language/script tags rather than claim one regional culinary vocabulary covers every country. `zh-Hans-CN`, `zh-Hant-TW`, `ar-SA` and other region-specific formatting probes may be used without falsely advertising a separate reviewed UI translation. A future locale request should be ranked by audience demand, reviewer availability and demonstrated examples; Turkish, Polish, Vietnamese, Dutch and other languages remain eligible. This is not a permanent exclusion list.

For the interface, let Apple's preferred-language bundle selection choose among genuinely packaged translations and retain `en-US` development fallback. Verify the signed product's actual selection rather than promising a custom regional order that Foundation has not demonstrated. Apple describes matching the user's preferred languages to supported localizations and falling back to the development language when no language matches. [Apple language-selection Q&A](https://developer.apple.com/library/archive/qa/qa1828/_index.html), [preferredLocalizations API](https://developer.apple.com/documentation/foundation/bundle/preferredlocalizations%28from%3Aforpreferences%3A%29).

For authored sample selection, retain the existing explicit exact-tag → supported same-language variant → `en-US` order. Specify and test deterministic same-language defaults separately from interface bundle behavior. Proposed defaults when no exact sample variant is available are `en-US`, `es-MX`, `fr-CA`, `de-DE`, `it-IT`, `pt-BR`, `ja-JP`, `ko-KR`, `hi-IN`, `id-ID`, and `ar`; select Chinese by matching script first, using a tested locale/script resolver. Never switch `zh-Hant` into a `zh-Hans` translation solely because both start with `zh`; an unresolvable script request falls back to `en-US` rather than pretending the other script is exact coverage. The concrete Chinese sample resolver is an implementation task, not present behavior claimed here.

Keep formatting locale independent of the selected UI language. A person using French UI with US regional formatting can retain that configuration. A French-authored Recipe with cups remains in cups. A locale fallback must never rewrite ingredient text or identifiers.

## Translation production and review

The actual generating model for this synthetic corpus is **`gpt-6.1-sol`**, the model identified for this research agent in this session. Date: 2026-10-07. The model authored the translations directly in the table below, with the source/context packet stated here; there was no separate translation service, public benchmark, hidden native reviewer, or measured linguistic accuracy rate. The deployment snapshot, sampling parameters and provider-internal weights are unavailable; do not claim exact reproducibility or future quality from the identifier alone. A production ledger must record the model available at generation time, prompt/context revision, source-key revision, generated output, reviewer and revision history.

Generation packet used for this corpus: “Translate the following synthetic Kitchen Memory messages into pt-BR, es-ES, fr-FR and ja-JP. Preserve named placeholders exactly. Preserve Session lifecycle meaning, recoverable draft versus submitted note, explicit action consent and unchanged authored units. Use neutral clear interface wording. Cooking text keeps uncertainty, optionality and quantity ranges. Supply locale-appropriate plural category drafts and separately flag region/register/counter uncertainty. Do not translate dynamic recipe titles or reinterpret formatted-number operands. Later probes use ar, zh-Hans, zh-Hant, ko-KR, hi-IN and id-ID.”

The glossary packet defines Recipe as maintained intent, Session as one actual cook, Entry as a submitted cooking note, Entry Draft as recoverable unsent text, Resume as reactivating the same stopped cook, Continue as creating a new cook from a Finished baseline, Withdraw as withdrawing an Entry rather than deleting its Recipe, and Finish as an explicit terminal decision. Cooking terms require source context: “stock” may be broth or inventory; “fold” is a technique; “scallion” is not automatically a locally sold onion variety; “cup” is an authored unit, not permission to replace it with milliliters.

Production should use contextual batches, with semantic key, complete English message, purpose/screen, relevant screenshot or layout description, glossary terms, grammar/count domains, operand types/examples, accessibility role, tone and destructive/recovery consequences. Generate complete messages, not stitched fragments. A second reviewer receives source/context and candidate output and reports semantic, culinary, linguistic and accessibility defects without treating generator confidence as evidence. A separate model invocation/reviewer is useful independent execution, but shared model-family blind spots remain; back-translation alone is insufficient. Record disagreements and revisions. Add knowledgeable human locale reviewers as demand grows; retain the project's release-tier human sign-offs rather than making native-speaker access an invented prerequisite for every unpublished slice.

## Authored synthetic evaluation corpus

All messages below are **synthetic evaluation material**, authored for this research. They are not additions to the app catalog, not translations of user data, and not proposed sample-pack assets. The generation itself is evidence of a concrete candidate output; linguistic confidence is unreviewed. Numeric operands below are named catalog-format drafts, not instructions to assemble runtime strings manually.

### C1 — short action, general/contextual note

Source/context: “Add Note.” Opens the single recoverable Session note composer; a meaningful existing draft is reopened without silently changing its target.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Adicionar nota |
| es-ES | Añadir nota |
| fr-FR | Ajouter une note |
| ja-JP | メモを追加 |

Review target: action clarity and glossary choice for “note”; no implied new submitted Entry merely from opening.

### C2 — Stopped draft consent

Source/context: “Resume to edit note.” Reactivates the same Stopped Session and opens its draft; abandons the present Finish attempt.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Retomar para editar a nota |
| es-ES | Reanudar para editar la nota |
| fr-FR | Reprendre pour modifier la note |
| ja-JP | 再開してメモを編集 |

Review target: Resume must not imply a new cook or immediate Finish.

### C3 — new cook rather than Resume

Source/context: “Continue in a new cooking session.” Creates a new Active Session from a Finished baseline; never edits the completed cook.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Continuar em uma nova sessão de preparo |
| es-ES | Continuar en una nueva sesión de cocina |
| fr-FR | Continuer dans une nouvelle session de cuisine |
| ja-JP | 新しい調理セッションで続ける |

Observed generator issue: pt-BR uses “sessão de preparo” while the glossary's general concept is “sessão de cozinha.” This is an actual within-corpus terminology variation to resolve, not a native-speaker judgment that one is wrong. Candidate normalized revision: “Continuar em uma nova sessão de cozinha.” Review whether a more natural nonliteral Session term should replace the glossary consistently; do not silently alternate by lifecycle.

### C4 — retained Finish, not cloud upload

Source/context: “Finishing—waiting to save.” Explicit Finish consent is retained, but local acceptance is delayed; Retry reuses its Closure identity.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Finalizando — aguardando salvar |
| es-ES | Finalizando: pendiente de guardar |
| fr-FR | Finalisation en cours — en attente d’enregistrement |
| ja-JP | 終了処理中 — 保存を待っています |

Review target: literal tense/register, naturalness, and distinction from finished evidence. None mentions cloud synchronization. Long French fit remains unmeasured.

### C5 — withdrawal ambiguity

Source/context: “Withdraw note.” Withdraws a submitted Session Entry; does not discard another draft, delete the Session or erase the Recipe.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Retirar nota |
| es-ES | Retirar nota |
| fr-FR | Retirer la note |
| ja-JP | メモを取り下げる |

Review target: ask the reviewer to explain what object remains and what action happens. Do not score this solely by translating it back to “withdraw.” Japanese wording may suggest a submitted request; Portuguese/Spanish may be mistaken for ordinary removal without the surrounding context. Those are open hypotheses for review.

### C6 — authored cooking ambiguity and uncertainty

Source/context: “Fold in the scallions. If needed, add about 1–2 tablespoons of stock; do not boil.” “Fold” is gentle incorporation; stock is broth, not pantry inventory. Range, approximation, conditional addition and negative instruction are mandatory.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Incorpore delicadamente a cebolinha. Se necessário, adicione cerca de 1–2 colheres de sopa de caldo; não deixe ferver. |
| es-ES | Incorpora las cebolletas con movimientos suaves. Si es necesario, añade aproximadamente 1–2 cucharadas de caldo; no dejes que hierva. |
| fr-FR | Incorporez délicatement les oignons nouveaux. Si nécessaire, ajoutez environ 1–2 cuillères à soupe de bouillon ; ne faites pas bouillir. |
| ja-JP | 青ねぎをやさしく混ぜ込みます。必要に応じて、ブイヨンを大さじ1〜2杯ほど加えます。沸騰させないでください。 |

Observed generator issue: Japanese “ブイヨン” may narrow generic stock to a particular culinary/product meaning; proposed review alternative “だし” has its own broader/regional associations. Do not make either an automatic correction without the stock's recipe context. Ingredient variety and Spanish imperative register also require review. All four visibly retain conditionality, approximation, range and negation on author inspection; that is not independent linguistic acceptance.

### C7 — authored-unit independence

Source/context: “This recipe is written in French. Its amounts remain as authored: %1$(amounts)@.” Example operand is the exact source string `1 cup; 2 tbsp`, not a format request or conversion.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Esta receita está escrita em francês. As quantidades permanecem como no original: %1$(amounts)@. |
| es-ES | Esta receta está escrita en francés. Las cantidades se conservan tal como se escribieron: %1$(amounts)@. |
| fr-FR | Cette recette est rédigée en français. Les quantités restent telles qu’elles ont été écrites : %1$(amounts)@. |
| ja-JP | このレシピはフランス語で書かれています。分量は原文のままです：%1$(amounts)@。 |

Review target: the operand must remain byte-for-byte source text. This demonstrates untranslated authored units embedded in translated interface copy; it does not require English unit labels for newly authored French recipes.

### C8 — accessible completion/next-step announcement

Source/context: “Step %1$(completed)lld completed. Step %2$(next)lld is next.” Announce progress; do not steal keyboard/VoiceOver focus or imply automatic Finish. Values 2 and 3.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Etapa %1$(completed)lld concluída. A próxima é a etapa %2$(next)lld. |
| es-ES | Paso %1$(completed)lld completado. El siguiente es el paso %2$(next)lld. |
| fr-FR | Étape %1$(completed)lld terminée. L’étape %2$(next)lld est la suivante. |
| ja-JP | 手順%1$(completed)lldが完了しました。次は手順%2$(next)lldです。 |

Review target: spoken number/counter quality in actual platform speech, repeated “step” clarity, and sentence order. Written copy alone cannot prove VoiceOver pronunciation.

### C9 — plural forms for a saved-note count

Source/context: “%1$(count)lld note(s) saved.” Nonnegative integer count; generate full category drafts, never render literal “(s).” Probe 0, 1, 2, 5 and 1,000,000.

| Locale | Generated candidate category drafts |
| --- | --- |
| pt-BR | one: `%1$(count)lld nota salva`; many: `%1$(count)lld de notas salvas`; other: `%1$(count)lld notas salvas` |
| es-ES | one: `%1$(count)lld nota guardada`; many: `%1$(count)lld de notas guardadas`; other: `%1$(count)lld notas guardadas` |
| fr-FR | one: `%1$(count)lld note enregistrée`; many: `%1$(count)lld de notes enregistrées`; other: `%1$(count)lld notes enregistrées` |
| ja-JP | other: `%1$(count)lld件のメモを保存しました` |

Inspection finding: pt-BR/French category `one` can include zero; a literal “0 nota salva” / “0 note enregistrée” deserves usage review rather than a blind English one=1 assumption. `many` examples with “de” need compiled rendering and linguistic review for full-digit versus compact-million representation; no compiled formatter was run here. Japanese uses a classifier (`件`) and only one cardinal category, which the current hosted validator would reject. Category guidance is grounded in stable [CLDR 48 plural rules](https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html); Apple/OS behavior must still be measured for the candidate.

### C10 — long recovery copy and retained submission identity

Source/context: “Your submitted note is waiting to save. Retry saves that same note. Changes you make here remain a separate draft and need another deliberate submission. Leaving this screen keeps both.” This is rare recovery copy, not constant save ceremony.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | A nota enviada está aguardando ser salva. Tentar novamente salva essa mesma nota. As alterações feitas aqui permanecem em um rascunho separado e precisam de um novo envio explícito. Ao sair desta tela, ambos são mantidos. |
| es-ES | La nota enviada está pendiente de guardar. Reintentar guarda esa misma nota. Los cambios que hagas aquí se conservan en un borrador independiente y requieren que los envíes de nuevo de forma explícita. Al salir de esta pantalla, se conservan ambos. |
| fr-FR | La note envoyée est en attente d’enregistrement. Réessayer enregistre cette même note. Les modifications faites ici restent dans un brouillon distinct et nécessitent un nouvel envoi explicite. Quitter cet écran conserve les deux. |
| ja-JP | 送信したメモは保存を待っています。再試行では、その同じメモを保存します。ここで加えた変更は別の下書きとして残り、あらためて明示的に送信する必要があります。この画面を離れても、両方が保持されます。 |

Review target: distinction between local submit and network send; everyday readability of “explicit”; what “both” refers to; responsive text layout. All variants are multi-sentence paragraphs, not translation fragments. The model's use of “enviado/envoyée/送信” may imply a network operation; reviewer must assess it against the local-acceptance contract. A more appropriate “submitted” glossary may require revisions throughout.

### C11 — mixed-script authored title and placeholder order

Source/context: “Recipe %1$(title)@ could not be saved. Your draft is retained.” Operand example: `مجدرة / Miso みそ (v2)`. Title text is authored data, not translation material.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Não foi possível salvar a receita %1$(title)@. Seu rascunho foi preservado. |
| es-ES | No se ha podido guardar la receta %1$(title)@. Se conserva el borrador. |
| fr-FR | Impossible d’enregistrer la recette %1$(title)@. Votre brouillon est conservé. |
| ja-JP | レシピ「%1$(title)@」を保存できませんでした。下書きは保持されています。 |

Review target: native rendering of mixed direction, quotes/parentheses, truncation and speech. Named operand remains identical even when sentence order changes. Do not normalize, translate or insert direction controls into the stored title.

### C12 — preformatted decimal operand

Source/context: “Scale: %1$(factor)@×. Authored units are unchanged.” Operand is a presentation-formatted rational 3/2; it is never parsed back. Probe displayed `1,5` and `1.5` under explicit formatting locales; UI language may differ from region.

| Locale | Generated candidate |
| --- | --- |
| pt-BR | Escala: %1$(factor)@×. As unidades do original permanecem inalteradas. |
| es-ES | Escala: %1$(factor)@×. Las unidades originales no cambian. |
| fr-FR | Échelle : %1$(factor)@×. Les unités d’origine restent inchangées. |
| ja-JP | 倍率：%1$(factor)@倍。原文の単位は変わりません。 |

Inspection finding: Japanese repeats multiplier semantics through the word “倍” rather than the glyph `×`, preserving the supplied factor operand but requiring product-copy review. This deliberately tests translation of meaning rather than glyph equality. The dot/comma examples are display probes, not claims of locale-invariant formatting. Unicode LDML describes locale number symbols and numbering systems; let Foundation format typed values rather than translating digits with string replacement. [Unicode number formatting](https://unicode.org/reports/tr35/tr35-numbers.html).

## Later-wave script and language probes

The later locales have fewer generated examples here than the first-wave candidates. That asymmetry limits any comparative conclusion; extend the full C1–C12 packet before accepting each locale. These are authored synthetic outputs from the same model, not quoted translations or proof of native typography.

### L1 — same mixed-script save failure as C11

| Locale | Generated candidate |
| --- | --- |
| ar | تعذّر حفظ الوصفة %1$(title)@. تم الاحتفاظ بالمسودة. |
| zh-Hans | 无法保存食谱“%1$(title)@”。草稿已保留。 |
| zh-Hant | 無法儲存食譜「%1$(title)@」。草稿已保留。 |
| ko-KR | 레시피 ‘%1$(title)@’을 저장할 수 없습니다. 초안은 유지됩니다. |
| hi-IN | रेसिपी %1$(title)@ सेव नहीं की जा सकी। आपका ड्राफ़्ट सुरक्षित है। |
| id-ID | Resep %1$(title)@ tidak dapat disimpan. Draf Anda tetap tersimpan. |

Review findings/hypotheses: Korean particle `을` after an arbitrary title may be wrong when the title ends in a vowel; rephrase candidate as `레시피를 저장할 수 없습니다: %1$(title)@. 초안은 유지됩니다.` so no title-dependent particle is required. Hindi uses loan words “रेसिपी/सेव/ड्राफ़्ट”; a native reviewer must judge expected audience register rather than assume pure-Hindi vocabulary is automatically better. Simplified/Traditional forms are separately authored, but two related outputs do not establish region-independent editorial quality. Arabic mixed-direction output requires actual native rendering.

For RTL rendering, preserve the title's storage and use presentation-level text handling. Unicode defines directional isolates that prevent embedded text from affecting surrounding order; use them or suitable native attributed/run handling only at display boundaries after measurement, not blanket reversal or insertion into persisted content. [Unicode bidirectional algorithm, isolates](https://www.unicode.org/reports/tr9/#Explicit_Directional_Isolates). Apple's RTL guidance also distinguishes interface adaptation from merely reversing every visual asset. [Apple RTL guidance](https://developer.apple.com/design/human-interface-guidelines/right-to-left).

### L2 — cooking ambiguity from C6

| Locale | Generated candidate |
| --- | --- |
| ar | أضف البصل الأخضر وامزجه برفق. إذا لزم الأمر، أضف نحو ملعقة إلى ملعقتين كبيرتين من المرق؛ لا تدعه يغلي. |
| zh-Hans | 轻轻拌入葱。如果需要，加入约1–2汤匙高汤；不要煮沸。 |
| zh-Hant | 輕輕拌入青蔥。如有需要，加入約1–2大匙高湯；不要煮沸。 |
| ko-KR | 쪽파를 넣고 부드럽게 섞으세요. 필요하면 육수를 약 1–2큰술 넣으세요. 끓이지 마세요. |
| hi-IN | हरे प्याज़ को हल्के हाथ से मिलाएँ। ज़रूरत हो तो लगभग 1–2 बड़े चम्मच स्टॉक डालें; उबालें नहीं। |
| id-ID | Aduk perlahan daun bawang hingga tercampur. Jika perlu, tambahkan sekitar 1–2 sendok makan kaldu; jangan sampai mendidih. |

Review targets: Arabic verbal quantity still conveys one to two tablespoons and must not invent precision. Chinese `高汤/高湯` can narrow generic stock; Korean `쪽파` can specify a particular scallion variety. Indonesian `daun bawang` is not automatically botanically identical to every English “scallion.” Hindi keeps “स्टॉक,” which may be obscure or read as inventory without cooking context. These flags make source-recipe context necessary in all scripts; Latin-script locales receive the same scrutiny.

### L3 — localized digits and decimal display

Source/context: C12 with rational 3/2. Translation templates: Arabic `معامل الكمية: %1$(factor)@×. تبقى الوحدات كما كُتبت في الوصفة.`; Hindi `मात्रा का गुणक: %1$(factor)@×। मूल इकाइयाँ नहीं बदलतीं।`; Simplified Chinese `缩放比例：%1$(factor)@倍。原文单位保持不变。`; Traditional Chinese `縮放比例：%1$(factor)@倍。原文單位保持不變。`.

Native display matrix must exercise typed 3/2 with `ar-SA` and an Arabic-digit numbering preference, `hi-IN` with both default and explicit Devanagari digit preferences, `ja-JP`, `zh-Hans-CN`, `zh-Hant-TW`, `pt-BR`, and UI/region combinations such as French UI with US formatting. Synthetic visual operands `١٫٥`, `१.५`, `1,5`, and `1.5` are **probe inputs**, not asserted outputs from this app or promises of those locale defaults. Keep rational 3/2 unchanged and do not parse display output back. Also probe 0, 1/2, 1–2, 1,000, 1.000, decimal grouping ambiguity, temperature/unit abbreviations, and a Latin URL in RTL copy. Unicode distinguishes numbering systems and localized decimal/grouping symbols. [Unicode numbers and numbering systems](https://unicode.org/reports/tr35/tr35-numbers.html).

Input parser evaluation is separate: Arabic-Indic and Devanagari ingredient lines may remain useful exact source text with no quantity structure. That preservation is valid behavior, not a failed UI translation. New parser language support needs its own evidence and scope.

### L4 — Arabic plural/operand constraint probe

For C9, Arabic has six cardinal categories; the first generated draft avoids unstable count/noun inflection through complete count-label sentences. Generate each branch as `عدد الملاحظات المحفوظة: %1$(count)lld`. Required category set: zero, one, two, few, many, other. Identical wording is intentional and not evidence that the six categories were accidentally omitted. Probe 0, 1, 2, 3, 11 and 100 with the compiled platform formatter. [CLDR 48 Arabic cardinal rules](https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html#ar).

A contrasting natural-language draft is zero `لم تُحفظ أي ملاحظات.`; one `تم حفظ ملاحظة واحدة.`; two `تم حفظ ملاحظتين.`; few `تم حفظ %1$(count)lld ملاحظات.`; many/other `تم حفظ %1$(count)lld ملاحظة.`. This second draft intentionally demonstrates a current contract conflict: zero/one/two omit the numeric operand and cannot pass the existing identical-signature rule. It is **rejected for import under this proposal**. Either retain the complete count-label wording, or separately design an operand-omission policy with generated-function/formatter tests; do not silently weaken the signature rule for all languages.

## Inspection results and what they establish

| Dimension | This draft's actual evidence | Remaining acceptance |
| --- | --- | --- |
| Candidate output | C1–C12 generated for four first-wave locales; L1/L2 for six later locales and extra Arabic/digit probes | Full corpus and production strings for every selected locale |
| Placeholder fidelity | Author and independent reviewer textual inspections preserve named operands in C7/C8/C9/C11/C12 and L1/L3; rejected Arabic alternative is explicitly marked | Compiled catalog/formatter execution; no automated corpus validator run here |
| Meaning and ambiguity | Author findings plus separate same-model review and documented revision proposals | Review of regenerated candidates and eventual locale acceptance; model judgments are not proficiency scores |
| Plural coverage | Locale-specific draft category sets and representative count domains stated | Exact Apple/Xcode categories, runtime selection and translated grammar on supported OS |
| RTL/CJK/digits | Authored mixed-script and numeric probes ready for a native matrix | No native rendering, line-break, clipping, speech, focus or input evidence collected |
| Cultural representation | No claim; all culinary examples are synthetic translation probes | Separate #127 provenance and knowledgeable human review |

No numeric “quality percentage,” language ranking by model proficiency, or shipping acceptance is inferred from this small corpus. Reviewing the table can expose specific defects; it cannot demonstrate broad fluency. An independent same-model review and its dispositions are recorded in the next section; linguistic and shipping acceptance remain pending.

## Independent review and revision dispositions

A separate **`gpt-6.1-sol` agent invocation** reviewed the complete original draft on 2026-10-07 against the source/context, current contract/validators, localization architecture and release policy. Its [original independent review](global-language-independent-review.md) is preserved with this report, including the disputed C9 proposal and its subsequent disposition below. This is independent execution of the **same model as the generator**, with shared-model blind spots; it is not a native-speaker review, proficiency benchmark, or shipping approval. The original C1–C12 and L1–L4 outputs above are deliberately preserved. Revised candidates below were authored after that review and have not received a second independent linguistic review.

| Rubric dimension | Independent disposition |
| --- | --- |
| Product meaning | Provisional; C10 needs a non-guaranteeing Retry statement |
| Culinary faithfulness | Hold for recipe context; stock/scallion substitutions unresolved |
| Language/register | Hold; glossary drift, submitted-note terms, classifier and stock terms need resolution |
| Named operands | Provisional pass by textual inspection; no compiled evidence |
| Plural wording | Hold; numeric presentation and category selection need separate review |
| Native layout, mixed direction/numerals, assistive presentation | Unverified; the matrix defines work, not passing evidence |
| Resource/content separation | Plan passes on source inspection; no unit conversion or stored-recipe rewrite authorized |

### C9: preserve category structure while fixing numeric copy carefully

The reviewer proposed removing `de` from each generated `many` branch: Portuguese `%1$(count)lld notas salvas`, Spanish `%1$(count)lld notas guardadas`, French `%1$(count)lld notes enregistrées`. Retain these as **review proposals**, not already accepted translations. The general concern is sound: a CLDR category is not an instruction to use any particular preposition, and a digit-rendered operand is not necessarily the word “million.” But verification found a source conflict that prevents treating the Spanish proposal as a proven correction.

RAE's cardinal guidance §6 explicitly gives digit-written `1 000 000 de personas` and `1 200 000 personas`. Therefore the review's assertion that `%lld` digits necessarily require dropping `de` in Spanish is unsupported; the original exact-million `de` candidate is consistent with that cited construction. Do not replace it under a false claim of authoritative correction. [RAE cardinal guidance](https://www.rae.es/dpd/cardinales). OQLF distinguishes French spoken million expressions from digit-written measurement abbreviations, exemplifying `10 000 000 km` without `de`; applying that example to an app's count of notes is an editorial inference, not direct proof of every French noun-count context or `fr-FR` acceptance. [OQLF number-reading guidance](https://vitrinelinguistique.oqlf.gouv.qc.ca/25100/la-prononciation/prononciation-des-nombres/regles-generales-de-lecture-des-nombres).

A neutral revised candidate avoids this lexical-million issue without dropping operands or categories:

| Locale | Revised count-label candidate for every required category |
| --- | --- |
| pt-BR | `Notas salvas: %1$(count)lld` |
| es-ES | `Notas guardadas: %1$(count)lld` |
| fr-FR | `Notes enregistrées : %1$(count)lld` |
| ja-JP | Retain original `other`: `%1$(count)lld件のメモを保存しました` |

For Portuguese/Spanish/French, retain the required one/many/other branches even when revised wording matches. Probe full-digit 0/1/2/1,000,000 output and actual speech; compact or spelled-out number output would require fresh context and review. Neutral copy does not establish native quality, and an awkward zero example is not evidence that CLDR selected an incorrect category. If the product prefers a sentence form over a count label, resolve the locale's written-number grammar independently rather than infer it from English or category names.

### C10: Retry describes an attempt, not a promised success

The original synthetic source “Retry saves that same note” itself overstates success. This is a product-copy defect exposed by evaluation, not merely a target-language mistranslation. Revised source/context: **“The note you asked to save is still waiting to be saved. Retry tries to save that same note again. Edits you make here stay in a separate draft for you to submit later. Leaving this screen keeps the note and the draft.”** The surrounding screen must identify the explicit submission action. No cloud upload, immediate acceptance or stronger crash-durability claim is introduced.

| Locale | Revised model-authored candidate |
| --- | --- |
| pt-BR | A nota que você pediu para salvar ainda aguarda o salvamento. Tentar novamente tenta salvar essa mesma nota de novo. As edições feitas aqui ficam em um rascunho separado, para você salvar depois, quando decidir. Ao sair desta tela, a nota e o rascunho são mantidos. |
| es-ES | La nota que pediste guardar sigue pendiente de guardar. Reintentar vuelve a intentar guardar esa misma nota. Los cambios que hagas aquí permanecen en un borrador independiente, que tendrás que guardar después de forma explícita. Al salir de esta pantalla, se conservan la nota y el borrador. |
| fr-FR | La note dont vous avez demandé l’enregistrement est toujours en attente. Réessayer tente d’enregistrer à nouveau cette même note. Les modifications faites ici restent dans un brouillon distinct, que vous devrez enregistrer ensuite de façon explicite. Quitter cet écran conserve la note et le brouillon. |
| ja-JP | 保存しようとしたメモは、まだ保存を待っています。再試行すると、その同じメモの保存をもう一度試みます。ここで加えた変更は別の下書きとして残り、後から自分で保存する必要があります。この画面を離れても、メモと下書きは保持されます。 |

Disposition: the success guarantee is removed in the revised source and these visible candidates. Network-like “send” verbs are avoided here, including Japanese `送信`. Review must still align the exact screen's Submit/Save action label with these paragraphs and evaluate naturalness: repeated “tenta/intent...” or formal Japanese `試みます` may be wordier than necessary. These are candidates for independent follow-up, not certified final copy.

### Dynamic titles and terminology

Adopt L1's particle-independent Korean **revision candidate**: `레시피를 저장할 수 없습니다: %1$(title)@. 초안은 유지됩니다.` It avoids deriving a Korean suffix from arbitrary authored title text. Retain the original output above as the discovered defect; check the app-wide draft term `초안` and speech/line-breaking before acceptance.

Normalize C3's Portuguese candidate to `Continuar em uma nova sessão de cozinha`; consistency fixes the observed glossary drift without proving that “sessão de cozinha” is the best native term. C12 French `Facteur de quantité : %1$(factor)@×. Les unités d’origine restent inchangées.` is the reviewer's proposed editorial alternative to `Échelle`; its terminology and multiplication display still require layout/linguistic review.

Japanese candidates supply actual material to review: `件` as a note-count classifier, `調理セッション` as a product concept, `取り下げる` for withdrawal, `ブイヨン` for stock, and the original network-suggesting `送信`. The independent review holds classifier/register/stock terms rather than claiming Japanese is good or poor in general. Uncommon culinary vocabulary may be over-specific even when a sentence is grammatical. Neither replacing `ブイヨン` with `だし` nor guessing a “more Japanese” ingredient fixes missing recipe context automatically. Tasting/season-to-taste idioms were not present in this reviewed packet; no proficiency claim for them is made. They should be added to the next recipe-context batch if selected, alongside terms with multiple regional or technique-specific meanings.

The roster remains a stewardship proposal: website percentages match the retrieved snapshot, but they do not prove app demand or regional priority. This review authorizes no shipping expansion. Its concrete outcomes are inspectable revisions and unresolved gates, not a language-quality score.

## Required catalog-contract changes before rollout

The existing Ruby guard compares every translated string-unit path with the English path exactly. The hosted `LocalizationCatalogTests` requires the same plural structure and `one` plus `other` for every language, and hardcodes supported locales/product names. Those are real source limitations, not speculative CLDR incompatibilities.

Replace English category-shape equality with an explicit **locale-and-operand-domain plural contract**. Keep nonplural device/substitution structure intentional and named placeholder types stable. Each plural axis must have the categories required by that selected locale/toolchain, always including `other`; compare each branch's operands to the source message's semantic signature, not to a nonexistent English category at the same path. Persist a reviewed category/count fixture inventory and its reference CLDR version, while compiled tests verify the actual target OS behavior. Stable CLDR 48 is the reference used here; the current search also surfaced CLDR 49 beta, which is not silently adopted as the project's runtime version. [Stable CLDR 48 release](https://cldr.unicode.org/downloads/cldr-48).

Indicative cardinal sets for the selected candidates: Japanese/Chinese/Korean/Indonesian `other`; Arabic `zero/one/two/few/many/other`; Hindi `one/other`; Spanish/French/Portuguese have `one/many/other`, with regional and integer/decimal differences. Do not assume all languages divide 1 from everything else, or that large counts are irrelevant because the interface normally displays small counts. [CLDR 48 plural chart](https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html). Final sets must be demonstrated for supported Apple environments; CLDR reference coverage is not proof of which ICU/CLDR release an OS uses.

Xcode's String Catalog editor can add language-specific plural variants; export/import and comments belong in the review workflow. [Apple String Catalog guidance](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), [Discover String Catalogs](https://developer.apple.com/videos/play/wwdc2023/10155/).

Implementation tasks:

1. Extend `Configurations/LocalizationContract.json` with an explicit reviewed plural-policy section before adding locales. Do not duplicate independent shipping arrays in Ruby and Swift; load the contract or generate fixtures at build time. Review required categories per numeric domain and target toolchain.
2. Change `Tools/check-localization.rb` and its synthetic fixtures together. Preserve manually managed keys, translator context, nonempty reviewed values, named position/name/type signatures, placeholder multiplicity, symbol collisions, retained-key lifecycle and literal-copy guards. Exercise missing `other`, missing required categories, invalid category names, mismatched operand type/order, duplicate/dropped operands and nested plural/device substitutions. New policy must not permit arbitrary source-message changes under “locale variation.”
3. Update hosted `LocalizationCatalogTests` to read the same inventory and plural policy, including product-name decisions. Preserve the copied-raw-catalog build contract, metadata, bundle, Credits and launch-resource validation.
4. Keep `%@`, `%d`, `%lld` support and named signatures bounded. Do not add unsupported printf conversions as incidental translation work. For integer counters, validate actual counts; if a decimal-bearing message later needs plurals, explicitly define its operand domain and fractional examples rather than treating every number as an integer.
5. Add compiled formatter cases for every required category and representative 0/1/2/large/decimal values where valid. Existing generated-symbol availability and type checking stay compiler-owned; rendered output tests establish selection, not linguistic correctness.
6. Keep structurally reviewed strings separate from linguistically accepted evidence. `state: translated` is a catalog build/status requirement, not proof that a native speaker approved it. Record reviewer identity/model, context, concrete findings and accepted revisions in a candidate ledger.

## Repeatable acceptance rubric

Use one rubric for all locales. A locale advances only when each applicable row has evidence or an explicit candidate-specific acceptance of a limitation; no historical alpha waiver is inherited. Unresolved lifecycle, preservation, quantity/negation or named-operand defects are blocking and cannot be accepted as routine limitations. Native/layout deferrals must retain the named release-tier scope and remain obligations before broader acceptance.

| Area | Required result | Reject/hold examples |
| --- | --- | --- |
| Product meaning | Same action/object/lifecycle and draft/retry identity as source | Resume becomes a new cook; Retry submits both drafts; save means only cloud upload; negation lost |
| Culinary faithfulness | Quantities, ranges, approximations, optionality, authored methods and units retained | Tablespoons become milliliters; stock becomes inventory; invented temperature or certainty |
| Language and register | Independent reviewer resolves terminology, idiom, naturalness and regional scope | Unresolved glossary drift; opaque literalism; unsupported claims about a region |
| Deterministic catalog correctness | Complete resources; reviewed nonempty values; required categories; exact named operands | Missing category/resource; malformed operand; translation marked complete without review ledger |
| Native text/layout | Compact and regular products remain readable with actual selected translations, long/doubled strings and accessibility sizes | Clipped destructive/recovery actions; unreachable control; invalid CJK line breaks; combining marks detached |
| Mixed direction/numerals | RTL navigation and authored mixed-script values remain coherent; typed quantities unchanged | Reversed unit/URL/title; text digit replacement changes stored input; imposed regional format |
| Assistive presentation | Spoken labels describe actions/state and retain named top-level semantics | Unclear counters; action label has visual-only context; focus jumps; title speech drops the object |
| Resource/content separation | UI changes do not rewrite stored Recipes, sample identities or units | Locale switch mutates an installed recipe; translation treated as cultural representation |

The independent reviewer should explain the intended operation in their own words, identify omissions/additions, inspect all high-consequence actions and recovery copy, check each plural/count fixture, compare regional vocabulary, and report uncertainties rather than return a blanket “looks good.” Resolve blocking meaning/operand defects before import. Long copy or rare vocabulary can carry a recorded limitation at a proportionate unpublished-slice stage, but major/1.0 acceptance retains the project's full sign-off obligations.

Use Xcode's language/region and doubled/RTL pseudolanguage tools as engineering probes; they do not replace actual script or native-language review. [Apple preparing interfaces](https://developer.apple.com/documentation/xcode/preparing-your-interface-for-localization), [Apple testing internationalized apps](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html). Follow the repository's signed Xcode application-test workflow; UI automation remains named top-level reachability under ADR 0007. Physical/VoiceOver/keyboard walkthrough omissions are recorded, not credited as passes.

## Per-wave implementation and correction plan

### Foundation slice, before any new shipping locale

Pin the implementation candidate, source-key inventory and translation context. Implement the locale-specific plural/operand contract and deterministic fixtures. Audit fallback behavior, native custom-reader hosting of locale/direction/typography, RTL layout and mixed-script output, and authored-content preservation. Review C1–C12 plus later probes independently. Select the roster with the maintainer; this research does not modify the shipping contract.

### First-wave language slices

Deliver `pt-BR` and `ja-JP` in separate reviewable slices or one bounded wave if the actual inventory makes that practical. Translate complete catalog/metadata/launch/Credits resources and full coherent authored sample variants. Maintain new immutable translated sample identities and original family provenance. Check complete resources, compiled plurals/formatters, first-use/new-default names, preserved user names, sample install/uninstall and fallback. Record iPhone compact and Mac regular native layout/accessibility evidence, explicit locale/region/toolchain and remaining omissions. Do not use English fallback strings to inflate a “complete Japanese” claim.

### First-wave regional slices, if selected

Add `es-ES` and `fr-FR` with side-by-side `es-MX`/`fr-CA` review. Reuse only contextually unchanged meanings; review culinary vocabulary and regional register rather than replacing all variants mechanically. Verify region-preference selection and explicit sample defaults, including a locale preference outside the two reviewed regions. Credit this as regional refinement, not two new languages.

### Later global slices

Extend full C1–C12 and the production context packet for `zh-Hans`, `zh-Hant`, `ar`, `ko-KR`, `hi-IN` and `id-ID`. Separate Arabic direction/digit/plural acceptance and Chinese script/region selection from generic locale completeness. Traditional Chinese gets its own linguistic review; it is not accepted via character conversion from Simplified Chinese. Preserve useful source input even when the parser cannot structure it. Reorder these slices when demand or review evidence supports doing so; the small synthetic samples here do not establish comparative model proficiency.

### Ongoing correction intake

Accept language corrections through GitHub issues with locale/tag, semantic key or screen/action, app version, original/proposed wording, explanation and optional synthetic example. Avoid requesting private Recipe content or account screenshots. Reproduce under an explicit locale and context, independently review the correction and regress relevant operands/plurals/layout. Record translation revisions and review status; changed source meaning reopens affected translations. Do not silently rewrite installed recipe variants: correct future authored variants through normal version/identity policy.

Recruit eventual human locale reviewers around demonstrated audience interest and maintenance load, especially for ambiguous cooking terms, RTL speech and cultural framing. [#127](https://github.com/ctwelve/KitchenMemory/issues/127) remains the separate locale-authentic Recipe effort with provenance/license review and knowledgeable human approval. Translated UI and synthetic cooking prose do not satisfy it.

Apply `docs/release-engineering.md` unchanged: unpublished patch slices use scoped integration acceptance; minor releases accept scoped programmatic review; major/leaving-beta/1.0 preparation keeps complete localization and explicit human sign-off. LLM-assisted production is permitted by current project policy. A reviewed research PR resolves discovery; it does not complete the selected-language delivery gate, authorize release publication, or waive major-release acceptance.

## Decision requested

Choose the initial language wave (`pt-BR`/`ja-JP` recommended), whether to include the regional `es-ES`/`fr-FR` portion, and the prioritized later global set. Approve the intended sample fallback defaults and the plural-contract foundation scope separately from accepting any generated wording. Acceptance of a roster starts implementation; it does not certify this corpus or the resulting UI.
