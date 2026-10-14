import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/screens/place_detail_screen.dart';
import '../ui_preview/profile_ui_preview.dart';
import '../../search/models/search_models.dart';
import 'public_profile_screen.dart';
import 'profile_post_feed_screen.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/settings_shared_widgets.dart';

enum SettingsPeopleListKind { blocked, reports, hiddenMoments }

/// Local-only UI preview until account moderation / muted lists are exposed.
class SettingsPeopleListScreen extends StatefulWidget {
  final SettingsPeopleListKind kind;
  const SettingsPeopleListScreen({super.key,required this.kind});
  @override
  State<SettingsPeopleListScreen> createState()=>_SettingsPeopleListScreenState();
}
class _SettingsPeopleListScreenState extends State<SettingsPeopleListScreen> {
  final demo=SettingsUiDemo.instance;
  @override
  void initState(){super.initState();demo.addListener(_refresh);}
  @override
  void dispose(){demo.removeListener(_refresh);super.dispose();}
  void _refresh(){if(mounted)setState((){});}
  @override
  Widget build(BuildContext context){
    final title=switch(widget.kind){
      SettingsPeopleListKind.blocked=>'Người dùng đã chặn',
      SettingsPeopleListKind.reports=>'Nội dung đã báo cáo',
      SettingsPeopleListKind.hiddenMoments=>'Khoảnh khắc đã ẩn',
    };
    final isReport=widget.kind==SettingsPeopleListKind.reports;
    final people=widget.kind==SettingsPeopleListKind.blocked?demo.blocked:demo.hiddenMoments;
    return SettingsPageShell(title:title,body: isReport
      ? (demo.reports.isEmpty
        ? const SettingsEmpty('Chưa có nội dung đã báo cáo')
        : ListView.builder(padding:const EdgeInsets.symmetric(vertical:14,horizontal:22),
          itemCount:demo.reports.length,itemBuilder:(context,i){
            final item=demo.reports[i];
            return InkWell(onTap:()=>_openReport(item),child:Padding(
              padding:const EdgeInsets.symmetric(vertical:15),
              child:Row(children:[
                Expanded(child:Text(item.reason,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14))),
                const SizedBox(width:14),
                if(item.image.isNotEmpty)
                  ClipRRect(borderRadius:BorderRadius.circular(7),
                    child:SizedBox(width:45,height:45,child:SettingsMediaImage(item.image)))
                else
                  const SettingsVisualAvatar(size:40),
              ])),
            );
          }))
      : (people.isEmpty
        ? SettingsEmpty(widget.kind==SettingsPeopleListKind.blocked
          ? 'Chưa chặn người dùng nào' : 'Chưa ẩn khoảnh khắc của ai')
        : ListView.builder(padding:const EdgeInsets.symmetric(vertical:14,horizontal:22),
          itemCount:people.length,itemBuilder:(context,i){
            final person=people[i];
            return InkWell(onTap:()=>_openPerson(person),
              child:ConstrainedBox(constraints:const BoxConstraints(minHeight:66),
                child:Row(children:[
                  const SettingsVisualAvatar(size:38),const SizedBox(width:11),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(person.name,style:const TextStyle(fontWeight:FontWeight.w500,fontSize:14)),
                    Text(person.subtitle,style:const TextStyle(fontSize:12,color:AppColors.grayText)),
                  ])),
                  TextButton(style:TextButton.styleFrom(padding:EdgeInsets.zero,
                      minimumSize:const Size(0,44)),
                    onPressed:()=>widget.kind==SettingsPeopleListKind.blocked
                      ? _unblock(person) : _unhide(person),
                    child:Text(widget.kind==SettingsPeopleListKind.blocked?'Bỏ chặn':'Bỏ ẩn',
                      style:const TextStyle(color:AppColors.primaryText,fontSize:12))),
                ])),
            );
          })),
    );
  }
  // Use canonical Profile UI for blocked/muted users, not a second UI screen.
  // TODO(BACKEND-SETTINGS-UI): replace previewPerson with trusted userId and
  // read isBlocked/isMuted from the shared repositories.
  void _openPerson(SettingsDemoPerson person) async {
    final blocked = widget.kind == SettingsPeopleListKind.blocked;
    final hidden = widget.kind == SettingsPeopleListKind.hiddenMoments;
    final preview = ProfilePreviewPerson(
      id: person.id, nickname: person.name.toLowerCase(),
      name: person.name, avatar: '', bio: '', isPrivate: false,
      initialRelation: hidden ? SearchUserRelation.friend : SearchUserRelation.none,
      followersCount: blocked ? 0 : 20, friendsCount: blocked ? 0 : 12,
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      PublicProfileScreen(
        userId: preview.id, previewPerson: preview,
        initialPreviewBlocked: blocked,
        initialPreviewMuted: hidden,
        onPreviewBlockedChanged: (value) {
          if (!value) demo.unblock(person.id);
        },
        onPreviewMutedChanged: (value) {
          if (!value) demo.unhide(person.id);
        },
      )));
  }
  void _unblock(SettingsDemoPerson person) {
    demo.unblock(person.id);
    GoMateSnackBar.show(context,message:'Đã bỏ chặn trong chế độ xem thử');
  }
  void _unhide(SettingsDemoPerson person) {
    demo.unhide(person.id);
    GoMateSnackBar.show(context,message:'Đã bỏ ẩn khoảnh khắc (xem thử)');
  }
  void _openReport(SettingsDemoReport report) {
    // TODO(BACKEND-SETTINGS-UI): route using a trusted report.targetType and
    // report.targetId. These are sample-only destinations, never call APIs.
    if(report.type=='place') {
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>
        PlaceDetailScreen(place:ProfileUiPreview.favoritePlaces.first)));
    }else if(report.type=='post') {
      final post=ProfileUiPreview.posts(authorId:'ui-preview-self',authorName:'Thune').first;
      Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>
        GoMateProfilePostFeedScreen(posts:[post])));
    }else {
      const preview=ProfilePreviewPerson(
        id:'ui-preview-reported-account',nickname:'dadada',
        name:'DaDaDa',avatar:'',bio:'',isPrivate:false,
        initialRelation:SearchUserRelation.none,
        followersCount:20,friendsCount:5,
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            userId: preview.id,
            previewPerson: preview,
          ),
        ),
      );

    }
  }

}

