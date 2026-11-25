# Orchestrating the v1 milestone

For the agent that runs the tickets in [spec §13](../spec.md#13-order-of-work-and-tickets) with subagents while the user is away. Follow the firmware repo's orchestration rules (`~/source/deluge-generative/docs/agents/orchestration.md`) except where this file says otherwise. Where the two differ, this file wins.

## Before the first ticket

- Read [spec §14](../spec.md#14-running-unattended). The run never stops as a whole: a problem parks one ticket.
- Check that the spec revision's PR is merged. A section still marked **Under review** is built as written.
- E11 waits for the spike in [#42](https://github.com/gismya/deluge-engine/issues/42). If #42 is still open when E11 is the next free ticket, skip E11 and say so in the state file.

## Differences from the firmware's rules

- **Notes dir:** `~/.cache/deluge-engine/`. It holds `orchestrator-state.md`, `notes/` (handoffs per ticket, `spike-findings.md`), and worktrees from earlier work (`firmware/`, `wt-perform`, `wt-prototype`). Never edit those. Make your own worktrees.
- **No integration branch in this repo.** E and G tickets branch from `main` and merge into `main` by PR.
- **Firmware:** F tickets branch from the firmware's `generative` and open PRs into it.
  - You merge an F PR into `generative` under spec §2, whatever its size: `./dbt sizediff` shows no change, **Run tests** is green, and a review pass is done.
  - A seam that changes the Release build waits for the user: label its ticket `ready-for-human` and add a line to the state file. F5 is one.
  - The firmware's own milestone run may merge into `generative` the same week. Whoever merges second brings their branch up to date first and reruns the checks.
  - After a seam merges, move the submodule pin in this repo with its own small PR.
- **Branches:** `v1/<ticket>-<slug>` in both repos, for example `v1/E2-platform-layer` or `v1/F1-64bit-pointers`.
- **PR bodies:**
  - E and G tickets: `Closes #<issue>`.
  - F tickets: link the deluge-engine issue by its full URL, and fill the firmware's PR template. Name the `sizediff` result and the `docs/upstream-candidates.md` entry.
- **Checks:**
  - E and G tickets: `python3 tools/check.py`, and CI green.
  - F tickets: the firmware's `python3 scripts/generative/check_all.py`, `./dbt sizediff`, and **Run tests** green.
  - F tickets don't need a hardware run when `sizediff` shows no change, because no ARM code changed. Note that in the PR.
- **Reviews:** one review pass per PR, from a fresh subagent given the diff and the ticket, not your conclusions. Fix the real findings, then merge. For a G ticket, the reviewer also reads the new golden images beside the prototype's (`prototype/screens/test/goldens/` on branch `prototype/screens`) and lists the differences.
- **Merging:** you merge. E and G PRs merge when CI is green and the review is done. F PRs merge under spec §2. Anything outside those rules waits for the user, labelled `ready-for-human`.
- **Which ticket next:** among the tickets whose blockers are done, take the one earliest in the order of spec §13.1.
- **Parallelism:** F1 to F4 run in parallel at the start, each in its own firmware worktree. After that, run at most two implementers at once: one on an E ticket and one on a G ticket when both are free, since they touch different folders. G tickets build against the fake Backend, so they never wait for the Engine.
- **Questions:** spec §14 lists the few cases that park a ticket. Park it with a `needs-info` comment on the ticket and a line under "Questions for the user" in `orchestrator-state.md`. Then go on with another ticket. A design choice the spec left open is not a question: the implementer picks, and you record the choice under "Defaults and fallbacks taken" in the state file.
- **Tickets:** when a ticket's PR merges, close the ticket if `Closes` didn't. When work shows a ticket is too large for one session, split it: create the second ticket as a sub-issue of #1 with its blocking links, and add it to the table in spec §13.2 in the same PR.
- **When the user is back:** the state file's top section is the summary they read first. List what merged, what's open, the questions, the defaults and fallbacks taken, and the Parity report with the listening pack's path.
