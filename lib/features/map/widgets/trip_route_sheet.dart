import 'package:flutter/material.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import '../theme/map_ui_tokens.dart';

class GoMateTripRouteSheet extends StatelessWidget {
  final GoMateMapRoute route;
  final List<GoMateMapPlace> stops;
  final VoidCallback onExitTrip;
  final VoidCallback onStartTrip;

  const GoMateTripRouteSheet({
    super.key,
    required this.route,
    required this.stops,
    required this.onExitTrip,
    required this.onStartTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:GoMateMapUi.floatingPanel(context),
      padding:const EdgeInsets.fromLTRB(15,14,15,14),
      child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          Row(
            children:[
              Container(
                width:44,height:44,
                decoration:BoxDecoration(
                  color:Theme.of(context)
                      .colorScheme.primaryContainer.withOpacity(.75),
                  borderRadius:BorderRadius.circular(14),
                ),
                child:Icon(
                  Icons.route_rounded,
                  color:Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width:11),
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('Đà Lạt cuối tuần',
                      style:GoMateMapUi.title(context)),
                    const SizedBox(height:2),
                    Text(
                      '${stops.length} điểm • ${route.distanceKm.toStringAsFixed(1)} km • ~${route.durationMinutes} phút',
                      style:GoMateMapUi.caption(context),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed:onExitTrip,child:const Text('Khám phá')),
            ],
          ),
          if (route.isFallback) ...[
            const SizedBox(height:10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal:10, vertical:8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withOpacity(.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Route tạm: backend/Mapbox Directions chưa trả route thật.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
          const SizedBox(height:12),
          SizedBox(
            height:62,
            child:ListView.separated(
              scrollDirection:Axis.horizontal,
              itemCount:stops.length,
              separatorBuilder:(_,__)=>const SizedBox(width:8),
              itemBuilder:(context,index){
                final p=stops[index];
                return Container(
                  constraints:const BoxConstraints(minWidth:145,maxWidth:190),
                  padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                  decoration:BoxDecoration(
                    color:Theme.of(context)
                        .colorScheme.surfaceContainerHighest.withOpacity(.65),
                    borderRadius:BorderRadius.circular(15),
                  ),
                  child:Row(
                    children:[
                      CircleAvatar(
                        radius:15,
                        backgroundColor:Theme.of(context).colorScheme.primary,
                        child:Text(
                          '${index+1}',
                          style:TextStyle(
                            color:Theme.of(context).colorScheme.onPrimary,
                            fontWeight:FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width:8),
                      Expanded(
                        child:Text(
                          p.name,
                          maxLines:2,
                          overflow:TextOverflow.ellipsis,
                          style:Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight:FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height:12),
          FilledButton.icon(
            onPressed:onStartTrip,
            icon:const Icon(Icons.navigation_rounded),
            label:const Text('Bắt đầu chuyến đi'),
            style:FilledButton.styleFrom(
              minimumSize:const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}
