Got it — here’s a **substantially expanded** course with deeper explanations (not one-liners), plus a brand-new chapter on **introducing versioning into legacy, unversioned APIs**. I’ve kept it technology-agnostic, focused on HTTP concepts, and reinforced the idea that **a version is a single, coherent contract across all endpoints**. The MCQ section includes both core-concept questions and the requested **Spot the Breaking Change** set (URL versioning only).

---

# Title

**API Versioning Fundamentals: Designing for Change Without Breaking Clients**

---

# Description of the course

Versioning is not a syntax detail; it’s a **compatibility strategy**. This course teaches you how to evolve APIs without surprising consumers. You’ll learn a precise definition of breaking change; how to design coherent versions that apply to the **entire API surface**; and how to operate versions over their life cycle (from introduction to deprecation). We also cover a practical, step-by-step playbook for **legacy APIs that currently have no versioning**—including how to introduce `/v1` without chaos, how to migrate consumers, and how to quantify and mitigate risk.

---

# Learning objectives

By the end of this course you will be able to:

1. **Define** an API contract and articulate why versioning is the unit of compatibility for the **whole API**.
2. **Diagnose** whether a change is breaking or backward-compatible, using a clear decision framework.
3. **Compare** versioning approaches conceptually (focus of exercises: URL versioning such as `/v1/...`, `/v2/...`).
4. **Design** changes to remain additive when possible and plan major versions when necessary.
5. **Operate** API versions: documentation, rollout, observability, and deprecation.
6. **Introduce** versioning to **legacy unversioned APIs** safely, with migration plans and guardrails.

---

# Content divided into chapters/subchapters/subsections

## Chapter 1 — The API Contract and Why Versioning Exists

### 1.1 The contract: a promise you must keep

An API contract is the **observable behavior** your clients rely on: URLs, methods, request/response shapes, status codes, authentication, error envelopes, pagination semantics, and performance/SLA expectations. Clients encode this contract into code, tests, and dashboards. Once published, any change that forces clients to adapt is a **breaking change** and must be isolated behind a new version boundary.

### 1.2 Stability vs change: both are required

Products must evolve, but integrations need stability. Versioning reconciles these by allowing **parallel truths**: `/v1` continues to behave as promised, while `/v2` can introduce incompatible improvements. This separation keeps trust with consumers while enabling progress.

### 1.3 Scope: the version belongs to the whole surface

A version is meaningful only if it’s **coherent** across endpoints. If `/v1/users` paginates with cursors but `/v1/orders` uses page numbers, consumers inherit complexity and inconsistencies. Treat a version as a **single product**: consistent models, errors, pagination, and auth posture.

---

## Chapter 2 — What Counts as a Breaking Change (and Why)

### 2.1 The decisive test

> If **any** existing client must change code/config to keep working as before, the change is **breaking**.

This includes not only field removals but also **semantic** shifts: different defaults, altered status codes, changed sorting, or timing (sync → async).

### 2.2 Structural breaks (easy to spot)

* Removing or renaming fields; changing types (`number` → `string`).
* Removing endpoints or changing URIs/methods.
* Changing error envelopes or pagination models.

### 2.3 Semantic breaks (easy to miss)

* Changing default sort or pagination limits.
* Swapping `200 OK` for `202 Accepted` and a polling flow.
* Tightening auth (new mandatory header/scope); changing rate-limit behavior.
* Returning `204` instead of `[]`, or `410` instead of `404` without prior contract.

### 2.4 Non-breaking patterns

* Additive fields/links that are **optional**.
* New endpoints that don’t alter existing behavior.
* Making required headers **optional** (preserving existing default behavior).
* Expanding enums **only if** clients are documented to tolerate unknown values.

### 2.5 Guardrails to stay compatible

* **Tolerant readers**: clients ignore unknown fields/enum values.
* **Strict writers**: servers validate inputs but accept superset reads.
* Prefer additive evolutions and **feature flags** internally before finalizing public changes.

---

## Chapter 3 — Versioning Strategies (Conceptual, Tech-agnostic)

### 3.1 URL versioning: explicit and debuggable

`/v1/...` makes compatibility clear in logs, docs, and caches. It’s easy for humans and tooling. Drawback: route proliferation—mitigated by clear documentation and good routing hygiene.

### 3.2 Alternatives (for context)

* Header/media-type versioning: cleaner URLs but harder to discover.
* Query-param versioning: simple but often misused for feature toggles, blurring contract boundaries.

### 3.3 Pick one, apply consistently

Whatever strategy you choose, the **coherence rule** still applies: a version is a single contract across the API, not per endpoint.

---

## Chapter 4 — Designing Coherent Versions

### 4.1 Cross-cutting concerns must align within a version

* **Error format**: one envelope, same fields everywhere.
* **Pagination**: one paradigm (cursor or page numbers), consistent defaults.
* **Auth posture**: scopes/headers/flows consistent by version.
* **Identifiers & formats**: types (string vs number), casing, timestamp formats.

### 4.2 Compatibility budget and change taxonomy

Maintain a change log with categories: **additive**, **behavioral**, **breaking**. Review each proposed change against the taxonomy before merging.

### 4.3 Deprecation as part of design

Design `/v2` with the deprecation of `/v1` in mind. Provide clear migration guides that map feature-by-feature and call out traps (e.g., default changes).

---

## Chapter 5 — Operating Versions in the Real World

### 5.1 Release & rollout

* **Dual-run** `/v1` and `/v2`; mirror traffic via shadow testing where safe.
* Gradual exposure behind environment flags; canary per consumer cohort.

### 5.2 Observability per version

* Version-tagged metrics and logs: latency, error rate, payload validation failures.
* Dashboards per version; alert on unexpected schema diffs or status-code shifts.

### 5.3 Deprecation and removal

* Communicate early via email, changelogs, and response headers (`Deprecation`, `Sunset`, link to migration guide).
* Offer an overlap window; publish a **removal date** and stick to it.

### 5.4 Testing and governance

* Contract tests for each version; consumer-driven tests where feasible.
* Schema diff checks in CI (fail builds on breaking diffs to `/v1`).
* A change advisory (even lightweight) to keep the taxonomy enforced.

---

## Chapter 6 — Introducing Versioning to Legacy Unversioned APIs

*(New, detailed playbook)*

### 6.1 Reality check and goals

Legacy APIs often evolved organically: undocumented defaults, inconsistent errors, and hidden dependencies. The objective is **stability first**, then **introduce `/v1`** with minimal disruption.

### 6.2 Inventory and baseline

* **Consumer census**: list consumers, their critical paths, and contact owners.
* **Behavior capture**: record current responses, status codes, defaults, and error shapes for key endpoints.
* **Compatibility map**: note inconsistencies (e.g., different timestamp formats) and decide which behavior becomes canonical in `/v1`.

### 6.3 Create `/v1` without breaking anyone

* **Alias approach**: initially map existing routes to `/v1` (e.g., `/users` → `/v1/users`) so that `/v1` is a **strict superset** of today’s behavior.
* **Gateway/facade**: place an API gateway that rewrites routes to `/v1/...` internally, enabling you to start documenting `/v1` immediately.
* **Freeze the contract**: document exactly what `/v1` is (warts and all). Changes that are breaking go to planned `/v2`.

### 6.4 Stabilize and document

* Write a **canonical spec** for `/v1` (OpenAPI is helpful but optional).
* Normalize **error envelopes** and **pagination** where you can **additively** (e.g., keep existing fields, add an envelope). If normalization would break, defer to `/v2`.

### 6.5 Migrate consumers deliberately

* Publish a **migration guide**: legacy → `/v1` mapping; list known quirks that persist in `/v1`.
* Offer **compat shims** if needed (e.g., accept both old and canonical timestamp formats).
* Provide **SDKs or examples** for `/v1`.

### 6.6 Plan `/v2` for the cleanups

* Move semantic fixes (status codes, defaults, type changes) to `/v2`.
* Set measurable objectives: e.g., 90% `/v1` adoption in 3 months, then start `/v2` beta with selected partners.

### 6.7 Risk management and measurement

* **KPIs**: error rates per endpoint per version, number of consumers migrated, support ticket volume.
* **Kill-switches**: ability to roll back routing or disable a path quickly.
* **Communication cadence**: monthly status to consumers, office hours, and a sandbox.

### 6.8 Anti-patterns to avoid

* Per-endpoint versions (e.g., `/v1/users` and `/v2/orders` concurrently) — breaks coherence.
* Silent semantic changes in `/v1` (e.g., default sort flip).
* Unbounded support windows — commit to deprecation timelines.

---

## Chapter 7 — Practical Decision Frameworks

### 7.1 “Should this be `/v2`?”

Ask: Will any existing client have to change? If yes → `/v2`. If no → additive in `/v1`. When in doubt, test with real payloads from representative consumers.

### 7.2 Designing additive changes

Prefer optional request/response fields, new endpoints, and link relations. Keep defaults and semantics unchanged for `/v1`.

### 7.3 Communicating clearly

State changes in three lines: **What changed**, **Who is affected**, **What action is required**. Link to examples. Provide before/after payloads.

---

# Test questions

## A. Core Concepts (Multiple Choice)

1. Which best defines an API contract?
   A. A private server implementation detail
   B. The observable behavior clients rely on (URLs, methods, bodies, status codes, errors, defaults)
   C. Only the OpenAPI document
   D. Only the JSON fields
   **Answer:** B

2. A change is “breaking” when:
   A. It changes internal database tables
   B. It forces existing clients to change code/config to keep working
   C. It adds an optional field
   D. It changes team ownership
   **Answer:** B

3. Why must a version apply to **all** endpoints?
   A. To reduce route count
   B. To satisfy a REST constraint
   C. To ensure a single coherent contract across the API surface
   D. Because caching requires it
   **Answer:** C

4. Which is **non-breaking** for `/v1`?
   A. Renaming `email` → `primary_email`
   B. Returning `204` instead of `[]` on empty lists
   C. Adding optional `avatar_url` to the response
   D. Requiring a new HMAC header for all POSTs
   **Answer:** C

5. Which is a **semantic** breaking change?
   A. Adding a new endpoint
   B. Changing default sort order from ASC to DESC
   C. Adding an optional request header
   D. Increasing rate limits
   **Answer:** B

6. In URL versioning, you introduce `/v2` when:
   A. You rewrite the service in another language
   B. Any existing `/v1` client would break without code changes
   C. You add a dashboard
   D. You fix documentation typos
   **Answer:** B

7. Within one version, pagination should be:
   A. Whatever each endpoint prefers
   B. Consistent across endpoints (model + defaults)
   C. Always page/per_page
   D. Always cursor
   **Answer:** B

8. Expanding an enum with a new value is non-breaking **only if**:
   A. Your server is behind a gateway
   B. Clients are documented/taught to tolerate unknown values
   C. You bump minor version
   D. You add a feature flag
   **Answer:** B

9. A proper deprecation process should include:
   A. Secret rollouts
   B. `Deprecation`/`Sunset` headers and a migration guide
   C. Immediate removal
   D. A Slack thread only
   **Answer:** B

10. For legacy unversioned APIs, the first safe step is:
    A. Ship `/v2` immediately
    B. Introduce `/v1` that faithfully reflects current behavior and document it
    C. Change defaults quietly
    D. Require new auth headers
    **Answer:** B

---

## B. Spot the Breaking Change (HTTP + URL versioning, `/v1/...` vs `/v2/...`) — MCQ

For each scenario, choose:
A. **Breaking (needs `/v2`)**  B. **Non-breaking (OK in `/v1`)**

1. `GET /v1/users/{id}` adds optional `avatar_url`.
   **Answer:** B

2. Rename response field `email` → `primary_email` (remove `email`).
   **Answer:** A

3. `POST /v1/users` accepts optional `referrer_code`.
   **Answer:** B

4. Default `limit` changes 50 → 20.
   **Answer:** A

5. Empty list returns `204` instead of `[]` (200).
   **Answer:** A

6. `id` type changes `number` → `string`.
   **Answer:** A

7. Download becomes async: `200` → `202` + polling.
   **Answer:** A

8. New mandatory header `X-Request-Signature` for POSTs.
   **Answer:** A

9. Add enum value `"suspended"`; clients are documented to tolerate unknown values.
   **Answer:** B

10. Default sort ASC → DESC (clients can still pass `sort=asc`).
    **Answer:** A

11. `/v1/users` uses cursor; `/v1/orders` switches to page/per_page.
    **Answer:** A

12. Error envelope changes only for `/v1/payments/*`.
    **Answer:** A

13. Missing order: `404` → `410 Gone` without prior contract.
    **Answer:** A

14. `/v1/health` becomes authenticated.
    **Answer:** A

15. Embedded `profile` replaced by `profile_id` requiring a second call.
    **Answer:** A

16. Add `PATCH` while keeping `PUT` behavior unchanged.
    **Answer:** B

17. `DELETE` returns `204` → now `200` with body.
    **Answer:** A

18. `POST` create `201` → `202` queued creation.
    **Answer:** A

19. Required header `X-Tenant-Id` becomes optional (same default semantics).
    **Answer:** B

20. Replace `GET /v1/users/{id}/orders` with `GET /v1/orders?user_id={id}` and remove the old URL.
    **Answer:** A

21. `GET /v1/files/{id}` streamed binary → now only metadata; streaming moved to `/content`.
    **Answer:** A

22. Add new endpoint `GET /v1/metrics/usage/weekly`; daily unchanged.
    **Answer:** B

23. Bundle proposal under `/v1`: (1) add optional `avatar_url`, (2) change default limit, (3) require HMAC header for POSTs, (4) switch `/v1/orders` to page/per_page. What can safely ship in `/v1`?
    A. Only (1)  B. (1) and (2)  C. (1), (2), (3)  D. All
    **Answer:** A

24. Timestamps change from ISO-8601 UTC to local time without TZ info.
    **Answer:** A

25. Add optional request param `locale`.
    **Answer:** B

---

# Three-pass “Hivemind” Review (Tech Lead + Architect + Teacher)

## Pass 1 — Technical Lead

* **Check:** Is there a concrete, repeatable way to make decisions?
  **Yes.** Chapter 7’s decision framework plus the Chapter 2 taxonomy gives a fast, practical test. The operating guidance (rollout, observability, deprecation) is now actionable.
* **Enhancement made:** Clear KPIs for legacy migration (adoption %, error rates), explicit kill-switch guidance.

## Pass 2 — Software Architect

* **Check:** Is the **coherence of a version** unambiguous and enforced?
  **Yes.** Chapters 1 & 4 explicitly call out alignment of errors, pagination, auth, and identifier formats. Anti-patterns for per-endpoint versions are documented.
* **Enhancement made:** Strengthened semantic-break examples and separated additive vs semantic vs structural changes; added governance/CI schema-diff advice.

## Pass 3 — Experienced Teacher

* **Check:** Is depth improved beyond one-liners?
  **Yes.** Each topic has multi-paragraph exposition with examples and pitfalls. The legacy chapter provides a concrete playbook.
* **Enhancement made:** MCQs balanced between concept recall and scenario judgment; wording simplified to remove ambiguity; every question maps to a chapter section for easy remediation.

### Final Consensus

* The course now provides **substantive explanations**, not slogans.
* The **legacy migration chapter** gives a practical route from “no versioning” to a clean `/v1` and future `/v2`.
* The exercises rigorously test understanding of **breaking vs non-breaking** under URL versioning, reinforcing the core principle:
  **If clients must change, it’s breaking — and a version covers the entire API.**

If you want, I can package this into a **slide deck**, a **migration playbook PDF**, or export the MCQs to **CSV/JSON** for your LMS.
