# Evals

Practical guidance for adding evals to a SaaS product that uses Codex and Claude for application logic, prompt iteration, support workflows, or internal copilots.

## Goal

Evals are a regression system for AI behavior. They let the team answer:

- Did the model follow policy?
- Did retrieval bring the right context?
- Did the tool chain produce the expected result?
- Did a prompt or model change improve behavior or break it?

The right approach is small, versioned, and tied to product risk. Do not start with a benchmark project. Start with the flows that can lose money, create support burden, or damage trust.

## Core Principles

- Test workflows, not model vibes.
- Keep deterministic assertions separate from LLM grading.
- Version prompts, rubrics, retrieval config, tools, and model IDs.
- Add production failures back into the dataset every week.
- Run a fast suite in PRs and a broader suite on a schedule.

## Where Evals Fit

```text
Product workflow
      |
      v
User input ---> Retrieval ---> Prompt/tool orchestration ---> Model output
      |               |                    |                      |
      |               |                    |                      |
      +---------------+--------------------+----------------------+
                              |
                              v
                            Evals
                              |
          +-------------------+-------------------+
          |                                       |
          v                                       v
Deterministic checks                     Model-based grading
schema, citations, cost,                correctness, tone,
latency, tool calls                     policy, completeness
```

## Recommended Repo Shape

```text
docs/
└── evals/
    └── README.md

tests/
└── evals/
    ├── datasets/
    │   ├── support-replies.jsonl
    │   ├── refunds.jsonl
    │   └── sales-assistant.jsonl
    ├── scorers/
    │   ├── deterministic.ts
    │   └── llm-grader.ts
    ├── tasks/
    │   ├── support-reply.ts
    │   └── refund-agent.ts
    ├── baselines/
    │   └── latest.json
    └── run.ts
```

## What To Evaluate First

Start with 3 to 5 workflows:

- support answer grounded in tenant data
- refund or credit handling against policy
- sales assistant accuracy on pricing and plan rules
- ticket routing or classification
- summarization of calls, emails, or incidents

For each workflow, collect 20 to 50 cases before scaling further.

## Dataset Format

Each eval case should capture enough context to replay the task:

```json
{
  "id": "refund-001",
  "workflow": "refund-agent",
  "input": "Customer asks for a refund after 45 days.",
  "context": {
    "tenant_tier": "pro",
    "policy_version": "2026-03-15",
    "retrieved_docs": ["refund-policy-v3"]
  },
  "expected": {
    "outcome": "deny_refund",
    "must_include": ["policy window"],
    "must_not_include": ["invented exception"]
  },
  "tags": ["policy", "edge-case"]
}
```

## Two-Layer Scoring

### 1. Deterministic checks

Use code for things that are objectively measurable:

- output parses as JSON
- required fields exist
- tool calls happen in the expected order
- citations are present
- prohibited actions are absent
- latency and token cost stay within budget

### 2. Model-based grading

Use an LLM judge only for qualitative questions:

- was the answer factually grounded in provided context
- did the tone match the workflow
- did the assistant follow policy without over-refusing
- did the summary preserve key facts and action items

The grader should use a fixed rubric and return structured scores, not free-form opinions.

## Codex and Claude Split

Use each tool where it is strongest.

### Codex

- scaffolding the eval harness
- writing loaders, scorers, and CI jobs
- generating fixture templates and replay scripts
- diffing prompt or tool changes against baselines

### Claude

- drafting rubrics for subjective grading
- generating harder edge cases and adversarial prompts
- serving as a second judge on ambiguous failures
- reviewing prompt wording for policy and tone regressions

## Workflow Drafts

### Authoring workflow

```text
Prod incidents / support escalations / QA findings
                      |
                      v
              Convert into eval cases
                      |
                      v
            Add expected result or rubric
                      |
                      v
              Store in versioned dataset
                      |
                      v
             Run locally against baseline
```

### PR workflow

```text
Prompt change / tool change / retrieval change / model swap
                      |
                      v
                Run smoke eval suite
                      |
          +-----------+------------+
          |                        |
          v                        v
       Pass                     Fail
          |                        |
          v                        v
      Merge PR            Inspect failing cases
                                  |
                                  v
                       fix prompt, code, or rubric
```

### Weekly improvement workflow

```text
Production conversations
          |
          v
Cluster bad outcomes by theme
          |
          v
Select highest-cost failures
          |
          v
Add new eval cases and rerun suite
          |
          v
Update baseline after review
```

## CI Levels

- `smoke`: 10 to 20 high-signal cases, runs on every PR
- `core`: business-critical suite, runs on merge and before release
- `full`: broader regression set, runs nightly or on schedule

This keeps feedback fast while still catching slow-burn regressions.

## Versioning Rules

Every eval result should record:

- workflow name
- prompt version
- model ID
- retrieval or index version
- tool schema version
- rubric version
- git commit SHA

If these are missing, failures will be hard to compare over time.

## Review Loop

Use a simple decision rule for failures:

```text
Case failed
   |
   +--> bad expected result? -> fix dataset or rubric
   |
   +--> bad retrieval? ------> fix indexing or ranking
   |
   +--> bad orchestration? --> fix tools, guards, or code
   |
   +--> bad prompt/model? --> revise prompt or change model
```

## Minimal Adoption Plan

Week 1:

- choose 3 critical workflows
- create 20 cases per workflow
- implement deterministic scorers
- add one LLM grader with a fixed rubric

Week 2:

- add PR smoke evals
- capture cost and latency metrics
- start turning production failures into cases

Week 3:

- add nightly full runs
- compare model versions side by side
- require baseline review before prompt releases

## Common Mistakes

- mixing expected output, policy, and grading logic in one place
- using only LLM judging when exact assertions are available
- skipping dataset versioning
- evaluating generic prompts instead of product-specific workflows
- collecting failures but never turning them into new cases

## Bottom Line

For a SaaS team, evals should behave like regression tests for business-critical AI workflows. Codex should own the harness and automation. Claude should help draft rubrics, generate edge cases, and act as a second reviewer where qualitative judgment is needed.
