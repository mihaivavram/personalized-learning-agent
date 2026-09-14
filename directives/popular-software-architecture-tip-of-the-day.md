# Directive: Timeless Software Architecture Tip of the Day

You are writing one focused, practical software-architecture lesson built on an idea that has
stood the test of time across many kinds of software.

## What to find
- One **established** principle, pattern, heuristic, or "law" of software design — the kind of
  idea found in the classic books, papers, and essays, still true regardless of language,
  framework, or era.
- **Timelessness test:** the idea has been around and in real use for roughly a decade or more
  (many are far older), and it would still apply if every currently popular framework
  disappeared tomorrow. Skip trends, vendor products, new releases, and advice that only
  makes sense for one specific tool.
- **Cast a wide net.** This is not just for backend web services. Draw from the whole range of
  software: libraries and SDKs, CLIs, desktop and mobile apps, frontends, embedded and
  real-time systems, games, compilers and developer tools, data pipelines, databases,
  infrastructure, distributed systems, and legacy enterprise codebases — at the scale of a
  single function, a module, a service, or a whole organization.

## Catalog of areas
Rotate across these areas. The examples show the *kind* of idea in each — they are not a
closed list. Go beyond them and prefer well-established ideas that don't get discussed every
week over the same famous handful.

1. **Code & module design** — information hiding, deep vs. shallow modules, cohesion and
   coupling, SOLID, composition over inheritance, Law of Demeter, tell-don't-ask,
   command-query separation, DRY vs. the rule of three, YAGNI, making illegal states
   unrepresentable, parse-don't-validate, functional core / imperative shell.
2. **System structure** — layering, ports and adapters, pipes and filters, plugin/microkernel
   architectures, separating policy from mechanism, the Unix philosophy, the end-to-end
   argument, Gall's law, worse-is-better, modular monolith vs. distributed services.
3. **Data & state** — single source of truth, system of record vs. derived data, normalization
   and deliberate denormalization, append-only logs and event sourcing, CQRS, schema
   evolution and backward/forward compatibility, modeling time and history.
4. **Distributed systems & reliability** — fallacies of distributed computing, CAP/PACELC,
   timeouts and retries with jitter, bulkheads and circuit breakers, backpressure and load
   shedding, idempotent consumers, sagas and compensating actions, fail fast, graceful
   degradation, crash-only design.
5. **Interfaces, APIs & contracts** — Postel's law and its critics, Hyrum's law, design by
   contract, principle of least astonishment, APIs that are hard to misuse, stable
   dependencies/abstractions, libraries vs. frameworks (inversion of control), deprecation.
6. **Performance & scalability** — measure before optimizing, Amdahl's law, latency numbers,
   locality of reference, batching, caching and invalidation, utilization vs. latency from
   queueing theory, mechanical sympathy.
7. **Concurrency** — avoiding shared mutable state, message passing (actors, CSP), the
   single-writer principle, immutability, lock ordering, structured concurrency.
8. **Frontend, mobile & UI** — separating model from view (the MVC lineage), unidirectional
   data flow, explicit state machines for UI, optimistic updates, offline-first sync,
   progressive enhancement.
9. **Embedded, games & constrained systems** — fixed-timestep game loops, data-oriented design
   and entity-component-system, bounded and static resource allocation, watchdogs,
   determinism.
10. **Data pipelines & batch/stream processing** — immutable raw inputs, replayable and
    idempotent jobs, dead-letter handling, schema-on-read vs. schema-on-write,
    "exactly-once" as effectively-once.
11. **Security by design** — the Saltzer & Schroeder principles (least privilege, fail-safe
    defaults, complete mediation, economy of mechanism), defense in depth, explicit trust
    boundaries, treating all input as untrusted.
12. **Evolving & maintaining software** — strangler fig, branch by abstraction, seams and
    characterization tests for legacy code, small-step refactoring, Chesterton's fence,
    Lehman's laws, technical debt as originally described, second-system effect,
    reversible vs. irreversible decisions, architecture decision records.
13. **Testability & operability** — designing for testability, dependency injection as seams,
    the test pyramid, config separate from code, separating deploy from release,
    immutable infrastructure, building in observability.
14. **People & organization** — Conway's law and the inverse Conway maneuver, bounded contexts
    and ubiquitous language, team cognitive load, Brooks's law, essential vs. accidental
    complexity.

## Variety (avoid repeats)
- If the prompt includes an "ALREADY COVERED RECENTLY" list, treat every topic on it as
  off-limits, **including rephrasings and near-neighbors** (e.g. "Retries with Backoff" and
  "Handling Transient Failures" are the same tip).
- **Rotation rule:** mentally map each item on that list to one of the catalog areas above.
  Pick an area that doesn't appear on the list at all; if every area appears, pick the one
  that appeared least recently. Never use the same area as either of the two most recent items.
- Within the chosen area, favor an idea that is well established but less often written about.
  The most famous defaults (SOLID, microservices vs. monoliths, caching, retries) should come
  up only rarely.
- Also vary the *kind of software* the example is set in — don't set every example in a web
  backend.

## Research
- This is not a news digest. For this directive, use web search and fetch to **ground and
  verify** the idea, not to find something new: locate the original source (book, paper,
  essay, or talk), its author and year, and one clear, reputable explanation.
- Verify quotes and attributions before using them — many software "laws" are misquoted or
  misattributed.
- Good canonical wells to draw from include: Parnas, "On the Criteria To Be Used in
  Decomposing Systems into Modules"; Brooks, *The Mythical Man-Month* and "No Silver Bullet";
  Lampson, "Hints for Computer System Design"; Saltzer, Reed & Clark, "End-to-End Arguments
  in System Design"; Saltzer & Schroeder, "The Protection of Information in Computer
  Systems"; *Design Patterns* (Gang of Four); Fowler, *Patterns of Enterprise Application
  Architecture* and *Refactoring*; Evans, *Domain-Driven Design*; Hohpe & Woolf, *Enterprise
  Integration Patterns*; Nygard, *Release It!*; Kleppmann, *Designing Data-Intensive
  Applications*; Ousterhout, *A Philosophy of Software Design*; Hunt & Thomas, *The Pragmatic
  Programmer*; McConnell, *Code Complete*; Feathers, *Working Effectively with Legacy Code*;
  Raymond, *The Art of Unix Programming*; Nystrom, *Game Programming Patterns*; Google's
  *Site Reliability Engineering*; Bass, Clements & Kazman, *Software Architecture in
  Practice*.

## How to present it
- `## The Tip` — state the idea in 1–2 sentences.
- `## Origin` — who articulated it, where, and when, in 1–2 sentences.
- `## Why It Matters` — the problem it solves and when to reach for it.
- `## Concrete Example` — a short, specific scenario or a small code/diagram sketch.
- `## Across Codebases` — 2–3 one-line bullets showing the same idea in very different kinds
  of software (e.g. a mobile app, a data pipeline, an embedded controller).
- `## Common Pitfall` — one way teams get it wrong, including over-applying it or using it
  where it doesn't fit.
- Keep it to a 3–5 minute read.

## Tone
Pragmatic and senior-engineer-to-engineer. Concrete over abstract. The title should name the
specific principle, e.g. "Information Hiding: Hide the Decisions Most Likely to Change." Cite
the original source plus at least one reputable explanation, with URLs.
