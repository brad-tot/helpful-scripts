<#
----------------- Copyright (c) Takeoff Technical LLC 2024 ---------------------
Purpose: Creates a new Windows ISO file with additional drivers
Notes: I wrote this to add RAID drivers to the installation disk
Runtime: Administrator permissions required to mount wim files
Video: https://youtube.com/@takeofftechnical
License: GPL v3
Prerequisite:
  The Windows Assessment and Deployment Kit (ADK) must be installed
    - https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
    - Only the "Deployment Tools" are required to be selected during install
    - This provides access to the oscdimg tool
--------------------------------------------------------------------------------
#>

<#
--------------------------------------------------------------------------------
This is the input ISO file -- it will not be modified by this script. Download
the Windows ISO from Microsoft and reference it here.
--------------------------------------------------------------------------------
#>
$INPUT_ISO = Join-Path $PSScriptRoot "Win11_24H2_English_x64.iso"

if (Test-Path -Path $INPUT_ISO -PathType Leaf) {
    Write-Host "Using Input ISO File: $INPUT_ISO"
} else {
    Write-Error "Unable to locate ISO file! [$INPUT_ISO]"
    Exit 1
}

<#
--------------------------------------------------------------------------------
This is the output ISO file. It will be overwritten by this script as a new 
file with all contents from the input ISO + the new drivers.
--------------------------------------------------------------------------------
#>
$OUTPUT_ISO = Join-Path $PSScriptRoot "Win11_24H2_English_x64.custom.iso"

if (-Not(Test-Path -Path $OUTPUT_ISO)) {
    Write-Host "Generating new ISO with drivers: $OUTPUT_ISO"
} elseif (Test-Path -Path $OUTPUT_ISO -PathType Leaf) {
    Write-Warning "Overwriting existing ISO file!"
    Remove-Item $OUTPUT_ISO
} else {
    Write-Error "Output ISO name conflicts with directory: $OUTPUT_ISO"
    Exit 1
}

<#
--------------------------------------------------------------------------------
These are the drivers we will add to the ISO.
--------------------------------------------------------------------------------
#>
$DRIVERS_PATH = Join-Path $PSScriptRoot "drivers"

if (Test-Path -Path $DRIVERS_PATH -PathType Container) {
    Write-Host "Drivers to install: $DRIVERS_PATH"
} else {
    Write-Error "Drivers path not found! [$DRIVERS_PATH]"
    Exit 1
}

<#
--------------------------------------------------------------------------------
Stage a temporary directory to perform work in
--------------------------------------------------------------------------------
#>
$SCRATCH_PATH = Join-Path $PSScriptRoot "scratch"

if (Test-Path -Path $SCRATCH_PATH) {
    Write-Error "Scratch directory cannot already exist! [$SCRATCH_PATH]"
    Exit 1
}

$SCRATCH_DIR = New-Item -ItemType Directory -Path $SCRATCH_PATH 
$SCRATCH_ISO_DIR = New-Item -ItemType Directory -Path $(Join-Path $SCRATCH_DIR.FullName "iso")
$SCRATCH_WIM_DIR = New-Item -ItemType Directory -Path $(Join-Path $SCRATCH_DIR.FullName "wim")

<#
--------------------------------------------------------------------------------
Copy the contents of the input ISO to the temporary directory. Windows can mount
ISOs as read-only, so we must clear those flags to work on the files later.
--------------------------------------------------------------------------------
#>
Write-Host "Exporting ISO to staging directory: $($SCRATCH_ISO_DIR.FullName)..."

$MOUNTED_ISO = Mount-DiskImage -PassThru -ImagePath $INPUT_ISO
$MOUNTED_VOL = Get-Volume -DiskImage $MOUNTED_ISO

$COPIED_ITEMS = Copy-Item -PassThru -Path "$($MOUNTED_VOL.DriveLetter):\*" -Destination $SCRATCH_ISO_DIR.FullName -Recurse
foreach ($item in $COPIED_ITEMS) 
{ 
    if (Test-Path -Path $item -PathType Leaf)
    {
        $item.IsReadOnly = $false
    }
}

Dismount-DiskImage -InputObject $MOUNTED_ISO | Out-Null

<#
--------------------------------------------------------------------------------
Add the drivers to boot.wim, so the pre-execution environment can use them.
--------------------------------------------------------------------------------
#>
Write-Host "Mounting boot.wim..."

$BOOT_WIM_PATH = $(Join-Path $SCRATCH_ISO_DIR.FullName "sources\boot.wim")
$BOOT_PE_IMG = Get-WindowsImage -ImagePath $BOOT_WIM_PATH | Where-Object ImageName -Match "Microsoft Windows PE*"

if ($BOOT_PE_IMG.Count -ne 1) {
    Write-Error "Failed to find PE partition of $BOOT_WIM_PATH"
    Exit 1
}

Mount-WindowsImage -Path $SCRATCH_WIM_DIR.FullName -ImagePath $BOOT_WIM_PATH -Index $BOOT_PE_IMG.ImageIndex | Out-Null

Write-Host "Adding drivers to boot.wim..."
$ADDED_DRIVERS = Add-WindowsDriver -Path $SCRATCH_WIM_DIR.FullName -Driver $DRIVERS_PATH -Recurse
Write-Host "$($ADDED_DRIVERS.Count) drivers installed."

Dismount-WindowsImage -Path $SCRATCH_WIM_DIR.FullName -Save | Out-Null

<#
--------------------------------------------------------------------------------
Iterate over each Windows edition and patch in the drivers
--------------------------------------------------------------------------------
#>
$INSTALL_WIM_PATH = $(Join-Path $SCRATCH_ISO_DIR.FullName "sources\install.wim")
$INSTALL_IMAGES = Get-WindowsImage -ImagePath $INSTALL_WIM_PATH

foreach ($img in $INSTALL_IMAGES) {
    Write-Host "Mounting install.wim [$($img.ImageIndex)]: $($img.ImageName)..."
    Mount-WindowsImage -Path $SCRATCH_WIM_DIR.FullName -ImagePath $INSTALL_WIM_PATH -Index $img.ImageIndex | Out-Null

    $ADDED_DRIVERS = Add-WindowsDriver -Path $SCRATCH_WIM_DIR.FullName -Driver $DRIVERS_PATH -Recurse
    Write-Host "$($ADDED_DRIVERS.Count) drivers installed."

    Dismount-WindowsImage -Path $SCRATCH_WIM_DIR.FullName -Save | Out-Null
}

<#
--------------------------------------------------------------------------------
All ISOs larger than 4.5 GB are required to specify a boot order file. This 
ensures that boot files are located at the beginning of the image.
--------------------------------------------------------------------------------
#>
$BOOT_ORDER_FILE = $(Join-Path $SCRATCH_DIR.FullName "bootOrder.txt")

$SAVE_LOCATION = $pwd
Set-Location $SCRATCH_ISO_DIR.FullName

$UPDATED_CONTENTS = Get-ChildItem -Recurse -Path $SCRATCH_ISO_DIR.FullName
foreach ($content in $UPDATED_CONTENTS) {
    if (Test-Path -Path $content.FullName -PathType Leaf) {
        $(Resolve-Path -Path $content.FullName -Relative).Substring(2) | Out-File -FilePath $BOOT_ORDER_FILE -Encoding ascii -Append
    }
}

Set-Location $SAVE_LOCATION

<#
--------------------------------------------------------------------------------
Write the new ISO that now includes additional drivers.

Options:
 -m             Ignores the maximum size limit of an image.
 -o             Uses a MD5 hashing algorithm to compare files. (optimization)
 -u2            Produces an image that contains only the UDF file system.
 -udfver102     Specifies UDF file system version 1.02.
 -yo            Boot order file
 -bootdata      Specifies a multi-boot image
--------------------------------------------------------------------------------
#>
$BIOS_BOOTFILE = Join-Path $SCRATCH_ISO_DIR.FullName "boot\etfsboot.com"
# Note - Replace with efisys_noprompt.bin as-desired
$EFI_BOOTFILE = Join-Path $SCRATCH_ISO_DIR.FullName "efi\microsoft\boot\efisys.bin"

oscdimg.exe `
    -m `
    -o `
    -u2 `
    -udfver102 `
    -yo"$BOOT_ORDER_FILE" `
    -bootdata:2`#p0,e,b"$BIOS_BOOTFILE"`#pEF,e,b"$EFI_BOOTFILE" `
    "$($SCRATCH_ISO_DIR.FullName)" `
    "$OUTPUT_ISO"

<#
--------------------------------------------------------------------------------
Clean up the temporary directory used for the work
--------------------------------------------------------------------------------
#>
Write-Host "Cleaning up..."
Remove-Item -Path $SCRATCH_DIR.FullName -Recurse -Force

Exit 0
