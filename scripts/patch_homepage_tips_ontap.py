from pathlib import Path
t = Path("lib/Homepage.dart").read_text()
if "() => _ejecutarTip(r)" not in t:
    n = t.count("onTap: r.onTap,")
    print("found onTap:r.onTap", n)
    t = t.replace("onTap: r.onTap,", "onTap: () => _ejecutarTip(r),", 1)
    Path("lib/Homepage.dart").write_text(t)
print("done", "() => _ejecutarTip(r)" in Path("lib/Homepage.dart").read_text())
