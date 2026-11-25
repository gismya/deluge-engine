# Orchestrating the v1 milestone

For the agent that runs the v1 tickets with subagents while the user is away (the `mattpocock-skills:implement-spec` skill). These are the user's standing rules: follow them without asking again. Where this file differs from the skill, this file wins. It stands alone: the firmware repo's orchestration doc doesn't apply to this run.

- Spec: [docs/spec.md](../spec.md). The order is §13.1, the ticket table §13.2, and the parking rules and limits §14.
- Epic: [v1: play Deluge presets on the computer](https://github.com/gismya/deluge-engine/issues/1). The tickets are its sub-issues, wired with native blocking links.

## State and resuming

- **Notes dir:** `~/.cache/deluge-engine/`, outside the repo.
  - `notes/<ticket>.md`: one handoff per ticket.
  - `orchestrator-state.md`: your state. It records, per PR, the review round, the CI runs and the agent threads, plus "Questions for the user" and "Defaults and fallbacks taken". With it, a fresh session can take over.
  - `firmware/`, `wt-perform` and `wt-prototype` are earlier work. Leave them untouched, and make your own worktrees.
- **The state file's first line** reads: "On resume (a restart or a compaction), re-read `docs/agents/orchestration.md`, and list the scheduled tasks: delete an old heartbeat bound to a dead thread and start your own." A summary of the session keeps the work but drops these rules.
- **Heartbeat:** while subagents run, and while you're paused, keep a T3 `schedule_task` bound to your thread every 55 minutes (`{type: 'interval', everyMs: 3300000}`). Each beat checks every running agent and open PR, advances what's ready, and updates the state file. Delete it when the run ends.
- A trap that later agents need goes into `docs/implementation-notes.md`, in the ticket's PR. The handoffs are for this run only.

## Choosing tickets

- **Next ticket:** among the open tickets whose blockers are all closed, take the one earliest in spec §13.1.
- **Parallelism:** F1 to F4 start in parallel, each in its own firmware worktree. After that, run at most two implementers at once: one on an E or F ticket and one on a G ticket when both are free, since they touch different folders. G tickets build against the fake Backend, so they never wait for the Engine.
- **Pass each implementer** the NITs that earlier reviews left in the code it will touch.
- **Implementers don't close, edit or comment on tickets:** you do.

## Implementer brief

Include this in each implementer's prompt, with the ticket, its branch and its worktree.

1. Read `AGENTS.md`, the ticket and the spec sections it links, `docs/implementation-notes.md`, and the handoffs in `notes/` for the code you'll touch.
2. Work in your own worktree on `v1/<ticket>-<slug>`, from `origin/main`. Check `git merge-base --is-ancestor origin/main HEAD`. If it fails, run `git fetch origin && git switch -C <branch> origin/main`. `git reset` and `git rebase` are blocked for agents. Bring a branch up to date by merging `origin/main` into it.
3. Build test-first with the `tdd` skill. It asks you to confirm the test seams with the user, which a subagent can't do: choose the seams yourself, preferring existing ones, and list them in your report.
4. Before reporting:
   - merge `origin/main`;
   - run `python3 tools/check.py` until it passes;
   - push with `git enginepush -u <branch>`;
   - open a PR into `main`, with the body from the `mattpocock-skills:pr` skill and a `Closes #<ticket>` line.
5. Write `notes/<ticket>.md`, short:
   - where the code lives;
   - the seams later tickets extend;
   - what's deferred;
   - the choices the spec left open;
   - checks only a human can do.
6. **Report:**
   - the PR URL, branch and head SHA;
   - the CI run's URL and state;
   - the checks you ran, with results;
   - human checks left, and anything deferred.

   Under **Tooling problems**, list any tool, skill, script or repo doc that got in your way and what you did instead. The user's rule is that tooling gets fixed during the build.
7. **Finish your own long commands in the same turn:** builds, `tools/check.py`, delugemu renders. Run them in the foreground with a long Bash timeout (up to 600000 ms, repeated), or in the background with an exit marker:
   - `cmd > LOG 2>&1; echo "cmd exit=$?" >> LOG`;
   - then wait with Monitor and an until-loop on that line, `until grep -q 'cmd exit=' LOG; do sleep 30; done`, with `timeout_ms: 1800000`, re-armed until the line appears.
   - A background task that ends without its `exit=` line was killed. Report it with the log's tail.
   - CI is the exception: report the run and let the orchestrator check it.

   Your last message is the report. A status line such as "waiting for …" ends the turn and gets read as the result.
8. **On review findings:** fix them on the same branch, push, and report what you changed and what you declined, with the reason. Before fixing a MUST, look for other cases of the same bug and fix those too. Add each round to `notes/<ticket>.md`, because a later round may start in a fresh session.
9. **Keep your context small.** Send long output (builds, checks, render logs) to a file and read only its tail or its failures. Read files in the ranges you need.

**F tickets** (firmware seams) also follow these, in place of steps 2 and 4:
- Read the firmware's `AGENTS.md`; its rules apply.
- Work in your own worktree of `~/source/deluge-generative` on `v1/<ticket>-<slug>` from `origin/generative`.
- Before reporting:
  - run `./dbt exec "pre-commit run --files <paths>"` before `git add`;
  - run `python3 scripts/generative/check_all.py`;
  - run `./dbt sizediff`.

  `check_all.py` takes 5 to 10 minutes, so use the background pattern from step 7.
- Push with `git delugepush -u <branch>`. Open the PR into `generative`, fill the firmware's PR template, and link the deluge-engine ticket by its full URL.
- Name the `sizediff` result in the PR. When it shows no change, no hardware run is needed, because no ARM code changed. Say so in the PR.
- Add the `docs/upstream-candidates.md` entry.

## Reviews and merging

- **One review pass per PR**, from a fresh agent given the diff and the ticket, not your conclusions. Send the fixes to the implementer's thread; make small ones yourself. After a fix round, the same reviewer re-checks only `git diff <reviewed head>..HEAD` against its MUSTs. A big fix gets a full pass again: a design change, or about 150 lines or more.
- **For G tickets,** the reviewer also compares the new golden images with the prototype's (`prototype/screens/test/goldens/` on branch `prototype/screens`) and lists the differences.
- **Merge E and G PRs yourself** when the review is happy and CI is green. A run stuck in the queue may be ignored; a failing one gets fixed.
- **Merge F PRs into `generative` yourself, whatever their size,** when:
  - `./dbt sizediff` shows no change;
  - **Run tests** is green;
  - the review is happy.

  A seam that changes the Release build (F5, and any other) waits for the user: label its ticket `ready-for-human` and add a line to the state file. After a seam merges, move the submodule pin in its own small PR.
- **After a merge,** close the ticket if `Closes` didn't, which unblocks what it blocked.
- **NITs never hold up a merge.** Hand each to the next implementer working in that code, or add it to `nit-backlog.md` in the notes dir (source PR, file, problem, fix). One implementer fixes the backlog in batches, in its own reviewed PR.
- **Context past 450k tokens:** before sending a fix round, check the implementer's context with `python3 ~/source/deluge-generative/scripts/agents/agent_context.py`. Past 450k, send the round with `freshContext: true` and a self-contained brief: the PR, the branch and head, `notes/<ticket>.md`, the implementer brief, and the findings in full.

**Reviewer brief** (include in each review prompt):
- The diff is `git diff $(git merge-base origin/<base> HEAD)...HEAD`. Drop findings outside it.
- Raise a MUST only for a behaviour bug against the spec or the ticket. Everything else is a NIT, with file and fix.
- Finish every command and sub-agent you start in the same turn. Your last message is the verdict: HAPPY, or CHANGES with the MUSTs.

## Tickets on GitHub

- **Too large for one session:** split it. Create the second ticket as a sub-issue of #1 with its blocking links, and add it to the table in spec §13.2 in the same PR.
- **Links use the issue's numeric `id`, not its number.** Read it with `gh api repos/gismya/deluge-engine/issues/<n> --jq .id`. Pass it as an integer with `-F`:
  - sub-issue: `gh api -X POST repos/gismya/deluge-engine/issues/1/sub_issues -F sub_issue_id=<id>`
  - blocking: `gh api -X POST repos/gismya/deluge-engine/issues/<blocked n>/dependencies/blocked_by -F issue_id=<blocker id>`

  Before a bulk edit, list what exists, then edit those issues by number. A script that creates where it should edit leaves duplicates.

## Parking and questions

Spec §14 lists the few cases that park a ticket. Park it with a `needs-info` comment on the ticket and a line under "Questions for the user" in the state file, then take the next free ticket. The run never stops as a whole.

A design choice the spec left open isn't a question. The implementer picks the simplest thing that meets the ticket, and you record it under "Defaults and fallbacks taken".

Never block on a human. Checks only a human can do, such as listening, go in the handoffs and the state file.

## Shared machine

The firmware's own milestone run (M5) shares this Mac and the firmware's `generative` branch.
- Start a delugemu instance only while fewer than 4 `qemu-system-arm` processes are running in total, M5's included (`pgrep -c qemu-system-arm`).
- Run one `check_all.py` at a time.
- Whoever merges into `generative` second merges `origin/generative` into their branch first and reruns the checks.
- To ask M5 for something, comment on a gismya/deluge-generative issue. Never push to M5's branches.

## When every ticket is closed

1. Run the `code-review` skill over `main` from fb02504 (the spec revision) to the tip, to find problems no single PR shows. File each real finding as a ticket under #1 and fix it like any other.
2. Write the state file's top section for the user, who reads it first:
   - what merged and what's open;
   - the questions;
   - the defaults and fallbacks taken;
   - the Parity report, with the listening pack's path.
3. Delete the heartbeat, and clean up the worktrees and merged branches the run made.
