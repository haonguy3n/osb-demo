<#
.SYNOPSIS
  Create a VirtualBox VM for an osb image, or for its installer ISO.

.DESCRIPTION
  Image mode converts a raw osb disk image into a VDI and boots it - the same
  bytes you would write with bmaptool. Iso mode creates an empty VDI and attaches
  the installer ISO to it, so the installer has somewhere to write.

  Both modes configure UEFI (the images will not boot on BIOS firmware) and, with
  -Tpm, a virtual TPM 2.0, which demo-image needs for its encrypted /data.

  See docs/virtualbox.md for what to check inside the guest, and for the one
  thing VirtualBox cannot test: Secure Boot itself.

.EXAMPLE
  .\create-vm.ps1 -Mode Image -Source .\verity-image.img -DiskGb 20

.EXAMPLE
  .\create-vm.ps1 -Mode Iso -Source .\demo-image.iso -DiskGb 20 -Tpm
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Image', 'Iso')][string]$Mode,
    [Parameter(Mandatory)][string]$Source,
    [string]$VmName = 'osb-ubuntu',
    [string]$VmDir = (Join-Path $PSScriptRoot '..\vm'),
    [int]$DiskGb = 20,
    [int]$MemoryMb = 4096,
    [int]$Cpus = 2,
    [switch]$Tpm
)

$ErrorActionPreference = 'Stop'

# VBoxManage is not always on PATH, and is not on PATH at all right after a
# default install.
$vbox = (Get-Command VBoxManage.exe -ErrorAction SilentlyContinue).Source
if (-not $vbox) {
    foreach ($guess in @("$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
                         "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe")) {
        if (Test-Path $guess) { $vbox = $guess; break }
    }
}
if (-not $vbox) { throw "VBoxManage.exe not found - install VirtualBox, or add it to PATH" }

function VB {
    & $vbox @args
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed ($LASTEXITCODE)" }
}

if (-not (Test-Path $Source)) {
    throw "$Source does not exist. CI artifacts arrive as a .zip: unzip it first."
}
$Source = (Resolve-Path $Source).Path
$VmDir = (New-Item -ItemType Directory -Force -Path $VmDir).FullName

if ((& $vbox list vms) -match "`"$VmName`"") {
    throw "a VM named '$VmName' already exists - pass -VmName something-else, or delete it"
}

$disk = Join-Path $VmDir "$VmName.vdi"
$diskMb = $DiskGb * 1024

if ($Mode -eq 'Image') {
    # A raw image is a whole disk: convert, then give the guest room to grow into.
    VB convertfromraw $Source $disk --format VDI
    VB modifymedium disk $disk --resize $diskMb
} else {
    VB createmedium disk --filename $disk --size $diskMb
}

VB createvm --name $VmName --ostype Ubuntu_64 --basefolder $VmDir --register
VB modifyvm $VmName --firmware efi --memory $MemoryMb --cpus $Cpus --ioapic on
if ($Tpm) { VB modifyvm $VmName --tpm-type 2.0 }

VB storagectl $VmName --name SATA --add sata --controller IntelAhci --portcount 4 --bootable on
VB storageattach $VmName --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
if ($Mode -eq 'Iso') {
    VB storageattach $VmName --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Source
}
VB modifyvm $VmName --boot1 disk --boot2 dvd --boot3 none --boot4 none

Write-Host ""
Write-Host "VM '$VmName' created in $VmDir"
Write-Host "  firmware : EFI"
Write-Host "  tpm      : $(if ($Tpm) { '2.0' } else { 'none' })"
Write-Host "  disk     : $disk ($DiskGb GB)"
if ($Mode -eq 'Iso') {
    Write-Host "  dvd      : $Source"
    Write-Host ""
    Write-Host "Install from the ISO, then detach it so the machine boots what it installed:"
    Write-Host "  & '$vbox' storageattach $VmName --storagectl SATA --port 1 --device 0 --type dvddrive --medium none"
} else {
    Write-Host "  booting  : the image itself (same bytes bmaptool would write)"
}
Write-Host ""
Write-Host "Boot it:"
Write-Host "  & '$vbox' startvm $VmName"
