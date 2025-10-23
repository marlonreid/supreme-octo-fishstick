flowchart TD
    A[Proposed API change] --> B{Is there a breaking change<br/>(removal, rename, behavior change,<br/>status codes, media type, required fields)?}
    B -- Yes --> C{Can you avoid breakage via<br/>backward-compatible techniques?}
    C -->|Additive only (new fields/ops)| D[Ship in current version (minor)]
    C -->|Defaulting / tolerant readers| D
    C -->|Feature flags / query params| D
    C -->|Content negotiation (e.g., new media type)| D
    C -->|No, unavoidable break| E[Consider NEW MAJOR VERSION]
    B -- No --> F{Is the change purely<br/>non-functional (docs, bugfix<br/>without contract change)?}
    F -- Yes --> G[Ship as patch in current version]
    F -- No --> H{Is it additive (new endpoint/field,<br/>optional param, new error code value<br/>with old still valid)?}
    H -- Yes --> D
    H -- No --> E

    %% Cross-cutting concerns gate
    E --> CC{Cross-cutting concerns impacted?}
    D --> CC
    CC -->|Auth/Scopes/Permissions| I[Prefer NEW MAJOR VERSION or<br/>separate auth scheme]
    CC -->|Error model / envelope / pagination / sorting| I
    CC -->|Versioning strategy / URL or header| I
    CC -->|Idempotency / retries / rate limits semantics| I
    CC -->|Security & Compliance (PII fields, retention,<br/>geo, legal, audit)| I
    CC -->|Performance/SLA changes visible to clients| I
    CC -->|Event schemas / webhooks / async contracts| I
    CC -->|Deprecation headers & sunset policy readiness| I
    CC -->|SDKs & client compatibility plan| I
    CC -->|No material cross-cutting impact| J[Proceed per path (D or E)]

    %% Additional checks before final decision
    D --> K{Do clients need a preview?<br/>(uncertain semantics / experimental)}
    K -- Yes --> L[Expose as preview/beta via header or version param]
    K -- No --> M[Release in current version]

    I --> N{Can impact be isolated?}
    N -- Yes --> O[Introduce parallel surface (e.g., /v2 or new media type)]
    N -- No --> P[NEW MAJOR VERSION with migration plan]

    %% Final gates
    M --> Q{Have you updated versioning docs,<br/>changelog, and contract tests?}
    O --> Q
    P --> Q
    Q -- Yes --> R[✅ Ready to release]
    Q -- No --> S[🛑 Block: complete docs/tests/tooling]

    %% Notes
    subgraph Legend
      direction TB
      L1[Minor/Patch: backward compatible]
      L2[Major: breaking or cross-cutting shift]
      L3[Preview: gated/opt-in]
    end
