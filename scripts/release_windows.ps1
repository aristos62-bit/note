# scripts/release_windows.ps1
#
# S-10: end-to-end Windows release:
#   1) flutter build windows --release
#   2) sign  build\windows\x64\runner\Release\super_note.exe
#   3) ISCC note_eco_new.iss  (InstallerOutput\SuperNoteSetup.exe)
#   4) sign  InstallerOutput\SuperNoteSetup.exe
#   5) verify both + tamper self-test
#   6) InstallerOutput\SHA256SUMS.txt  (για δημοσίευση στο GitHub Release)
#
# Το cert δημιουργείται μία φορά με scripts\new_codesign_cert.ps1 (self-signed,
# Cert:\CurrentUser\My). Το script το βρίσκει από το Subject - κανένα secret,
# κανένα .pfx, κανένα password μέσα στο repo.
#
# Χρήση:
#   powershell -ExecutionPolicy Bypass -File scripts\release_windows.ps1
#   ... -SkipBuild        (χρησιμοποιεί το υπάρχον Release build)
#   ... -SkipInstaller    (μόνο exe: build + sign + hashes)
param(
    [string]$Subject = 'CN=Aris Gavrielatos (SuperNote), O=Gavrielatos, C=GR',
    [switch]$SkipBuild,
    [switch]$SkipInstaller
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Fail([string]$msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

function Find-SignTool {
    $base = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path $base)) { return $null }
    return Get-ChildItem $base -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Find-CodeSignCert([string]$subject) {
    return Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $subject -and $_.NotAfter -gt (Get-Date).AddDays(30) } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1
}

function Sign-File([string]$signtool, [string]$thumb, [string]$file) {
    if (-not (Test-Path $file)) { Fail "missing file: $file" }
    & $signtool sign /fd sha256 /sha1 $thumb $file | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "signtool sign failed: $file" }
    Write-Host "  signed: $file" -ForegroundColor Green
}

function Test-Signature([string]$file) {
    $sig = Get-AuthenticodeSignature $file
    $subjectOk = $sig.SignerCertificate -and $sig.SignerCertificate.Subject -eq $Subject
    if (-not $subjectOk) { Fail "unsigned / wrong signer: $file ($($sig.Status))" }
    Write-Host "  verify: $([System.IO.Path]::GetFileName($file)) -> $($sig.Status) | $($sig.SignerCertificate.Subject)" -ForegroundColor Gray
    Write-Host "    $($sig.StatusMessage)" -ForegroundColor DarkGray
}

function Test-Tamper([string]$file) {
    $tmp = Join-Path $env:TEMP ("sn_tamper_" + [System.IO.Path]::GetFileName($file))
    Copy-Item $file $tmp -Force
    $bytes = [System.IO.File]::ReadAllBytes($tmp)
    # Μεσαίο byte: το τέλος του αρχείου είναι ο πίνακας υπογραφής (δεν μετράει στο hash).
    $mid = [int]([Math]::Floor($bytes.Length / 2))
    $bytes[$mid] = $bytes[$mid] -bxor 0xFF
    [System.IO.File]::WriteAllBytes($tmp, $bytes)
    $sig = Get-AuthenticodeSignature $tmp
    Remove-Item $tmp -Force
    if ($sig.Status -ne 'HashMismatch') {
        Fail "tamper test: expected HashMismatch, got $($sig.Status) ($file)"
    }
    Write-Host "  tamper test: 1 byte changed -> HashMismatch" -ForegroundColor Gray
}

# ── prerequisites ────────────────────────────────────────────────────────────
$signtool = Find-SignTool
if (-not $signtool) { Fail 'signtool.exe not found (install the Windows SDK signing tools).' }
$cert = Find-CodeSignCert $Subject
if (-not $cert) { Fail "code-signing cert not found. Run scripts\new_codesign_cert.ps1 first." }
$thumb = $cert.Thumbprint
Write-Host "signtool : $signtool"
Write-Host "cert     : $thumb | $($cert.Subject) | expires $($cert.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host ''

$exe = Join-Path $root 'build\windows\x64\runner\Release\super_note.exe'
$outDir = Join-Path $root 'InstallerOutput'
$setup = Join-Path $outDir 'SuperNoteSetup.exe'

$version = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$extraDir = Join-Path $outDir 'setup_extra'

# ── 1) build ─────────────────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host '[1/6] flutter build windows --release' -ForegroundColor Cyan
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) { Fail 'flutter build windows failed' }
}
else {
    Write-Host '[1/6] build skipped (-SkipBuild)' -ForegroundColor DarkGray
}

# ── 2) sign exe ──────────────────────────────────────────────────────────────
Write-Host '[2/6] sign super_note.exe' -ForegroundColor Cyan
Sign-File $signtool $thumb $exe

# ── 3) extras που πακετάρονται ΜΕΣΑ στο setup ({app}) ────────────────────────
Write-Host '[3/6] cert + οδηγίες + SHA256SUMS-app.txt (μπαίνουν στο setup)' -ForegroundColor Cyan
if (Test-Path $extraDir) { Remove-Item $extraDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extraDir | Out-Null

# Δημόσιο πιστοποιητικό (ΜΟΝΟ public — το ιδιωτικό κλειδί μένει στο store του χρήστη)
$cerPath = Join-Path $extraDir 'SuperNote-codesign.cer'
Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
Copy-Item $cerPath (Join-Path $outDir 'SuperNote-codesign.cer') -Force

$readme = @"
SuperNote $version - οδηγίες εγκατάστασης (Windows)
===================================================

1) ΕΓΚΑΤΑΣΤΑΣΗ
   Τρέξε το SuperNoteSetup.exe.
   Αν βγει "Windows protected your PC / Άγνωστος εκδότης":
     Περισσότερες πληροφορίες  ->  Εκτέλεση ούτως ή άλλως.
   Εγκαθίσταται ΧΩΡΙΣ admin, μόνο για τον τρέχοντα χρήστη:
     πρόγραμμα: %LOCALAPPDATA%\SuperNote
     δεδομένα : %LOCALAPPDATA%\SuperNoteData  (δεν σβήνονται στην απεγκατάσταση)

   Ο installer καταχωρεί το πιστοποιητικό εκδότη ΜΟΝΟ για τον τρέχοντα χρήστη
   (Trusted Root + Trusted Publishers), ώστε μετά το πρόγραμμα να εμφανίζεται
   "Valid". Αφαίρεση: certmgr.msc -> Trusted Root -> "Aris Gavrielatos (SuperNote)".

2) ΕΛΕΓΧΟΣ ΑΚΕΡΑΙΟΤΗΤΑΣ ΤΟΥ ΕΓΚΑΤΕΣΤΗΜΕΝΟΥ ΠΡΟΓΡΑΜΜΑΤΟΣ
   Στον φάκελο εγκατάστασης (%LOCALAPPDATA%\SuperNote):
     Get-FileHash .\super_note.exe -Algorithm SHA256
   Σύγκρινε με τη γραμμή super_note.exe του SHA256SUMS-app.txt (ίδιος φάκελος).
   Διαφορά = το exe δεν είναι αυτό που εγκαταστάθηκε  ->  ΜΗΝ το τρέξεις.

   Αν έλαβες και SHA256SUMS.txt μαζί με το setup (π.χ. από GitHub Release):
     Get-FileHash .\SuperNoteSetup.exe -Algorithm SHA256
   και σύγκρινε με τη γραμμή SuperNoteSetup.exe.

3) ΑΦΑΙΡΕΣΗ
   Ρυθμίσεις  ->  Εφαρμογές  ->  "Προσωπικός Βοηθός"  ->  Κατάργηση.
   (Τα δεδομένα στο %LOCALAPPDATA%\SuperNoteData μένουν — διαγράφονται χειροκίνητα.)

Το πιστοποιητικό είναι SELF-SIGNED: αποδεικνύει ακεραιότητα (κανείς δεν άλλαξε το
αρχείο), όχι ταυτότητα εκδότη σε τρίτους. Γι' αυτό ο installer το καταχωρεί τοπικά
και μόνο για τον τρέχοντα χρήστη.
"@
$readmePath = Join-Path $extraDir 'ΕΓΚΑΤΑΣΤΑΣΗ.txt'
Set-Content -Path $readmePath -Value $readme -Encoding UTF8
Copy-Item $readmePath (Join-Path $outDir 'ΕΓΚΑΤΑΣΤΑΣΗ.txt') -Force

# Hash του exe (ΟΧΙ του setup — αυγό/κότα: το setup δεν μπορεί να περιέχει το hash του)
$appSumsPath = Join-Path $extraDir 'SHA256SUMS-app.txt'
$exeHash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
$cerHash = (Get-FileHash $cerPath -Algorithm SHA256).Hash.ToLower()
$appSums = @(
    "# SuperNote $version - installed files (super_note.exe + SuperNote-codesign.cer)",
    "$exeHash  super_note.exe",
    "$cerHash  SuperNote-codesign.cer"
)
Set-Content -Path $appSumsPath -Value $appSums -Encoding ascii
Copy-Item $appSumsPath (Join-Path $outDir 'SHA256SUMS-app.txt') -Force
Write-Host "  staging: $extraDir" -ForegroundColor Gray

# ── 4) + 5) installer + sign setup ───────────────────────────────────────────
if (-not $SkipInstaller) {
    Write-Host '[4/6] ISCC note_eco_new.iss' -ForegroundColor Cyan
    $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
    if (-not (Test-Path $iscc)) { Fail "ISCC.exe not found at $iscc" }
    & $iscc (Join-Path $root 'note_eco_new.iss')
    if ($LASTEXITCODE -ne 0) { Fail 'ISCC failed' }

    Write-Host '[5/6] sign SuperNoteSetup.exe' -ForegroundColor Cyan
    Sign-File $signtool $thumb $setup
}
else {
    Write-Host '[4/6] installer skipped (-SkipInstaller)' -ForegroundColor DarkGray
    Write-Host '[5/6] installer skipped (-SkipInstaller)' -ForegroundColor DarkGray
}

# ── 6) verify + SHA256SUMS.txt (για δημοσίευση / έλεγχο κατεβάσματος) ────────
Write-Host '[6/6] verify + SHA256SUMS.txt' -ForegroundColor Cyan
Test-Signature $exe
Test-Tamper $exe
$files = @($exe)
if (-not $SkipInstaller) {
    Test-Signature $setup
    Test-Tamper $setup
    $files += $setup
}
$files += (Join-Path $outDir 'SuperNote-codesign.cer')

$lines = foreach ($f in $files) {
    $hash = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
    "$hash  $([System.IO.Path]::GetFileName($f))"
}
$sumPath = Join-Path $outDir 'SHA256SUMS.txt'
$header = "# SuperNote $version - $(Get-Date -Format 'yyyy-MM-dd HH:mm') - self-signed build"
Set-Content -Path $sumPath -Value (@($header) + $lines) -Encoding ascii
Write-Host ''
Get-Content $sumPath
Write-Host ''
Write-Host "OK: $sumPath" -ForegroundColor Green
Write-Host 'Διανομή: μόνο το SuperNoteSetup.exe — τα υπόλοιπα είναι μέσα του.' -ForegroundColor Yellow
Write-Host 'Προαιρετικά (GitHub Release): + SHA256SUMS.txt για το hash του setup.' -ForegroundColor Yellow
