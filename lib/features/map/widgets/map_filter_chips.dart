import 'package:flutter/material.dart';
import '../models/map_place.dart';

class GoMateMapFilterChips extends StatelessWidget {
  final GoMatePlaceCategory? selected;
  final ValueChanged<GoMatePlaceCategory?> onChanged;

  const GoMateMapFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items=<(String,IconData,GoMatePlaceCategory?)>[
      ('Tất cả',Icons.apps_rounded,null),
      ('Check-in',Icons.photo_camera_rounded,GoMatePlaceCategory.attraction),
      ('Cafe',Icons.local_cafe_rounded,GoMatePlaceCategory.cafe),
      ('Ăn uống',Icons.restaurant_rounded,GoMatePlaceCategory.food),
      ('Thiên nhiên',Icons.park_rounded,GoMatePlaceCategory.nature),
      ('Mua sắm',Icons.shopping_bag_rounded,GoMatePlaceCategory.shopping),
    ];

    return SizedBox(
      height:40,
      child:ListView.separated(
        scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.symmetric(horizontal:14),
        itemCount:items.length,
        separatorBuilder:(_,__)=>const SizedBox(width:8),
        itemBuilder:(context,index){
          final item=items[index];
          return FilterChip(
            selected:selected==item.$3,
            onSelected:(_)=>onChanged(item.$3),
            avatar:Icon(item.$2,size:16),
            label:Text(item.$1),
            showCheckmark:false,
            materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,
            visualDensity:VisualDensity.compact,
          );
        },
      ),
    );
  }
}
