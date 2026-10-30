"""Exercise allocation arithmetic with isolated synthetic sysfs counters."""

from pathlib import Path
import runpy
import sys
import tempfile


monitor = runpy.run_path(sys.argv[1])
gib = monitor["GIB"]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    values = {
        "devices/test/size": str(100 * gib // 512),
        "allocation/data/disk_total": str(80 * gib),
        "allocation/metadata/disk_total": str(20 * gib),
        "allocation/system/disk_total": "0",
        "allocation/metadata/total_bytes": str(10 * gib),
        "allocation/metadata/bytes_used": str(4 * gib),
    }
    for name, value in values.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
    metrics = monitor["allocation"](root)
    assert metrics == {"unallocated": 0, "metadata_percent": 40}
    assert len(monitor["warnings"](metrics)) == 1
    (root / "allocation/metadata/bytes_used").write_text(str(8 * gib))
    assert len(monitor["warnings"](monitor["allocation"](root))) == 2
    (root / "allocation/data/disk_total").write_text(str(60 * gib))
    (root / "allocation/metadata/bytes_used").write_text(str(4 * gib))
    assert monitor["warnings"](monitor["allocation"](root)) == []
print("Btrfs allocation arithmetic and independent warning thresholds passed")
