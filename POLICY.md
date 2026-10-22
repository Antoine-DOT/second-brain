<!-- BEGIN MANAGED SECOND-BRAIN POLICY -->
# Durable memory: the vault

The Obsidian vault (`__VAULT__`) is **the shared memory of the user and their agents**: projects, business and clients, infrastructure, decisions, personal growth, ideas, journal. Its entry page, `Home.md`, is the user's **dashboard**.

The full schema is in `__VAULT__/CLAUDE.md`. Read it before writing to the vault.

## Proportionate use

- **Starting a session on a project**: `git -C __VAULT__ pull --rebase`, then read `wiki/index.md`, `wiki/projects/<project>.md` and the latest log entries (`grep "^## \[" wiki/log.md | tail -5`). For a quick overview, read `Home.md`. Before acting on a machine, read its page `wiki/entities/<hostname>.md`. Optional if the request is fully specified and past context cannot change the outcome.
- **Record** when continuity has value: substantial or multi-session work, significant investigation, release, deployment, architecture decision, infrastructure change. For small local or read-only work, record nothing.
- **At the end of recorded work, and after every deployment or infrastructure change**:
  1. write `raw/sessions/YYYY-MM-DD-<project>-<slug>.md` (what was done, outcome or decision, useful SHA or state, next step; short);
  2. update `wiki/projects/<project>.md`, the infrastructure pages touched, `wiki/index.md` and `wiki/log.md`;
  3. `git add -A && git commit -m "session: <project> <title>" && git push`.
- Don't duplicate git history, transcripts or test logs.

## Capturing as you go

- When the user shares **durable information** about themselves, their life, their business or their projects (a fact, decision, preference, date, deadline, change of plan, new thought), or when a decision is made together: **update the relevant page in the same turn**, then say it in one line: `📝 noted in <page>`.
- **"Note this"**: follow the "Captures" section of `__VAULT__/CLAUDE.md`, then reply `📌 noted in <work> → <topics>`. **Never pass a paraphrase off as a quote.**
- **Inbox** (`__VAULT__/Inbox.md`): at the start of an interactive session, if the hook reports waiting items, triage them following the "Inbox" section of the schema, then reply `📥 inbox triaged: …`. Never in an automated job or during a deployment.
- **Don't record the ephemeral**: one-off questions, writing help, drafts, isolated translations, topics with no follow-up.
- **Health** and other sensitive but non-secret information: only in `private/` (outside git). Never any secrets anywhere.
- After changing a page's tracking fields: `python3 __VAULT__/scripts/dashboard.py`, then commit and push.
- When unsure where something goes, suggest the page in one line rather than creating new structure.

## Rules

- **Ideas ≠ Actions**: an idea goes to `raw/ideas/`. Never promote it to an action or act on it without the user's explicit decision.
- **Delegating to a second agent** (for example Codex on a dev server): count the main agent's tokens, not the total. If delegating reduces the main agent's share, even when the total goes up, delegate (reading, inventory, search, bounded changes), then have the main agent review the result.
- **Following a delegated agent**: a single completion signal. Start a background wait that ends when the agent is done, then wait for the notification. No repeated checks: each one re-reads the whole context.
- **Switching sessions**: move to a new session only when the hook has reported a context above the threshold **and** a phase has just ended (release, validation, merge, change of topic). Above the high threshold, switch at the end of the current step. **Never in the middle of a task.** Before switching: record a trace in the vault with a `- Resume:` line (exact state, SHA, next action). After a `/clear`, the start hook hands that line back, so no session starts from a blank page.
- **No secrets in the vault**. Only note where they are stored.
- **Never edit `raw/`** once written. `wiki/` is maintained by the agent.
- **Availability**: an unreachable, stale or conflicted vault never blocks safe work. Continue from git, the live system and the runbooks, then reconcile the vault afterwards.

## Sources of truth

1. Live inspection is authoritative for current state.
2. Git is authoritative for code.
3. Release artifacts are authoritative for release identity and gates.
4. Runbooks are authoritative for procedures.
5. The vault is authoritative for intent, progress, decisions and open work.

On conflict, follow the technical source, then fix the vault.
<!-- END MANAGED SECOND-BRAIN POLICY -->
