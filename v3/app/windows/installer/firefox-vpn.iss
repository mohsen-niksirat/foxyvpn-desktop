; The Windows installer of Firefox VPN (Inno Setup 6). scripts\build-windows.ps1
; compiles it with the built app:
;
;   ISCC /DAppVersion=1.1.9 /DSourceDir=<the app's folder> /DOutputDir=<dir>
;        /DOutputName=<file name without .exe> firefox-vpn.iss
;
; It installs for the current user only, without administrator rights, by
; default into %LOCALAPPDATA%\Programs\Firefox VPN Client (apart from
; Mozilla's own client). The first install lets the user choose another
; folder; it must be one the user can write to, because the app keeps its
; data (accounts, settings, logs) in user-data beside it. A new version
; installs over the old one, in the same folder, and keeps user-data. An
; uninstall that keeps the data notes its folder, which the next install
; offers again.

#define AppName "Firefox VPN"
#define AppExe "firefox-vpn.exe"
#define AppDir "Firefox VPN Client"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #error SourceDir must name the built app's folder
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputName
  #define OutputName "Firefox-VPN-Setup"
#endif

[Setup]
; The same id in every version, so a new one replaces the old.
AppId={{6F3A2C1E-9B4D-4E7A-8C21-5D0F7B9E4A63}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Arman
AppPublisherURL=https://github.com/armanlife/firefox-vpn-client
AppSupportURL=https://github.com/armanlife/firefox-vpn-client/issues
AppUpdatesURL=https://github.com/armanlife/firefox-vpn-client/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={code:DefaultDir}
; The folder is asked on the first install only; an update goes where the
; installed version is.
DisableDirPage=auto
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; A running copy is closed before its files are replaced.
CloseApplications=force
RestartApplications=no
ShowLanguageDialog=auto

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "fa"; MessagesFile: "languages\Farsi.isl"
Name: "ar"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "az"; MessagesFile: "languages\Azerbaijan.isl"
Name: "id"; MessagesFile: "languages\Indonesian.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "hu"; MessagesFile: "compiler:Languages\Hungarian.isl"
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "vi"; MessagesFile: "languages\Vietnamese.isl"
Name: "bn"; MessagesFile: "languages\Bengali.islu"

[CustomMessages]
; Uninstalling asks about the data, keeping it unless the user chooses
; otherwise.
DataQuestion=Keep your accounts and settings?
DataText=They stay in the user-data folder, so installing the app again brings them back. Delete them only if you will not use Firefox VPN again.
DataKeep=Keep them (recommended)
DataDelete=Delete them
fa.DataQuestion=حساب‌ها و تنظیمات شما نگه داشته شوند؟
fa.DataText=در پوشه user-data می‌مانند و با نصب دوباره برنامه برمی‌گردند. فقط اگر دیگر از Firefox VPN استفاده نمی‌کنید پاکشان کنید.
fa.DataKeep=نگه داشته شوند (پیشنهادی)
fa.DataDelete=پاک شوند
ar.DataQuestion=هل تريد الاحتفاظ بحساباتك وإعداداتك؟
ar.DataText=تبقى في مجلد user-data، فتعود عند تثبيت التطبيق مرة أخرى. احذفها فقط إذا كنت لن تستخدم Firefox VPN مجددًا.
ar.DataKeep=احتفظ بها (موصى به)
ar.DataDelete=احذفها
ru.DataQuestion=Сохранить ваши аккаунты и настройки?
ru.DataText=Они останутся в папке user-data, и при повторной установке приложение их вернёт. Удаляйте их, только если больше не будете пользоваться Firefox VPN.
ru.DataKeep=Сохранить (рекомендуется)
ru.DataDelete=Удалить
tr.DataQuestion=Hesaplarınız ve ayarlarınız saklansın mı?
tr.DataText=user-data klasöründe kalırlar; uygulamayı yeniden kurduğunuzda geri gelirler. Yalnızca Firefox VPN'i bir daha kullanmayacaksanız silin.
tr.DataKeep=Sakla (önerilen)
tr.DataDelete=Sil
az.DataQuestion=Hesablarınız və ayarlarınız saxlanılsın?
az.DataText=Onlar user-data qovluğunda qalır və tətbiqi yenidən quraşdıranda geri qayıdır. Yalnız Firefox VPN-dən bir daha istifadə etməyəcəksinizsə silin.
az.DataKeep=Saxla (tövsiyə olunur)
az.DataDelete=Sil
id.DataQuestion=Simpan akun dan pengaturan Anda?
id.DataText=Semuanya tetap di folder user-data, jadi akan kembali saat aplikasi dipasang lagi. Hapus hanya jika Anda tidak akan memakai Firefox VPN lagi.
id.DataKeep=Simpan (disarankan)
id.DataDelete=Hapus
es.DataQuestion=¿Conservar tus cuentas y ajustes?
es.DataText=Se quedan en la carpeta user-data, así que vuelven al instalar de nuevo la aplicación. Bórralos solo si no vas a volver a usar Firefox VPN.
es.DataKeep=Conservarlos (recomendado)
es.DataDelete=Borrarlos
fr.DataQuestion=Conserver vos comptes et paramètres ?
fr.DataText=Ils restent dans le dossier user-data et reviennent si vous réinstallez l'application. Ne les supprimez que si vous n'utiliserez plus Firefox VPN.
fr.DataKeep=Les conserver (recommandé)
fr.DataDelete=Les supprimer
hu.DataQuestion=Megtartja a fiókjait és a beállításait?
hu.DataText=A user-data mappában maradnak, így az alkalmazás újratelepítésekor visszakerülnek. Csak akkor törölje őket, ha többé nem használja a Firefox VPN-t.
hu.DataKeep=Megtartás (ajánlott)
hu.DataDelete=Törlés
pt.DataQuestion=Manter suas contas e configurações?
pt.DataText=Elas ficam na pasta user-data e voltam se você instalar o aplicativo de novo. Apague-as só se não for mais usar o Firefox VPN.
pt.DataKeep=Manter (recomendado)
pt.DataDelete=Apagar
vi.DataQuestion=Giữ lại tài khoản và cài đặt của bạn?
vi.DataText=Chúng vẫn nằm trong thư mục user-data, nên sẽ quay lại khi bạn cài lại ứng dụng. Chỉ xóa nếu bạn sẽ không dùng Firefox VPN nữa.
vi.DataKeep=Giữ lại (khuyên dùng)
vi.DataDelete=Xóa
bn.DataQuestion=আপনার অ্যাকাউন্ট ও সেটিংস রেখে দেবেন?
bn.DataText=এগুলো user-data ফোল্ডারে থেকে যায়, তাই অ্যাপটি আবার ইনস্টল করলে ফিরে আসে। Firefox VPN আর ব্যবহার না করলে তবেই মুছুন।
bn.DataKeep=রেখে দিন (প্রস্তাবিত)
bn.DataDelete=মুছে ফেলুন
; A chosen folder the user cannot write to (such as Program Files).
DirNotWritable=Firefox VPN can't write to this folder. It keeps your accounts and settings beside itself, so it needs a folder you can change without administrator rights (not Program Files). Choose another folder.
fa.DirNotWritable=Firefox VPN نمی‌تواند در این پوشه بنویسد. حساب‌ها و تنظیمات کنار خود برنامه نگه داشته می‌شوند، پس پوشه‌ای لازم است که بدون دسترسی Administrator قابل تغییر باشد (نه Program Files). پوشه دیگری انتخاب کنید.
ar.DirNotWritable=لا يستطيع Firefox VPN الكتابة في هذا المجلد. فهو يحتفظ بحساباتك وإعداداتك بجانبه، لذا يحتاج إلى مجلد يمكنك تعديله دون صلاحيات المسؤول (وليس Program Files). اختر مجلدًا آخر.
ru.DirNotWritable=Firefox VPN не может записывать в эту папку. Аккаунты и настройки хранятся рядом с программой, поэтому нужна папка, которую можно менять без прав администратора (не Program Files). Выберите другую папку.
tr.DirNotWritable=Firefox VPN bu klasöre yazamıyor. Hesaplarınız ve ayarlarınız uygulamanın yanında tutulur; bu yüzden yönetici hakları olmadan değiştirebileceğiniz bir klasör gerekir (Program Files değil). Başka bir klasör seçin.
az.DirNotWritable=Firefox VPN bu qovluğa yaza bilmir. Hesablarınız və ayarlarınız tətbiqin yanında saxlanılır, ona görə də administrator hüquqları olmadan dəyişə biləcəyiniz qovluq lazımdır (Program Files yox). Başqa qovluq seçin.
id.DirNotWritable=Firefox VPN tidak dapat menulis ke folder ini. Akun dan pengaturan Anda disimpan di samping aplikasi, jadi diperlukan folder yang dapat Anda ubah tanpa hak administrator (bukan Program Files). Pilih folder lain.
es.DirNotWritable=Firefox VPN no puede escribir en esta carpeta. Guarda tus cuentas y ajustes junto a sí mismo, así que necesita una carpeta que puedas modificar sin permisos de administrador (no Program Files). Elige otra carpeta.
fr.DirNotWritable=Firefox VPN ne peut pas écrire dans ce dossier. Il garde vos comptes et paramètres à côté de lui ; il lui faut donc un dossier modifiable sans droits d'administrateur (pas Program Files). Choisissez un autre dossier.
hu.DirNotWritable=A Firefox VPN nem tud írni ebbe a mappába. A fiókjait és a beállításait maga mellett tárolja, ezért olyan mappa kell, amelyet rendszergazdai jogok nélkül módosíthat (nem a Program Files). Válasszon másik mappát.
pt.DirNotWritable=O Firefox VPN não consegue gravar nesta pasta. Ele guarda suas contas e configurações ao lado de si, então precisa de uma pasta que você possa alterar sem direitos de administrador (não a Program Files). Escolha outra pasta.
vi.DirNotWritable=Firefox VPN không thể ghi vào thư mục này. Tài khoản và cài đặt của bạn được lưu ngay cạnh ứng dụng, nên cần một thư mục bạn có thể thay đổi mà không cần quyền quản trị (không phải Program Files). Hãy chọn thư mục khác.
bn.DirNotWritable=Firefox VPN এই ফোল্ডারে লিখতে পারছে না। আপনার অ্যাকাউন্ট ও সেটিংস অ্যাপের পাশেই রাখা হয়, তাই এমন একটি ফোল্ডার দরকার যা অ্যাডমিনিস্ট্রেটর অনুমতি ছাড়াই বদলানো যায় (Program Files নয়)। অন্য একটি ফোল্ডার বেছে নিন।

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

; Versions before 1.1.2 kept the core beside the app; it is in core\ now.
[InstallDelete]
Type: files; Name: "{app}\firefox-vpn-core.exe"

[Files]
; Never an existing data folder, if one was in the source.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "user-data,portable"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  InternetKey = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  // Where an uninstall that kept the data notes the folder it is in.
  KeptKey = 'Software\{#AppName}';
  KeptValue = 'KeptDataIn';

// The folder a first install offers: the one an uninstalled copy left its
// data in, so installing again brings the data back; else the usual one.
function DefaultDir(Param: String): String;
begin
  if not RegQueryStringValue(HKCU, KeptKey, KeptValue, Result) or
     not DirExists(AddBackslash(Result) + 'user-data') then
    Result := ExpandConstant('{localappdata}\Programs\{#AppDir}');
end;

// IsUnder tells whether Dir is Parent or a folder inside it.
function IsUnder(Dir, Parent: String): Boolean;
begin
  Result := Pos(AddBackslash(Lowercase(Parent)), AddBackslash(Lowercase(Dir))) = 1;
end;

// CanWrite tells whether the user can create files in Dir, which the app's
// user-data needs; a folder it had to make for the test is removed again.
// Setup started as administrator can write to the system's folders, which
// the app, started normally, cannot: those are refused outright.
function CanWrite(Dir: String): Boolean;
var
  Made: Boolean;
  Probe: String;
begin
  if IsAdmin and (IsUnder(Dir, ExpandConstant('{commonpf32}')) or
     IsUnder(Dir, ExpandConstant('{commonpf64}')) or
     IsUnder(Dir, ExpandConstant('{commonappdata}')) or
     IsUnder(Dir, ExpandConstant('{win}'))) then
  begin
    Result := False;
    Exit;
  end;
  Made := not DirExists(Dir);
  Result := ForceDirectories(Dir);
  if Result then
  begin
    Probe := AddBackslash(Dir) + 'write-test.tmp';
    Result := SaveStringToFile(Probe, '', False);
    DeleteFile(Probe);
  end;
  if Made then
    RemoveDir(Dir);
end;

// A chosen folder the user cannot write to is refused before anything is
// installed (also in a silent install with /DIR).
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpSelectDir) and not CanWrite(WizardDirValue) then
  begin
    SuppressibleMsgBox(CustomMessage('DirNotWritable'), mbError, MB_OK, IDOK);
    Result := False;
  end;
end;

// Installed: the new copy's own uninstall entry knows its folder now.
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RegDeleteValue(HKCU, KeptKey, KeptValue);
    RegDeleteKeyIfEmpty(HKCU, KeptKey);
  end;
end;

// Uninstalling: the app's autostart entry goes, and so does a Windows
// proxy setting the app left pointing at its own (now gone) proxy; then
// the data, if the user wants. Kept data's folder is noted for the next
// install.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Enabled: Cardinal;
  Server: String;
  Data: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    RegDeleteValue(HKCU, RunKey, '{#AppName}');
    if RegQueryDWordValue(HKCU, InternetKey, 'ProxyEnable', Enabled) and (Enabled = 1) and
       RegQueryStringValue(HKCU, InternetKey, 'ProxyServer', Server) and
       (Pos('127.0.0.1:', Server) = 1) then
      RegWriteDWordValue(HKCU, InternetKey, 'ProxyEnable', 0);
  end;
  if CurUninstallStep = usPostUninstall then
  begin
    Data := ExpandConstant('{app}\user-data');
    // Keep is the first and default button; a silent uninstall keeps too.
    if DirExists(Data) and not UninstallSilent and
       (TaskDialogMsgBox(CustomMessage('DataQuestion'), CustomMessage('DataText'), mbConfirmation,
          MB_YESNO, [CustomMessage('DataKeep'), CustomMessage('DataDelete')], 0) = IDNO) then
      DelTree(Data, True, True, True);
    if DirExists(Data) then
      RegWriteStringValue(HKCU, KeptKey, KeptValue, ExpandConstant('{app}'))
    else
    begin
      RegDeleteValue(HKCU, KeptKey, KeptValue);
      RegDeleteKeyIfEmpty(HKCU, KeptKey);
    end;
    RemoveDir(ExpandConstant('{app}'));
  end;
end;
