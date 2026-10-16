# ==============================================================================
# Script: package-windows.ps1
# Packages Flutter Windows desktop release bundles into Inno Setup (.exe) and (.zip)
# ==============================================================================

param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

if ($Version.StartsWith("v")) {
    $Version = $Version.Substring(1)
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$AbsOutputDir = (Resolve-Path $OutputDir).Path

Write-Host "=========================================================="
Write-Host " Packaging Windows Releases for Version: $Version"
Write-Host " Output Directory: $AbsOutputDir"
Write-Host "=========================================================="

# Locate ISCC (Inno Setup Compiler)
$Iscc = "iscc"
if (-not (Get-Command "iscc" -ErrorAction SilentlyContinue)) {
    $candidate = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (Test-Path $candidate) {
        $Iscc = $candidate
    } else {
        $candidate2 = "C:\Program Files\Inno Setup 6\ISCC.exe"
        if (Test-Path $candidate2) {
            $Iscc = $candidate2
        } else {
            Write-Warning "Inno Setup Compiler (iscc) not found! Setup.exe will be skipped; only .zip will be generated."
            $Iscc = $null
        }
    }
}

$Apps = @(
    @{
        Id = "iec104_server"
        Name = "IEC 104 Server Simulator"
        Desc = "IEC 60870-5-104 RTU Server Simulator"
        Guid = "A1040001-C381-453F-9A52-8717812AA104"
        Icon = "iec104_server\windows\runner\resources\app_icon.ico"
    },
    @{
        Id = "iec104_client"
        Name = "IEC 104 Client Simulator"
        Desc = "IEC 60870-5-104 Master Client Simulator"
        Guid = "A1040002-C381-453F-9A52-8717812BB104"
        Icon = "iec104_client\windows\runner\resources\app_icon.ico"
    },
    @{
        Id = "iec61850_server"
        Name = "IEC 61850 Server Simulator"
        Desc = "IEC 61850 MMS & GOOSE Server Simulator"
        Guid = "B6180001-C381-453F-9A52-8717812CC850"
        Icon = "iec61850_server\windows\runner\resources\app_icon.ico"
    },
    @{
        Id = "iec61850_client"
        Name = "IEC 61850 Client Simulator"
        Desc = "IEC 61850 MMS & GOOSE Client Simulator"
        Guid = "B6180002-C381-453F-9A52-8717812DD850"
        Icon = "iec61850_client\windows\runner\resources\app_icon.ico"
    },
    @{
        Id = "modbus_slave"
        Name = "Modbus Slave Emulator"
        Desc = "Modbus RTU / TCP / UDP Slave Emulator (MSE)"
        Guid = "C5020001-C381-453F-9A52-8717812EE502"
        Icon = "modbus_slave\windows\runner\resources\app_icon.ico"
    },
    @{
        Id = "modbus_master"
        Name = "Modbus Master Emulator"
        Desc = "Modbus RTU / TCP / UDP Master Emulator (MME)"
        Guid = "C5020002-C381-453F-9A52-8717812FF502"
        Icon = "modbus_master\windows\runner\resources\app_icon.ico"
    }
)

foreach ($App in $Apps) {
    $AppId = $App.Id
    $AppName = $App.Name
    $AppDesc = $App.Desc
    $AppGuid = $App.Guid
    $IconRel = $App.Icon

    Write-Host "----------------------------------------------------------"
    Write-Host ">>> Packaging Windows: $AppName ($AppId)"
    Write-Host "----------------------------------------------------------"

    $BundleDir = "$AppId\build\windows\x64\runner\Release"
    if (-not (Test-Path $BundleDir)) {
        Write-Error "Bundle directory not found: $BundleDir. Please build the Flutter app first."
        continue
    }

    $AbsBundleDir = (Resolve-Path $BundleDir).Path
    $AbsIcon = if (Test-Path $IconRel) { (Resolve-Path $IconRel).Path } else { "" }

    # 1. Package Portable ZIP
    $ZipName = "$AppId-$Version-windows-x64.zip"
    $ZipPath = Join-Path $AbsOutputDir $ZipName
    Write-Host "Creating portable archive: $ZipName..."
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Compress-Archive -Path "$AbsBundleDir\*" -DestinationPath $ZipPath -Force
    Write-Host "✓ Generated: $ZipPath"

    # 2. Package Inno Setup (.exe Installer)
    if ($Iscc) {
        $InstallerBaseName = "$AppId-$Version-windows-x64-setup"
        $IssPath = "$AppId\_installer.iss"

        $IconDirective = ""
        if ($AbsIcon -and (Test-Path $AbsIcon)) {
            $IconDirective = "SetupIconFile=$AbsIcon"
        }

        $IssContent = @"
#define MyAppName "$AppName"
#define MyAppPublisher "Industrial Protocol Suite"
#define MyAppExeName "$AppId.exe"
#define MyAppVersion "$Version"

[Setup]
AppId={{$AppGuid}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=$AbsOutputDir
OutputBaseFilename=$InstallerBaseName
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
$IconDirective
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$AbsBundleDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
"@

        Set-Content -Path $IssPath -Value $IssContent -Encoding UTF8
        Write-Host "Compiling Inno Setup installer: $InstallerBaseName.exe..."
        & $Iscc $IssPath
        Remove-Item $IssPath -Force -ErrorAction SilentlyContinue

        $ExpectedExe = Join-Path $AbsOutputDir "$InstallerBaseName.exe"
        if (Test-Path $ExpectedExe) {
            Write-Host "✓ Generated Installer: $ExpectedExe"
        } else {
            Write-Warning "Inno Setup output file not found at expected path: $ExpectedExe"
        }
    }
}

Write-Host "=========================================================="
Write-Host " Windows packaging completed successfully!"
Get-ChildItem -Path $AbsOutputDir | Format-Table Name, Length, LastWriteTime
Write-Host "=========================================================="
