import 'package:flutter/widgets.dart';

class AdsenseWidget extends StatelessWidget {
  final String adClient;
  final String adSlot;
  final String adFormat;
  final bool fullWidthResponsive;
  final double width;
  final double height;

  const AdsenseWidget({
    super.key,
    required this.adClient,
    required this.adSlot,
    required this.adFormat,
    required this.fullWidthResponsive,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
