#!/usr/bin/env bash
# PoC: turn a finished critical-pytest run into Pushgateway metrics.
#
# This is the logic destined for the "📊 Push critical-test metrics" step in
# DevOps/.github/workflows/build-deploy-critical-pytest.yml. It lives here as a
# standalone script so it can be run and verified locally, without a CI round
# trip, before it goes anywhere near the shared template.
#
# Counts come from allure-results/*-result.json, which the pytest step already
# produces and uploads — no second test run, no pytest output scraping.
#
# Usage:
#   ./poc-push-critical-metrics.sh --service docflow --environment dev \
#       --status success --allure-dir ./allure-results --repo DocBits_DocFlow
#
#   ./poc-push-critical-metrics.sh ... --dry-run     # print payload, push nothing

set -uo pipefail

PUSHGATEWAY="${PUSHGATEWAY_URL:-https://pushwebgateway.docbits.com}"
JOB_NAME="critical-tests"

SERVICE=""
ENVIRONMENT=""
STATUS=""
ALLURE_DIR="allure-results"
REPO="${GITHUB_REPOSITORY##*/}"
RUN_ID="${GITHUB_RUN_ID:-local}"
COMMIT="${GITHUB_SHA:0:7}"
IMAGE_TAG="${IMAGE_TAG:-unknown}"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --service)     SERVICE="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --status)      STATUS="$2"; shift 2 ;;          # success | failure
    --allure-dir)  ALLURE_DIR="$2"; shift 2 ;;
    --repo)        REPO="$2"; shift 2 ;;
    --run-id)      RUN_ID="$2"; shift 2 ;;
    --commit)      COMMIT="$2"; shift 2 ;;
    --image-tag)   IMAGE_TAG="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

[ -n "$SERVICE" ] && [ -n "$ENVIRONMENT" ] && [ -n "$STATUS" ] || {
  echo "--service, --environment and --status are required" >&2; exit 64
}

# ── counts from allure ─────────────────────────────────────────────────────
# Allure writes one *-result.json per test with a "status" of
# passed | failed | broken | skipped. "broken" is an error, not a pass, so it
# is folded into failed — a test that errored did not verify anything.
count_status() {
  local want="$1" n=0
  shopt -s nullglob
  for f in "$ALLURE_DIR"/*-result.json; do
    local s
    s=$(sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$f" | head -1)
    [ "$s" = "$want" ] && n=$((n + 1))
  done
  shopt -u nullglob
  echo "$n"
}

PASSED=$(count_status passed)
FAILED=$(( $(count_status failed) + $(count_status broken) ))
SKIPPED=$(count_status skipped)

# The gate's own verdict wins over the counts. pytest exit code 5 (no critical
# tests collected) is a deliberate pass in this template, and it yields zero of
# everything — that must still report status=1, or every service without
# critical tests would light up red.
if [ "$STATUS" = "success" ]; then STATUS_VALUE=1; else STATUS_VALUE=0; fi

NOW=$(date +%s)

# ── grouping key ───────────────────────────────────────────────────────────
# Grouping-key labels are what make a push idempotent: re-pushing the same key
# REPLACES the group instead of appending. service+environment means dev and
# stage keep separate rows and never overwrite each other.
#
# Values containing "/" (feature branches like feat/foo) would break the URL
# path, so those are sent base64-encoded via the label@base64 form, which the
# Pushgateway understands natively.
enc_segment() {
  local label="$1" value="$2"
  if printf '%s' "$value" | grep -q '[/]'; then
    printf '%s@base64/%s' "$label" "$(printf '%s' "$value" | base64 | tr -d '\n' | tr '+/' '-_')"
  else
    printf '%s/%s' "$label" "$value"
  fi
}

URL="$PUSHGATEWAY/metrics/job/$JOB_NAME/$(enc_segment service "$SERVICE")/$(enc_segment environment "$ENVIRONMENT")"

# ── payload ────────────────────────────────────────────────────────────────
# environment lives ONLY in the grouping key. Repeating it in the body would
# collide with the key-derived label and the Pushgateway would reject the push.
#
# run_id/commit/image_tag are high-cardinality and stay on _run_info only;
# putting them on the status metric would mint a fresh series every pipeline run.
PAYLOAD=$(cat <<EOF
# HELP docbits_critical_tests_status Critical test gate result of the latest run (1=pass, 0=fail)
# TYPE docbits_critical_tests_status gauge
docbits_critical_tests_status{branch="$ENVIRONMENT",repo="$REPO"} $STATUS_VALUE
# HELP docbits_critical_tests_timestamp_seconds Unix time the latest critical-test run finished
# TYPE docbits_critical_tests_timestamp_seconds gauge
docbits_critical_tests_timestamp_seconds{branch="$ENVIRONMENT",repo="$REPO"} $NOW
# HELP docbits_critical_tests_total Test counts of the latest run
# TYPE docbits_critical_tests_total gauge
docbits_critical_tests_total{result="passed"} $PASSED
docbits_critical_tests_total{result="failed"} $FAILED
docbits_critical_tests_total{result="skipped"} $SKIPPED
# HELP docbits_critical_tests_run_info Run metadata (always 1; labels carry the payload)
# TYPE docbits_critical_tests_run_info gauge
docbits_critical_tests_run_info{run_id="$RUN_ID",commit="$COMMIT",image_tag="$IMAGE_TAG"} 1
EOF
)

echo "service=$SERVICE environment=$ENVIRONMENT status=$STATUS_VALUE passed=$PASSED failed=$FAILED skipped=$SKIPPED"
echo "POST $URL"
echo "$PAYLOAD"

if [ "$DRY_RUN" = "1" ]; then
  echo "--dry-run: nothing sent"
  exit 0
fi

HTTP=$(printf '%s\n' "$PAYLOAD" | curl -s -o /tmp/pushgw-resp.txt -w '%{http_code}' \
  --max-time 30 --data-binary @- "$URL")

echo "HTTP $HTTP"
[ -s /tmp/pushgw-resp.txt ] && cat /tmp/pushgw-resp.txt

# 200/202 = accepted. Anything else is reported but never fails the caller:
# a metrics push must not turn a green test run red.
case "$HTTP" in
  200|202) echo "OK — metrics pushed"; exit 0 ;;
  *) echo "WARN — push rejected (HTTP $HTTP); test result is unaffected" >&2; exit 0 ;;
esac
