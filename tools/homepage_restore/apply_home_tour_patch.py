#!/usr/bin/env python3
"""Aplica integracion de HomeTour sobre Homepage restaurado desde e91f788."""
from pathlib import Path
import re
import sys

p = Path("lib/Homepage.dart")
src = p.read_text()

if "HomeTourOverlay" in src:
    print("Tour already present — skip")
    sys.exit(0)

if "PLACEHOLDER" in src or len(src) < 1000:
    print("Homepage looks broken, abort", len(src))
    sys.exit(1)

# 1) imports
old_imp = "import 'services/fcm_service.dart';"
new_imp = (
    old_imp
    + "\nimport 'onboarding/home_tour_service.dart';"
    + "\nimport 'onboarding/home_tour_overlay.dart';"
)
if old_imp not in src:
    print("import marker missing")
    sys.exit(1)
src = src.replace(old_imp, new_imp, 1)

# 2) state fields after tips set
old_tips = "final Set<String> _tipsVisitadosSesion = {};"
if old_tips not in src:
    print("tips marker missing")
    sys.exit(1)
src = src.replace(
    old_tips,
    old_tips
    + "\n\n  /// Tour primera vez (coach-marks).\n"
    + "  bool _showHomeTour = false;\n"
    + "  bool _tourCheckDone = false;",
    1,
)

# 3) initState post-frame
old_fcm = "    FcmService.instance.ensureStarted();\n  }"
new_fcm = (
    "    FcmService.instance.ensureStarted();\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());\n"
    "  }"
)
if old_fcm not in src:
    print("initState FCM marker missing")
    sys.exit(1)
src = src.replace(old_fcm, new_fcm, 1)

# 4) tour methods — insert after _selectTab
methods = """
  Future<void> _maybeStartHomeTour() async {
    if (!mounted || _currentIndex != 0) return;
    final show = await HomeTourService.instance.shouldShow(
      modoPrestador: _modoPrestador,
    );
    if (!mounted) return;
    _tourCheckDone = true;
    if (show) {
      setState(() => _showHomeTour = true);
    }
  }

  Future<void> _finishHomeTour() async {
    await HomeTourService.instance.markDone(modoPrestador: _modoPrestador);
    if (mounted) setState(() => _showHomeTour = false);
  }

  void _toggleModoPrestador() {
    setState(() {
      _modoPrestador = !_modoPrestador;
      _showHomeTour = false;
    });
    // Si el otro rol nunca vio el tour, ofrecerlo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());
  }

"""

marker = "  void _selectTab(int index) {"
idx = src.find(marker)
if idx < 0:
    print("_selectTab missing")
    sys.exit(1)
brace = 0
started = False
end = idx
for i, ch in enumerate(src[idx:], idx):
    if ch == "{":
        brace += 1
        started = True
    elif ch == "}":
        brace -= 1
        if started and brace == 0:
            end = i + 1
            break
src = src[:end] + "\n" + methods + src[end:]

# 5) Replace inline role toggle
old_toggle = "onTap: () => setState(() => _modoPrestador = !_modoPrestador),"
new_toggle = "onTap: _toggleModoPrestador,"
count = src.count(old_toggle)
if count >= 1:
    src = src.replace(old_toggle, new_toggle, 1)
    print("toggle replacements:", 1)
else:
    print("WARN: inline toggle not found")
    for line in src.splitlines():
        if "modoPrestador = !" in line:
            print("  found:", line.strip()[:100])

# 6) Overlay in Stack after bottom nav
pat = (
    r"(child: _buildBottomNav\(\),\n\s+\),\n)"
    r"(\s+\],\n\s+\),\n\s+\);\n\s+\}\n\n\s+Widget _buildBottomNav\(\))"
)
m = re.search(pat, src)
if not m:
    print("FAIL nav stack match")
    i = src.find("child: _buildBottomNav()")
    print(repr(src[max(0, i - 80) : i + 220]))
    sys.exit(1)

overlay = """          if (_showHomeTour && _currentIndex == 0)
            Positioned.fill(
              child: HomeTourOverlay(
                modoPrestador: _modoPrestador,
                accent: primaryColor,
                onFinished: _finishHomeTour,
              ),
            ),
"""
src = src[: m.start()] + m.group(1) + overlay + m.group(2) + src[m.end() :]

# Validate
assert "HomeTourOverlay" in src
assert "_maybeStartHomeTour" in src
assert "onboarding/home_tour_service.dart" in src
assert "PLACEHOLDER" not in src
assert len(src) > 40000

p.write_text(src)
print("OK patched", len(src), "bytes", src.count("\n") + 1, "lines")
