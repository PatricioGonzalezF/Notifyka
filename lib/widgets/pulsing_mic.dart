import 'package:flutter/material.dart';

/// Icono de microfono con animacion de pulso mientras se graba.
class PulsingMic extends StatefulWidget {
  const PulsingMic({super.key, required this.active});

  final bool active;

  @override
  State<PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = widget.active
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.outline;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double t = widget.active ? _controller.value : 0;
        return Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: base.withValues(alpha: 0.12 + 0.18 * t),
          ),
          child: Icon(Icons.mic, color: base, size: 28),
        );
      },
    );
  }
}
