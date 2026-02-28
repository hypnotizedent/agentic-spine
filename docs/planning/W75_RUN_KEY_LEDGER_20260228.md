# W75 Run Key Ledger (20260228)

| step | command | run_key | status |
|---|---|---|---|
| phase0-1 | `./bin/ops cap run session.start ` | `CAP-20260228-063852__session.start__Rsiz833871` | done |
| phase0-2 | `./bin/ops cap run loops.status ` | `CAP-20260228-063910__loops.status__Rptrq50107` | done |
| phase0-3 | `./bin/ops cap run gaps.status ` | `CAP-20260228-063911__gaps.status__Rfc1l50869` | done |
| phase0-4 | `./bin/ops cap run gate.topology.validate ` | `CAP-20260228-063914__gate.topology.validate__R0qbb56292` | done |
| phase0-5 | `./bin/ops cap run verify.route.recommend ` | `CAP-20260228-063916__verify.route.recommend__R2me657415` | done |
| phase0-6 | `./bin/ops cap run verify.freshness.reconcile ` | `CAP-20260228-063917__verify.freshness.reconcile__Rcrcr58070` | done |
| phase0-7a | `./bin/ops cap run loops.create --title "W75 Weekly Steady State"` | `CAP-20260228-064044__loops.create__R25lk40354` | failed |
| phase0-7c | `./bin/ops cap run loops.create ` | `CAP-20260228-064101__loops.create__Rh8bh68564` | failed |
| phase0-7d | `./bin/ops cap run loops.create --name "W75 Weekly Steady State"` | `CAP-20260228-064111__loops.create__R7llp74261` | failed |
| phase0-7e | `./bin/ops cap run loops.create --name "W75 Weekly Steady State" --objective "Weekly steady-state governance maintenance" --owner "@ronny"` | `CAP-20260228-064118__loops.create__Rz4ub79213` | failed |
| phase0-7f | `./bin/ops cap run loops.create --name "W75 Weekly Steady State" --objective "Weekly steady-state governance maintenance"` | `CAP-20260228-064125__loops.create__Rxoze84904` | done |
| phase1-1 | `./bin/ops cap run verify.freshness.reconcile ` | `CAP-20260228-064138__verify.freshness.reconcile__Rgq8h91331` | done |
| phase1-2 | `./bin/ops cap run verify.pack.run hygiene-weekly ` | `CAP-20260228-064229__verify.pack.run__R8hcn26199` | done |
| phase1-3 | `./bin/ops cap run verify.pack.run workbench ` | `CAP-20260228-064254__verify.pack.run__R8xwx43893` | done |
| phase1-4 | `./bin/ops cap run verify.pack.run core ` | `CAP-20260228-064401__verify.pack.run__R0wo416256` | done |
| phase1-5 | `./bin/ops cap run verify.pack.run secrets ` | `CAP-20260228-064403__verify.pack.run__Rb8qe19908` | done |
| phase1-6 | `./bin/ops cap run verify.pack.run communications ` | `CAP-20260228-064423__verify.pack.run__R4ppl38425` | done |
| phase1-7 | `./bin/ops cap run verify.pack.run mint ` | `CAP-20260228-064431__verify.pack.run__R7kzi42712` | done |
| phase1-8 | `./bin/ops cap run verify.run -- fast ` | `CAP-20260228-064448__verify.run__Rwo6m49798` | done |
| phase3-loop-LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227.acceptance.w75.md"` | `CAP-20260228-064559__loop.closeout.finalize__R4ri332722` | failed |
| phase3-loop-LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227.acceptance.w75.md"` | `CAP-20260228-064600__loop.closeout.finalize__R6ram33235` | failed |
| phase3-loop-LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301.acceptance.w75.md"` | `CAP-20260228-064601__loop.closeout.finalize__R8zwz33744` | failed |
| phase3-loop2-LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227.acceptance.w75.md"` | `CAP-20260228-064619__loop.closeout.finalize__R447o39878` | failed |
| phase3-loop2-LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227.acceptance.w75.md"` | `CAP-20260228-064620__loop.closeout.finalize__Rjjxy40254` | failed |
| phase3-loop2-LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301.acceptance.w75.md"` | `CAP-20260228-064620__loop.closeout.finalize__Ro97t40576` | failed |
| phase3-loop-close-LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227.acceptance.w75.md"` | `CAP-20260228-064639__loop.closeout.finalize__Risdt63147` | done |
| phase3-loop-close-LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301.acceptance.w75.md"` | `CAP-20260228-064640__loop.closeout.finalize__R1rtv64503` | done |
| phase4-1 | `./bin/ops cap run verify.pack.run workbench ` | `CAP-20260228-064721__verify.pack.run__Rblhp96030` | done |
| phase4-2 | `./bin/ops cap run verify.pack.run hygiene-weekly ` | `CAP-20260228-064823__verify.pack.run__R6ru838641` | done |
| phase4-3 | `./bin/ops cap run verify.run -- domain communications ` | `CAP-20260228-064853__verify.run__Rxny461382` | done |
| phase4-4 | `./bin/ops cap run loops.status ` | `CAP-20260228-064901__loops.status__Refdh63518` | done |
| phase4-5 | `./bin/ops cap run gaps.status ` | `CAP-20260228-064902__gaps.status__Rz3iu63765` | done |
| phase3-candidates | `./bin/ops cap run loops.list --open` | `CAP-20260228-064514__loops.list__R9pr978541` | done |
| phase3-loop-close-LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227 | `./bin/ops cap run loop.closeout.finalize --loop-id "LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227" --acceptance-matrix "/Users/ronnyworks/code/agentic-spine/docs/planning/loop-closeouts/w75-20260228/LOOP-SPINE-NIGHTLY-CLOSEOUT-AUTOPILOT-20260227.acceptance.w75.md"` | `CAP-20260228-064629__loop.closeout.finalize__Rnm8c43890` | done |
