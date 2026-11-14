; ========================================
; Προσωπικός Βοηθός - Super Note
; ========================================

[Setup]
AppId={{A13E92D4-7F5B-4A5F-8C11-2B7D99887766}}
AppName=Προσωπικός Βοηθός
AppVersion=1.2.0
VersionInfoVersion=1.2.0.4
AppPublisher=Aris Gavrielatos
AppPublisherURL=https://github.com/aristos62-bit/note
AppSupportURL=https://github.com/aristos62-bit/note/issues
AppUpdatesURL=https://github.com/aristos62-bit/note/releases

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
OutputDir={#SourcePath}InstallerOutput
OutputBaseFilename=SuperNoteSetup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#SourcePath}windows\runner\resources\app_icon.ico
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
Source: "{#SourcePath}build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Το VC++ Redistributable
Source: "{#SourcePath}Dependencies\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

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
; Μόνο ο φάκελος εγκατάστασης. Τα δεδομένα (βλ. [Code]) διαγράφονται ΜΟΝΟ αν ο
; χρήστης απαντήσει «Ναι» στο prompt του InitializeUninstall.
Type: filesandordirs; Name: "{app}"

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
  DataRoot, SupportRoot, LegacySupportRoot, LegacyAppData: string;
  Removed: Boolean;
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then
  begin
    Removed := False;

    // S-01: η πραγματική ρίζα δεδομένων (βάση, συνημμένα, ρυθμίσεις)
    DataRoot := ExpandConstant('{localappdata}\SuperNoteData');
    if DirExists(DataRoot) then
    begin
      DelTree(DataRoot, True, True, True);
      Removed := True;
    end;

    // E50: support dir του path_provider = {appdata}\<CompanyName>\<ProductName>
    // του Runner.rc (Gavrielatos / SuperNote) — εκεί ζουν τα SuperNoteBackups.
    SupportRoot := ExpandConstant('{userappdata}\Gavrielatos\SuperNote');
    if DirExists(SupportRoot) then
    begin
      DelTree(SupportRoot, True, True, True);
      Removed := True;
    end;

    // Legacy support dir (πριν το S-09: CompanyName «com.example», ProductName «super_note»)
    LegacySupportRoot := ExpandConstant('{userappdata}\com.example\super_note');
    if DirExists(LegacySupportRoot) then
    begin
      DelTree(LegacySupportRoot, True, True, True);
      Removed := True;
    end;

    // Legacy: το έφτιαχνε το [Dirs] παλιότερων εκδόσεων (η εφαρμογή δεν γράφει εδώ)
    LegacyAppData := ExpandConstant('{userappdata}\super_note');
    if DirExists(LegacyAppData) then
    begin
      DelTree(LegacyAppData, True, True, True);
      Removed := True;
    end;

    // Το legacy root (app documents) ΔΕΝ αγγίζεται: είναι ο Documents του χρήστη
    // και το `attachments` είναι γενικό όνομα — θα έσβηνε ξένα αρχεία.

    if Removed then
      MsgBox('Τα δεδομένα της εφαρμογής διαγράφηκαν.', mbInformation, MB_OK)
    else
      MsgBox('Δεν βρέθηκαν δεδομένα της εφαρμογής προς διαγραφή.', mbInformation, MB_OK);
  end;
end;