#!/usr/bin/env python3
"""PoC: push a critical-test-status metric into Thanos via remote-write.

Answers one question: can a short-lived CI job write a metric straight to
https://thanos-receive.docbits.com/api/v1/receive without a Pushgateway?

Remote-write wants a snappy-compressed, protobuf-encoded WriteRequest. Both are
hand-rolled here so the script runs on a bare GitHub runner with nothing but
`requests` — no protoc, no libsnappy.

Usage:
    ./poc-thanos-remote-write.py --service docflow --status 1
    ./poc-thanos-remote-write.py --service docflow --status 0 --dry-run

Verify (thanos-query has no public ingress, so tunnel to it):
    kubectl --context do-fra1-polydocs -n kube-prometheus-stack \
        port-forward svc/thanos-query 9090:9090
    curl -s 'http://localhost:9090/api/v1/query?query=docbits_critical_tests_status' | jq
"""

from __future__ import annotations

import argparse
import struct
import sys
import time

import requests

DEFAULT_ENDPOINT = "https://thanos-receive.docbits.com/api/v1/receive"


# ── protobuf wire format ───────────────────────────────────────────────────
# Only what prometheus/prompb/remote.proto needs:
#   WriteRequest { repeated TimeSeries timeseries = 1; }
#   TimeSeries   { repeated Label labels = 1; repeated Sample samples = 2; }
#   Label        { string name = 1; string value = 2; }
#   Sample       { double value = 1; int64 timestamp = 2; }


def _varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        out.append(b | 0x80 if n else b)
        if not n:
            return bytes(out)


def _tag(field: int, wire: int) -> bytes:
    return _varint((field << 3) | wire)


def _len_delimited(field: int, payload: bytes) -> bytes:
    return _tag(field, 2) + _varint(len(payload)) + payload


def _string(field: int, value: str) -> bytes:
    return _len_delimited(field, value.encode("utf-8"))


def _double(field: int, value: float) -> bytes:
    return _tag(field, 1) + struct.pack("<d", value)


def _int64(field: int, value: int) -> bytes:
    # Protobuf int64 is zig-zag free: negatives would need 10-byte varints.
    # Timestamps are always positive here, so the plain varint is correct.
    return _tag(field, 0) + _varint(value)


def encode_label(name: str, value: str) -> bytes:
    return _string(1, name) + _string(2, value)


def encode_sample(value: float, timestamp_ms: int) -> bytes:
    return _double(1, value) + _int64(2, timestamp_ms)


def encode_timeseries(labels: dict[str, str], value: float, timestamp_ms: int) -> bytes:
    # Remote-write requires labels sorted by name; Thanos rejects unsorted sets.
    body = b"".join(
        _len_delimited(1, encode_label(k, labels[k])) for k in sorted(labels)
    )
    body += _len_delimited(2, encode_sample(value, timestamp_ms))
    return body


def encode_write_request(series: list[tuple[dict[str, str], float, int]]) -> bytes:
    return b"".join(
        _len_delimited(1, encode_timeseries(lbls, val, ts)) for lbls, val, ts in series
    )


# ── snappy block format ────────────────────────────────────────────────────
# A stream of literal-only chunks is a valid snappy block: we give up
# compression (the payload is a few hundred bytes) and gain zero dependencies.


def snappy_compress(data: bytes) -> bytes:
    out = bytearray(_varint(len(data)))
    pos = 0
    while pos < len(data):
        chunk = data[pos : pos + 65536]
        pos += len(chunk)
        n = len(chunk) - 1
        if n < 60:
            out.append(n << 2)
        elif n < 1 << 8:
            out.append(60 << 2)
            out += n.to_bytes(1, "little")
        elif n < 1 << 16:
            out.append(61 << 2)
            out += n.to_bytes(2, "little")
        elif n < 1 << 24:
            out.append(62 << 2)
            out += n.to_bytes(3, "little")
        else:
            out.append(63 << 2)
            out += n.to_bytes(4, "little")
        out += chunk
    return bytes(out)


# ── the actual metric ──────────────────────────────────────────────────────


def build_series(args: argparse.Namespace) -> list[tuple[dict[str, str], float, int]]:
    now_ms = int(time.time() * 1000)
    now_s = now_ms // 1000

    common = {
        "service": args.service,
        "environment": args.environment,
        "branch": args.branch,
        "repo": args.repo,
    }

    series: list[tuple[dict[str, str], float, int]] = [
        ({"__name__": "docbits_critical_tests_status", **common}, float(args.status), now_ms),
        (
            {"__name__": "docbits_critical_tests_timestamp_seconds", **common},
            float(now_s),
            now_ms,
        ),
    ]

    for result, count in (
        ("passed", args.passed),
        ("failed", args.failed),
        ("skipped", args.skipped),
    ):
        series.append(
            (
                {
                    "__name__": "docbits_critical_tests_total",
                    "service": args.service,
                    "environment": args.environment,
                    "result": result,
                },
                float(count),
                now_ms,
            )
        )

    # Run metadata rides in labels on an always-1 gauge. High-cardinality labels
    # (run_id, commit, image_tag) live ONLY here — putting them on the status
    # metric would mint a fresh series per pipeline run.
    series.append(
        (
            {
                "__name__": "docbits_critical_tests_run_info",
                "service": args.service,
                "environment": args.environment,
                "run_id": args.run_id,
                "commit": args.commit,
                "image_tag": args.image_tag,
            },
            1.0,
            now_ms,
        )
    )
    return series


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    p.add_argument("--service", default="poc-service")
    p.add_argument("--environment", default="dev")
    p.add_argument("--branch", default="dev")
    p.add_argument("--repo", default="DocBits_PoC")
    p.add_argument("--status", type=int, choices=(0, 1), default=1)
    p.add_argument("--passed", type=int, default=12)
    p.add_argument("--failed", type=int, default=0)
    p.add_argument("--skipped", type=int, default=0)
    p.add_argument("--run-id", default="poc-local")
    p.add_argument("--commit", default="0000000")
    p.add_argument("--image-tag", default="0.0.0-poc")
    p.add_argument("--timeout", type=int, default=30)
    p.add_argument("--dry-run", action="store_true", help="encode and report sizes, send nothing")
    args = p.parse_args()

    series = build_series(args)
    raw = encode_write_request(series)
    body = snappy_compress(raw)

    print(f"series:     {len(series)}")
    print(f"protobuf:   {len(raw)} bytes")
    print(f"snappy:     {len(body)} bytes")
    for labels, value, _ in series:
        name = labels["__name__"]
        rest = ",".join(f'{k}="{v}"' for k, v in sorted(labels.items()) if k != "__name__")
        print(f"  {name}{{{rest}}} {value:.0f}")

    if args.dry_run:
        print("\n--dry-run: nothing sent")
        return 0

    headers = {
        "Content-Type": "application/x-protobuf",
        "Content-Encoding": "snappy",
        "X-Prometheus-Remote-Write-Version": "0.1.0",
        "User-Agent": "docbits-critical-tests-poc/1",
    }

    print(f"\nPOST {args.endpoint}")
    try:
        r = requests.post(args.endpoint, data=body, headers=headers, timeout=args.timeout)
    except requests.RequestException as e:
        print(f"transport error: {e}", file=sys.stderr)
        return 2

    print(f"HTTP {r.status_code}")
    if r.text.strip():
        print(f"body: {r.text.strip()[:500]}")

    # Thanos Receive answers 200 or 204 on success; 409 means a duplicate sample
    # for an identical series+timestamp, which still proves the path works.
    if r.status_code in (200, 204):
        print("\nOK — remote-write accepted. Verify with:")
        print("  kubectl --context do-fra1-polydocs -n kube-prometheus-stack \\")
        print("      port-forward svc/thanos-query 9090:9090")
        print("  curl -s 'http://localhost:9090/api/v1/query?query=docbits_critical_tests_status' | jq")
        return 0

    print("\nremote-write rejected", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
