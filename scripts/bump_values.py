#!/usr/bin/env python3
"""Update charts/api-pulse/values.yaml image tag, versions, and versionsActive.

Usage:
  bump_values.py <values.yaml> <service_key> <image_tag>
  bump_values.py <values.yaml> <service_key> <image_tag> --active-only

With --active-only: only append to versionsActive (for feature-branch canaries).
  Does not change images.*.tag or versions.* so global/default stays put.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def bump(path: Path, service_key: str, tag: str, *, active_only: bool = False) -> None:
    if service_key not in {"web", "auth", "analytics"}:
        raise SystemExit(f"unknown service_key: {service_key}")

    version_key = "ui" if service_key == "web" else service_key
    text = path.read_text()
    lines = text.splitlines(keepends=True)

    max_m = re.search(r"^versionsActiveMax:\s*(\d+)\s*$", text, re.M)
    max_keep = int(max_m.group(1)) if max_m else 5

    out: list[str] = []
    in_images = False
    in_service = False
    in_versions = False
    in_versions_active = False
    updated_image = False
    updated_version = False
    updated_active = False

    i = 0
    while i < len(lines):
        line = lines[i]
        # Keepends=True leaves trailing \n; strip it so endswith(":") / startswith work.
        stripped = line.lstrip().rstrip("\r\n")
        indent = len(line) - len(line.lstrip())

        if stripped.startswith("images:"):
            in_images = True
            in_versions = False
            in_versions_active = False
            in_service = False
            out.append(line)
            i += 1
            continue
        if stripped.startswith("versionsActive:"):
            in_versions_active = True
            in_images = False
            in_versions = False
            in_service = False
            out.append(line)
            i += 1
            continue
        if stripped.startswith("versions:") and not stripped.startswith("versionsActive"):
            in_versions = True
            in_images = False
            in_versions_active = False
            in_service = False
            out.append(line)
            i += 1
            continue
        if indent == 0 and stripped and not stripped.startswith("#"):
            if not (
                stripped.startswith("images:")
                or stripped.startswith("versions:")
                or stripped.startswith("versionsActive")
            ):
                in_images = False
                in_versions = False
                in_versions_active = False
            in_service = False

        if in_images and indent == 2 and stripped.startswith(f"{service_key}:"):
            in_service = True
            out.append(line)
            i += 1
            continue
        if in_images and indent == 2 and stripped.endswith(":") and not stripped.startswith(
            f"{service_key}:"
        ):
            in_service = False

        if (
            not active_only
            and in_images
            and in_service
            and indent >= 4
            and stripped.startswith("tag:")
        ):
            out.append(f"{' ' * indent}tag: {tag}\n")
            updated_image = True
            i += 1
            continue

        if (
            not active_only
            and in_versions
            and indent == 2
            and stripped.startswith(f"{version_key}:")
        ):
            out.append(f"{' ' * indent}{version_key}: \"{tag}\"\n")
            updated_version = True
            i += 1
            continue

        if in_versions_active and indent == 2 and stripped.startswith(f"{service_key}:"):
            out.append(line)
            i += 1
            items: list[str] = []
            while i < len(lines):
                item_line = lines[i]
                item_stripped = item_line.lstrip()
                if item_stripped.startswith("- "):
                    raw = item_stripped[2:].strip().strip('"').strip("'")
                    items.append(raw)
                    i += 1
                    continue
                break
            items = [t for t in items if t != tag]
            items.append(tag)
            items = items[-max_keep:]
            for t in items:
                out.append(f'    - "{t}"\n')
            updated_active = True
            continue

        out.append(line)
        i += 1

    if not active_only and not updated_image:
        raise SystemExit(f"failed to update images.{service_key}.tag")
    if not active_only and not updated_version:
        raise SystemExit(f"failed to update versions.{version_key}")
    if not updated_active:
        raise SystemExit(f"failed to update versionsActive.{service_key}")

    path.write_text("".join(out))
    if active_only:
        print(f"Appended versionsActive.{service_key} -> {tag} (active-only)")
    else:
        print(
            f"Updated images.{service_key}.tag, versions.{version_key}, "
            f"versionsActive.{service_key} -> {tag}"
        )


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--active-only"]
    active_only = "--active-only" in sys.argv[1:]
    if len(args) != 3:
        raise SystemExit(
            "usage: bump_values.py <values.yaml> <service_key> <image_tag> [--active-only]"
        )
    bump(Path(args[0]), args[1], args[2], active_only=active_only)
