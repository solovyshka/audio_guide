from __future__ import annotations

from urllib.request import ProxyHandler, build_opener

# Windows urllib otherwise picks up the system/VPN HTTP proxy.
_DIRECT = build_opener(ProxyHandler({}))


def urlopen_direct(request, timeout: float = 60):
    return _DIRECT.open(request, timeout=timeout)
