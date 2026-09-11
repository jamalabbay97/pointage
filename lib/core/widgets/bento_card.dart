import 'package:flutter/material.dart';

class BentoCard extends StatefulWidget {
  const BentoCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.accentColor,
    this.gradient,
    this.trailing,
    this.badgeText,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.height,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final Gradient? gradient;
  final Widget? trailing;
  final String? badgeText;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? theme.colorScheme.primary;

    final defaultBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark
        ? (_isHovered ? accent.withValues(alpha: 0.6) : const Color(0xFF1E293B))
        : (_isHovered
            ? accent.withValues(alpha: 0.5)
            : const Color(0xFFE2E8F0));

    final shadowColor = isDark
        ? (_isHovered
            ? accent.withValues(alpha: 0.15)
            : const Color.fromRGBO(0, 0, 0, 0.4))
        : (_isHovered
            ? accent.withValues(alpha: 0.12)
            : const Color.fromRGBO(15, 23, 42, 0.05));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.gradient == null ? defaultBg : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: _isHovered ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _isHovered ? 16 : 8,
              offset: _isHovered ? const Offset(0, 6) : const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: widget.padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                    ),
                    child: Icon(widget.icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.badgeText!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ] else if (widget.onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
