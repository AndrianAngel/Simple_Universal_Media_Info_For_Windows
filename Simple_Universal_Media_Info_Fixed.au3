; =============================================================================
; SIMPLE UNIVERSAL MEDIA INFO
; =============================================================================
; Author: AndrianAngel (Github)
; Open-Source: Non-commercial usage (AndrianAngel Copyright 13st March 2026)
; =============================================================================
#NoTrayIcon
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <FontConstants.au3>
#include <Date.au3>
#include <Misc.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <WinAPI.au3>
#include <WinAPIGdi.au3>
#include <ButtonConstants.au3>
; Note: $WM_PAINT (0x000F) and $WM_THEMECHANGED (0x031A) are defined in WindowsConstants.au3

; Initialize =============================================================================
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)

; Global variables =============================================================================
Global $hMainGUI, $hSettingsGUI
Global $iTitleColor = 0xFFFFFF, $iPlayerColor = 0xCCCCCC, $iFileTypeColor = 0xAAAAAA, $iLengthColor = 0xCCCCCC
Global $sPlayerPath = "C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe"
Global $sCustomPlayerName = ""
Global $bRememberPos = False, $bBoldFont = False, $bUpperCase = False, $bShowOnStart = True
Global $iFadeTime = 2
Global $iLastX = -1, $iLastY = -1
Global $hTimer = 0
Global $bMouseOver = False
Global $sCurrentMediaFile = ""
Global $sCurrentPlayerProcess = ""
Global $hTraySettings, $hTrayExit
Global $idTitle, $idPlayer, $idFileType, $idLength
Global $idVolUp, $idPlayPause, $idVolDown, $idPrev, $idNext, $idMute, $idMuteLabel
Global $sHotKey = "!{F1}"
Global $sSettingsHotKey = "^!y"
Global $bHotKeyRegistered = False
Global $bSettingsHotKeyRegistered = False
Global $hDarkBrush = 0
Global $hSettingsDlg = 0
Global $iCurrentVolume = 50
Global $bIsPlaying = True 
Global $bIsMuted = False 
Global $bStartupDone = False

; Button hotkey settings =============================================================================
Global $sVolUpHotkey = "{VOLUME_UP}"      
Global $sPlayPauseHotkey = "{MEDIA_PLAY_PAUSE}" 
Global $sVolDownHotkey = "{VOLUME_DOWN}"  
Global $sPrevHotkey = "{PGUP}"            
Global $sNextHotkey = "{PGDN}"            
Global $sMuteHotkey = "m"                 

; Behaviour settings =============================================================================
Global $bIgnoreFullscreen = True          
Global $iFadeDelay = 3              
Global $iFadeDuration = 500             

; Dark theme colors (BGR format for GDI) =============================================================================
Global Const $BGR_BAR_BG = 0x001E1E1E
Global Const $BGR_DARK_BG = 0x002D2D2D
Global Const $BGR_TEXT = 0x00DCDCDC
Global Const $BGR_ACCENT = 0x003D5A80

; Create tray menu =============================================================================
$hTraySettings = TrayCreateItem("Settings")
TrayItemSetOnEvent(-1, "ShowSettings")
$hTrayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitScript")
TraySetState(1)

LoadSettings()

RegisterHotKey()
HotKeySet($sSettingsHotKey, "ShowSettings")

CreateMainGUI()

$hDarkBrush = _WinAPI_CreateSolidBrush($BGR_DARK_BG)

$iCurrentVolume = 50

; Main loop =============================================================================
While 1
    Local $nMsg = GUIGetMsg()
    Switch $nMsg
        Case $GUI_EVENT_CLOSE
            ExitScript()
        Case $idVolUp, $idPlayPause, $idVolDown, $idPrev, $idNext, $idMute
            HandleButtonPress($nMsg)
    EndSwitch

    CheckForNewMedia()
    $bStartupDone = True

    Sleep(50)
WEnd

; Functions =============================================================================
Func CreateMainGUI()
    If IsHWnd($hMainGUI) Then GUIDelete($hMainGUI)

    Local $iX = ($iLastX = -1) ? (@DesktopWidth - 440) : $iLastX
    Local $iY = ($iLastY = -1) ? (@DesktopHeight - 160) : $iLastY

    Local $iButtonAreaW = 100   ; buttons column width
    Local $iTextAreaW = 340   ; text column width
    Local $iGUIW = $iTextAreaW + $iButtonAreaW

    ; Layout: top margin + title (3 lines) + 3 info rows + bottom margin
    Local $iLM        = 12   ; left margin
    Local $iTopM      = 8    ; top margin
    Local $iTitleH    = 60   ; height for 3 lines at 11pt Segoe UI
    Local $iRowH      = 22   ; height per info row
    Local $iRowGap    = 1    ; gap between rows
    Local $iGUIH = $iTopM + $iTitleH + ($iRowH + $iRowGap) * 3 + 8

    $hMainGUI = GUICreate("Media Info", $iGUIW, $iGUIH, $iX, $iY, _
        $WS_POPUP, BitOR($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST, $WS_EX_LAYERED))
    GUISetBkColor(0x1E1E1E)
    _SetCtrlColorMode($hMainGUI, True)

    Local $iLabelW = $iTextAreaW - $iLM - 4

    $idTitle = GUICtrlCreateLabel(" ", $iLM, $iTopM, $iLabelW, $iTitleH, $SS_LEFT)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor(-1, $iTitleColor)
    GUICtrlSetFont(-1, 11, $bBoldFont ? 800 : 400, 0, "Segoe UI")

    Local $iRow1Y = $iTopM + $iTitleH + $iRowGap
    Local $iRow2Y = $iRow1Y + $iRowH + $iRowGap
    Local $iRow3Y = $iRow2Y + $iRowH + $iRowGap

    ; Player name
    $idPlayer = GUICtrlCreateLabel(" ", $iLM, $iRow1Y, $iLabelW, $iRowH)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor(-1, $iPlayerColor)
    GUICtrlSetFont(-1, 10, $bBoldFont ? 800 : 400, 0, "Segoe UI")

    ; File type  •  VIDEO/AUDIO
    $idFileType = GUICtrlCreateLabel(" ", $iLM, $iRow2Y, $iLabelW, $iRowH)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor(-1, $iFileTypeColor)
    GUICtrlSetFont(-1, 10, $bBoldFont ? 800 : 400, 0, "Segoe UI")

    ; Date & Time row
    $idLength = GUICtrlCreateLabel(" ", $iLM, $iRow3Y, 182, $iRowH)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor(-1, $iLengthColor)
    GUICtrlSetFont(-1, 10, $bBoldFont ? 800 : 400, 0, "Segoe UI")

    Local $iMuteBtnW  = 18
    Local $iMuteBtnH  = 16
    
    Local $iMuteBtnX  = $iLM + 185
    Local $iMuteBtnY  = $iRow3Y + ($iRowH - $iMuteBtnH) / 2
    $idMute = GUICtrlCreateButton(" ", $iMuteBtnX, $iMuteBtnY, $iMuteBtnW, $iMuteBtnH)
    GUICtrlSetBkColor(-1, 0xAA2222)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 7, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Mute/Unmute  Send: " & $sMuteHotkey)

    ; MUTE label — white when off / blue when on
    Global $idMuteLabel
    $idMuteLabel = GUICtrlCreateLabel("MUTE", $iMuteBtnX + $iMuteBtnW + 4, $iRow3Y, 48, $iRowH, $SS_LEFT)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor(-1, 0xFFFFFF)     
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")

    ; ── Right column buttons ──────────────────────────────────────────────────
    Local $iBtnX    = $iTextAreaW
    Local $iBtnSz   = 28          
    Local $iColW    = $iButtonAreaW  ; 100 px
    Local $iSlotW   = $iColW / 3    ; 3 slots for transport row

    Local $iThird   = $iGUIH / 3
    Local $iCY1     = 0       + ($iThird - $iBtnSz) / 2   ; top 
    Local $iCY2     = $iThird + ($iThird - $iBtnSz) / 2   ; middle 
    Local $iCY3     = $iThird * 2 + ($iThird - $iBtnSz) / 2 ; bottom 

    ; Vol+ — top
    $idVolUp = GUICtrlCreateButton("+", $iBtnX + ($iColW - $iBtnSz) / 2, $iCY1, $iBtnSz, $iBtnSz)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetFont(-1, 14, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Volume Up  Send: " & $sVolUpHotkey)

    ; Transport row — middle, 3 equal slots
    $idPrev = GUICtrlCreateButton("|<", $iBtnX + 0 * $iSlotW + ($iSlotW - $iBtnSz) / 2, $iCY2, $iBtnSz, $iBtnSz)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetFont(-1, 10, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Previous  Send: " & $sPrevHotkey)

    $idPlayPause = GUICtrlCreateButton(">", $iBtnX + 1 * $iSlotW + ($iSlotW - $iBtnSz) / 2, $iCY2, $iBtnSz, $iBtnSz)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetFont(-1, 13, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Play/Pause  Send: " & $sPlayPauseHotkey)

    $idNext = GUICtrlCreateButton(">|", $iBtnX + 2 * $iSlotW + ($iSlotW - $iBtnSz) / 2, $iCY2, $iBtnSz, $iBtnSz)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetFont(-1, 10, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Next  Send: " & $sNextHotkey)

    ; Vol- — bottom
    $idVolDown = GUICtrlCreateButton("-", $iBtnX + ($iColW - $iBtnSz) / 2, $iCY3, $iBtnSz, $iBtnSz)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetFont(-1, 14, 800, 0, "Segoe UI")
    GUICtrlSetTip(-1, "Volume Down  Send: " & $sVolDownHotkey)

    GUIRegisterMsg($WM_NCHITTEST, "WM_NCHITTEST")
    GUISetState(@SW_HIDE, $hMainGUI)
EndFunc

; =============================================================================

Func WM_NCHITTEST($hWnd, $iMsg, $wParam, $lParam)
    #forceref $iMsg, $wParam, $lParam
    If $hWnd = $hMainGUI Then
        Return $HTCAPTION
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

Func CheckForNewMedia()
    Local $sPlayerProcess = ""
    Local $iPID = 0

    ; Check if the configured player is running
    If $sPlayerPath <> "" Then
        Local $sExeName = StringMid($sPlayerPath, StringInStr($sPlayerPath, "\", 0, -1) + 1)
        Local $aProcessList = ProcessList($sExeName)
        If $aProcessList[0][0] > 0 Then
            $sPlayerProcess = $sExeName
            $iPID = $aProcessList[1][1]
        EndIf
    EndIf

    If $sPlayerProcess = "" Then
        ; Player closed — reset state and hide flyout
        If $sCurrentMediaFile <> "" Or $sCurrentPlayerProcess <> "" Then
            $sCurrentMediaFile = ""
            $sCurrentPlayerProcess = ""
            $hTimer = 0
            AdlibUnRegister("HandleFadeOut")
            GUISetState(@SW_HIDE, $hMainGUI)
        EndIf
        Return
    EndIf

    $sCurrentPlayerProcess = $sPlayerProcess

    ; Get the player's window title
    Local $hPlayerWin = _GetMainWindowByPID($iPID)
    Local $sWindowTitle = _GetFreshWindowTitle($hPlayerWin)

    ; Extract media filename from window title
    Local $sMediaFile = _ExtractMediaFileFromTitle($sWindowTitle)

    ; Update clock row on every tick when flyout is visible
    If WinGetState($hMainGUI) > 0 And BitAND(WinGetState($hMainGUI), 2) Then ; visible
        Local $sDateTime = GetFormattedDateTime()
        GUICtrlSetData($idLength, $sDateTime)
    EndIf

    ; Nothing playing, or same song as before — no show needed
    If $sMediaFile = "" Or $sMediaFile = $sCurrentMediaFile Then Return

    ; New media detected — update info then show
    $sCurrentMediaFile = $sMediaFile
    UpdateMediaInfo($sMediaFile, $sPlayerProcess)

    If $bShowOnStart And $bStartupDone Then
        If $bIgnoreFullscreen And _IsFullscreenAppActive() Then Return
        GUISetState(@SW_SHOWNOACTIVATE, $hMainGUI)
        WinSetTrans($hMainGUI, "", 255)
        If Not $bIgnoreFullscreen Then _ForceTopmost($hMainGUI)
        $hTimer = TimerInit()
        $bMouseOver = False
        AdlibUnRegister("HandleFadeOut")
        AdlibRegister("HandleFadeOut", 50)
    EndIf
EndFunc

; Get the player window handle =============================================================================
Func _GetMainWindowByPID($iPID)
    Local $aWinList = WinList()
    Local $hFallback = 0
    Local $aExtensions = ["mp3", "mp4", "flac", "wav", "ogg", "m4a", "wma", "aac", "flv", "mkv", "avi", "mov", "m4v", "mpg", "mpeg", "wmv", "webm"]

    For $i = 1 To $aWinList[0][0]
        If WinGetProcess($aWinList[$i][1]) = $iPID And $aWinList[$i][0] <> "" Then
            ; Prefer the window that has a known media extension in its title
            Local $sT = $aWinList[$i][0]
            For $sExt In $aExtensions
                If StringInStr($sT, "." & $sExt) Then
                    Return $aWinList[$i][1]   ; Found the right one
                EndIf
            Next
            If $hFallback = 0 Then $hFallback = $aWinList[$i][1]
        EndIf
    Next
    Return $hFallback
EndFunc

; Read a window's title fresh from its message =============================================================================
Func _GetFreshWindowTitle($hWnd)
    If $hWnd = 0 Then Return ""
    ; SendMessage WM_GETTEXT
    Local $iLen = _SendMessage($hWnd, 0x000E, 0, 0) ; WM_GETTEXTLENGTH
    If $iLen <= 0 Then Return ""
    Local $tBuf = DllStructCreate("wchar[" & ($iLen + 2) & "]")
    DllCall("user32.dll", "int", "SendMessageW", "hwnd", $hWnd, "uint", 0x000D, _
            "wparam", $iLen + 1, "struct*", $tBuf)  ; WM_GETTEXT
    Return DllStructGetData($tBuf, 1)
EndFunc

; Extract media filename from a player window title string =============================================================================
Func _ExtractMediaFileFromTitle($sWindowTitle)
    If $sWindowTitle = "" Then Return ""
    Local $aExtensions = ["mp3", "mp4", "flac", "wav", "ogg", "m4a", "wma", "aac", "flv", "mkv", "avi", "mov", "m4v", "mpg", "mpeg", "wmv", "webm"]
    For $sExt In $aExtensions
        Local $iPos = StringInStr($sWindowTitle, "." & $sExt, 0)
        If $iPos > 0 Then
            Local $iStart = $iPos
            While $iStart > 1
                Local $sChar = StringMid($sWindowTitle, $iStart - 1, 1)
                If $sChar = "\" Or $sChar = "/" Or $sChar = "|" Then ExitLoop
                $iStart -= 1
            WEnd
            Local $iEnd = $iPos + StringLen($sExt)
            Return StringStripWS(StringMid($sWindowTitle, $iStart, $iEnd - $iStart + 1), 3)
        EndIf
    Next
    Return ""
EndFunc

; =============================================================================

Func UpdateMediaInfo($sMediaFile, $sPlayerProcess)
    Local $sPlayerName = ($sCustomPlayerName <> "") ? $sCustomPlayerName : StringReplace($sPlayerProcess, ".exe", "")

    ; --- Extract display title (filename without extension) ---
    Local $sFileName = StringRegExpReplace($sMediaFile, "\.[^.]*$", "")

    ; --- Extract file type from extension ---
    Local $sFileType = ""
    Local $iDot = StringInStr($sMediaFile, ".", 0, -1)
    If $iDot > 0 Then $sFileType = StringUpper(StringMid($sMediaFile, $iDot + 1))
    
    ; --- Determine if VIDEO or AUDIO based on extension ---
    Local $sMediaType = "AUDIO"
    Local $aVideoExts = ["mp4", "mkv", "avi", "mov", "m4v", "flv", "wmv", "webm", "mpg", "mpeg", "ts", "m2ts"]
    For $sExt In $aVideoExts
        If StringLower($sFileType) = $sExt Then
            $sMediaType = "VIDEO"
            ExitLoop
        EndIf
    Next

    ; Get current date and time
    Local $sDateTime = GetFormattedDateTime()

    ; Apply uppercase if enabled
    If $bUpperCase Then
        $sFileName   = StringUpper($sFileName)
        $sPlayerName = StringUpper($sPlayerName)
        $sFileType   = StringUpper($sFileType)
        $sMediaType  = StringUpper($sMediaType)
    EndIf

    ; Update all labels
    GUICtrlSetData($idTitle,    $sFileName)
    GUICtrlSetData($idPlayer,   $sPlayerName)
    GUICtrlSetData($idFileType, $sFileType & "  •  " & $sMediaType)
    GUICtrlSetData($idLength,   $sDateTime)

    ; Force immediate repaint
    DllCall("user32.dll", "bool", "InvalidateRect", "hwnd", $hMainGUI, "ptr", 0, "bool", True)
    DllCall("user32.dll", "bool", "UpdateWindow",   "hwnd", $hMainGUI)
EndFunc

; Get formatted date/time like "Wed 11 Mar 20:53 PM" =============================================================================
Func GetFormattedDateTime()
    ; @WDAY: 1=Sun,2=Mon,3=Tue,4=Wed,5=Thu,6=Fri,7=Sat
    Local $aDayNames[8] = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    Local $aMonNames[13] = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    Local $sDay   = $aDayNames[@WDAY]
    Local $sMonth = $aMonNames[Int(@MON)]
    Local $iHour  = Int(@HOUR)
    Local $sAMPM  = "AM"

    If $iHour >= 12 Then
        $sAMPM = "PM"
        If $iHour > 12 Then $iHour -= 12
    ElseIf $iHour = 0 Then
        $iHour = 12
    EndIf

    Local $sHourStr = ($iHour < 10) ? "0" & $iHour : $iHour
    Local $sMinStr  = @MIN

    Return $sDay & " " & @MDAY & " " & $sMonth & " " & $sHourStr & ":" & $sMinStr & " " & $sAMPM
EndFunc

; =============================================================================

Func HandleButtonPress($iButton)
    ; Find the player window using the shared helper
    Local $hPlayerWin = 0
    If $sCurrentPlayerProcess <> "" Then
        Local $aPID = ProcessList($sCurrentPlayerProcess)
        If $aPID[0][0] > 0 Then
            $hPlayerWin = _GetMainWindowByPID($aPID[1][1])
        EndIf
    EndIf
	
    ; Helper
    Local $sSendHelper_Key = ""

    Switch $iButton
        Case $idVolUp
            $sSendHelper_Key = $sVolUpHotkey

        Case $idVolDown
            $sSendHelper_Key = $sVolDownHotkey

        Case $idPlayPause
            $sSendHelper_Key = $sPlayPauseHotkey
            $bIsPlaying = Not $bIsPlaying
            GUICtrlSetData($idPlayPause, $bIsPlaying ? ">" : "||")

        Case $idPrev
            $sSendHelper_Key = $sPrevHotkey

        Case $idNext
            $sSendHelper_Key = $sNextHotkey

        Case $idMute
            $sSendHelper_Key = $sMuteHotkey
            $bIsMuted = Not $bIsMuted
            If $bIsMuted Then
                GUICtrlSetBkColor($idMute, 0x224488)      ; blue button when muted
                GUICtrlSetData($idMuteLabel, "MUTED")
                GUICtrlSetColor($idMuteLabel, 0x4499FF)   ; blue text when muted
            Else
                GUICtrlSetBkColor($idMute, 0xAA2222)      ; red button when not muted
                GUICtrlSetData($idMuteLabel, "MUTE")
                GUICtrlSetColor($idMuteLabel, 0xFFFFFF)   ; white text when not muted
            EndIf
    EndSwitch

    If $sSendHelper_Key <> "" And $hPlayerWin Then
        ; Activate the player, send the key, then restore flyout on top
        WinActivate($hPlayerWin)
        WinWaitActive($hPlayerWin, "", 2)
        Send($sSendHelper_Key)
        ; Bring flyout back to top without stealing focus from player
        WinSetOnTop($hMainGUI, "", 1)
    ElseIf $sSendHelper_Key <> "" Then
        Send($sSendHelper_Key)
    EndIf

    ; Reset fade timer so flyout stays visible after button press
    $hTimer = TimerInit()
    $bMouseOver = False
    AdlibUnRegister("HandleFadeOut")
    AdlibRegister("HandleFadeOut", 50)
EndFunc

; =============================================================================

Func HandleFadeOut()
    ; Called every 50ms by AdlibRegister
    If $hTimer = 0 Then
        AdlibUnRegister("HandleFadeOut")
        Return
    EndIf

    ; --- Fullscreen check ---
    If $bIgnoreFullscreen And _IsFullscreenAppActive() Then
        ; Hide immediately while a fullscreen app has focus, resume timer when gone
        GUISetState(@SW_HIDE, $hMainGUI)
        Return
    EndIf

    ; Make sure flyout is visible
    If Not BitAND(WinGetState($hMainGUI), 2) Then
        If $bIgnoreFullscreen And _IsFullscreenAppActive() Then Return
        GUISetState(@SW_SHOWNOACTIVATE, $hMainGUI)
        WinSetTrans($hMainGUI, "", 255)
    EndIf

    ; When fullscreen-ignore is OFF
    If Not $bIgnoreFullscreen Then _ForceTopmost($hMainGUI)

    Local $aMousePos = MouseGetPos()
    Local $aWinPos = WinGetPos($hMainGUI)

    If Not IsArray($aWinPos) Then Return

    Local $bMouseOverWindow = ($aMousePos[0] >= $aWinPos[0] And $aMousePos[0] <= $aWinPos[0] + $aWinPos[2] And _
                               $aMousePos[1] >= $aWinPos[1] And $aMousePos[1] <= $aWinPos[1] + $aWinPos[3])

    If $bMouseOverWindow Then
        If Not $bMouseOver Then
            $bMouseOver = True
            WinSetTrans($hMainGUI, "", 255)
            $hTimer = TimerInit() 
        EndIf
        Return
    Else
        If $bMouseOver Then
            $bMouseOver = False
            $hTimer = TimerInit()
        EndIf

        Local $iElapsed = TimerDiff($hTimer)

        If $iElapsed < $iFadeTime * 1000 Then
            ; --- DELAY phase: stay fully visible until the delay expires ---
            WinSetTrans($hMainGUI, "", 255)
        Else
            ; --- FADE phase: quick fade over $iFadeDuration ms after the delay ---
            Local $iFadeElapsed = $iElapsed - ($iFadeTime * 1000)
            If $iFadeElapsed < $iFadeDuration Then
                Local $iAlpha = Int(255 - (255 * ($iFadeElapsed / $iFadeDuration)))
                If $iAlpha < 0 Then $iAlpha = 0
                WinSetTrans($hMainGUI, "", $iAlpha)
            Else
                GUISetState(@SW_HIDE, $hMainGUI)
                WinSetTrans($hMainGUI, "", 255)
                $hTimer = 0
                $bMouseOver = False
                AdlibUnRegister("HandleFadeOut")
            EndIf
        EndIf
    EndIf
EndFunc

; =============================================================================

Func _IsFullscreenAppActive()
    Local $hFG = _WinAPI_GetForegroundWindow()
    If $hFG = 0 Or $hFG = $hMainGUI Then Return False

    ; Get screen dimensions and foreground window rect
    Local $tRect = DllStructCreate("int;int;int;int")
    DllCall("user32.dll", "bool", "GetWindowRect", "hwnd", $hFG, "struct*", $tRect)
    Local $iW = DllStructGetData($tRect, 3) - DllStructGetData($tRect, 1)
    Local $iH = DllStructGetData($tRect, 4) - DllStructGetData($tRect, 2)

    ; A window covering the full primary monitor is considered fullscreen
    If $iW >= @DesktopWidth And $iH >= @DesktopHeight Then
        ; Exclude the desktop / shell windows (class = "Progman", "WorkerW")
        Local $sClass = _WinAPI_GetClassName($hFG)
        If $sClass = "Progman" Or $sClass = "WorkerW" Or $sClass = "Shell_TrayWnd" Then Return False
        Return True
    EndIf
    Return False
EndFunc

; Force a window above all others including fullscreen apps (HWND_TOPMOST + SWP_NOSIZE/NOMOVE)
Func _ForceTopmost($hWnd)
    ; HWND_TOPMOST = -1, SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE = 0x0013
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hWnd, "hwnd", -1, _
            "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
EndFunc

; DARK MODE =============================================================================

; Dark mode settings dialog with button hotkey configuration
Func ShowSettings()
    If IsHWnd($hSettingsGUI) Then
        WinActivate($hSettingsGUI)
        Return
    EndIf
    
    ; GUI with dark theme
    $hSettingsGUI = GUICreate("Media Info Settings", 720, 855, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU))
    
    _SetCtrlColorMode($hSettingsGUI, True)
 
    Local $tDarkVal = DllStructCreate("int")
    DllStructSetData($tDarkVal, 1, 1)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hSettingsGUI, _
        "dword", 20, "struct*", $tDarkVal, "dword", 4)
    
    GUISetBkColor(0x1E1E1E)
    
    Local Const $WM_CTLCOLOREDIT = 0x0133
    Local Const $WM_CTLCOLORSTATIC = 0x0138
    Local Const $WM_CTLCOLORBTN = 0x0135
    GUIRegisterMsg($WM_CTLCOLOREDIT,   "WM_CTLCOLOR_Edit")
    GUIRegisterMsg($WM_CTLCOLORSTATIC, "WM_CTLCOLOR_Static")
    GUIRegisterMsg($WM_CTLCOLORBTN,    "WM_CTLCOLOR_Btn")
    
    ; Left margin and spacing
    Local $iLeft = 25
    Local $iTop = 30
    Local $iRowHeight = 35
    Local $iLabelWidth = 150
    Local $iInputWidth = 350
    Local $iButtonWidth = 80
    
    ; Player path
    GUICtrlCreateLabel("Player Path:", $iLeft, $iTop, $iLabelWidth, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idPlayerPath = GUICtrlCreateInput($sPlayerPath, $iLeft, $iTop + 25, $iInputWidth, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    Local $idBrowsePlayer = GUICtrlCreateButton("Browse", $iLeft + $iInputWidth + 10, $iTop + 25, $iButtonWidth, 25)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    _SetCtrlColorMode(GUICtrlGetHandle($idBrowsePlayer), True)
    
    ; Custom player name
    $iTop += $iRowHeight + 25
    GUICtrlCreateLabel("Custom Player Name:", $iLeft, $iTop, $iLabelWidth, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlCreateLabel("(Leave empty to use EXE name)", $iLeft + $iLabelWidth + 10, $iTop, 200, 20)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idCustomPlayerName = GUICtrlCreateInput($sCustomPlayerName, $iLeft, $iTop + 25, $iInputWidth, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    ; Hotkeys section
    $iTop += $iRowHeight + 25
    GUICtrlCreateLabel("GLOBAL HOTKEYS", $iLeft, $iTop, 200, 25)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetFont(-1, 11, 800)
    
    $iTop += 25
    GUICtrlCreateLabel("Show Info Hotkey:", $iLeft, $iTop, $iLabelWidth, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idHotkey = GUICtrlCreateInput(HotKeyToString($sHotKey), $iLeft, $iTop + 25, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Settings Hotkey:", $iLeft + 200, $iTop, $iLabelWidth - 50, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idSettingsHotkey = GUICtrlCreateInput(HotKeyToString($sSettingsHotKey), $iLeft + 200, $iTop + 25, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Format:  Ctrl+  Alt+  Shift+  Win+  then key (e.g. Ctrl+Alt+F1)", $iLeft, $iTop + 55, 500, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    ; Button Hotkeys section
    $iTop += $iRowHeight + 35
    GUICtrlCreateLabel("BUTTON HOTKEYS (What to send when clicked)", $iLeft, $iTop, 400, 25)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetFont(-1, 11, 800)
    
    $iTop += 30
    GUICtrlCreateLabel("Volume Up:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idVolUpHotkey = GUICtrlCreateInput($sVolUpHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("AutoIt Send() key syntax  e.g. {VOLUME_UP}  {SPACE}  ^p  +{F9}", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    $iTop += 35
    GUICtrlCreateLabel("Play/Pause:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idPlayPauseHotkey = GUICtrlCreateInput($sPlayPauseHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Modifiers:  ^ = Ctrl   ! = Alt   + = Shift   # = Win", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    $iTop += 35
    GUICtrlCreateLabel("Volume Down:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idVolDownHotkey = GUICtrlCreateInput($sVolDownHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Special keys in braces:  {F1}  {UP}  {VOLUME_DOWN}  {MEDIA_PLAY_PAUSE}", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iTop += 35
    GUICtrlCreateLabel("Previous:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idPrevHotkey = GUICtrlCreateInput($sPrevHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)

    GUICtrlCreateLabel("Default: {PGUP}  (sent to player when Prev button clicked)", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iTop += 35
    GUICtrlCreateLabel("Next:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idNextHotkey = GUICtrlCreateInput($sNextHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)

    GUICtrlCreateLabel("Default: {PGDN}  (sent to player when Next button clicked)", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iTop += 35
    GUICtrlCreateLabel("Mute/Unmute:", $iLeft, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    Local $idMuteHotkey = GUICtrlCreateInput($sMuteHotkey, $iLeft + 90, $iTop - 3, 150, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)

    GUICtrlCreateLabel("Default: m  (sent to player when red mute button clicked)", $iLeft + 250, $iTop, 420, 18)
    GUICtrlSetColor(-1, 0x888888)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    ; Checkboxes
    $iTop += 45
    Local $idRememberPos = GUICtrlCreateCheckbox("", $iLeft, $iTop, 18, 18)
    If $bRememberPos Then GUICtrlSetState($idRememberPos, $GUI_CHECKED)
    GUICtrlCreateLabel("Remember Last Position (Draggable)", $iLeft + 22, $iTop + 1, 250, 18)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    $iTop += $iRowHeight
    Local $idBoldFont = GUICtrlCreateCheckbox("", $iLeft, $iTop, 18, 18)
    If $bBoldFont Then GUICtrlSetState($idBoldFont, $GUI_CHECKED)
    GUICtrlCreateLabel("Bold Font", $iLeft + 22, $iTop + 1, 120, 18)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idUpperCase = GUICtrlCreateCheckbox("", $iLeft + 200, $iTop, 18, 18)
    If $bUpperCase Then GUICtrlSetState($idUpperCase, $GUI_CHECKED)
    GUICtrlCreateLabel("Upper Case Font", $iLeft + 222, $iTop + 1, 150, 18)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    $iTop += $iRowHeight
    Local $idShowOnStart = GUICtrlCreateCheckbox("", $iLeft, $iTop, 18, 18)
    If $bShowOnStart Then GUICtrlSetState($idShowOnStart, $GUI_CHECKED)
    GUICtrlCreateLabel("Show flyout when player starts a song", $iLeft + 22, $iTop + 1, 250, 18)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)

    $iTop += $iRowHeight
    Local $idIgnoreFullscreen = GUICtrlCreateCheckbox("", $iLeft, $iTop, 18, 18)
    If $bIgnoreFullscreen Then GUICtrlSetState($idIgnoreFullscreen, $GUI_CHECKED)
    GUICtrlCreateLabel("Hide flyout when a fullscreen app is active", $iLeft + 22, $iTop + 1, 300, 18)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    ; Fade time
    $iTop += $iRowHeight + 10
    GUICtrlCreateLabel("Stay visible for:", $iLeft, $iTop, 110, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idFadeTime = GUICtrlCreateInput($iFadeTime, $iLeft + 110, $iTop, 50, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("seconds, then fade out quickly", $iLeft + 170, $iTop + 3, 250, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    
    ; Colors section
    $iTop += $iRowHeight + 15
    GUICtrlCreateLabel("COLORS (Hex)", $iLeft, $iTop, 200, 25)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetFont(-1, 11, 800)
    
    ; Color grid
    $iTop += 30
    GUICtrlCreateLabel("Title:", $iLeft, $iTop, 60, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    Local $idTitleColor = GUICtrlCreateInput(Hex($iTitleColor, 6), $iLeft + 70, $iTop - 3, 80, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Player:", $iLeft + 180, $iTop, 60, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    Local $idPlayerColor = GUICtrlCreateInput(Hex($iPlayerColor, 6), $iLeft + 250, $iTop - 3, 80, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    $iTop += 35
    GUICtrlCreateLabel("File Info:", $iLeft, $iTop, 60, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    Local $idFileTypeColor = GUICtrlCreateInput(Hex($iFileTypeColor, 6), $iLeft + 70, $iTop - 3, 80, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    GUICtrlCreateLabel("Date/Volume:", $iLeft + 180, $iTop, 80, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, $GUI_BKCOLOR_TRANSPARENT)
    Local $idLengthColor = GUICtrlCreateInput(Hex($iLengthColor, 6), $iLeft + 270, $iTop - 3, 80, 25)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    GUICtrlSetColor(-1, 0xDCDCDC)
    
    ; Buttons
    Local $iBtnY = 805
    Local $idSave = GUICtrlCreateButton("SAVE", 250, $iBtnY, 100, 35)
    GUICtrlSetBkColor(-1, 0x3D5A80)
    GUICtrlSetColor(-1, 0xFFFFFF)
    _SetCtrlColorMode(GUICtrlGetHandle($idSave), True)
    
    Local $idCancel = GUICtrlCreateButton("CANCEL", 370, $iBtnY, 100, 35)
    GUICtrlSetBkColor(-1, 0x3A3A3A)
    GUICtrlSetColor(-1, 0xDCDCDC)
    _SetCtrlColorMode(GUICtrlGetHandle($idCancel), True)
    
    GUISetState(@SW_SHOW, $hSettingsGUI)
    
    ; Message loop
    While 1
        Local $nMsg = GUIGetMsg()
        
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $idCancel
                GUIDelete($hSettingsGUI)
                ExitLoop
                
            Case $idBrowsePlayer
                Local $sFile = FileOpenDialog("Select Player", @ProgramFilesDir, "Executables (*.exe)", 1)
                If Not @error Then GUICtrlSetData($idPlayerPath, $sFile)
                
            Case $idSave
                ; Save all settings
                $sPlayerPath = GUICtrlRead($idPlayerPath)
                $sCustomPlayerName = GUICtrlRead($idCustomPlayerName)
                $bRememberPos = GUICtrlRead($idRememberPos) = $GUI_CHECKED
                $bBoldFont = GUICtrlRead($idBoldFont) = $GUI_CHECKED
                $bUpperCase = GUICtrlRead($idUpperCase) = $GUI_CHECKED
                $bShowOnStart = GUICtrlRead($idShowOnStart) = $GUI_CHECKED
                $bIgnoreFullscreen = GUICtrlRead($idIgnoreFullscreen) = $GUI_CHECKED
                $iFadeTime = Int(GUICtrlRead($idFadeTime))
                If $iFadeTime < 1 Then $iFadeTime = 2
                
                ; Save colors
                $iTitleColor = Dec(StringStripWS(GUICtrlRead($idTitleColor), 8))
                $iPlayerColor = Dec(StringStripWS(GUICtrlRead($idPlayerColor), 8))
                $iFileTypeColor = Dec(StringStripWS(GUICtrlRead($idFileTypeColor), 8))
                $iLengthColor = Dec(StringStripWS(GUICtrlRead($idLengthColor), 8))
                
                ; Save global hotkeys
                Local $sNewHotKey = GUICtrlRead($idHotkey)
                If $sNewHotKey <> "" Then
                    $sHotKey = StringToHotKey($sNewHotKey)
                EndIf
                
                Local $sNewSettingsHotKey = GUICtrlRead($idSettingsHotkey)
                If $sNewSettingsHotKey <> "" Then
                    $sSettingsHotKey = StringToHotKey($sNewSettingsHotKey)
                EndIf
                
                ; Save button hotkeys
                $sVolUpHotkey = GUICtrlRead($idVolUpHotkey)
                $sPlayPauseHotkey = GUICtrlRead($idPlayPauseHotkey)
                $sVolDownHotkey = GUICtrlRead($idVolDownHotkey)
                $sPrevHotkey = GUICtrlRead($idPrevHotkey)
                $sNextHotkey = GUICtrlRead($idNextHotkey)
                $sMuteHotkey = GUICtrlRead($idMuteHotkey)
                
                ; Save position if enabled
                If $bRememberPos Then
                    Local $aPos = WinGetPos($hMainGUI)
                    If Not @error And IsArray($aPos) Then
                        $iLastX = $aPos[0]
                        $iLastY = $aPos[1]
                    EndIf
                EndIf
                
                SaveSettings()
                RegisterHotKey()
                CreateMainGUI()
                $bStartupDone = True
                
                GUIDelete($hSettingsGUI)
                ExitLoop
        EndSwitch
    WEnd
    
    ; Unregister message handlers
    GUIRegisterMsg($WM_CTLCOLOREDIT,   "")
    GUIRegisterMsg($WM_CTLCOLORSTATIC, "")
    GUIRegisterMsg($WM_CTLCOLORBTN,    "")
EndFunc

; =============================================================================

; Dark mode handler for EDIT controls (input boxes)
Func WM_CTLCOLOR_Edit($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $lParam
    If $hDarkBrush = 0 Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", 0x00DCDCDC)
    DllCall("gdi32.dll", "int", "SetBkColor",   "handle", $wParam, "dword", 0x002D2D2D)
    Return $hDarkBrush
EndFunc

; Dark mode handler for STATIC/LABEL controls — background must match window BkColor
Func WM_CTLCOLOR_Static($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $lParam
    If $hDarkBrush = 0 Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", 0x00DCDCDC)
    DllCall("gdi32.dll", "int", "SetBkColor",   "handle", $wParam, "dword", 0x001E1E1E)
    ; Return a brush matching the window background so checkboxes don't show white
    Local Static $hStaticBrush = 0
    If $hStaticBrush = 0 Then $hStaticBrush = _WinAPI_CreateSolidBrush(0x001E1E1E)
    Return $hStaticBrush
EndFunc

; Dark mode handler for BUTTON controls
Func WM_CTLCOLOR_Btn($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $lParam
    If $hDarkBrush = 0 Then Return $GUI_RUNDEFMSG
    DllCall("gdi32.dll", "int", "SetTextColor", "handle", $wParam, "dword", 0x00DCDCDC)
    DllCall("gdi32.dll", "int", "SetBkColor",   "handle", $wParam, "dword", 0x002D2D2D)
    Return $hDarkBrush
EndFunc

; Dark mode functions
Func _SetCtrlColorMode($hWnd, $bDarkMode = True, $sName = Default)
    If $sName = Default Then $sName = $bDarkMode ? 'DarkMode_Explorer' : 'Explorer'
    $bDarkMode = Not Not $bDarkMode
    If Not IsHWnd($hWnd) And $hWnd <> 0 Then $hWnd = GUICtrlGetHandle($hWnd)
    Local Enum $eDefault, $eAllowDark, $eForceDark, $eForceLight, $eMax
    If $hWnd <> 0 Then DllCall('uxtheme.dll', 'bool', 133, 'hwnd', $hWnd, 'bool', $bDarkMode)
    DllCall('uxtheme.dll', 'int', 135, 'int', ($bDarkMode ? $eForceDark : $eForceLight))
    If $hWnd <> 0 Then _WinAPI_SetWindowTheme_unr($hWnd, $sName)
    DllCall('uxtheme.dll', 'none', 104)
    If $hWnd <> 0 Then _SendMessage($hWnd, $WM_THEMECHANGED, 0, 0)
EndFunc

Func _WinAPI_SetWindowTheme_unr($hWnd, $sName = Null, $sList = Null)
    Local $sResult = DllCall('UxTheme.dll', 'long', 'SetWindowTheme', 'hwnd', $hWnd, 'wstr', $sName, 'wstr', $sList)
    If @error Then Return SetError(@error, @extended, 0)
    If $sResult[0] Then Return SetError(10, $sResult[0], 0)
    Return 1
EndFunc

; =============================================================================

Func LoadSettings()
    Local $sIniFile = @ScriptDir & "\MediaInfo.ini"
    If Not FileExists($sIniFile) Then Return
    
    $sPlayerPath = IniRead($sIniFile, "Settings", "PlayerPath", $sPlayerPath)
    $sCustomPlayerName = IniRead($sIniFile, "Settings", "CustomPlayerName", "")
    $bRememberPos = IniRead($sIniFile, "Settings", "RememberPos", "0") = "1"
    $bBoldFont = IniRead($sIniFile, "Settings", "BoldFont", "0") = "1"
    $bUpperCase = IniRead($sIniFile, "Settings", "UpperCase", "0") = "1"
    $bShowOnStart = IniRead($sIniFile, "Settings", "ShowOnStart", "1") = "1"
    $iFadeTime = Int(IniRead($sIniFile, "Settings", "FadeTime", "2"))
    $sHotKey = IniRead($sIniFile, "Settings", "HotKey", "!{F1}")
    $sSettingsHotKey = IniRead($sIniFile, "Settings", "SettingsHotKey", "^!y")
    
    ; Load button hotkeys
    $sVolUpHotkey = IniRead($sIniFile, "ButtonHotkeys", "VolumeUp", "{VOLUME_UP}")
    $sPlayPauseHotkey = IniRead($sIniFile, "ButtonHotkeys", "PlayPause", "{MEDIA_PLAY_PAUSE}")
    $sVolDownHotkey = IniRead($sIniFile, "ButtonHotkeys", "VolumeDown", "{VOLUME_DOWN}")
    $sPrevHotkey = IniRead($sIniFile, "ButtonHotkeys", "Prev", "{PGUP}")
    $sNextHotkey = IniRead($sIniFile, "ButtonHotkeys", "Next", "{PGDN}")
    $sMuteHotkey = IniRead($sIniFile, "ButtonHotkeys", "Mute", "m")

    $bIgnoreFullscreen = IniRead($sIniFile, "Settings", "IgnoreFullscreen", "1") = "1"
    
    $iTitleColor = Dec(IniRead($sIniFile, "Colors", "Title", "FFFFFF"))
    $iPlayerColor = Dec(IniRead($sIniFile, "Colors", "Player", "CCCCCC"))
    $iFileTypeColor = Dec(IniRead($sIniFile, "Colors", "FileType", "AAAAAA"))
    $iLengthColor = Dec(IniRead($sIniFile, "Colors", "Length", "CCCCCC"))
    $iLastX = Int(IniRead($sIniFile, "Position", "X", "-1"))
    $iLastY = Int(IniRead($sIniFile, "Position", "Y", "-1"))
EndFunc

Func SaveSettings()
    Local $sIniFile = @ScriptDir & "\MediaInfo.ini"
    
    IniWrite($sIniFile, "Settings", "PlayerPath", $sPlayerPath)
    IniWrite($sIniFile, "Settings", "CustomPlayerName", $sCustomPlayerName)
    IniWrite($sIniFile, "Settings", "RememberPos", $bRememberPos ? "1" : "0")
    IniWrite($sIniFile, "Settings", "BoldFont", $bBoldFont ? "1" : "0")
    IniWrite($sIniFile, "Settings", "UpperCase", $bUpperCase ? "1" : "0")
    IniWrite($sIniFile, "Settings", "ShowOnStart", $bShowOnStart ? "1" : "0")
    IniWrite($sIniFile, "Settings", "FadeTime", $iFadeTime)
    IniWrite($sIniFile, "Settings", "HotKey", $sHotKey)
    IniWrite($sIniFile, "Settings", "SettingsHotKey", $sSettingsHotKey)
    
    ; Save button hotkeys
    IniWrite($sIniFile, "ButtonHotkeys", "VolumeUp", $sVolUpHotkey)
    IniWrite($sIniFile, "ButtonHotkeys", "PlayPause", $sPlayPauseHotkey)
    IniWrite($sIniFile, "ButtonHotkeys", "VolumeDown", $sVolDownHotkey)
    IniWrite($sIniFile, "ButtonHotkeys", "Prev", $sPrevHotkey)
    IniWrite($sIniFile, "ButtonHotkeys", "Next", $sNextHotkey)
    IniWrite($sIniFile, "ButtonHotkeys", "Mute", $sMuteHotkey)

    IniWrite($sIniFile, "Settings", "IgnoreFullscreen", $bIgnoreFullscreen ? "1" : "0")
    
    IniWrite($sIniFile, "Colors", "Title", Hex($iTitleColor, 6))
    IniWrite($sIniFile, "Colors", "Player", Hex($iPlayerColor, 6))
    IniWrite($sIniFile, "Colors", "FileType", Hex($iFileTypeColor, 6))
    IniWrite($sIniFile, "Colors", "Length", Hex($iLengthColor, 6))
    
    If $bRememberPos Then
        Local $aPos = WinGetPos($hMainGUI)
        If Not @error And IsArray($aPos) Then
            IniWrite($sIniFile, "Position", "X", $aPos[0])
            IniWrite($sIniFile, "Position", "Y", $aPos[1])
        EndIf
    EndIf
EndFunc

; =============================================================================

Func RegisterHotKey()
    ; Unregister previous hotkeys
    If $bHotKeyRegistered Then
        HotKeySet($sHotKey)
        $bHotKeyRegistered = False
    EndIf
    If $bSettingsHotKeyRegistered Then
        HotKeySet($sSettingsHotKey)
        $bSettingsHotKeyRegistered = False
    EndIf
    
    ; Register new hotkeys
    If $sHotKey <> "" Then
        HotKeySet($sHotKey, "ShowInfoFlyout")
        $bHotKeyRegistered = True
    EndIf
    If $sSettingsHotKey <> "" Then
        HotKeySet($sSettingsHotKey, "ShowSettings")
        $bSettingsHotKeyRegistered = True
    EndIf
EndFunc

Func ShowInfoFlyout()
    ; Toggle: if already visible, hide it
    If BitAND(WinGetState($hMainGUI), 2) Then
        AdlibUnRegister("HandleFadeOut")
        GUISetState(@SW_HIDE, $hMainGUI)
        $hTimer = 0
        $bMouseOver = False
        Return
    EndIf

    ; Show flyout if we have media info OR if the player is at least running
    Local $bPlayerRunning = False
    If $sCurrentPlayerProcess <> "" Then
        Local $aPID = ProcessList($sCurrentPlayerProcess)
        If $aPID[0][0] > 0 Then $bPlayerRunning = True
    EndIf

    If $sCurrentMediaFile <> "" Or $bPlayerRunning Then
        ; If fullscreen hiding is enabled and a fullscreen app is active, don't show
        If $bIgnoreFullscreen And _IsFullscreenAppActive() Then Return

        ; Force-refresh the display immediately (title may have changed since last poll)
        If $sCurrentMediaFile <> "" Then
            UpdateMediaInfo($sCurrentMediaFile, $sCurrentPlayerProcess)
        EndIf
        GUISetState(@SW_SHOWNOACTIVATE, $hMainGUI)
        WinSetTrans($hMainGUI, "", 255)
        ; When fullscreen-ignore is OFF, force the flyout above fullscreen apps via SetWindowPos
        If Not $bIgnoreFullscreen Then _ForceTopmost($hMainGUI)
        $hTimer = TimerInit()
        $bMouseOver = False
        AdlibUnRegister("HandleFadeOut")
        AdlibRegister("HandleFadeOut", 50)
    EndIf
EndFunc

Func HotKeyToString($sHotKey)
    Local $sResult = ""
    If StringInStr($sHotKey, "^") Then $sResult &= "Ctrl+"
    If StringInStr($sHotKey, "!") Then $sResult &= "Alt+"
    If StringInStr($sHotKey, "+") Then $sResult &= "Shift+"
    If StringInStr($sHotKey, "#") Then $sResult &= "Win+"
    
    Local $sKey = StringRegExpReplace($sHotKey, "[!+^#]", "")
    $sKey = StringReplace($sKey, "{", "")
    $sKey = StringReplace($sKey, "}", "")
    $sResult &= $sKey
    
    Return $sResult
EndFunc

Func StringToHotKey($sReadable)
    Local $sResult = ""
    
    If StringInStr($sReadable, "Ctrl+") Then $sResult &= "^"
    If StringInStr($sReadable, "Alt+") Then $sResult &= "!"
    If StringInStr($sReadable, "Shift+") Then $sResult &= "+"
    If StringInStr($sReadable, "Win+") Then $sResult &= "#"
    
    Local $aParts = StringSplit($sReadable, "+")
    Local $sKey = $aParts[$aParts[0]]
    
    Switch StringUpper($sKey)
        Case "F1" To "F12"
            $sResult &= "{" & $sKey & "}"
        Case "UP", "DOWN", "LEFT", "RIGHT", "HOME", "END", "PGUP", "PGDN", "INSERT", "DELETE"
            $sResult &= "{" & $sKey & "}"
        Case Else
            $sResult &= $sKey
    EndSwitch
    
    Return $sResult
EndFunc

; =============================================================================
; Convert a simple AutoIt Send() key string to a Windows Virtual Key code
; Supports: {SPACE} {ENTER} {F1}-{F12} {UP} {DOWN} {LEFT} {RIGHT} {HOME} {END}
;           {PGUP} {PGDN} {DELETE} {INSERT} {ESC} {TAB} and single letter/number keys
;           {VOLUME_UP} {VOLUME_DOWN} {VOLUME_MUTE} {MEDIA_PLAY_PAUSE}
;           {MEDIA_NEXT} {MEDIA_PREV} {MEDIA_STOP} {BROWSER_*} {LAUNCH_*}
; Returns 0 if not mappable (caller should fallback)
; =============================================================================

Func _HotkeyStringToVK($sKey)
    ; Strip modifiers — we only care about the base key
    Local $sBase = StringRegExpReplace($sKey, "[\^!+#]", "")
    $sBase = StringUpper(StringReplace(StringReplace($sBase, "{", ""), "}", ""))

    Switch $sBase
        ; --- Media / Volume keys ---
        Case "VOLUME_UP"            : Return 0xAF
        Case "VOLUME_DOWN"          : Return 0xAE
        Case "VOLUME_MUTE"          : Return 0xAD
        Case "MEDIA_PLAY_PAUSE"     : Return 0xB3
        Case "MEDIA_NEXT"           : Return 0xB0
        Case "MEDIA_PREV"           : Return 0xB1
        Case "MEDIA_STOP"           : Return 0xB2
        Case "BROWSER_BACK"         : Return 0xA6
        Case "BROWSER_FORWARD"      : Return 0xA7
        Case "BROWSER_REFRESH"      : Return 0xA8
        Case "BROWSER_STOP"         : Return 0xA9
        Case "BROWSER_SEARCH"       : Return 0xAA
        Case "BROWSER_FAVORITES"    : Return 0xAB
        Case "BROWSER_HOME"         : Return 0xAC
        Case "LAUNCH_MAIL"          : Return 0xB4
        Case "LAUNCH_MEDIA"         : Return 0xB5
        Case "LAUNCH_APP1"          : Return 0xB6
        Case "LAUNCH_APP2"          : Return 0xB7
        ; --- Navigation / editing ---
        Case "SPACE"                : Return 0x20
        Case "ENTER"                : Return 0x0D
        Case "ESC", "ESCAPE"        : Return 0x1B
        Case "TAB"                  : Return 0x09
        Case "UP"                   : Return 0x26
        Case "DOWN"                 : Return 0x28
        Case "LEFT"                 : Return 0x25
        Case "RIGHT"                : Return 0x27
        Case "HOME"                 : Return 0x24
        Case "END"                  : Return 0x23
        Case "PGUP"                 : Return 0x21
        Case "PGDN"                 : Return 0x22
        Case "DELETE", "DEL"        : Return 0x2E
        Case "INSERT", "INS"        : Return 0x2D
        ; --- Function keys ---
        Case "F1"  : Return 0x70
        Case "F2"  : Return 0x71
        Case "F3"  : Return 0x72
        Case "F4"  : Return 0x73
        Case "F5"  : Return 0x74
        Case "F6"  : Return 0x75
        Case "F7"  : Return 0x76
        Case "F8"  : Return 0x77
        Case "F9"  : Return 0x78
        Case "F10" : Return 0x79
        Case "F11" : Return 0x7A
        Case "F12" : Return 0x7B
        Case Else
            ; Single letter A-Z or digit 0-9
            If StringLen($sBase) = 1 Then
                Local $iAsc = Asc($sBase)
                If ($iAsc >= 65 And $iAsc <= 90) Or ($iAsc >= 48 And $iAsc <= 57) Then
                    Return $iAsc
                EndIf
            EndIf
    EndSwitch
    Return 0  ; Not mappable
EndFunc

; =============================================================================

Func ExitScript()
    SaveSettings()
    
    ; Unregister hotkeys
    If $bHotKeyRegistered Then HotKeySet($sHotKey)
    If $bSettingsHotKeyRegistered Then HotKeySet($sSettingsHotKey)
    
    ; Clean up GDI brush objects
    If $hDarkBrush Then _WinAPI_DeleteObject($hDarkBrush)
    
    Exit
EndFunc

; =============================================================================