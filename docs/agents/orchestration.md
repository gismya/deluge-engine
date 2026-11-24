# Orchestrating the v1 milestone

For the agent that runs the tickets in [spec §8](../spec.md#8-tickets) with subagents while the user is away. Follow the firmware repo's orchestration rules (`~/source/deluge-generative/docs/agents/orchestration.md`) except where this file says otherwise. Where the two differ, this file wins.

## Differences from the firmware's rules

- **Notes dir:** `~/.cache/deluge-engine/`. It holds `orchestrator-state.md`, `notes/` (handoffs per ticket, `spike-findings.md`) and `firmware/`, a read-only worktree of `generative` that the spike used. Make your own worktrees for firmware work; never edit that one.
- **No integration branch.** E tickets branch from `main` and merge into `main` by PR. F tickets branch from the firmware's `generative` and merge into it under spec §2.
- **Branches:** `v1/<ticket>-<slug>` in both repos, for example `v1/E2-platform-layer` or `v1/F1-64bit-pointers`.
- **PR bodies:**
  - E tickets: `Closes #<issue>`.
  - F tickets: link the deluge-engine issue by its full URL, and fill the firmware's PR template. Name the `sizediff` result and the `docs/upstream-candidates.md` entry.
- **Checks:**
  - E tickets: the commands E1 creates, and CI green.
  - F tickets: the firmware's `python3 scripts/generative/check_all.py`, `./dbt sizediff`, and **Run tests** green.
  - F tickets don't need a hardware run when `sizediff` shows no change, because no ARM code changed. Note that in the PR.
- **Reviews:** one review pass per PR, from a fresh subagent given the diff and the ticket, not your conclusions. Fix the real findings, then merge.
- **Merging:** you merge. E PRs merge when CI is green and the review is done. F PRs merge under spec §2. Anything outside those rules waits for the user, labelled `ready-for-human`.
- **Stopping:** spec §9 lists the cases where you stop and ask. Ask with a `needs-info` comment on the ticket and a line under "Questions for the user" in `orchestrator-state.md`. Then go on with unblocked tickets.
- **Parallelism:** F1 to F4 and E1 run in parallel at the start, each in its own worktree. After that, run at most two implementers at once.
- **When the user is back:** the state file's top section is the summary they read first. List what merged, what's open, the questions, and the parity report with the listening pack's path.
