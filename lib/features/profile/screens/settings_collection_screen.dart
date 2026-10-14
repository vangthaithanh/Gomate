import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/screens/place_detail_screen.dart';
import '../ui_preview/profile_ui_preview.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/profile_ui_widgets.dart';
import '../widgets/settings_shared_widgets.dart';
import 'profile_post_feed_screen.dart';

enum SettingsCollectionKind { likes, comments, reviews, saved }

/// Activity content. Selection/deletion is preview-local until activity APIs exist.
class SettingsCollectionScreen extends StatefulWidget {
  final SettingsCollectionKind kind;
  const SettingsCollectionScreen({super.key, required this.kind});
  @override
  State<SettingsCollectionScreen> createState() => _SettingsCollectionScreenState();
}
class _SettingsCollectionScreenState extends State<SettingsCollectionScreen> {
  final _demo = SettingsUiDemo.instance;
  bool _manage = false;
  bool _postsTab = false;
  final Set<String> _selected = {};

  String get _title => switch(widget.kind) {
    SettingsCollectionKind.likes => 'Lượt thích',
    SettingsCollectionKind.comments => 'Bình luận',
    SettingsCollectionKind.reviews => 'Đánh giá',
    SettingsCollectionKind.saved => 'Đã lưu',
  };

  @override
  void initState() { super.initState();_demo.addListener(_refresh); }
  @override
  void dispose() { _demo.removeListener(_refresh);super.dispose(); }
  void _refresh() {if (mounted) setState(() {});}
  void _toggleManage() => setState(() { _manage=!_manage;_selected.clear(); });

  List<String> get _ids => switch(widget.kind) {
    SettingsCollectionKind.likes => _postsTab
      ? _demo.likedPosts.map((x)=>x.id).toList() : _demo.likedPlaceIds,
    SettingsCollectionKind.saved => _demo.savedPosts.map((x)=>x.id).toList(),
    SettingsCollectionKind.comments => _demo.comments.map((x)=>x.id).toList(),
    SettingsCollectionKind.reviews => _demo.reviews.map((x)=>x.id).toList(),
  };
  void _toggle(String id) => setState(() {if (!_selected.add(id)) _selected.remove(id);});
  void _selectAll() => setState(() {
    if (_selected.containsAll(_ids)) { _selected.clear(); }
    else { _selected.addAll(_ids); }
  });
  void _remove() {
    if (_selected.isEmpty) return;
    if (widget.kind == SettingsCollectionKind.likes) {
      if (_postsTab) { _demo.removePosts(_selected, saved:false); }
      else { _demo.removePlaces(_selected); }
    } else if (widget.kind == SettingsCollectionKind.saved) {
      _demo.removePosts(_selected, saved:true);
    } else if (widget.kind == SettingsCollectionKind.comments) {
      _demo.removeComments(_selected);
    } else {
      _demo.removeReviews(_selected);
    }
    setState(() { _selected.clear();_manage=false; });
    GoMateSnackBar.show(context,message: 'Đã cập nhật danh sách xem thử (chưa đồng bộ máy chủ)');
  }
  void _openPost(GoMateProfilePostPreview post) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      GoMateProfilePostFeedScreen(posts:[post])));
  }
  void _openPlace(String id) {
    MapPlaceUi? place;
    for (final p in ProfileUiPreview.favoritePlaces) { if(p.id==id) {place=p; break;} }
    if (place==null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlaceDetailScreen(place: place!)));
  }
  @override
  Widget build(BuildContext context) {
    final list = _ids;
    return SettingsPageShell(title:_title,
      trailing: IconButton(onPressed:_toggleManage,
        tooltip:_manage?'Huỷ chọn':'Quản lý',
        icon: Icon(LucideIcons.copy,
          size:23,color:_manage ? AppColors.black : AppColors.grayText)),
      body: Stack(children: [
        Column(children: [
          if(widget.kind==SettingsCollectionKind.likes)
            Row(children: [
              Expanded(child: _tab('Địa điểm', !_postsTab, ()=>setState(() { _postsTab=false;_selected.clear();}))),
              Expanded(child: _tab('Bài viết', _postsTab, ()=>setState(() { _postsTab=true;_selected.clear();}))),
            ]),
          if (_manage)
            Align(alignment: Alignment.centerRight,
              child: Padding(padding: const EdgeInsets.only(right: 16),
                child: TextButton(onPressed:_selectAll,
                child: Text('(${_selected.length}) ${_selected.length==list.length && list.isNotEmpty?'Bỏ chọn':'Chọn tất cả'}',
                  style:const TextStyle(color:AppColors.primaryIcon,fontSize:12))))),
          Expanded(child: list.isEmpty
            ? const SettingsEmpty('Chưa có nội dung trong danh sách này')
            : _content()),
        ]),
        if (_manage && _selected.isNotEmpty)
          Positioned(left:0,right:0,bottom:22,
            child: Center(child: SettingsGradientButton(
              text:'${switch(widget.kind){SettingsCollectionKind.likes=>'Bỏ thích',SettingsCollectionKind.saved=>'Bỏ lưu',SettingsCollectionKind.comments=>'Gỡ bình luận',SettingsCollectionKind.reviews=>'Xoá đánh giá'}} (${_selected.length})',
              onTap:_remove))),
      ]),
    );
  }
  Widget _tab(String title,bool chosen,VoidCallback cb)=>InkWell(onTap:cb,
    child: SizedBox(height:50,child:Center(child:Text(title,style:TextStyle(
      color:chosen?AppColors.black:AppColors.grayText,
      fontWeight:chosen?FontWeight.w700:FontWeight.w500,fontSize:14)))));

  Widget _content() {
    switch(widget.kind) {
      case SettingsCollectionKind.likes:
        return _postsTab ? _postGrid(_demo.likedPosts) : _placeGrid();
      case SettingsCollectionKind.saved:
        return _postGrid(_demo.savedPosts);
      case SettingsCollectionKind.comments:
        return _commentList();
      case SettingsCollectionKind.reviews:
        return _reviewList();
    }
  }
  Widget _choice(String id) => Positioned(top:8,left:8,child:Container(
    width:24,height:24,decoration:BoxDecoration(
      color:_selected.contains(id)?AppColors.primaryIcon:const Color(0xB3FFFFFF),
      shape:BoxShape.circle,border:Border.all(color:Colors.white,width:1.5)),
    child:_selected.contains(id)?const Icon(LucideIcons.check,size:15,color:Colors.white):null));

  Widget _postGrid(List<GoMateProfilePostPreview> posts) => GridView.builder(
    physics:const BouncingScrollPhysics(),
    padding:EdgeInsets.only(bottom:_manage?95:20),
    itemCount:posts.length,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount:2,mainAxisSpacing:3,crossAxisSpacing:3,childAspectRatio:1),
    itemBuilder:(context,index) {
      final post=posts[index];
      return InkWell(onTap:()=>_manage?_toggle(post.id):_openPost(post),
        child:Stack(fit:StackFit.expand,children:[
          SettingsMediaImage(post.media.isEmpty?'':post.media.first),
          if(_manage) _choice(post.id),
        ]));
    },
  );

  Widget _placeGrid() => LayoutBuilder(builder:(context,constraints){
    final w=constraints.maxWidth;
    final cardWidth=(w-42-16)/2;
    final ids=_demo.likedPlaceIds;
    return GridView.builder(padding:const EdgeInsets.fromLTRB(21,12,21,90),
      itemCount:ids.length,
      gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:2,crossAxisSpacing:16,mainAxisSpacing:16,
        childAspectRatio:cardWidth/(cardWidth*1.66)),
      itemBuilder:(context,i){
        final p=ProfileUiPreview.favoritePlaces.where((x)=>x.id==ids[i]).first;
        return InkWell(onTap:()=>_manage?_toggle(p.id):_openPlace(p.id),
          borderRadius:BorderRadius.circular(17),
          child:ClipRRect(borderRadius:BorderRadius.circular(17),
            child:Stack(fit:StackFit.expand,children:[
              SettingsMediaImage(p.imageAsset??''),
              const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
                begin:Alignment.topCenter,end:Alignment.bottomCenter,
                colors:[Colors.transparent,Color(0xAA000000)]))),
              Positioned(bottom:12,left:10,right:10,child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(p.name,maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:12)),
                  Text(p.address,maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Colors.white70,fontSize:11)),
                ])),
              Positioned(top:8,right:8,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),
                decoration:BoxDecoration(color:Colors.white70,borderRadius:BorderRadius.circular(12)),
                child:Text('★ ${p.rating.toStringAsFixed(1)}',style:const TextStyle(
                  color:AppColors.primaryIcon,fontSize:11,fontWeight:FontWeight.bold)))),
              if(_manage) _choice(p.id),
            ])),
        );
      },
    );
  });

  // TODO(BACKEND-SETTINGS-UI): only the OWN comment id is selectable;
  // parent comment/post belongs to another object, NEVER delete it here.
  Widget _commentList() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 105),
    itemCount: _demo.comments.length,
    separatorBuilder: (_, __) => const SizedBox(height: 24),
    itemBuilder: (context, index) {
      final item = _demo.comments[index];
      final isSelected = _selected.contains(item.id);
      void openPost() => _openPost(ProfileUiPreview.posts(
        authorId: 'ui-preview-self', authorName: 'Thune').first);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: original post or parent comment. No selection control.
        InkWell(onTap: openPost, child: Row(children: [
          const SettingsVisualAvatar(size: 35),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.reply ? 'Bình luận cha' : 'Bài viết gốc',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 3),
              Text(item.parentCaption, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.grayText)),
            ])),
          const SizedBox(width: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5),
            child: SizedBox(width: 45, height: 45,
              child: SettingsMediaImage(item.postThumbnail))),
        ])),
        const SizedBox(height: 11),
        Padding(padding: const EdgeInsets.only(left: 22),
          child: InkWell(onTap: () => _manage ? _toggle(item.id) : openPost(),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_manage) ...[
                Padding(padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Icon(isSelected ? LucideIcons.circle_check
                    : LucideIcons.circle, size: 20,
                    color: isSelected ? AppColors.primaryIcon : AppColors.grayBorder)),
              ],
              const SettingsVisualAvatar(size: 35),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${item.author}  ',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                        color: AppColors.black, fontSize: 13)),
                    TextSpan(text: item.time, style: const TextStyle(
                      color: AppColors.grayText, fontSize: 11)),
                  ])),
                  const SizedBox(height: 5),
                  Text(item.text, maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.black, fontSize: 13)),
                ])),
            ]))),
      ]);
    },
  );

  Widget _reviewList() => ListView.separated(
    padding:const EdgeInsets.fromLTRB(20,16,20,100),
    itemCount:_demo.reviews.length,
    separatorBuilder:(_,__)=>const SizedBox(height:19),
    itemBuilder:(context,index){
      final r=_demo.reviews[index];
      final p=ProfileUiPreview.favoritePlaces.where((x)=>x.id==r.placeId).first;
      return InkWell(onTap:()=>_manage?_toggle(r.id):_openPlace(p.id),
        child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(
          color:Colors.white,borderRadius:BorderRadius.circular(16),
          boxShadow:AppColors.elevatedShadow),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              if(_manage) Padding(padding:const EdgeInsets.only(right:8),
                child:Icon(_selected.contains(r.id)?LucideIcons.circle_check:LucideIcons.circle,
                  size:19,color:AppColors.primaryIcon)),
              ClipRRect(borderRadius:BorderRadius.circular(8),
                child:SizedBox(width:49,height:49,child:SettingsMediaImage(p.imageAsset??''))),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14)),
                Text(p.address,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:AppColors.grayText,fontSize:12)),
              ])),
              Text('★ ${r.rating.toStringAsFixed(1)}',
                style:const TextStyle(color:AppColors.primaryIcon,fontWeight:FontWeight.w700)),
            ]),
            const SizedBox(height:12),Text(r.caption),
            if(r.images.isNotEmpty)...[
              const SizedBox(height:12),
              SizedBox(height:82,child:ListView.separated(scrollDirection:Axis.horizontal,
                itemCount:r.images.length,separatorBuilder:(_,__)=>const SizedBox(width:4),
                itemBuilder:(context,i)=>ClipRRect(borderRadius:BorderRadius.circular(10),
                  child:SizedBox(width:82,child:SettingsMediaImage(r.images[i]))))),
            ],
          ])),
      );
    },
  );
}
