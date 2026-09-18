import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import 'ui_kit.dart';

/// Phone-style push notification that slides in at the top of the parent
/// frame. Simulated: no real push service is involved.
class PushBanner extends StatelessWidget {
  const PushBanner({super.key, required this.notice, required this.onTap, required this.onDismiss});
  final PushNotice? notice;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.easeOutBack,
    transitionBuilder: (child, anim) => SlideTransition(
      position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(anim),
      child: FadeTransition(opacity: anim, child: child),
    ),
    child: notice == null
        ? const SizedBox.shrink()
        : Padding(
            key: ValueKey('${notice!.time}-${notice!.title}'),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: notice!.critical ? const Color(0xFFFFF1F0) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: notice!.critical ? Navi.red.withAlpha(120) : const Color(0xFFCCFBF1),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: notice!.critical ? Navi.red : Navi.tealDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('NAVI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Navi.muted)),
                                const Spacer(),
                                Text(notice!.time, style: const TextStyle(fontSize: 10, color: Navi.muted)),
                              ],
                            ),
                            Text(notice!.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Navi.ink, fontSize: 13)),
                            Text(notice!.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Navi.secondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
