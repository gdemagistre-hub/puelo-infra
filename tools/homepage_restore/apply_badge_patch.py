#!/usr/bin/env python3
"""Apply badge patch to Homepage.dart (must already be the full good version)."""
from pathlib import Path
import sys

p = Path('lib/Homepage.dart')
if not p.exists():
    sys.exit('lib/Homepage.dart missing')
c = p.read_text()

old_row = "                _navItem(3, Icons.chat_bubble_outline_rounded, 'Mensajes'),"
new_row = "                _mensajesNavItem(),"
if old_row not in c:
    if '_mensajesNavItem' in c:
        print('Badge already present')
        sys.exit(0)
    sys.exit('nav row not found')
c = c.replace(old_row, new_row, 1)

old_start = '  Widget _navItem(int index, IconData icon, String label, {VoidCallback? onTap}) {'
idx = c.find(old_start)
if idx < 0:
    sys.exit('old _navItem not found')
i = idx + len(old_start) - 1
depth = 0
end = None
for j in range(i, len(c)):
    if c[j] == '{':
        depth += 1
    elif c[j] == '}':
        depth -= 1
        if depth == 0:
            end = j + 1
            break
if end is None:
    sys.exit('could not find end of _navItem')

new_nav = '''  /// Badge de recibos pendientes de responder (no los que yo emití).
  Widget _mensajesNavItem() {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty) {
      return _navItem(3, Icons.chat_bubble_outline_rounded, 'Mensajes');
    }
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversaciones')
            .where('participantes', arrayContains: uid)
            .orderBy('last_event_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          int pending = 0;
          if (snap.hasData) {
            for (final doc in snap.data!.docs) {
              final d = doc.data();
              if (d['pending_recibo_event_id'] == null) continue;
              final actor = (d['pending_recibo_actor_uid'] ?? '').toString();
              if (actor.isEmpty || actor != uid) pending++;
            }
          }
          return _navItemContent(
            3,
            Icons.chat_bubble_outline_rounded,
            'Mensajes',
            badgeCount: pending,
          );
        },
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {VoidCallback? onTap, int badgeCount = 0}) {
    return Expanded(
      child: _navItemContent(index, icon, label, onTap: onTap, badgeCount: badgeCount),
    );
  }

  Widget _navItemContent(int index, IconData icon, String label, {VoidCallback? onTap, int badgeCount = 0}) {
    final selected = _currentIndex == index;
    final showBadge = badgeCount > 0;
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';
    return InkWell(
      onTap: onTap ?? () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: selected ? 24 : 22,
                  color: selected ? primaryColor : const Color(0xFF94A3B8),
                ),
                if (showBadge)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? primaryColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }'''

c = c[:idx] + new_nav + c[end:]
if c.count('{') != c.count('}'):
    sys.exit(f'brace mismatch {c.count("{")} vs {c.count("}")}')
if '_mensajesNavItem' not in c or '_buildClienteHome' not in c:
    sys.exit('missing expected symbols')
p.write_text(c)
print(f'OK: patched Homepage.dart ({len(c)} bytes)')
