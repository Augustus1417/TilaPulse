import 'package:flutter/material.dart';

class TilaPulseLogo extends StatelessWidget {
  const TilaPulseLogo({
    super.key,
    this.height = 36,
    this.showLabel = true,
  });

  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'TilaPulse',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'lib/assets/tilapulse_logo.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'TilaPulse',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
