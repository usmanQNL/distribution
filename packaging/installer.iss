; Inno Setup script template. Built on the Windows runner with: iscc packaging/installer.iss
; Paths are relative to this file (packaging/). PyInstaller writes the exe to build/dist/.
; Replace MyApp and the version placeholders, or the workflow fills them in from VERSION.
#define MyAppName "app"
#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
OutputDir=..\release
OutputBaseFilename={#MyAppName}-{#MyAppVersion}-setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\build\dist\app.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\app.exe"
