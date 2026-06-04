#!/usr/bin/env python3
"""Normalize Terraform plan JSON or test JSONL for OPA plan policies."""

from __future__ import annotations

import json
import sys
from typing import Any


def planned_values(change: dict[str, Any]) -> dict[str, Any]:
    after = change.get("after")
    if isinstance(after, dict):
        return after
    before = change.get("before")
    if isinstance(before, dict):
        return before
    return {}


def include_resource(change: dict[str, Any]) -> bool:
    if change.get("mode") != "managed":
        return False
    actions = change.get("change", {}).get("actions", [])
    return actions not in (["delete"], ["no-op"])


def normalize_resource(change: dict[str, Any]) -> dict[str, Any]:
    detail = change.get("change", {})
    return {
        "address": change.get("address", ""),
        "mode": change.get("mode", ""),
        "type": change.get("type", ""),
        "name": change.get("name", ""),
        "actions": detail.get("actions", []),
        "change": detail,
        "values": planned_values(detail),
    }


def load_plans(raw: str) -> list[dict[str, Any]]:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        payload = None

    if isinstance(payload, dict):
        if "resource_changes" in payload:
            return [payload]
        if isinstance(payload.get("test_plan"), dict):
            return [payload["test_plan"]]

    plans: list[dict[str, Any]] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        plan = event.get("test_plan")
        if isinstance(plan, dict):
            plans.append(plan)
    return plans


def main() -> int:
    resources = []
    raw_changes = []
    for plan in load_plans(sys.stdin.read()):
        for change in plan.get("resource_changes", []):
            if include_resource(change):
                raw_changes.append(change)
                resources.append(normalize_resource(change))

    json.dump({"resources": resources, "resource_changes": raw_changes}, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
