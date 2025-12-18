; Flutter Windows 应用程序 Inno Setup 配置文件
; 请根据你的实际项目信息修改以下配置

#define MyAppName "AI相册管家"
#define MyAppVersion "1.0.7"
#define MyAppPublisher "joykee"
#define MyAppURL "https://www.joykee.com"
#define MyAppExeName "AIAlbum.exe"
; 修改为你的 Flutter 项目构建输出目录
#define MyAppBuildDir "build\windows\x64\runner\Release"

[Setup]
; 应用程序基本信息
AppId={{joykee-win-firmlyalbum}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 默认安装目录（用户可以修改）
DefaultDirName={autopf}\{#MyAppName}
; 允许用户选择安装目录
DisableDirPage=no
; 在开始菜单创建程序组
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 许可协议文件（如果有的话）
;LicenseFile=LICENSE.txt
; 安装前显示的信息文件（如果有的话）
;InfoBeforeFile=README.txt

; 输出配置
OutputDir=installer_output
OutputBaseFilename={#MyAppName}_Setup_{#MyAppVersion}
; 设置安装包图标（需要准备一个 .ico 文件）
;SetupIconFile=app_icon.ico

; 压缩配置
Compression=lzma
SolidCompression=yes

; Windows 版本要求
MinVersion=10.0.17763
; 架构
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; 权限（如果需要管理员权限，改为 admin）
PrivilegesRequired=lowest

; 安装界面配置
WizardStyle=modern
; 设置安装向导图片（可选）
;WizardImageFile=installer_image.bmp
;WizardSmallImageFile=installer_small_image.bmp

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; 主程序可执行文件
Source: "{#MyAppBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; 包含所有其他文件和目录
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 如果有额外的资源文件
;Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion
;Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

; P2P 隧道 DLL 库（位于 windows 目录下）
Source: "windows\pgDllTunnel.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; 开始菜单图标
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; 桌面图标（如果用户选择）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; 快速启动图标（如果用户选择）
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; 安装完成后运行应用程序（可选）
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; ===== 卸载时清理运行时生成的文件和目录 =====

; 安装目录下的所有文件和子目录
Type: filesandordirs; Name: "{app}\*"
Type: dirifempty; Name: "{app}"

; ===== 清理应用实际使用的数据目录 =====
; Roaming 目录: C:\Users\xxx\AppData\Roaming\joykee\亲选相册
Type: filesandordirs; Name: "{userappdata}\joykee\亲选相册"
Type: dirifempty; Name: "{userappdata}\joykee"

; Local 目录: C:\Users\xxx\AppData\Local\joykee\亲选相册
Type: filesandordirs; Name: "{localappdata}\joykee\亲选相册"
Type: dirifempty; Name: "{localappdata}\joykee"

; 如果还有其他数据目录，请在此添加

[Code]
// 自定义安装目录选择页面（可选）
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
  begin
    // 在这里可以添加自定义逻辑
    WizardForm.DirEdit.Text := ExpandConstant('{autopf}\{#MyAppName}');
  end;
end;

// 卸载前：关闭应用并确认卸载
function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
begin
  // 先尝试关闭正在运行的应用程序，避免文件被占用
  Exec('taskkill.exe', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // 等待进程完全退出
  Sleep(500);

  // 弹出确认对话框
  Result := MsgBox('确定要卸载 {#MyAppName} 吗？', mbConfirmation, MB_YESNO) = IDYES;
end;

// 卸载完成后：强制清理残留目录
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDir: String;
  RoamingDataDir: String;
  RoamingJoykeeDir: String;
  LocalDataDir: String;
  LocalJoykeeDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // 清理安装目录
    AppDir := ExpandConstant('{app}');
    if DirExists(AppDir) then
    begin
      DelTree(AppDir, True, True, True);
    end;

    // 清理 Roaming\joykee\亲选相册 目录
    RoamingDataDir := ExpandConstant('{userappdata}\joykee\亲选相册');
    if DirExists(RoamingDataDir) then
    begin
      DelTree(RoamingDataDir, True, True, True);
    end;

    // 如果 joykee 目录为空，也删除它
    RoamingJoykeeDir := ExpandConstant('{userappdata}\joykee');
    if DirExists(RoamingJoykeeDir) then
    begin
      RemoveDir(RoamingJoykeeDir);
    end;

    // 清理 Local\joykee\亲选相册 目录
    LocalDataDir := ExpandConstant('{localappdata}\joykee\亲选相册');
    if DirExists(LocalDataDir) then
    begin
      DelTree(LocalDataDir, True, True, True);
    end;

    // 如果 joykee 目录为空，也删除它
    LocalJoykeeDir := ExpandConstant('{localappdata}\joykee');
    if DirExists(LocalJoykeeDir) then
    begin
      RemoveDir(LocalJoykeeDir);
    end;
  end;
end;
