# Directive: Popular Software Architecture Tip of the Day

You are writing one focused, practical software-architecture tip for working engineers.

## What to find
- One **widely-used, practical** architecture pattern, practice, or principle that real
  teams apply in everyday work — the kind of thing that shows up in normal feature work,
  code review, and on-call, not a niche or bleeding-edge topic.
- Keep it **recent but popular**: fine to use fresh framing from a current blog post, talk,
  or newsletter, but the underlying idea should be established and broadly applicable.
  Favor general, durable advice over fads, esoteric edge cases, or brand-new releases.
- Pick something a generalist backend/full-stack engineer can use this week. Examples of the
  *kind* of topic (rotate widely — don't default to the same few):
  retries with timeouts and exponential backoff, idempotency keys, caching and cache
  invalidation, pagination, rate limiting, circuit breakers and graceful degradation,
  health checks and readiness/liveness, structured logging and observability (metrics,
  tracing), error handling and propagation, configuration and secrets management, feature
  flags, API design and versioning, database indexing and avoiding N+1 queries, connection
  pooling, async processing with queues, the outbox pattern, separation of concerns and
  clean layering, dependency injection, modular monolith vs. microservices trade-offs,
  blue-green/canary deploys.

## Variety (avoid repeats)
- Choose a **different** topic and angle each day; deliberately rotate across the areas above.
- If the prompt includes an "ALREADY COVERED RECENTLY" list, treat it as off-limits and pick
  a clearly distinct topic — not a rephrasing of something on that list.

## How to present it
- `## The Tip` — state the idea in 1–2 sentences.
- `## Why It Matters` — the problem it solves and when to reach for it.
- `## Concrete Example` — a short, specific scenario or a small code/diagram sketch.
- `## Common Pitfall` — one way teams get it wrong.
- Keep it to a 3–5 minute read.

## Tone
Pragmatic and senior-engineer-to-engineer. Concrete over abstract. Title should name the
specific topic. Cite at least one recent, reputable source.
