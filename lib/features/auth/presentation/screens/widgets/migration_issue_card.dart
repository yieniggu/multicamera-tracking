import 'package:flutter/material.dart';

class MigrationIssueCard extends StatelessWidget {
  final String title;
  final String issueTitle;
  final String issueMessage;
  final int issueCount;
  final int issueIndex;
  final bool canMovePrev;
  final bool canMoveNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<DragEndDetails>? onHorizontalDragEnd;

  const MigrationIssueCard({
    required this.title,
    required this.issueTitle,
    required this.issueMessage,
    required this.issueCount,
    required this.issueIndex,
    required this.canMovePrev,
    required this.canMoveNext,
    required this.onPrev,
    required this.onNext,
    required this.onHorizontalDragEnd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 10),
          child: GestureDetector(
            key: const Key('migration_issue_swipe_area'),
            onHorizontalDragEnd: onHorizontalDragEnd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8B26A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFF9A4F00),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF9A4F00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    issueTitle,
                    style: const TextStyle(
                      color: Color(0xFF7A3F00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issueMessage,
                    style: const TextStyle(color: Color(0xFF7A3F00)),
                  ),
                  if (issueCount > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: const Key('migration_issue_prev'),
                          visualDensity: VisualDensity.compact,
                          onPressed: canMovePrev ? onPrev : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${issueIndex + 1}/$issueCount',
                          key: const Key('migration_issue_position'),
                          style: const TextStyle(
                            color: Color(0xFF7A3F00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          key: const Key('migration_issue_next'),
                          visualDensity: VisualDensity.compact,
                          onPressed: canMoveNext ? onNext : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            key: const Key('migration_issue_count_badge'),
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFD64545),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              issueCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
