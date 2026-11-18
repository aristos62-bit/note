# scripts/new_codesign_cert.ps1
#
# S-10: δημιουργεί (μία φορά) ένα **self-signed** code-signing πιστοποιητικό για
# το SuperNote, στο `Cert:\CurrentUser\My` του τρέχοντος χρήστη.
#
# Γιατί self-signed:
#  • Μηδέν κόστος, κανένας εξωτερικός CA, κανένα hardware token.
#  • ΔΕΝ αποδεικνύει ταυτότητα σε τρίτους: το SmartScreen θα δείχνει «Άγνωστος
#    εκδότης» μέχρι το cert να μπει στα Trusted Root/Trusted Publishers **του
#    μηχανήματος που το ελέγχει** (βλ. -TrustLocal).
#  • Χρησιμεύει για: (α) ακεραιότητα — αν αλλοιωθεί έστω 1 byte, η υπογραφή
#    σπάει· (β) σταθερή ταυτότητα σε δικά μας builds/μηχανήματα.
#
# Το κλειδί μένει στο store του χρήστη (Exportable=false by default ⇒ δεν
# εξάγεται κατά λάθος). Για backup: εξαγωγή .pfx χειροκίνητα από το
# `certmgr.msc` — ΠΟΤΕ μέσα στο repo.
#
# Χρήση:
#   powershell -ExecutionPolicy Bypass -File scripts\new_codesign_cert.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\new_codesign_cert.ps1 -TrustLocal
#
# -TrustLocal: προσθέτει το cert στα Trusted Root + Trusted Publishers του
# **τρέχοντος χρήστη** ώστε τα Windows να δείχνουν «Valid» σε αυτό το PC.
# (Το Windows μπορεί να ζητήσει επιβεβαίωση — είναι αναμενόμενο.)
param(
    [string]$Subject = 'CN=Aris Gavrielatos (SuperNote), O=Gavrielatos, C=GR',
    [int]$Years = 5,
    [switch]$TrustLocal
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$existing = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $Subject -and $_.NotAfter -gt (Get-Date).AddDays(30) } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if ($existing) {
    Write-Host "Υπάρχει ήδη code-signing cert:" -ForegroundColor Yellow
    Write-Host "  Subject   : $($existing.Subject)"
    Write-Host "  Thumbprint: $($existing.Thumbprint)"
    Write-Host "  Λήγει     : $($existing.NotAfter.ToString('yyyy-MM-dd'))"
    $cert = $existing
}
else {
    Write-Host "Δημιουργία self-signed code-signing cert..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $Subject `
        -KeyUsage DigitalSignature `
        -FriendlyName 'SuperNote Self-Signed Code Signing' `
        -CertStoreLocation Cert:\CurrentUser\My `
        -NotAfter (Get-Date).AddYears($Years)
    Write-Host "  Νέο cert: $($cert.Thumbprint)" -ForegroundColor Green
}

if ($TrustLocal) {
    $root = 'Cert:\CurrentUser\Root'
    $publishers = 'Cert:\CurrentUser\TrustedPublisher'
    foreach ($store in @($root, $publishers)) {
        $already = Get-ChildItem $store -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
        if (-not $already) {
            Export-Certificate -Cert $cert -FilePath "$env:TEMP\supernote-codesign.cer" -Force | Out-Null
            Import-Certificate -FilePath "$env:TEMP\supernote-codesign.cer" -CertStoreLocation $store | Out-Null
            Remove-Item "$env:TEMP\supernote-codesign.cer" -Force
            Write-Host "  Προστέθηκε στο $store" -ForegroundColor Green
        }
        else {
            Write-Host "  Ήδη παρόν στο $store" -ForegroundColor DarkGray
        }
    }
}

Write-Host ''
Write-Host 'Thumbprint (για το release script):' -ForegroundColor Cyan
Write-Host $cert.Thumbprint
