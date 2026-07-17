#!/usr/bin/env python3
"""Render Istio Gateway + VirtualServices from routing/tenants.yaml.

Usage:
  scripts/render-istio-routing.py [tenants.yaml] [output_dir]

Resolution: for each service, tenant[svc] ?? global[svc].
Writes:
  gateway.yaml
  vs-<service>.yaml
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    raise SystemExit(1)


NAMESPACE = "api-pulse"
GATEWAY_NAME = "api-pulse-gateway"
# Istio ingress gateway service in istio-system
INGRESS_SELECTOR = {"istio": "ingressgateway"}


def load_routing(path: Path) -> dict:
    data = yaml.safe_load(path.read_text())
    if not data or data.get("kind") != "TenantRouting":
        raise SystemExit(f"expected TenantRouting in {path}")
    return data["spec"]


def resolve(global_pins: dict, tenant_pins: dict, service: str) -> str:
    if service in tenant_pins and tenant_pins[service]:
        return str(tenant_pins[service])
    return str(global_pins[service])


def host_for(prefix: str, tag: str) -> str:
    return f"{prefix}-{tag}.{NAMESPACE}.svc.cluster.local"


def render_gateway() -> dict:
    return {
        "apiVersion": "networking.istio.io/v1beta1",
        "kind": "Gateway",
        "metadata": {
            "name": GATEWAY_NAME,
            "namespace": NAMESPACE,
            "labels": {"app.kubernetes.io/name": "api-pulse", "app.kubernetes.io/part-of": "odin"},
        },
        "spec": {
            "selector": INGRESS_SELECTOR,
            "servers": [
                {
                    "port": {"number": 80, "name": "http", "protocol": "HTTP"},
                    "hosts": ["*"],
                }
            ],
        },
    }


def render_virtual_service(svc: dict, spec: dict) -> dict:
    name = svc["name"]
    prefix = svc["k8sServicePrefix"]
    port = int(svc.get("port", 80))
    gateway_path = svc.get("gatewayPath", "/")
    global_pins = spec["global"]
    tenants = spec.get("tenants") or {}

    http_routes: list[dict] = []

    for slug, pins in sorted(tenants.items()):
        pins = pins or {}
        tag = resolve(global_pins, pins, name)
        # Only emit a match when tenant overrides this service (or always for clarity).
        # Always emit so changing only one service still has a dedicated match row.
        match: dict = {
            "headers": {"x-tenant-slug": {"exact": slug}},
        }
        if gateway_path and gateway_path != "/":
            match["uri"] = {"prefix": gateway_path}
        elif gateway_path == "/":
            # Root VS: exclude /auth and /analytics via separate VS path matches on those.
            # Web matches everything else with prefix /
            match["uri"] = {"prefix": "/"}

        route_entry: dict = {
            "match": [match],
            "route": [
                {
                    "destination": {
                        "host": host_for(prefix, tag),
                        "port": {"number": port},
                    }
                }
            ],
        }
        if gateway_path and gateway_path != "/":
            # Strip gateway prefix only. Plain rewrite uri:/ can turn /auth/health into //health.
            stripped = gateway_path.rstrip("/")
            route_entry["rewrite"] = {
                "uriRegexRewrite": {
                    "match": f"^{stripped}(/|$)(.*)",
                    "rewrite": "/\\2",
                }
            }
        http_routes.append(route_entry)

    # Default / no header → global
    default_tag = str(global_pins[name])
    default_entry: dict = {}
    if gateway_path and gateway_path != "/":
        stripped = gateway_path.rstrip("/")
        default_entry["match"] = [{"uri": {"prefix": gateway_path}}]
        default_entry["rewrite"] = {
            "uriRegexRewrite": {
                "match": f"^{stripped}(/|$)(.*)",
                "rewrite": "/\\2",
            }
        }
    else:
        default_entry["match"] = [{"uri": {"prefix": "/"}}]
    default_entry["route"] = [
        {
            "destination": {
                "host": host_for(prefix, default_tag),
                "port": {"number": port},
            }
        }
    ]
    http_routes.append(default_entry)

    # For web, avoid stealing /auth and /analytics: use regex or rely on VS length.
    # Istio picks the most specific match across VirtualServices on the same gateway.
    # Longer prefix (/auth) wins over (/).

    return {
        "apiVersion": "networking.istio.io/v1beta1",
        "kind": "VirtualService",
        "metadata": {
            "name": f"api-pulse-{name}",
            "namespace": NAMESPACE,
            "labels": {
                "app.kubernetes.io/name": "api-pulse",
                "app.kubernetes.io/part-of": "odin",
                "odin.cd-demo.io/service": name,
            },
        },
        "spec": {
            "hosts": ["*"],
            "gateways": [f"{NAMESPACE}/{GATEWAY_NAME}"],
            "http": http_routes,
        },
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    tenants_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "routing" / "tenants.yaml"
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "routing" / "generated"
    out_dir.mkdir(parents=True, exist_ok=True)

    spec = load_routing(tenants_path)

    gateway = render_gateway()
    (out_dir / "gateway.yaml").write_text(
        yaml.dump(gateway, sort_keys=False, default_flow_style=False)
    )

    for svc in spec["services"]:
        vs = render_virtual_service(svc, spec)
        # Fix web matches: when gatewayPath is /, tenant matches should not require
        # colliding with /auth — Istio specificity handles it.
        name = svc["name"]
        path = out_dir / f"vs-{name}.yaml"
        path.write_text(yaml.dump(vs, sort_keys=False, default_flow_style=False))
        print(f"wrote {path.relative_to(root)}")

    print(f"wrote {(out_dir / 'gateway.yaml').relative_to(root)}")
    print("done")


if __name__ == "__main__":
    main()
