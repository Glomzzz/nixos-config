#!/usr/bin/env python3
"""Render mihomo's proxy and group configuration on top of a base file.

Proxy sources:
- vless-hk and vless-sg: REALITY nodes from secrets (vless.<region>.*). They do
  not depend on the subscription. The ai group uses vless-sg only, with no fallback.
  Singapore nodes (vless-sg and subscription nodes named SG, Singapore or 新加坡)
  dial through vless-hk as a mid-point hop.
- subscription nodes: fetched from the private subscription URL (VLESS, Trojan,
  AnyTLS). They form the general proxy pool when reachable.

Secret values are passed as file paths, never as arguments, and only counts are
printed. The rendered configuration is written with mode 0600 to tmpfs.

After each successful fetch the node list is encrypted to the YubiKey's public
encryption subkey. When the subscription is unreachable, subscription nodes come
from, in order: the last rendered configuration (this boot), then the cache
unlocked by the unlock command. With neither, the proxy runs on the VLESS nodes alone.
"""

import argparse
import base64
import binascii
import copy
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
from urllib.parse import parse_qs, unquote, urlsplit
from urllib.request import Request, urlopen

# Names that subscription nodes must not take: our groups, our VLESS nodes, and
# mihomo's built-in names.
RESERVED_NAMES = {
    "proxy", "auto", "dns-auto", "ai", "vless-hk", "vless-sg",
    "DIRECT", "direct", "REJECT", "reject", "GLOBAL", "global",
}
PROXY_TYPES = {"vless", "trojan", "anytls"}
# Fingerprints accepted by mihomo's client-fingerprint option.
CLIENT_FINGERPRINTS = {"chrome": "chrome", "firefox": "firefox", "safari": "safari",
                       "ios": "iOS", "android": "android", "edge": "edge",
                       "360": "360", "qq": "qq", "random": "random"}
REALITY_FINGERPRINT = "chrome"
# Sent with the subscription request. Not yet tested against the provider with another value.
USER_AGENT = "v2rayA"
TEST_URL = "https://www.gstatic.com/generate_204"
# Subscription info entries are not servers ("剩余 13.21GB 流量", "将在 11-12 恢复", ...).
INFO_NODE = re.compile(r"剩余|将在|订阅更新")
# Automatic selection tests only these exit regions; the manual selector keeps all.
AUTO_REGION = re.compile(
    r"\b(HK|TW|JP|SG|KR|US|UK|AU|MY|PH|VN)\b|Hong Kong|Taiwan|Japan|California"
    r"|新加坡|香港|台湾|日本|韩国|美国|英国|澳大利亚|马来西亚|菲律宾|越南",
    re.IGNORECASE,
)
# Turkey exits, and nodes the subscription marks as failing, stay manual-only.
AUTO_EXCLUDE = re.compile(r"土耳其|故障")
# Singapore nodes dial through vless-hk (dialer-proxy). A direct connection to Singapore is slow.
SG_REGION = re.compile(r"\bSG\b|Singapore|新加坡", re.IGNORECASE)
RELAY = "vless-hk"
VLESS_REGIONS = ("hk", "sg")
# Field names as stored in nixos-secrets (vless.<region>.<field>).
VLESS_FIELDS = ("host", "port", "uuid", "public-key", "short-id", "sni")
UUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
HOST = re.compile(r"[A-Za-z0-9._:-]+")
# A bare hostname: no port, no path, no whitespace.
SNI = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*")


class RenderError(Exception):
    pass


class Unsupported(Exception):
    pass


def read_value(path):
    value = Path(path).read_text().strip()
    if not value or any(ch in value for ch in "\x00\r\n"):
        raise RenderError(f"invalid value in {Path(path).name}")
    return value


def read_or_create_secret(path):
    # Controller API secret: generated once at first start, kept 0600 in the state directory.
    target = Path(path)
    if target.exists():
        return read_value(target)
    descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as handle:
        handle.write(secrets.token_urlsafe(24))
    return read_value(target)


def fetch_text(url, timeout):
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def share_links(text):
    if "://" not in text:
        compact = "".join(text.split())
        compact += "=" * (-len(compact) % 4)
        try:
            text = base64.b64decode(compact, validate=True).decode("utf-8")
        except (binascii.Error, ValueError):
            text = base64.urlsafe_b64decode(compact).decode("utf-8")
    return [line.strip() for line in text.splitlines() if "://" in line]


def query_of(parts):
    return {key: values[-1] for key, values in parse_qs(parts.query, keep_blank_values=True).items()}


def endpoint(parts):
    host = parts.hostname
    port = parts.port
    if not host or port is None:
        raise Unsupported
    return host, port


def display_name(parts, scheme, host, port):
    return unquote(parts.fragment).strip() or f"{scheme}-{host}:{port}"


def fingerprint_of(query):
    return CLIENT_FINGERPRINTS.get((query.get("fp") or "chrome").lower(), "chrome")


def parse_vless(link):
    parts = urlsplit(link)
    query = query_of(parts)
    host, port = endpoint(parts)
    if query.get("type", "tcp") not in ("", "tcp") or query.get("headerType", "none") not in ("", "none"):
        raise Unsupported
    uuid = unquote(parts.username or "")
    if not UUID.fullmatch(uuid):
        raise Unsupported
    name = display_name(parts, "vless", host, port)
    proxy = {"name": name, "type": "vless", "server": host, "port": port, "uuid": uuid,
             "network": "tcp", "tls": True, "udp": True,
             "servername": query.get("sni") or host, "client-fingerprint": fingerprint_of(query)}
    security = query.get("security", "")
    if security == "reality":
        if not query.get("pbk"):
            raise Unsupported
        reality = {"public-key": query["pbk"], "short-id": query.get("sid", "")}
        # Share links from servers that require X25519MLKEM768 carry this hint.
        if query.get("support-x25519mlkem768", "") in ("1", "true"):
            reality["support-x25519mlkem768"] = True
        proxy["reality-opts"] = reality
    elif security != "tls":
        raise Unsupported
    if query.get("flow"):
        proxy["flow"] = query["flow"]
    return proxy, name


def parse_trojan(link):
    parts = urlsplit(link)
    query = query_of(parts)
    host, port = endpoint(parts)
    password = unquote(parts.username or "")
    if not password:
        raise Unsupported
    name = display_name(parts, "trojan", host, port)
    proxy = {"name": name, "type": "trojan", "server": host, "port": port, "password": password,
             "sni": query.get("sni") or host,
             "skip-cert-verify": query.get("allowInsecure", "0") in ("1", "true"), "udp": True}
    kind = query.get("type", "tcp")
    if kind == "grpc":
        proxy["network"] = "grpc"
        proxy["grpc-opts"] = {"grpc-service-name": query.get("serviceName", "")}
    elif kind not in ("", "tcp"):
        raise Unsupported
    return proxy, name


def parse_anytls(link):
    parts = urlsplit(link)
    query = query_of(parts)
    host, port = endpoint(parts)
    password = unquote(parts.username or "")
    if not password or query.get("type", "tcp") not in ("", "tcp"):
        raise Unsupported
    name = display_name(parts, "anytls", host, port)
    insecure = query.get("insecure", query.get("allowInsecure", "0")) in ("1", "true")
    proxy = {"name": name, "type": "anytls", "server": host, "port": port, "password": password,
             "sni": query.get("sni") or host, "skip-cert-verify": insecure, "udp": True}
    return proxy, name


PARSERS = {"vless": parse_vless, "trojan": parse_trojan, "trojan-go": parse_trojan, "anytls": parse_anytls}


def build_nodes(links):
    nodes, skipped, used = [], 0, set(RESERVED_NAMES)
    for link in links:
        parser = PARSERS.get(link.split("://", 1)[0].lower())
        try:
            if parser is None:
                raise Unsupported
            proxy, name = parser(link)
        except (Unsupported, ValueError):
            skipped += 1
            continue
        unique, index = name, 2
        while unique in used:
            unique = f"{name} ({index})"
            index += 1
        used.add(unique)
        proxy["name"] = unique
        nodes.append(proxy)
    if not nodes:
        raise RenderError("subscription has no supported nodes")
    return nodes, skipped


def drop_info_entries(nodes):
    kept = [node for node in nodes if not INFO_NODE.search(node["name"])]
    if not kept:
        raise RenderError("no servers left after dropping subscription info entries")
    return kept


def vless_proxy(values, name):
    # Built from the separate secret fields. Errors name the field, never its value.
    if not HOST.fullmatch(values["host"]):
        raise RenderError(f"{name} host is malformed")
    try:
        port = int(values["port"])
    except ValueError:
        raise RenderError(f"{name} port is not a number") from None
    if not 1 <= port <= 65535:
        raise RenderError(f"{name} port is out of range")
    if not UUID.fullmatch(values["uuid"]):
        raise RenderError(f"{name} uuid is malformed")
    public_key = values["public-key"]
    try:
        raw = base64.urlsafe_b64decode(public_key + "=" * (-len(public_key) % 4))
    except (binascii.Error, ValueError):
        raise RenderError(f"{name} public key is not base64") from None
    if len(raw) != 32:
        raise RenderError(f"{name} public key must decode to 32 bytes")
    short_id = values["short-id"]
    if len(short_id) % 2 or len(short_id) > 16 or not re.fullmatch(r"[0-9a-fA-F]*", short_id):
        raise RenderError(f"{name} short id must be hex, even length, at most 16")
    if not SNI.fullmatch(values["sni"]):
        raise RenderError(f"{name} sni must be a bare hostname (no port, no path)")
    return {
        "name": name, "type": "vless", "server": values["host"], "port": port,
        "uuid": values["uuid"], "network": "tcp", "tls": True, "udp": True,
        "flow": "xtls-rprx-vision", "servername": values["sni"],
        "client-fingerprint": REALITY_FINGERPRINT,
        # ML-KEM is required by Xray >= 26.9.8 servers; mihomo omits it unless asked.
        "reality-opts": {"public-key": public_key, "short-id": short_id,
                         "support-x25519mlkem768": True},
    }


def render_config(base, nodes, vless, clash_secret):
    names = [node["name"] for node in nodes]
    auto_names = [name for name in names if AUTO_REGION.search(name) and not AUTO_EXCLUDE.search(name)] or names
    config = copy.deepcopy(base)
    config["secret"] = clash_secret
    proxies = [vless["vless-hk"], vless["vless-sg"], *nodes]
    for proxy in proxies:
        if proxy["name"] == "vless-sg" or SG_REGION.search(proxy["name"]):
            proxy["dialer-proxy"] = RELAY
    config["proxies"] = proxies
    config["proxy-groups"] = [
        # No DIRECT here: a manual pick must never send general traffic out of the real
        # address. vless-sg is left out too: the ai group is its only user.
        {"name": "proxy", "type": "select", "proxies": ["auto", *names, "vless-hk"]},
        # Automatic choice tests only the allowed regions. Re-tests every 120s so a node that
        # starts timing out is dropped within two minutes instead of five.
        {"name": "auto", "type": "url-test", "proxies": [*auto_names, "vless-hk"],
         "url": TEST_URL, "interval": 120, "tolerance": 50, "lazy": True},
        # DNS prefers the subscription pool and falls back to vless-hk, in order. A failing
        # VLESS node is never waited on before the pool answers.
        {"name": "dns-auto", "type": "fallback", "proxies": ["auto", "vless-hk"],
         "url": TEST_URL, "interval": 60},
        # AI services: vless-sg only, no fallback.
        {"name": "ai", "type": "select", "proxies": ["vless-sg"]},
    ]
    return config


def write_atomic(path, config):
    target = Path(path)
    descriptor, temporary = tempfile.mkstemp(prefix=".mihomo.", dir=target.parent)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(config, handle)
        os.chmod(temporary, 0o600)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def write_cache(args, nodes):
    # Encrypt to the YubiKey's public subkey. Import into a private homedir first:
    # the Nix store keyring path is read-only and gpg may want to write beside it.
    home = Path(args.gpg_home)
    home.mkdir(mode=0o700, parents=True, exist_ok=True)
    gpg = [args.gpg, "--homedir", str(home), "--batch", "--yes"]
    subprocess.run([*gpg, "--import", args.gpg_keyring], check=True, capture_output=True)
    target = Path(args.cache_file)
    descriptor, temporary = tempfile.mkstemp(prefix=".nodes.", dir=target.parent)
    os.close(descriptor)
    try:
        subprocess.run(
            [*gpg, "--trust-model", "always", "--recipient", args.gpg_recipient,
             "--encrypt", "--output", temporary],
            input=json.dumps(nodes).encode(), check=True, capture_output=True,
        )
        os.chmod(temporary, 0o600)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def usable_proxies(candidates):
    # Only subscription-style proxies with unique, non-reserved names.
    kept, used = [], set(RESERVED_NAMES)
    for proxy in candidates:
        if not isinstance(proxy, dict) or proxy.get("type") not in PROXY_TYPES:
            continue
        name = proxy.get("name")
        if not isinstance(name, str) or not name or name in used:
            continue
        used.add(name)
        kept.append(proxy)
    return kept


def read_nodes_file(path):
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return []
    return usable_proxies(data) if isinstance(data, list) else []


def previous_nodes(path):
    # Only subscription proxies; VLESS nodes and groups come from the current inputs.
    try:
        previous = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return []
    proxies = previous.get("proxies", []) if isinstance(previous, dict) else []
    return usable_proxies(proxies) if isinstance(proxies, list) else []


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--subscription-file", required=True)
    for region in VLESS_REGIONS:
        for field in VLESS_FIELDS:
            parser.add_argument(f"--vless-{region}-{field}-file", required=True)
    parser.add_argument("--clash-secret-file", required=True)
    parser.add_argument("--cache-file", required=True)
    parser.add_argument("--unlocked-file", required=True)
    parser.add_argument("--gpg", required=True)
    parser.add_argument("--gpg-home", required=True)
    parser.add_argument("--gpg-keyring", required=True)
    parser.add_argument("--gpg-recipient", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args(argv)
    try:
        base = json.loads(Path(args.base).read_text())
        if not isinstance(base, dict) or "proxies" in base or "proxy-groups" in base:
            raise RenderError("base must not define proxies or proxy-groups")
        vless = {}
        for region in VLESS_REGIONS:
            values = {field: read_value(getattr(args, f"vless_{region}_{field.replace('-', '_')}_file"))
                      for field in VLESS_FIELDS}
            vless[f"vless-{region}"] = vless_proxy(values, f"vless-{region}")
        url = read_value(args.subscription_file)
        clash_secret = read_or_create_secret(args.clash_secret_file)
    except (OSError, RenderError, ValueError) as error:
        print(f"mihomo-render: {error}", file=sys.stderr)
        return 1
    try:
        text = fetch_text(url, args.timeout)
        nodes, skipped = build_nodes(share_links(text))
        nodes = drop_info_entries(nodes)
    except (OSError, RenderError, ValueError, UnicodeError) as error:
        nodes = previous_nodes(args.output)
        source = "the last rendered configuration"
        if not nodes:
            nodes = read_nodes_file(args.unlocked_file)
            source = "the YubiKey-unlocked cache"
        skipped = 0
        if nodes:
            print(f"mihomo-render: subscription unavailable ({type(error).__name__}); "
                  f"reusing {len(nodes)} nodes from {source}", file=sys.stderr)
        else:
            print(f"mihomo-render: subscription unavailable ({type(error).__name__}) and no cache; "
                  "running on the VLESS nodes only", file=sys.stderr)
    else:
        try:
            write_cache(args, nodes)
        except (OSError, subprocess.CalledProcessError) as error:
            print(f"mihomo-render: cache not written ({type(error).__name__})", file=sys.stderr)
    write_atomic(args.output, render_config(base, nodes, vless, clash_secret))
    print(f"mihomo-render: {len(nodes)} subscription nodes, skipped {skipped} unsupported; "
          "VLESS nodes: vless-hk, vless-sg", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
