; Installeur Windows de TimeLog (NSIS 3.x, 64 bits).
;
; Fabriqué par build-windows.ps1, qui passe les défines suivantes :
;   APP_VERSION  version affichée (lue dans app/pubspec.yaml)
;   SOURCE_DIR   dossier de sortie de « flutter build windows --release »
;   OUTPUT_DIR   dossier où écrire l'installeur
;
; Optionnel : placer vc_redist.x64.exe dans packaging\windows\redist\ pour que
; l'installeur installe automatiquement le runtime Visual C++ s'il manque.

Unicode true
ManifestDPIAware true

; ---------------------------------------------------------------- Défines

!define ROOT_DIR "${__FILEDIR__}\..\.."

!ifndef APP_VERSION
  !define APP_VERSION "1.1.0"
!endif
!ifndef SOURCE_DIR
  !define SOURCE_DIR "${ROOT_DIR}\app\build\windows\x64\runner\Release"
!endif
!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "${__FILEDIR__}\..\dist"
!endif
!ifndef VCREDIST_EXE
  !define VCREDIST_EXE "${__FILEDIR__}\redist\vc_redist.x64.exe"
!endif

!define APP_NAME      "TimeLog"
!define APP_EXE       "timelog.exe"
!define APP_PUBLISHER "Lukas Hofer"
!define APP_URL       "https://github.com/Hoferlukaslh/TimeLog"
!define APP_ID        "ch.lukas.timelog"
!define UNINST_KEY    "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

; ---------------------------------------------------------------- Installeur

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTPUT_DIR}\timelog-${APP_VERSION}-setup-x64.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
BrandingText "${APP_NAME} ${APP_VERSION}"

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription" "Installeur de ${APP_NAME}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "© ${APP_PUBLISHER}, GPL v3"

!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

!define MUI_ICON   "${ROOT_DIR}\app\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "${ROOT_DIR}\app\windows\runner\resources\app_icon.ico"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${ROOT_DIR}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Lancer ${APP_NAME}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Le premier langage est celui par défaut si la langue du système n'est pas gérée.
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------- Vérifications

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "${APP_NAME} nécessite Windows 64 bits."
    Abort
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- Installation

Section "${APP_NAME}" SecMain
  SectionIn RO
  SetShellVarContext all
  SetRegView 64

  ; Mise à jour : fermer l'application si elle tourne encore (erreur ignorée).
  nsExec::Exec 'taskkill /F /IM ${APP_EXE}'
  Pop $0

  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}\*.*"

  ; Runtime Visual C++ (requis par Flutter), seulement s'il manque.
  !if /FileExists "${VCREDIST_EXE}"
    ; Si vcruntime140.dll existe déjà, sauter les 3 instructions suivantes (+4 : jusqu'au SetOutPath).
    IfFileExists "$SYSDIR\vcruntime140.dll" +4 0
      InitPluginsDir
      File /oname=$PLUGINSDIR\vc_redist.x64.exe "${VCREDIST_EXE}"
      ExecWait '"$PLUGINSDIR\vc_redist.x64.exe" /install /quiet /norestart'
    SetOutPath "$INSTDIR"
  !endif

  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Raccourcis : menu Démarrer (tous les utilisateurs) et bureau.
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Désinstaller ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe"
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

  ; Entrée dans « Applications et fonctionnalités ».
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "${APP_URL}"
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" $0
SectionEnd

; ---------------------------------------------------------------- Désinstallation

Section "Uninstall"
  SetShellVarContext all
  SetRegView 64

  nsExec::Exec 'taskkill /F /IM ${APP_EXE}'
  Pop $0

  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"
  RMDir /r "$INSTDIR"

  DeleteRegKey HKLM "${UNINST_KEY}"

  ; Les données de l'utilisateur (%APPDATA%\ch.lukas\TimeLog) sont conservées volontairement.
SectionEnd
