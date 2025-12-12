; Flutter Windows 应用程序 Inno Setup 配置文件
; 请根据你的实际项目信息修改以下配置

#define MyAppName "AI相册管家"
#define MyAppVersion "1.0.7"
#define MyAppPublisher "joykee"
#define MyAppURL "https://www.joykee.com"
#define MyAppExeName "ablumwin.exe"
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

// 卸载前确认（可选）
function InitializeUninstall(): Boolean;
begin
  Result := MsgBox('确定要卸载 {#MyAppName} 吗？', mbConfirmation, MB_YESNO) = IDYES;
end;