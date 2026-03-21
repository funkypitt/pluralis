import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class FontSizeControls extends StatelessWidget {
  const FontSizeControls({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FontButton(
          label: '−',
          enabled: settings.fontSize > 13,
          onTap: settings.decreaseFontSize,
        ),
        GestureDetector(
          onLongPress: () => _confirmReset(context, settings),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${settings.fontSize.toInt()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  settings.fontSizeIsAuto ? 'auto' : 'manual',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        _FontButton(
          label: '+',
          enabled: settings.fontSize < 30,
          onTap: settings.increaseFontSize,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _confirmReset(BuildContext context, SettingsProvider settings) {
    final autoSize =
        SettingsService.computeAdaptiveFontSize(context).toInt();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset font size?'),
        content: Text(
          'Revert to auto-calculated size for this screen ($autoSize px)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settings.resetFontSize(context);
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _FontButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? color : color.withValues(alpha: 0.25),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: enabled ? color : color.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
