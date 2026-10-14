import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/settings_shared_widgets.dart';

enum SettingsOptionsKind { privacy, permissions, language, darkMode, support, terms, about }
class SettingsOptionsScreen extends StatefulWidget {
  final SettingsOptionsKind kind;
  const SettingsOptionsScreen({super.key,required this.kind});
  @override
  State<SettingsOptionsScreen> createState()=>_SettingsOptionsScreenState();
}
class _SettingsOptionsScreenState extends State<SettingsOptionsScreen> {
  final demo=SettingsUiDemo.instance;
  @override
  void initState(){super.initState();demo.addListener(_refresh);}
  @override
  void dispose(){demo.removeListener(_refresh);super.dispose();}
  void _refresh(){if(mounted)setState((){});}
  String get title=>switch(widget.kind){
    SettingsOptionsKind.privacy=>'Quyền riêng tư',
    SettingsOptionsKind.permissions=>'Quyền truy cập thiết bị',
    SettingsOptionsKind.language=>'Ngôn ngữ giao diện',
    SettingsOptionsKind.darkMode=>'Chế độ tối',
    SettingsOptionsKind.support=>'Trợ giúp & Hỗ trợ',
    SettingsOptionsKind.terms=>'Điều khoản & chính sách',
    SettingsOptionsKind.about=>'Giới thiệu GoMate',
  };
  @override
  Widget build(BuildContext context)=>SettingsPageShell(title:title,
    body:switch(widget.kind){
      SettingsOptionsKind.privacy=>_privacy(),
      SettingsOptionsKind.permissions=>_permissions(),
      SettingsOptionsKind.darkMode=>_darkMode(),
      SettingsOptionsKind.language=>_language(),
      _=>_future(),
    });
  Widget _privacy()=>ListView(children:[
    SettingsMenuRow(title:'Tài khoản riêng tư',showArrow:false,
      trailing:Switch.adaptive(value:demo.privatePreview,
        activeColor:AppColors.primaryIcon,
          inactiveTrackColor: const Color(0xFFF0F0F0),
          inactiveThumbColor: Colors.white,
          trackOutlineColor:
          const WidgetStatePropertyAll<Color?>(
            Colors.transparent,
          ),
        onChanged:(value){demo.privatePreview=value;demo.changed();
          GoMateSnackBar.show(context,message:'Chế độ riêng tư đang được xem thử; chưa lưu máy chủ');})),
    const Padding(padding:EdgeInsets.fromLTRB(24,10,24,0),
      child:Text('Khi bật tài khoản riêng tư, chỉ người được bạn phê duyệt mới được theo dõi và xem nội dung của bạn. Các yêu cầu mới cần được xác nhận.\n\nChế độ này hiện chỉ là demo giao diện; backend sẽ áp dụng quyền truy cập thật cho Profile, Moments và nội dung.',
        style:TextStyle(fontSize:12.5,height:1.45,color:AppColors.grayText))),
  ]);
  Widget _darkMode()=>ListView(children:[
    SettingsMenuRow(title:'Chế độ tối',icon:LucideIcons.moon,showArrow:false,
      trailing:Switch.adaptive(value:demo.darkModePreview,
        activeColor:AppColors.primaryIcon,
          inactiveTrackColor: const Color(0xFFF0F0F0),
          inactiveThumbColor: Colors.white,
          trackOutlineColor:
          const WidgetStatePropertyAll<Color?>(
            Colors.transparent,
          ),
        onChanged:(value){demo.darkModePreview=value;demo.changed();
          GoMateSnackBar.show(context,message:'Đã cập nhật công tắc xem thử (chưa đổi Theme toàn ứng dụng)');})),
    const Padding(padding:EdgeInsets.symmetric(horizontal:23),
      child:Text('Giao diện GoMate hiện dùng chủ đề sáng. Hỗ trợ ThemeMode.system, sáng/tối và lưu lựa chọn sẽ được tích hợp sau.',
        style:TextStyle(color:AppColors.grayText,fontSize:12))),
  ]);
  Widget _permissions(){
    // TODO(BACKEND-SETTINGS-UI): read real OS permission statuses with platform
    // adapter/permission_handler. Do not present the demo labels as real grants.
    const data = <String, String>{
      'Camera': 'Đã cho phép',
      'Danh bạ': 'Chưa cho phép',
      'Vị trí': 'Đã cho phép',
      'Micro': 'Đã cho phép',
      'Thông báo': 'Đã cho phép',
      'Ảnh': 'Đã cho phép',
    };
    return ListView(children:[
      const SettingsSectionLabel('Tuỳ chọn của bạn'),
      for(final item in data.entries)
        SettingsMenuRow(title:item.key,value:item.value,
          onTap:()=>GoMateSnackBar.show(context,
            message:'Trạng thái quyền ${item.key} cần được đọc từ hệ thống thiết bị.')),
      const Padding(padding:EdgeInsets.fromLTRB(23,24,23,0),
        child:Text('Danh sách hiện chưa truy vấn quyền hệ điều hành. Sau khi tích hợp, chạm một dòng sẽ mở phần cài đặt quyền tương ứng trên thiết bị.',
          style:TextStyle(fontSize:12,color:AppColors.grayText))),
    ]);
  }
  Widget _language()=>ListView(children:[
    const SettingsSectionLabel('Ngôn ngữ ứng dụng'),
    SettingsMenuRow(title:'Tiếng Việt',icon:LucideIcons.languages,
      value:'Đang hiển thị',
      onTap:()=>GoMateSnackBar.show(context,
        message:'Chuyển ngôn ngữ sẽ được kết nối hệ thống đa ngôn ngữ sau.')),
    const Padding(padding:EdgeInsets.symmetric(horizontal:23,vertical:18),
      child:Text('Hiện chưa thay đổi ngôn ngữ của toàn bộ ứng dụng.',
        style:TextStyle(color:AppColors.grayText,fontSize:12))),
  ]);
  Widget _future()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(LucideIcons.info,size:42,color:AppColors.primaryIcon),
    const SizedBox(height:16),
    Text('$title sẽ được phát triển sau',
      textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:16)),
  ]));
}

/// Reusable confirmation UI for settings actions; same GoMateBottomSheet shell.
Future<bool> showSettingsConfirm(BuildContext context,{
  required String title,required String explanation,required String confirmText}) async {
  final result=await GoMateBottomSheet.show<bool>(context:context,
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(title,textAlign:TextAlign.center,
        style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:12),
      Text(explanation,textAlign:TextAlign.center,
        style:const TextStyle(color:AppColors.grayText,fontSize:13,height:1.4)),
      const SizedBox(height:20),
      SettingsGradientButton(text:confirmText,
        onTap:()=>Navigator.of(context).pop(true)),
      const SizedBox(height:9),
    ]));
  return result==true;
}
