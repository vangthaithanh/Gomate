import 'package:flutter/material.dart';

class GoMateMapStatusPill extends StatelessWidget {
  final String text;
  final IconData icon;

  const GoMateMapStatusPill({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:Theme.of(context).colorScheme.surface.withOpacity(.94),
      elevation:4,
      borderRadius:BorderRadius.circular(16),
      child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
        child:Row(
          mainAxisSize:MainAxisSize.min,
          children:[
            Icon(icon,size:16),
            const SizedBox(width:6),
            Text(
              text,
              style:Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight:FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
