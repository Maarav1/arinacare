
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

   @override
  Widget build(BuildContext context) {
    return Linkify(
      onOpen: (link) async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // Add mounted check before using context
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch $link')),
            );
          }
        }
      },
      text: text,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      linkStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: Colors.blue.shade700,
        decoration: TextDecoration.underline,
      ),
    );
  }
}