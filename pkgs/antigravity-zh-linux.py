"""给 antigravity_chinese_v2 打 Linux 适配补丁（在上游源码目录里原地修改）。"""
import sys

from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")


def replace(path, old, new, count=1):
    p = root / path
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {path}: {old[:60]!r}")
    p.write_text(text.replace(old, new, count), encoding="utf-8")


# ---------------- cdp_discovery.py ----------------
replace(
    "cdp_discovery.py",
    "import csv\n",
    "import csv\nimport os\n",
)

replace(
    "cdp_discovery.py",
    '    raise DiscoveryError("Automatic discovery supports Windows and macOS only.")',
    '''    if sys.platform.startswith("linux"):
        pids = set()
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            try:
                with open(f"/proc/{entry}/comm", encoding="utf-8", errors="replace") as handle:
                    comm = handle.read().strip()
            except OSError:
                continue
            if comm in ("antigravity", "Antigravity"):
                pids.add(int(entry))
        return pids
    raise DiscoveryError("Automatic discovery supports Windows, macOS and Linux only.")''',
)

replace(
    "cdp_discovery.py",
    '''    else:
        raise DiscoveryError("Unsupported platform for listener discovery.")
    return sorted(endpoints, key=lambda e: (e.port, e.host != "127.0.0.1", e.host))''',
    '''    elif sys.platform.startswith("linux"):
        result = _run(["ss", "-ltnpH"])
        if result.returncode != 0:
            raise DiscoveryError("ss failed; listener ownership is unknown.")
        for line in result.stdout.decode("utf-8", "replace").splitlines():
            fields = line.split()
            if len(fields) < 4:
                continue
            marker = fields[3]
            owner = None
            for token in line.replace(",", " ").replace(")", " ").split():
                if token.startswith("pid="):
                    owner = token[4:]
                    break
            if not owner or not owner.isdigit() or int(owner) not in pids:
                continue
            host, _, port = marker.rpartition(":")
            if not port.isdigit():
                continue
            host = host or "127.0.0.1"
            if host in ("*", "0.0.0.0", "[::]", "::"):
                host = "127.0.0.1"
            endpoint = _endpoint(f"{host}:{port}")
            if endpoint:
                endpoints.add(endpoint)
    else:
        raise DiscoveryError("Unsupported platform for listener discovery.")
    return sorted(endpoints, key=lambda e: (e.port, e.host != "127.0.0.1", e.host))''',
)

replace(
    "cdp_discovery.py",
    '''    elif sys.platform == "darwin":
        command = ["kill", "-TERM", *map(str, sorted(targets))]
    else:
        raise DiscoveryError("Unsupported platform for restart.")''',
    '''    elif sys.platform == "darwin":
        command = ["kill", "-TERM", *map(str, sorted(targets))]
    elif sys.platform.startswith("linux"):
        command = ["kill", "-TERM", *map(str, sorted(targets))]
    else:
        raise DiscoveryError("Unsupported platform for restart.")''',
)

# FHS 包装下进程可能不可见：显式给 --port 时直接探测回环端口
replace(
    "cdp_discovery.py",
    '''    if port is not None:
        candidates = [endpoint for endpoint in candidates if endpoint.port == port]
''',
    '''    if port is not None:
        candidates = [endpoint for endpoint in candidates if endpoint.port == port]
        if not candidates and sys.platform.startswith("linux"):
            candidates = [Endpoint("127.0.0.1", port)]
''',
)

# ---------------- hanhua_v2.py ----------------
replace(
    "hanhua_v2.py",
    "import subprocess\n",
    "import shutil\nimport subprocess\n",
)

replace(
    "hanhua_v2.py",
    """    if sys.platform == 'darwin':
        return [
            '/Applications/Antigravity.app/Contents/MacOS/Antigravity',
            os.path.expanduser('~/Applications/Antigravity.app/Contents/MacOS/Antigravity'),
        ]""",
    """    if sys.platform.startswith('linux'):
        found = [shutil.which(name) for name in ('antigravity-app', 'antigravity')]
        return [p for p in (*found,
                            '/run/current-system/sw/bin/antigravity-app',
                            '/run/current-system/sw/bin/antigravity') if p]
    if sys.platform == 'darwin':
        return [
            '/Applications/Antigravity.app/Contents/MacOS/Antigravity',
            os.path.expanduser('~/Applications/Antigravity.app/Contents/MacOS/Antigravity'),
        ]""",
)

print("linux patch applied")
