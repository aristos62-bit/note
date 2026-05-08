; ========================================
; Προσωπικός Βοηθός - Super Note
; ========================================

[Setup]
AppId={{A13E92D4-7F5B-4A5F-8C11-2B7D99887766}}
AppName=Προσωπικός Βοηθός
AppVersion=1.0.0
AppPublisher=Aris Gavrielatos
AppPublisherURL=https://www.example.com
AppSupportURL=https://www.example.com/support
AppUpdatesURL=https://www.example.com/updates
AppContact=support@example.com

; Εμποδίζει την εγκατάσταση αν η εφαρμογή είναι ανοιχτή
AppMutex=SuperNote_Flutter_Mutex
CloseApplications=yes

; Install location (no admin required)
DefaultDirName={localappdata}\SuperNote
DefaultGroupName=Προσωπικός Βοηθός
UsePreviousAppDir=yes
DisableProgramGroupPage=no
AllowNoIcons=yes

; Output
OutputDir=.\InstallerOutput
OutputBaseFilename=SuperNoteSetup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=C:\Users\Vaggelis\Flutter Projects\super_note\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\super_note.exe

; Permissions
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "greek"; MessagesFile: "Greek.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Δημιουργία συντόμευσης στην Επιφάνεια Εργασίας"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Files]
; Η εφαρμογή (Release build)
Source: "C:\Users\Vaggelis\Flutter Projects\super_note\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Το VC++ Redistributable
Source: "C:\Users\Vaggelis\Flutter Projects\super_note\Dependencies\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Dirs]
Name: "{app}"; Permissions: users-full
Name: "{app}\data"; Permissions: users-full
Name: "{userappdata}\super_note"; Permissions: users-full

[Icons]
Name: "{group}\Προσωπικός Βοηθός"; Filename: "{app}\super_note.exe"; WorkingDir: "{app}"; Comment: "Προσωπικός Βοηθός"
Name: "{group}\Απεγκατάσταση"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Προσωπικός Βοηθός"; Filename: "{app}\super_note.exe"; WorkingDir: "{app}"; Tasks: desktopicon; Comment: "Προσωπικός Βοηθός"

[Run]
; Εγκατάσταση του VC Redist αν λείπει (Silent install)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: VCRedistNeedsInstall; StatusMsg: "Εγκατάσταση απαραίτητων στοιχείων συστήματος (Visual C++)..."
; Εκκίνηση εφαρμογής μετά το setup
Filename: "{app}\super_note.exe"; Description: "Εκκίνηση Προσωπικός Βοηθός"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\super_note"
Type: filesandordirs; Name: "{localappdata}\super_note"

[Code]
var
  DeleteUserData: Boolean;

// Έλεγχος αν το VC++ Redistributable είναι ήδη εγκατεστημένο
function VCRedistNeedsInstall(): Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', Version);
end;

procedure InitializeWizard();
begin
  if GetWindowsVersion < $0A000000 then
  begin
    MsgBox('Αυτό το πρόγραμμα απαιτεί Windows 10 ή νεότερα.', mbError, MB_OK);
    Abort();
  end;

  if not IsWin64 then
  begin
    MsgBox('Η εφαρμογή λειτουργεί μόνο σε 64-bit Windows.', mbError, MB_OK);
    Abort();
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('Επιθυμείτε να διαγραφούν ΟΛΑ τα δεδομένα της εφαρμογής (βάση δεδομένων, ρυθμίσεις);', 
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    DeleteUserData := True
  else
    DeleteUserData := False;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath, LocalAppDataPath: string;
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then
  begin
    AppDataPath := ExpandConstant('{userappdata}\f_budget');
    if DirExists(AppDataPath) then DelTree(AppDataPath, True, True, True);

    LocalAppDataPath := ExpandConstant('{localappdata}\f_budget');
    if DirExists(LocalAppDataPath) then DelTree(LocalAppDataPath, True, True, True);
    
    MsgBox('Τα δεδομένα χρήστη διαγράφηκαν.', mbInformation, MB_OK);
  end;
end;