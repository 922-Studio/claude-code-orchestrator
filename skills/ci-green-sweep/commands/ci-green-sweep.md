# CI Green Sweep

Drive every 922-Studio repo to a green latest deploy and close every CI-failure issue —
repo by repo, via per-repo sub-agents. You orchestrate; only real work runs in sub-agents.

Load and follow the playbook:

1. Read `/Users/gregor/dev/922/orchestrator/skills/ci-green-sweep/SWEEP.md`
2. Execute it, starting with Phase 0 recon.

Get Gregor's two decisions (merge policy, infra scope) before dispatching fix agents. Sub-agents
use the Sonnet model. Hand back host/infra-parity blockers rather than editing hosts unless
explicitly authorized.
