; Inno Setup script template. Built on the Windows runner with: iscc packaging/installer.iss
; Paths are relative to this file (packaging/). PyInstaller writes the exe to build/dist/.
; The workflow and release_local.sh pass MyAppName (app_name in distribution.json) and MyAppVersion.
; They also write the settings template to build/env/.env.example when the project has one (scripts/env_example.sh);
; it is installed next to the exe, where the user copies it to .env. An existing .env is never touched.
#ifndef MyAppName
#define MyAppName "app"
#endif
#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
OutputDir=..\release
OutputBaseFilename={#MyAppName}-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\build\dist\{#MyAppName}.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\env\.env.example"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppName}.exe"; WorkingDir: "{app}"
