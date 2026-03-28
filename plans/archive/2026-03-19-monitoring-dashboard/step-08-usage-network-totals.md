# Executor Prompt — Step 8: Usage Page — Network TX/RX Totals

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homeui.md` — stack, patterns, testing rules
2. `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UsagePage.tsx` — full file
4. `/Users/gregor/dev/922/HomeUI/src/features/dashboard/pages/UsagePage.test.tsx` — existing tests
5. `/Users/gregor/dev/922/HomeCollector/app/services/prometheus_service.py` — read the `network_transfer` metric collection to determine whether `rx_bytes`/`tx_bytes` are **cumulative counters** or **per-interval values**

---

## What to implement

### Goal
Remove "Net ↓" and "Net ↑" stat cards from the top of the Usage page. Replace them with "Net RX" and "Net TX" stat cards that show the total bytes transferred within the selected time range.

### Step 1: Read `prometheus_service.py` first

Before writing code, read `HomeCollector/app/services/prometheus_service.py` and find how `network_transfer` data is fetched. Determine:
- Are `rx_bytes` / `tx_bytes` **cumulative counters** (ever-increasing, like OS network interface counters from Node Exporter `node_network_receive_bytes_total`)? → Use `last - first` to get range total.
- Or are they **per-interval snapshot values** (already a rate or delta)? → Use `sum(rx_bytes)`.

Use the correct calculation method. If uncertain, check what Prometheus metric name is being queried (counters have `_total` suffix in Prometheus convention).

### Step 2: Update `UsagePage.tsx`

**Remove these two StatCards** (find them in the stat cards section, they use `netRx` and `netTx`):
```tsx
<StatCard label="Net ↓" value={history ? formatBytes(netRx) : '—'} />
<StatCard label="Net ↑" value={history ? formatBytes(netTx) : '—'} />
```
Also remove the variables `netRx` and `netTx` if they are no longer used elsewhere (check the file — they may only be used in these cards).

**Add total computation** after the existing `lastNetTransfer` lines:

```typescript
// Get all network data filtered to the selected range
const filteredNetwork = history ? filterByRange(history.network_transfer, range) : []

// Compute range totals
// If rx_bytes/tx_bytes are cumulative counters: use last - first
const netRxTotal = filteredNetwork.length >= 2
  ? Math.max(0, filteredNetwork[filteredNetwork.length - 1].rx_bytes - filteredNetwork[0].rx_bytes)
  : 0
const netTxTotal = filteredNetwork.length >= 2
  ? Math.max(0, filteredNetwork[filteredNetwork.length - 1].tx_bytes - filteredNetwork[0].tx_bytes)
  : 0

// If they are per-interval values, use sum instead:
// const netRxTotal = filteredNetwork.reduce((s, p) => s + p.rx_bytes, 0)
// const netTxTotal = filteredNetwork.reduce((s, p) => s + p.tx_bytes, 0)
```

Choose the correct approach based on what you read in `prometheus_service.py`.

**Add the two replacement StatCards** in the same position where the old cards were:
```tsx
<StatCard
  label="Net RX"
  value={history ? formatBytes(netRxTotal) : '—'}
  unit="total"
/>
<StatCard
  label="Net TX"
  value={history ? formatBytes(netTxTotal) : '—'}
  unit="total"
/>
```

### Step 3: Update tests

In `UsagePage.test.tsx`:
- Verify "Net ↓" and "Net ↑" are NOT rendered
- Verify "Net RX" and "Net TX" ARE rendered with total values
- If there are existing tests checking for the old card labels, update them

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
Fix any failures. Ensure coverage ≥70%.

## Commit & Push
```bash
git add src/features/dashboard/pages/UsagePage.tsx \
        src/features/dashboard/pages/UsagePage.test.tsx
git commit -m "fix(usage): replace Net↑/↓ instant stat cards with Net RX/TX total for selected range"
git push origin main
```

## Report format
```
=== STEP 8 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 8 - Usage Page Network Totals
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [counter vs gauge decision + reasoning, which calculation method used]
```
