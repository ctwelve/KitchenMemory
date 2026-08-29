# Alamofire for recipe retrieval

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Research complete; do not adopt for the current recipe fetcher
- Researched: 2026-08-29
- Scope: Whether Alamofire 5.12.0 should replace the direct `URLSession`
  transport used to retrieve recipe documents

## Recommendation

Do **not** add Alamofire for the current recipe-retrieval surface.

Alamofire is a capable, current, permissively licensed wrapper over
`URLSession`, and its supported Apple platforms are compatible with Kitchen
Memory. It would become attractive if Kitchen Memory acquired a broader HTTP
client problem: several APIs, authenticated requests and token refresh,
standardized request adaptation and retry, uploads or downloads, or shared
network observability. The present problem is one bounded, person-initiated,
credential-free `GET` for untrusted HTML. Kitchen Memory already exposes that
operation through the small `RecipeDocumentLoading` seam, while its transport
implementation is mostly product-specific safety policy rather than generic
HTTP ceremony. [Alamofire feature and platform summary](https://github.com/Alamofire/Alamofire/tree/5.12.0#features)
· [Current loader](../../KitchenKit/Import/RecipeURLImporter.swift)
· [Current import architecture](../web-import.md#pipeline)

Using Alamofire would not remove the important code. Kitchen Memory would still
need to own structural URL validation, validation of every redirect, the exact
redirect count, reconstruction of a minimal request, refusal of ambient
credentials, the 2 MiB streaming limit, final-URL attribution, cancellation,
and the one-operation deadline. Alamofire can host several of those policies,
but that would move them behind its request, delegate, and callback model while
adding a runtime dependency. No current feature compensates for that extra
layer.

This is a decision about the current transport, not a rejection of Alamofire in
general. Revisit under the concrete conditions at the end of this report.

## The current retrieval contract

`URLSessionRecipeDocumentLoader` currently creates a fresh ephemeral session
for each import and explicitly removes its URL cache, cookie store, and
credential store. It accepts only structurally public-looking HTTPS URLs,
rejects credentials, literal and ambiguous numeric addresses, local-looking
hostnames, nonstandard ports, and oversized URL strings, and applies the same
policy to every redirect. It allows the operating system to perform ordinary
server-trust evaluation but cancels every other authentication challenge.
[Loader and URL policy](../../KitchenKit/Import/RecipeURLImporter.swift)
· [Authentication and redirect delegate](../../KitchenKit/Import/RecipeURLRedirectController.swift)

An accepted redirect is not Foundation's proposed request carried forward. The
loader reconstructs a bodyless `GET` containing only Kitchen Memory's `Accept`
and `User-Agent` headers, so cookies, authorization, referrers, bodies, and
publisher-supplied headers cannot cross the boundary. Redirects stop after five
by default. The response must be successful HTML or XHTML, and is consumed as
an asynchronous byte sequence into a buffer capped at 2 MiB. Task cancellation
explicitly cancels the underlying transfer. Both request-idle and whole-resource
timeouts are 20 seconds by default; Apple defines the resource timeout as the
maximum duration for the entire resource transfer, beginning when the request
starts. [Current loader](../../KitchenKit/Import/RecipeURLImporter.swift)
· [Apple: resource timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforresource)
· [Apple: asynchronous bytes](https://developer.apple.com/documentation/foundation/urlsession/bytes%28for%3Adelegate%3A%29)

These details are enforced without live websites. The deterministic tests
inject a custom `URLProtocol`, exercise exact and over-limit declared and
streamed bodies, transport errors, cancellation, fresh hardened configurations,
hostile redirect proposals, redirect limits, and session- and task-level
authentication challenges. The parser and product logic depend on
`RecipeDocumentLoading`, so most import tests use an in-memory loader and know
nothing about the HTTP implementation. [Transport tests](../../KitchenKitTests/Import/URLSessionRecipeDocumentLoaderTests.swift)
· [Policy tests](../../KitchenKitTests/Import/URLSessionRecipeDocumentLoaderPolicyTests.swift)
· [Boundary tests](../../KitchenKitTests/Import/RecipeURLImporterTests.swift)
· [Delegate tests](../../KitchenKitTests/Import/RecipeURLRedirectDelegateTests.swift)

That narrow interface is already the most valuable abstraction a networking
library would normally provide. Replacing its implementation would not simplify
the importer, persistence, application, or fixture strategy.

## What Alamofire would provide

Alamofire 5.12.0 is the latest published release as of the research date. It
was released on 2026-05-04. Its documented feature set includes chainable
request/response APIs, Swift concurrency, response validation and serializers,
request adapters and retriers, authentication, progress, task metrics, redirect
and cache handlers, downloads/uploads, and optional certificate or public-key
pinning. It remains built on Apple's `URLSession`, so it does not substitute a
different DNS, TLS, proxy, or HTTP implementation.
[5.12.0 release](https://github.com/Alamofire/Alamofire/releases/tag/5.12.0)
· [Alamofire features](https://github.com/Alamofire/Alamofire/tree/5.12.0#features)
· [Alamofire's URLSession foundation](https://github.com/Alamofire/Alamofire/tree/5.12.0#communication)

For recipe retrieval, the relevant conveniences are real but modest:

- `validate()` can check the usual 200–299 status range and match response
  content type against the request's `Accept` header. Kitchen Memory already
  performs those two checks directly and maps them to stable domain-facing
  errors. [Alamofire `DataRequest` validation](https://alamofire.github.io/Alamofire/Classes/DataRequest.html)
- `RedirectHandler` can follow, deny, or modify each proposed redirect.
  Kitchen Memory could place its existing destination check and minimal-request
  reconstruction in a custom handler. The documented built-in behaviors do not
  supply Kitchen Memory's redirect counter, URL policy, or header allowlist, so
  those remain project code. [Alamofire redirect handler](https://alamofire.github.io/Alamofire/Protocols/RedirectHandler.html)
- `DataStreamRequest` exposes response chunks and a cancellation token. It
  could implement a bounded accumulator. This would still require custom count,
  overflow, cancellation, response-validation, and error-mapping logic.
  [Alamofire streaming request](https://alamofire.github.io/Alamofire/Classes/DataStreamRequest.html)
- `RequestInterceptor`, `RetryPolicy`, `EventMonitor`, metrics, progress,
  serializers, and compact async response APIs are useful for a larger client.
  The present fetch has no authentication, request parameters, JSON API model,
  upload, download, retry policy, or cross-request metrics requirement.
  [Alamofire `Session`](https://alamofire.github.io/Alamofire/Classes/Session.html)

Certificate pinning is not a current benefit. A recipe importer contacts
arbitrary publisher hosts, so Kitchen Memory has no stable publisher certificate
or key set to pin. Its deliberate policy is ordinary system trust evaluation,
which Alamofire also ultimately delegates to Foundation unless a custom
`ServerTrustManager` is installed.

## Why the byte boundary is decisive

The normal Alamofire `DataRequest` is not a safe replacement for the current
bounded stream. Alamofire's source shows that `DataRequest` appends every
received `Data` chunk to an in-memory `Data` value, then validates and serializes
after collection. Checking the resulting size would therefore happen after an
untrusted server had already caused the complete body to be buffered.
[Alamofire 5.12.0 `DataRequest` source](https://raw.githubusercontent.com/Alamofire/Alamofire/5.12.0/Source/Core/DataRequest.swift)

Using `DataStreamRequest` avoids that whole-body behavior, but it recreates the
essential form of the existing code: receive chunks, maintain a cumulative
count, cancel on the first byte beyond the limit, retain only accepted bytes,
coordinate completion and cancellation, and map transport errors. Alamofire's
stream API defaults `automaticallyCancelOnStreamError` to `false`, so this
policy must be selected deliberately. Its async event streams also document an
unbounded default buffering policy, which should not be used casually at this
untrusted input boundary. [Alamofire streaming request](https://alamofire.github.io/Alamofire/Classes/DataStreamRequest.html)
· [Alamofire `Session.streamRequest`](https://alamofire.github.io/Alamofire/Classes/Session.html)

Apple's native `URLSession.bytes(for:)` already provides exactly the primitive
needed here: a response plus an asynchronous sequence of bytes that can be
processed while transfer is underway. The current implementation's simple
`for await` loop makes the maximum retained bytes and the cancellation point
visible in one place. [Apple: `bytes(for:delegate:)`](https://developer.apple.com/documentation/foundation/urlsession/bytes%28for%3Adelegate%3A%29)

## Redirects, credentials, and session state

Alamofire can install a custom redirect handler, but the security property does
not come from using the library; it comes from preserving Kitchen Memory's
policy in that handler. Apple's redirect delegate permits returning the
proposed request, a modified request, or `nil`, exactly the primitive used by
both the current `RedirectController` and Alamofire's `RedirectHandler`.
[Apple: redirect delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession%28_%3Atask%3Awillperformhttpredirection%3Anewrequest%3Acompletionhandler%3A%29)
· [Alamofire redirect handler](https://alamofire.github.io/Alamofire/Protocols/RedirectHandler.html)

Alamofire also supports challenge-based credentials and higher-level
authentication interceptors. Those are advantages for an authenticated API,
but the recipe fetcher's rule is the opposite: provide no credential and cancel
Basic, Digest, NTLM, Negotiate, client-certificate, proxy, and other credential
challenges. Preserving that explicit rule would require retaining a custom
`SessionDelegate` path and its tests rather than adopting Alamofire's
authentication conveniences. Apple specifically documents cancellation as the
response when an app cannot or will not provide a credential.
[Alamofire authentication usage](https://github.com/Alamofire/Alamofire/blob/5.12.0/Documentation/Usage.md#authentication)
· [Alamofire `SessionDelegate`](https://alamofire.github.io/Alamofire/Classes/SessionDelegate.html)
· [Apple: authentication challenges](https://developer.apple.com/documentation/foundation/handling-an-authentication-challenge)

Alamofire can be initialized with a customized ephemeral
`URLSessionConfiguration`. Apple says ephemeral configurations do not persist
caches, cookies, or credentials, but their credential store is still a private
in-memory store unless explicitly set to `nil`. Kitchen Memory's current code
does set the cache, cookie store, and credential store to `nil` and creates a
new session for every import. An Alamofire adapter would have to reproduce that
configuration and lifetime, not use the global `AF` session. Alamofire also
warns clients not to manipulate its underlying `URLSessionTask`s directly
because doing so breaks its tracking, adding another lifecycle boundary around
the explicit cancellation Kitchen Memory already has.
[Apple: session configuration](https://developer.apple.com/documentation/foundation/urlsessionconfiguration)
· [Apple: credential storage](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/urlcredentialstorage)
· [Alamofire `Session`](https://alamofire.github.io/Alamofire/Classes/Session.html)

Automatic retry should remain off for this transport even if Alamofire is used.
Each retry is another contact with an untrusted publisher, and Kitchen Memory's
current contract is one finite person-initiated operation. Any future retry
policy would need an explicit aggregate attempt and elapsed-time budget rather
than assuming a per-task resource timeout bounds a multi-task retry sequence.

## Integration and maintenance cost

There is no platform mismatch. Alamofire 5.12.0's package manifest supports
iOS 12 and macOS 10.13 or later, provides ordinary and explicitly dynamic
library products, carries no package dependencies of its own, and bundles a
privacy manifest. Kitchen Memory currently targets iOS 26 and macOS 26, uses
Swift 6 mode, and is built with Xcode 26.6, so the package's Swift 6.3 manifest
is consumable by the current toolchain. [Alamofire 5.12.0 package manifest](https://github.com/Alamofire/Alamofire/blob/5.12.0/Package.swift)
· [Kitchen Memory project settings](../../KitchenMemory.xcodeproj/project.pbxproj)

The addition is nevertheless not free in this repository. Every dependency
change requires review of source, changelog, license, privacy manifest,
products, transitive graph, and executable artifacts; synchronized updates to
`Package.resolved`, `SBOM.spdx.json`, and `DEPENDENCIES.md`; inventory checks;
and inspection of the final signed application. Alamofire would be a new
runtime component linked into `KitchenKit`, not merely a developer tool.
[Kitchen Memory dependency policy](../../DEPENDENCIES.md#update-procedure)
· [KitchenKit boundary](../adr/0012-consolidate-business-code-in-kitchenkit.md)

Alamofire 5.12.0 is released under the short permissive license commonly called
MIT (the license text is the Expat form). It permits distribution with the
MIT-licensed Kitchen Memory application, subject to preserving Alamofire's
copyright and license notice in distributions. This is not a licensing blocker.
[Alamofire license](https://github.com/Alamofire/Alamofire/blob/5.12.0/LICENSE)
· [Kitchen Memory licensing decision](../adr/0015-adopt-mit-license.md)

Alamofire's bundled privacy manifest declares no tracking and no collected data.
It declares system boot time for approved reason `35F9.1`; its response source
uses `ProcessInfo.processInfo.systemUptime` to measure serialization duration.
Apple describes `35F9.1` as measuring elapsed time between in-app events or
enabling timers. The declaration is consistent with Kitchen Memory's no-data
stance, but it expands the built product's required-reason API inventory and
therefore requires archive/privacy-report validation and a dependency-manifest
audit. [Alamofire privacy manifest](https://raw.githubusercontent.com/Alamofire/Alamofire/5.12.0/Source/PrivacyInfo.xcprivacy)
· [Alamofire response timing source](https://raw.githubusercontent.com/Alamofire/Alamofire/5.12.0/Source/Core/DataRequest.swift)
· [Apple: system boot time reason](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
· [Apple: aggregated privacy reports](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
· [Kitchen Memory privacy policy](../../PRIVACY.md#release-discipline)

The repository advertises a private security-reporting email, but GitHub shows
no versioned `SECURITY.md` policy and no published repository advisories as of
the research date. The latest release contains several race and cancellation
fixes, demonstrating active maintenance but also the ordinary update burden of
adding a concurrent networking layer. Absence of a published advisory is not
evidence that a library has no vulnerabilities.
[Alamofire security disclosure](https://github.com/Alamofire/Alamofire/tree/5.12.0#security-disclosure)
· [GitHub security overview](https://github.com/Alamofire/Alamofire/security)
· [5.12.0 fixes](https://github.com/Alamofire/Alamofire/releases/tag/5.12.0)

Alamofire exposes cURL descriptions, detailed response debug output, event
monitors, and task metrics. These are useful diagnostic tools, but Kitchen
Memory must not emit preserved source URLs, recipe content, credentials, or
other private values into public or retained logs. Adoption would therefore
need a narrow diagnostics rule; the feature should not be treated as an
automatic observability benefit. [Alamofire request example](https://github.com/Alamofire/Alamofire/tree/5.12.0#write-requests-fast)
· [Kitchen Memory diagnostic boundary](../../PRIVACY.md#debugging-and-support)

## Testability

Alamofire would not materially improve testability at the current seam.
`RecipeDocumentLoading` already lets parser and workflow tests inject complete
documents without networking. Transport tests already inject a configured
`URLProtocol`, which remains possible through the `URLSessionConfiguration`
used to create an Alamofire `Session`. An Alamofire conversion would instead
require proving that its asynchronous request lifecycle preserves early
cancellation, exact error mapping, redirect state, and no buffering beyond the
limit. Recent Alamofire releases fixed rare races in stream creation, response
serialization, cancellation, suspend/resume, and session teardown, so those
tests remain product obligations rather than behavior Kitchen Memory can safely
stop checking. [Existing transport test seam](../../KitchenKit/Import/RecipeURLImporter.swift)
· [5.11.1 response-serialization race fix](https://github.com/Alamofire/Alamofire/releases/tag/5.11.1)
· [5.11.2 stream race fix](https://github.com/Alamofire/Alamofire/releases/tag/5.11.2)
· [5.12.0 lifecycle fixes](https://github.com/Alamofire/Alamofire/releases/tag/5.12.0)

## Decision matrix

| Concern | Direct `URLSession` today | Alamofire adapter |
| --- | --- | --- |
| One bounded HTML `GET` | Directly matches the native primitive | Supported, but requires a streaming request rather than the ordinary data request |
| URL and redirect policy | Project-owned, linear, and visible | Same project policy inside a custom handler plus Alamofire lifecycle |
| Credential refusal | Explicit delegate rule with direct tests | Custom delegate behavior and equivalent tests still required |
| Exact 2 MiB ceiling | Simple `AsyncBytes` loop; cancellation is adjacent | Custom stream accumulator, cancellation, completion, and mapping |
| Parsing and workflow tests | Already isolated by `RecipeDocumentLoading` | Unchanged |
| Generic validation and serialization | Small amount of local code | Better built-in API, but little of it applies to HTML discovery |
| Auth, adaptation, retry, progress, uploads | Intentionally absent | Strong capabilities, currently unused or contrary to policy |
| Privacy | System networking plus app policy | No collection declared, but adds an SDK manifest and System Boot Time reason |
| Supply chain | No runtime networking dependency | New runtime package, SBOM/license/privacy/update/release obligations |
| Platform support | Native on every supported Apple OS | Compatible with current targets and toolchain |

The comparison favors the direct implementation because the policy complexity
is irreducible and the generic capability is presently unused. This conclusion
does not depend on claiming that the existing code is smaller than all possible
Alamofire versions; it depends on which responsibilities remain after the
wrapper is introduced.

## Conditions that would change the recommendation

Reconsider Alamofire when at least one of these becomes a committed product
requirement rather than a speculative convenience:

1. Kitchen Memory must speak to multiple HTTP APIs with shared request
   construction, validation, typed JSON serialization, and error mapping.
2. A first-party service requires credentials, token refresh, request
   adaptation, or coordinated retry across concurrent requests.
3. Uploads, resumable downloads, progress reporting, or common task metrics
   become product features.
4. More than one production transport needs the same redirect, cache, trust,
   retry, and monitoring machinery.
5. The direct fetcher grows because of generic HTTP concerns rather than
   recipe-specific trust and resource policies.

Before adoption, run a narrow adapter experiment rather than changing the
production dependency graph. The experiment succeeds only if it:

- preserves the public `RecipeDocumentLoading` interface and all existing
  deterministic tests;
- demonstrates, with hostile redirects, that no disallowed intermediate
  destination is contacted and only the minimal rebuilt `GET` crosses each
  redirect;
- proves that neither declared nor streamed bodies can retain more than the
  configured byte limit;
- cancels the underlying request when the import task is cancelled;
- cancels every non-server-trust authentication challenge without consulting
  ambient credentials;
- uses a fresh cache-free, cookie-free, credential-free ephemeral session per
  import and enforces one aggregate operation deadline;
- preserves final response URL and encoding metadata exactly;
- reduces transport implementation and test complexity in review, rather than
  merely relocating it; and
- records build-time, archive-size, privacy-report, and launch measurements so
  dependency cost is evidence rather than assumption.

Until such an experiment is motivated and passes, the native transport is the
deeper module for this particular job: callers see one recipe-document
operation, while the implementation keeps its unusual safety rules explicit
and locally testable.
