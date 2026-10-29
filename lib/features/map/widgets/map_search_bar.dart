import 'package:flutter/material.dart';
import '../theme/map_ui_tokens.dart';

class GoMateMapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const GoMateMapSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:54,
      decoration:GoMateMapUi.floatingPanel(context),
      padding:const EdgeInsets.symmetric(horizontal:12),
      child:Row(
        children:[
          Icon(Icons.search_rounded,
            color:Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width:8),
          Expanded(
            child:TextField(
              controller:controller,
              onChanged:onChanged,
              textInputAction:TextInputAction.search,
              style:GoMateMapUi.body(context),
              decoration:const InputDecoration(
                hintText:'Tìm địa điểm trong GoMate',
                border:InputBorder.none,
                isDense:true,
              ),
            ),
          ),
          if(controller.text.isNotEmpty)
            IconButton(
              onPressed:onClear,
              icon:const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed:(){},
            icon:const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}
