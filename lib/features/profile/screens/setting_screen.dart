import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_search_field.dart';
import '../../../core/widgets/snackbar.dart';
import '../../auth/screens/forgot_password_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/my_moments_screen.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/profile_ui_widgets.dart';
import '../widgets/settings_shared_widgets.dart';
import 'profile_edit_screen.dart';
import 'settings_activity_screen.dart';
import 'settings_account_lists_screen.dart';
import 'settings_collection_screen.dart';
import 'settings_history_screen.dart';
import 'settings_preferences_screen.dart';

/// Settings home. Uses existing auth session and logout flow unchanged.
/// The list is searchable by every nested setting, not only section names.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  String _query='';
  bool _isLoggingOut=false;
  @override
  void initState(){
    super.initState();
    AuthService.instance.addListener(_refresh);
    SettingsUiDemo.instance.addListener(_refresh);
    AuthService.instance.loadProfile().catchError((_ ){});
  }
  @override
  void dispose(){
    AuthService.instance.removeListener(_refresh);
    SettingsUiDemo.instance.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }
  void _refresh(){if(mounted)setState((){});}
  Map<String,dynamic> get _user=>AuthService.instance.user ?? const {};
  String get _name {
    final full=(_user['fullName']??_user['displayName']??_user['nickname']??'Người dùng').toString();
    return full.trim().isEmpty?'Người dùng':full;
  }
  String get _email=> (_user['email']??'').toString();
  String? get _avatar {
    final url=(_user['avatarUrl']??'').toString();
    return url.isEmpty?null:url;
  }
  void _go(Widget page)=>Navigator.of(context).push(
    MaterialPageRoute<void>(builder:(_)=>page));
  void _option(SettingsOptionsKind kind)=>_go(SettingsOptionsScreen(kind:kind));
  void _activity()=>_go(const SettingsActivityScreen());
  void _editProfile()=>_go(const ProfileEditScreen());
  void _changePassword()=>_go(const ForgotPasswordScreen(changePasswordMode: true));
  bool _searching(String value)=>_query.isEmpty ||
    value.toLowerCase().contains(_query);

  List<_SettingsEntry> get _account=>[
    _SettingsEntry('Chỉnh sửa hồ sơ',LucideIcons.user_round,_editProfile),
    _SettingsEntry('Hoạt động của bạn',LucideIcons.timer,_activity),
  ];
  List<_SettingsEntry> get _security=>[
    _SettingsEntry('Quyền riêng tư',LucideIcons.lock_keyhole,
      ()=>_option(SettingsOptionsKind.privacy)),
    _SettingsEntry('Đổi mật khẩu',LucideIcons.key_round,_changePassword),
  ];
  List<_SettingsEntry> get _options=>[
    _SettingsEntry('Ngôn ngữ giao diện',LucideIcons.globe,
      ()=>_option(SettingsOptionsKind.language),subtitle:'Tiếng Việt'),
    _SettingsEntry('Chế độ tối',LucideIcons.moon,
      ()=>_option(SettingsOptionsKind.darkMode),subtitle:'Tắt'),
    _SettingsEntry('Quyền truy cập thiết bị',LucideIcons.smartphone,
      ()=>_option(SettingsOptionsKind.permissions)),
  ];
  List<_SettingsEntry> get _help=>[
    _SettingsEntry('Trợ giúp & Hỗ trợ',LucideIcons.circle_question_mark,
      ()=>_option(SettingsOptionsKind.support)),
    _SettingsEntry('Điều khoản & chính sách',LucideIcons.file_text,
      ()=>_option(SettingsOptionsKind.terms)),
    _SettingsEntry('Giới thiệu GoMate',LucideIcons.circle_alert,
      ()=>_option(SettingsOptionsKind.about)),
  ];
  // All nested settings are searchable at the top level.
  List<_SettingsEntry> get _nested=>[
    _SettingsEntry('Lượt thích',LucideIcons.heart,
      ()=>_go(const SettingsCollectionScreen(kind:SettingsCollectionKind.likes))),
    _SettingsEntry('Bình luận',LucideIcons.message_circle,
      ()=>_go(const SettingsCollectionScreen(kind:SettingsCollectionKind.comments))),
    _SettingsEntry('Đánh giá',LucideIcons.star,
      ()=>_go(const SettingsCollectionScreen(kind:SettingsCollectionKind.reviews))),
    _SettingsEntry('Đã lưu',LucideIcons.bookmark,
      ()=>_go(const SettingsCollectionScreen(kind:SettingsCollectionKind.saved))),
    _SettingsEntry('Thư viện khoảnh khắc',LucideIcons.images,
      ()=>_go(MyMomentsScreen(repository:ApiMomentsRepository.instance))),
    _SettingsEntry('Đã chặn',LucideIcons.ban,
      ()=>_go(const SettingsPeopleListScreen(kind:SettingsPeopleListKind.blocked))),
    _SettingsEntry('Đã báo cáo',LucideIcons.message_square_warning,
      ()=>_go(const SettingsPeopleListScreen(kind:SettingsPeopleListKind.reports))),
    _SettingsEntry('Khoảnh khắc đã ẩn',LucideIcons.eye_off,
      ()=>_go(const SettingsPeopleListScreen(kind:SettingsPeopleListKind.hiddenMoments))),
    _SettingsEntry('Quản lý thời gian',LucideIcons.timer,
      ()=>_go(const SettingsHistoryScreen(kind:SettingsHistoryKind.time))),
    _SettingsEntry('Lịch sử xem',LucideIcons.timer_reset,
      ()=>_go(const SettingsHistoryScreen(kind:SettingsHistoryKind.visits))),
    _SettingsEntry('Tìm kiếm gần đây',LucideIcons.search,
      ()=>_go(const SettingsHistoryScreen(kind:SettingsHistoryKind.searches))),
  ];

  Widget _section(String name,List<_SettingsEntry> entries){
    final filtered=_query.isEmpty || _searching(name)
      ? entries : entries.where((e)=>_searching(e.title)).toList();
    if(filtered.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Divider(height:8,thickness:4,color:AppColors.grayBackground),
      SettingsSectionLabel(name),
      for(final item in filtered)
        if(item.title=='Chế độ tối')
          SettingsMenuRow(title:item.title,icon:item.icon,showArrow:false,
            trailing:Switch.adaptive(value:SettingsUiDemo.instance.darkModePreview,
              activeColor:AppColors.primaryIcon,
                inactiveTrackColor: const Color(0xFFF0F0F0),
                inactiveThumbColor: Colors.white,
                trackOutlineColor:
                const WidgetStatePropertyAll<Color?>(
                  Colors.transparent,
                ),
                onChanged:(v){
                SettingsUiDemo.instance.darkModePreview=v;
                SettingsUiDemo.instance.changed();
                GoMateSnackBar.show(context,message:'Chỉ đổi công tắc xem thử; Theme toàn ứng dụng chưa thay đổi.');
              }))
        else
          SettingsMenuRow(title:item.title,icon:item.icon,
            value:item.subtitle,onTap:item.onTap),
    ]);
  }
  @override
  Widget build(BuildContext context){
    final w=MediaQuery.sizeOf(context).width;
    final profileVisible=_query.isEmpty || _searching('tài khoản hồ sơ tên email') ||
      _searching(_name) || _searching(_email);
    return Scaffold(backgroundColor:Colors.white,
      body:SafeArea(child:Column(children:[
        const SettingsCompactHeader(title:'Cài đặt và hoạt động'),
        Expanded(child:ListView(physics:const BouncingScrollPhysics(),children:[
          Padding(padding:EdgeInsets.fromLTRB(
            (w*.060).clamp(19.0,25.0).toDouble(),4,
            (w*.060).clamp(19.0,25.0).toDouble(),14),
            child:GoMateSearchField(
              controller:_search,hintText:'Tìm kiếm ....',
              showCancel:_query.isNotEmpty,
              onChanged:(v)=>setState(()=>_query=v.trim().toLowerCase()),
              onCancel:(){_search.clear();setState(()=>_query='');},
            )),
          if(profileVisible)...[
            const SizedBox(height:9),
            Center(child:SettingsVisualAvatar(url:_avatar,size:49)),
            const SizedBox(height:8),
            Center(child:Text(_name,style:const TextStyle(
              fontWeight:FontWeight.w700,fontSize:16))),
            const SizedBox(height:2),
            Center(child:Text(_email.isEmpty?'Thông tin tài khoản':_email,
              style:const TextStyle(color:AppColors.grayText,fontSize:12))),
            const SizedBox(height:14),
          ],
          _section('Tài khoản',_account),
          _section('Bảo mật',_security),
          _section('Tuỳ chọn',_options),
          _section('Hỗ trợ',_help),
          if(_query.isNotEmpty && _nested.any((e)=>_searching(e.title)))
            _section('Trong hoạt động của bạn',_nested),
          if(_query.isEmpty || _searching('đăng xuất logout'))...[
            const SizedBox(height:18),
            Align(alignment:Alignment.center,
              child:SettingsGradientButton(
                text:_isLoggingOut?'Đang đăng xuất...':'Đăng xuất',
                enabled:!_isLoggingOut,onTap:_confirmLogout)),
          ],
          const SizedBox(height:36),
        ])),
      ])),
    );
  }

  // Keep the existing account logout contract (invalidate session, clear stack).
  Future<void> _confirmLogout() async {
    final confirmed=await showDialog<bool>(context:context,
      builder:(dialog)=>AlertDialog(
        backgroundColor:Colors.white,
        title:const Text('Đăng xuất?',style:TextStyle(
          fontWeight:FontWeight.w800,color:AppColors.primaryText)),
        content:const Text('Bạn có chắc muốn đăng xuất khỏi GoMate không?'),
        actions:[
          TextButton(onPressed:()=>Navigator.of(dialog).pop(false),
            child:const Text('Huỷ',style:TextStyle(color:AppColors.grayText))),
          TextButton(onPressed:()=>Navigator.of(dialog).pop(true),
            child:const Text('Đăng xuất',style:TextStyle(color:AppColors.primaryText))),
        ],
      ));
    if(confirmed==true && mounted)await _logout();
  }
  Future<void> _logout() async {
    if(_isLoggingOut)return;
    setState(()=>_isLoggingOut=true);
    try {
      await AuthService.instance.logout();
      if(!mounted)return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder:(_)=>const LoginScreen()),(route)=>false);
    }catch(error){
      if(!mounted)return;
      setState(()=>_isLoggingOut=false);
      GoMateSnackBar.show(context,
        message:'Không thể đăng xuất lúc này. Kiểm tra kết nối và thử lại.');
    }
  }
}
class _SettingsEntry {
  final String title;final IconData icon;final VoidCallback onTap;
  final String? subtitle;
  const _SettingsEntry(this.title,this.icon,this.onTap,{this.subtitle});
}
