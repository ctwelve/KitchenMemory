# GPLv3 and paid App Store distribution

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors
SPDX-License-Identifier: MIT
-->

- Status: Historical research complete; project licensing superseded by
  [ADR 0015](../adr/0015-adopt-mit-license.md)
- Research date: 2026-08-29
- Scope: A `GPL-3.0-only` Kitchen Memory binary sold through the iOS/iPadOS
  App Store and/or Mac App Store

**Bottom line — conditional:** GPLv3 expressly permits charging for copies, but
the publicly verifiable App Store agreement stack still appears to attach
non-transferability, Usage Rules, and Apple security controls to the copy in
ways that may be GPLv3 section 10 “further restrictions”; a paid
`GPL-3.0-only` App Store release is therefore not a defensible plan unless the
account holder first verifies the binding English agreements and obtains legal
confidence—preferably written confirmation from Apple—that an accepted custom
EULA and distribution arrangement preserve every GPL right.

This is research, not legal advice. The conclusion concerns an App Store copy
that remains `GPL-3.0-only`. A copyright holder able to grant a separate license
or exception presents a different rights question and would first require a
complete ownership audit.

Kitchen Memory subsequently adopted the MIT License after its sole copyright
holder confirmed authority to relicense the project. This note remains the
record of why a GPL-only App Store release was rejected; it is not the current
project-license decision.

## Decision summary

1. **Selling is allowed by GPLv3.** Section 4 permits “any price or no price.”
   GNU's FAQ likewise says a distributor may sell copies and need not also
   offer them to the public without charge. The buyer may nevertheless
   redistribute their copy, free or for a fee.
2. **Payment activates more Apple terms, not more GPL restrictions.** A free
   App Store app uses Schedule 1. A paid app additionally requires Schedule 2,
   which supplies pricing, collection, commission, tax, and paid-delivery
   machinery. Apple's commission is compensation for its store service; it is
   not, on the public text, a fee for a recipient's later exercise of GPL
   rights.
3. **The hard problem exists for free and paid App Store apps.** Both paths
   authorize Apple to add its Security Solution, make Apple the developer's
   agent or commissionaire, and place use under either Apple's Standard EULA or
   an Apple-constrained custom EULA. The Standard EULA expressly forbids
   redistribution and modification. A custom EULA avoids that exact Standard
   EULA language, but Apple still requires a non-transferable,
   Usage-Rules-limited license and does not publicly promise that GPL rights
   override the store's security and account rules.
4. **Apple recognizes FOSS but does not publish a complete GPL safe harbor.**
   The program agreement requires developers to comply with FOSS licenses, and
   the Standard EULA has a narrow open-source exception to its
   reverse-engineering sentence. Neither provision expressly removes the
   separate no-redistribution language, the mandatory minimum EULA scope, the
   Usage Rules, or the Security Solution.
5. **The source-code obligation is manageable but must be designed.** For an
   App Store network download, GPLv3 section 6(d), not the physical-product
   written-offer route, is the natural option: give equivalent, no-additional-
   charge access to the exact Corresponding Source and clear directions next
   to the binary. A source repository alone is not enough unless it preserves
   the exact complete source for the shipped binary, build/install scripts,
   and included non-System-Library dependencies for as long as required.
6. **iOS/iPadOS and Mac App Store licensing is materially the same.** iOS and
   iPadOS make modified installation more constrained in practice. The Mac App
   Store adds sandbox, packaging, and store-only-update rules. Those platform
   differences do not remove the shared EULA/Security Solution issue. Direct
   Developer ID Mac distribution avoids the App Store customer terms and is a
   materially cleaner GPL path.
7. **Do not treat App Review acceptance as a license opinion.** Apple may
   reject an app even if it meets stated requirements, and an approval would
   not adjudicate GPL compliance. Conversely, a theoretically GPL-compliant
   custom EULA is not useful unless Apple accepts it and the account's binding
   agreements permit the resulting delivery.

## Prominent source-version limitation

Apple states that the English agreements accepted in the developer account are
the binding and most up-to-date versions. Those account-specific accepted texts
were not available to this research. The public materials also disagree about
their own dates:

- Apple's public English Apple Developer Program License Agreement PDF and
  consolidated HTML end with identifier `LYL255`, dated **August 18, 2026**.
- The consolidated HTML immediately presents a Schedule 2 after that date, but
  Apple's separately linked Schedule 2/3 PDF is still `v126`, dated
  **December 17, 2025**.
- The separately linked paid-agreement exhibits PDF is dated
  **August 27, 2026**, while the agreements index labels the exhibits “Last
  update: January 29, 2026.”
- The agreements index labels the program agreement “Last update: June 18,
  2026,” although its linked PDF is dated August 18.

The public terms therefore support a serious issue-spotting conclusion, not a
release-time legal clearance. Before relying on this report, the account holder
must download the **active** English Apple Developer Program License Agreement,
Paid Applications Agreement, and paid exhibits from the developer account and
App Store Connect, record their identifiers/effective dates, and compare the
clauses listed under [Release-time verification](#release-time-verification).
Apple's own App Store Connect help explains how to download the active
agreements.

## Source and version table

| Source | Public version or date used | Role and limitation |
| --- | --- | --- |
| [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.html) | Version 3, June 29, 2007 | Controlling project license text; sections 1, 3, 4, 6, 10, and 12 |
| [GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html) | Accessed 2026-08-29; page exposes no controlling license version | Official license-steward explanation for charging, redistribution, network source, exact source, and System Libraries |
| [Apple agreements index](https://developer.apple.com/support/terms/) | Public index accessed 2026-08-29; displayed dates conflict with linked files | States that the account-accepted English text is binding and latest |
| [Apple Developer Program License Agreement](https://developer.apple.com/support/downloads/terms/apple-developer-program/Apple-Developer-Program-License-Agreement-English.pdf) | `LYL255`, August 18, 2026 | Public program agreement and Schedule 1; linked PDF does not include the separately accepted paid schedules |
| [Consolidated program-agreement HTML](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) | Displays `LYL255`, August 18, 2026, then Schedules 2 and 3 | Searchable public text; the displayed paid schedule is newer than the separately linked paid PDF, so it is not treated as proof of the account's accepted text |
| [Paid Applications Agreement PDF](https://developer.apple.com/support/downloads/terms/schedules/Schedule-2-and-3-English.pdf) | `v126`, December 17, 2025 | Separately linked public Schedules 2 and 3; stale relative to the consolidated page/account warning |
| [Paid-agreement exhibits](https://developer.apple.com/support/downloads/terms/exhibits/Exhibits-to-Schedule-2-and-3-English.pdf) | August 27, 2026 | Exhibit D contains current publicly linked minimum custom-EULA terms |
| [Apple Media Services Terms](https://www.apple.com/legal/internet-services/itunes/) | Last updated September 15, 2025 | Customer transactions, Usage Rules, App Store licensing, and embedded Standard EULA |
| [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) | No displayed revision date; accessed 2026-08-29 | Standalone rendering of the customer EULA also embedded in the Media Services Terms |
| [Minimum EULA terms](https://www.apple.com/legal/internet-services/itunes/dev/minterms/) | No displayed revision date; accessed 2026-08-29 | Public web rendering; paid Exhibit D is the dated paid-app source |
| [Custom-EULA instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/) | No displayed revision date; accessed 2026-08-29 | Confirms a custom EULA can supersede the Standard EULA by selected region |
| [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Last updated June 8, 2026 | Review discretion, signing/update constraints, and Mac-specific rules |

## Clause-by-clause matrix

| Question | GPLv3 rule | Apple rule | Assessment for Kitchen Memory |
| --- | --- | --- | --- |
| May the developer charge? | Section 4: “any price or no price”; [GNU FAQ: selling copies](https://www.gnu.org/licenses/gpl-faq.html#DoesTheGPLAllowMoney) | Program Agreement purpose and §7.1 require Schedule 2 before charging; Schedule 2 §§3.1 and 3.4 provide price tiers, collection, and commission | **Compatible in itself.** Price and commission are not the conflict. A buyer remains free under GPL to redistribute elsewhere. |
| Does free versus paid change the GPL? | No. The same sections 4, 6, and 10 apply | Schedule 1 §1.5 is no-charge; Schedule 2 is required for a paid app. Both use the shared program terms, Security Solution, and EULA structure | **No GPL difference; an Apple-contract difference.** Paid adds Schedule 2, but the apparent further-restriction problem also exists for free App Store delivery. |
| Who conveys the app? | “Convey” includes propagation that enables another party to receive a copy; §10 automatically licenses each recipient | Schedule 2 §§1.1–1.3 appoint Apple as developer's agent/commissionaire and state Apple acts “for You and on Your behalf”; §3.1 says Apple hosts and allows downloads on the developer's behalf. Media Services Terms §O says third-party apps are licensed by the App Provider, even where an Apple entity is merchant of record | **The developer cannot safely characterize Apple as an unrelated downstream distributor.** Kitchen Memory is principal/licensor; Apple performs delivery on its behalf. |
| Standard EULA: transfer and redistribution | Section 10 gives rights to run, modify, and propagate and prohibits further restrictions | Standard EULA §a calls the license nontransferable and says users “may not transfer, redistribute or sublicense” the app | **Direct apparent conflict.** GPL sublicensing is itself unnecessary, but redistribution is an express GPL right. Do not use the Standard EULA for a GPL-only App Store copy. |
| Standard EULA: reverse engineering and modification | Sections 2 and 10 affirm running/modification; §3 protects circumvention needed to exercise GPL rights | Standard EULA §a prohibits copying, reverse engineering, source derivation, modification, and derivatives, but excepts what open-source component licenses permit | **Partial counterevidence, not a complete cure.** The carve-out can preserve GPL modification/reverse-engineering rights at least for an included GPL component. It grammatically modifies that sentence only; it does not expressly override the preceding redistribution ban, nontransferability, or Usage Rules. Whether “components included with” includes the whole GPL app is also not stated. |
| Custom EULA | Sections 7 and 10 allow additional permissions, but non-permissive additions outside §7 are further restrictions | Schedule 2 §4.2 allows a custom EULA but requires all Exhibit D minimum terms and no inconsistency with them. Exhibit D §§1–2 require an agreement between developer and user, no Usage-Rule conflict, and a non-transferable license limited to Apple-branded products the user owns/controls. App Store Connect permits a custom EULA by region | **Necessary but not proven sufficient.** A custom EULA can state that GPLv3 rights control and avoid the Standard EULA's express redistribution ban. The public minimum terms still appear to limit the license in ways broader than GPL. An argument that the Apple “license to use” is separate from the automatic GPL license is plausible but untested here and not confirmed by Apple. |
| Device/account limits and noncommercial use | GPL gives unrestricted permission to run an unmodified copy and does not confine propagation to Apple accounts/devices | Media Services Terms §F applies personal/noncommercial use by default, account/device association limits, a 90-day reassociation rule, and a ban on circumventing security technology. Exhibit D incorporates Usage Rules. App-specific rules add enterprise-device licensing | **Apparent restriction, with a possible service/app distinction.** Apple may view these as limits on its store service and authenticated downloads rather than on independently obtained GPL copies. The public text nevertheless defines Apps as Content and makes the EULA subject to Usage Rules, so that distinction is not secure enough for release clearance. |
| FairPlay/Security Solution | Sections 3 and 10 prevent the conveyor from using legal or contractual restrictions to block GPL exercise | Program definition calls the Security Solution Apple's FairPlay system applied to App Store apps to administer standard usage rules. Schedule 2 §1.2(c) has the developer authorize Apple to add it. Program §5.1 requires app/FOSS licenses not to conflict with signing or content protection and not to require Apple keys or procedures | **Material unresolved conflict.** Apple expressly recognizes that licensing and content protection can conflict and reserves the ability to stop distribution. GPL probably does not require disclosure of Apple's own secret keys, especially where Installation Information is not triggered, but developer-authorized FairPlay plus anti-circumvention terms may still restrict redistribution or modified use. |
| Receipt/signature requirements | Legal GPL rights do not guarantee store services; section 6 can require Installation Information only in the defined User Product transaction | Program purpose and §§5.1, 6.9 say App Store apps are digitally signed by Apple. The reviewed public terms did not establish a general requirement that this paid app implement its own receipt check. Mac Review Guideline 2.4.5(vi) forbids developer license keys and developer copy protection | **Do not overstate receipts.** Apple signing is certain. A Kitchen Memory receipt gate is not presently required by the sources and should not be added as a licensing control without a fresh GPL analysis. |
| Object code and source | Section 6 requires machine-readable Corresponding Source through one listed route | Apple delivers an optimized/signed object-code app and may perform app thinning; App Store Connect provides metadata fields and a custom EULA, but Apple does not promise to host Corresponding Source | **Manageable with deliberate metadata and hosting.** Preserve source for every shipped thinned build from the same source state; Apple-specific repackaging need not make the developer reproduce Apple's signature, but the developer must provide everything it controls that is needed to build and modify the work. |
| Network-source route | Section 6(d) permits charged object-code access if equivalent source access is offered through the same place at no further charge; source may be on another server with clear directions next to the binary. [GNU FAQ](https://www.gnu.org/licenses/gpl-faq.html#SourceAndBinaryOnDifferentSites) confirms this | App Store product metadata can include a custom EULA and URLs, but public documentation does not promise a dedicated Corresponding Source field or rule that source directions will appear literally next to the download control | **Feasible but must be confirmed.** Put a durable exact-source URL in the custom EULA, product description or closest accepted product-page field, and the in-app Legal screen. Confirm with Apple and counsel that the rendered product page satisfies “clear directions next to the object code.” |
| Physical written offer | Section 6(b) applies when object code is conveyed in or with a physical product; §6(c) is occasional, noncommercial pass-through | An App Store download is a network delivery | **Not the natural route.** A three-year written offer does not substitute for section 6(d) in an ordinary paid App Store download. |
| Installation Information/anti-tivoization | Section 6 requires Installation Information only when object code is in/with/for a User Product **and** the same transaction transfers possession and use of that User Product. §3 separately waives anti-circumvention power for GPL exercise | App Store sale transfers an app license to someone who already owns or controls an Apple device; Apple signing limits installation of modified builds, especially on iOS/iPadOS | **Likely not triggered by the app sale alone, but interpretation remains unsettled.** The sale does not transfer the iPhone, iPad, or Mac. GPL still grants legal modification/propagation rights; it does not clearly force Apple to sign a fork or grant CloudKit/App Store entitlements. Do not promise modified binaries can retain Apple services. |
| Apple system frameworks | Section 1 excludes qualifying System Libraries from Corresponding Source; [GNU FAQ](https://www.gnu.org/licenses/gpl-faq.html#SystemLibraryException) says proprietary libraries may be linked if they meet the definition | Program §3.3.4(A)(v) requires FOSS compliance and forbids making non-FOSS Apple Software subject to FOSS obligations | **Plausible, not automatic.** OS-provided Foundation, SwiftUI, AppKit/UIKit, and similar public system frameworks are strong System Library candidates. Audit every linked and embedded component. A framework copied into the app, an application-specific non-System Library, or a package dependency needs its own license/source treatment. |
| Inability to satisfy both | Section 12 says contradictory external obligations do not excuse GPL compliance; if both cannot be satisfied, do not convey | Program §5.1 requires the developer to notify Apple of license/signing conflicts and lets Apple stop distribution; §6.9 permits rejection even if requirements are met | **Controlling release gate.** Ambiguity is not permission to submit and hope review resolves it. If the accepted Apple terms and GPL cannot be satisfied simultaneously, do not convey the GPL-only app through the App Store. |

## The commercial terms are not the GPL problem

GPLv3 deliberately separates freedom from price. Section 4 authorizes charging
for each copy. The GNU FAQ adds two practical consequences:

- the distributor need not also give the program to the general public without
  charge; and
- once a buyer receives a copy, the GPL permits that buyer to redistribute it,
  with or without charging.

That means Kitchen Memory may set an App Store price. Schedule 2 then makes
Apple the collection agent or merchant of record, permits the developer to
choose a price tier, and allows Apple to deduct its commission. None of those
terms, standing alone, charges a recipient for later modifying or propagating
the GPL work. GPL section 10's example prohibition on a fee “for exercise” of
GPL rights should not be confused with the permitted initial sale price.

The price also does not create exclusivity. A purchaser may lawfully post a
GPL-compliant copy elsewhere. The project cannot promise that every recipient
will have to purchase through the App Store.

## Why Apple is part of Kitchen Memory's conveyance

The agreement structure is unusually important here. Schedule 2 does not
describe Apple as buying a binary and independently redistributing it. The
developer appoints Apple as agent or commissionaire, Apple markets and makes
downloads available “for You and on Your behalf,” and Apple hosts the app on
the developer's behalf. Apple Media Services Terms say the App Provider grants
the third-party app license, even when an Apple entity acts as merchant of
record.

Accordingly, a practical GPL analysis should treat Kitchen Memory as a
conveyor and licensor. The project authorizes Apple to add the Security
Solution and present user terms. It cannot safely answer a section 10 concern
by saying Apple, rather than the project, imposed every restriction.

## Standard EULA, FOSS clauses, and the custom-EULA gap

### What supports compatibility

Apple does not categorically forbid free software:

- The program agreement defines FOSS to include GPL software and
  §3.3.4(A)(v) tells the developer to comply with all applicable FOSS terms.
- The Standard EULA's no-copy/no-reverse-engineering/no-modification sentence
  expressly yields where the license of an included open-source component
  permits those acts.
- Schedule 2 §4.2 and App Store Connect allow a custom EULA to supersede the
  Standard EULA in selected regions.
- Apple remains the developer's agent and does not take ownership of the app.

These are meaningful counterweights to a categorical “GPL apps are forbidden”
claim.

### What they do not cure on their face

The same Standard EULA separately says the license is nontransferable and the
user may not transfer or redistribute the application. The open-source proviso
appears only at the end of the later reverse-engineering/modification sentence.
It does not say that open-source terms override every preceding EULA term.

A custom EULA is therefore necessary for any credible GPL-only submission, but
the mandatory minimum terms still say each license must be limited to a
non-transferable right to use the app on owned or controlled Apple products and
as permitted by Apple's Usage Rules. A custom EULA might distinguish:

- the account-bound right to obtain and use Apple's App Store service and
  Apple-signed build; from
- the GPL license automatically received from Kitchen Memory's original
  licensors to run, modify, and propagate the covered work outside that
  service.

That distinction is a plausible drafting theory, not a conclusion established
by Apple's public text. Exhibit D speaks broadly of “each license” granted for
the app, and the Usage Rules classify apps as Content. Apple also requires the
developer's licensing terms not to conflict with its signing/content-protection
system. A unilateral custom EULA cannot waive Apple's separate Media Services
contract with the customer.

## Corresponding Source plan for an App Store sale

If the EULA/security issue is cleared, Kitchen Memory should use a release-
specific section 6(d) plan:

1. Archive the exact accepted source commit and immutable release tag.
2. Publish a complete machine-readable source archive at no charge. It must
   include the preferred source for all shipped Kitchen Memory code, the Xcode
   project, build scripts/configuration, package resolution, and source for any
   included dependency that is not excluded as a System Library or another
   section 1 exclusion. A pointer only to a moving branch is insufficient.
3. Keep complete sources, not only diffs. The source must correspond to the
   submitted binary version. Reproducibility to the identical signed hash is
   not necessarily possible because Apple performs signing, optimization, and
   possibly app thinning; that does not remove the obligation to provide the
   source and scripts under the developer's control.
4. Put clear source directions in every location Apple will accept closest to
   acquisition: the custom EULA and product-page metadata first, with the same
   link in Kitchen Memory's Legal/About screen. The current Legal screen should
   continue to expose copyright, warranty, license, and source information.
5. Keep the source available for at least as long as Apple offers the binary
   and for any longer period required by the chosen section 6 route. Withdrawal
   from sale does not undo obligations for copies already conveyed.
6. Do not use the physical-product written-offer alternatives as a shortcut for
   a network-only App Store download.

Public GitHub source can host Corresponding Source on a different server. GNU's
FAQ confirms that arrangement, provided instructions are clear and the exact
source stays available. Existing public source is helpful but does not cure a
missing release-specific source package or directions, and it does not cure a
section 10 EULA conflict.

## Installation, signing, and modified builds

### Confident conclusions

- GPLv3 gives recipients legal permission to modify and propagate Kitchen
  Memory.
- App Store builds are selected and digitally signed by Apple. The developer
  authorizes Apple to add FairPlay as the Security Solution.
- The App Store transaction transfers an app copy/license; it does not transfer
  possession and use of the recipient's iPhone, iPad, or Mac. The most natural
  reading is therefore that GPL section 6's User Product Installation
  Information condition is not triggered by this app purchase alone.
- GPL does not require Apple to grant a modifier the original developer's
  signing identity, App Store listing, receipts, private CloudKit container, or
  other Apple service credentials.

### Unsettled points

- On iOS/iPadOS, a recipient can edit source but cannot ordinarily replace the
  App Store copy with an arbitrary modified binary under the original identity.
  Development signing and region-specific alternative distribution do not
  reproduce the original App Store entitlement set. Whether the developer's
  authorization of Apple signing/FairPlay itself imposes a section 10 further
  restriction, despite section 6's likely inapplicability, is not resolved by
  the reviewed primary texts.
- On macOS, a modifier can more readily build and sign a separate application,
  but the Mac App Store still uses the same Security Solution and EULA stack.
  Review Guideline 2.4.5 requires sandboxing, Xcode packaging, App Store-only
  updates for the store build, and no developer license screen/key/copy
  protection. Those review rules affect the store artifact; they do not erase
  GPL rights to distribute an independently built fork.
- Apple program §5.1 specifically refuses any inference that FOSS requires
  Apple to disclose signing/DRM keys or procedures. Kitchen Memory should not
  make that demand unless qualified counsel concludes section 6 requires it.

## Apple frameworks and package linkage

GPLv3 section 1's System Libraries definition is the likely bridge to public
Apple frameworks. GNU's official FAQ confirms that a GPL program may link to a
proprietary System Library when the library satisfies the definition. For this
project:

- dynamically linked OS frameworks such as Foundation, SwiftUI, AppKit/UIKit,
  and other ordinarily installed platform components are strong candidates;
- Xcode and ordinary build tools can fall outside Corresponding Source as
  general-purpose tools;
- a copied/embedded framework is not automatically a System Library;
- application-specific Apple services and every non-Apple package still need a
  component-specific analysis; and
- Defaults, currently linked by the app, is not an Apple System Library. Its
  license is permissive, but the release source/notice inventory still needs
  its exact source and terms handled consistently with GPL section 6 and the
  repository's dependency procedure.

Do not replace that audit with “Apple ships it, therefore it is a System
Library.” The definition, the binary's actual linkage/embedding, and the exact
release package control. Apple's own FOSS clause also forbids using FOSS in a
way that would subject non-FOSS Apple Software to FOSS obligations, making the
System Library analysis a release prerequisite rather than a formality.

## Platform comparison

| Route | GPL/App Store terms | Modified-build reality | Practical position |
| --- | --- | --- | --- |
| iOS/iPadOS App Store, paid | Shared Program Agreement + Schedule 2 + Exhibit D + Media Services/Usage Rules + Standard or custom EULA | Apple signing and entitlements make replacement builds difficult; alternative distribution varies by region and does not preserve the original identity/services | Conditional and legally unresolved without account-text review and accepted GPL-preserving custom EULA |
| Mac App Store, paid | Materially the same agreement, Schedule 2, Security Solution, Usage Rules, and EULA | Independent forks are technically easier, but store builds are sandboxed and updates must use the Mac App Store | Same core licensing concern; Mac openness does not cure the store contract |
| Direct Developer ID Mac download | Program terms for certificates/notarization, but no App Store customer EULA, Store Usage Rules, Schedule 2 sale machinery, or App Store Security Solution attached to the download | Users can obtain source and build/sign a distinct copy more directly | Existing and materially cleaner GPL distribution route; charging directly is permitted by GPL, subject to ordinary commerce law |

## Existing Kitchen Memory facts

- At the time of this research, [ADR 0002](../adr/0002-gpl-3-only.md) adopted
  `GPL-3.0-only` and required a license review against the Apple agreement in
  force at release. [ADR 0015](../adr/0015-adopt-mit-license.md) later
  superseded that decision.
- At the time of this research, the repository license and project notices
  consistently identified `GPL-3.0-only` rather than `GPL-3.0-or-later`.
- [COPYRIGHT](../../COPYRIGHT) says individual contributors retain copyright in
  their contributions. Therefore, any App Store-specific exception or separate
  license would require authority from all relevant rightsholders.
- Git currently reports one author identity across reachable history. That is
  a useful signal, not a copyright audit: Git authorship does not settle
  employment rights, assets, generated material, imported code, aliases, or
  contributions received outside Git.
- The [0.1 release evidence](../release-evidence-0.1.md) records a public,
  signed, notarized Developer ID macOS artifact distributed directly from the
  GitHub prerelease, with a GPL notice and immutable source tag.
- The repository records no public iOS artifact or TestFlight group. Its cloud
  archives are prepared for App Store Connect, but no post-action distributes
  them. This report therefore evaluates a future distribution choice; it does
  not identify a past App Store GPL violation.
- The existing direct 0.1 GPL copies remain governed by the license conveyed
  with them. Their existence, availability, or zero price does not decide the
  terms for a later App Store copy.

## Theoretical compliance, Apple acceptance, and a defensible plan

These are three different gates:

1. **GPL theory:** Can every recipient exercise GPL rights without a further
   restriction, and can the project meet section 6 for the exact binary?
2. **Apple contract:** Do the active, account-accepted English agreements permit
   the proposed custom EULA and GPL distribution, including Apple's Security
   Solution and Usage Rules?
3. **Apple review:** Will Apple select this particular app and metadata for
   distribution? Program §6.9 reserves rejection discretion even when stated
   requirements are met.

A defensible `GPL-3.0-only` App Store plan would require all of the following:

- the active-agreement comparison below;
- a custom EULA applied in every storefront, expressly preserving recipients'
  GPLv3 rights and making clear that Apple account/service rules do not limit
  exercise of those rights in copies obtained or conveyed outside the service;
- written Apple confirmation, or qualified legal advice based on the accepted
  terms, that the custom EULA is allowed and that FairPlay/Usage Rules do not
  add restrictions to GPL exercise;
- a release-specific section 6(d) Corresponding Source package and durable
  product-page directions;
- an exact System Library, package, notices, entitlement, signing, and source
  audit; and
- App Review notes that disclose the GPL license, custom EULA, source route,
  and absence of developer-added copy protection rather than asking ordinary
  review acceptance to silently answer the license question.

If Apple will not confirm that structure, or the accepted terms still require
the project to impose incompatible restrictions, GPLv3 section 12 supplies the
answer: do not convey the `GPL-3.0-only` binary through the App Store. Continue
direct Mac distribution while the project separately decides whether a
rightsholder-approved exception or different licensing model is desirable.

## Release-time verification

The account holder should perform this check immediately before any App Store
submission, because Apple can change program requirements:

1. In the developer account, download the active English **Apple Developer
   Program License Agreement** and record its identifier and effective date.
2. In App Store Connect → Business → Agreements, download the active English
   **Paid Applications Agreement** and all exhibits; do not rely on the public
   `v126` PDF if the account offers a newer text.
3. Compare at minimum:
   - definitions of `FOSS`, `Licensed Application`, and `Security Solution`;
   - Program §§3.3.4(A)(v), 5.1, 6.2, 6.9, and 7.1;
   - Schedule 1 §§1.1–1.3, 3.1–3.3 and Exhibit B §§1–2;
   - Schedule 2 §§1.1–1.3, 2.1, 3.1, 4.1–4.3, and Exhibit D §§1–2;
   - every clause authorizing FairPlay, app thinning, signatures, receipts,
     account/device rules, or store-only updates; and
   - any new FOSS/open-source exception.
4. Capture the then-current English Apple Media Services Terms, Standard EULA,
   minimum EULA terms, App Review Guidelines, and rendered custom EULA for every
   selected storefront.
5. Ask Apple in writing whether the proposed custom EULA may say GPLv3 controls
   recipients' copying, modification, and redistribution rights notwithstanding
   the minimum non-transferable license and Usage Rules, and whether Apple will
   deliver the app without applying contractual or technical restrictions to
   those GPL rights.
6. Have qualified counsel compare Apple's written answer and accepted terms to
   GPLv3 §§3, 6, 10, and 12, plus the complete Kitchen Memory rights and
   dependency audit.
7. Re-run the source-delivery and linked-framework audit against the exact
   submitted archive, product page, and immutable source tag.

Until that comparison is complete, the answer is not “GPL forbids selling” and
not “Apple supports FOSS, so it is fine.” It is: **charging is allowed, but a
GPL-only App Store conveyance remains conditional on resolving Apple's
additional distribution and customer-use terms.**
