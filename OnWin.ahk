/* Function: OnWin
 *     Specifies a function to call when the specified window event for the
 *     specified window occurs.
 * Version:
 *     v1.0.03.00
 * License:
 *     WTFPL [http://wtfpl.net/]
 * Requirments:
 *     AutoHotkey v1.1.17.00+ OR v2.0-a058
 * Syntax:
 *     OnWin( event, WinTitle, callback )
 * Parameters:
 *     event    [in] - Window event to monitor. Valid values are: Exist, Active,
 *                     NotActive/!Active, Show, Hide, Minimize, Maximize, Move,
 *                     Close/NotExist/!Exist and CloseAll/NotExistAll/!ExistAll.
 *     WinTitle [in] - see http://ahkscript.org/docs/misc/WinTitle.htm. Due to
 *                     limitations, 'ahk_group GroupName' is not supported
 *                     directly. To specify a window group, pass an array of
 *                     WinTitle(s) instead.
 *     callback [in] - Function name, Func object or object. The callback will
 *                     receive an event object with the ff properties: 'Event'
 *                     and 'Window', as its first argument. For now, monitoring
 *                     is for one-time use only.
 * Remarks:
 *     - Script must be #Include-ed(manually or automatically) and must not be
 *       copy-pasted into the main script.
 *     - OnWin() uses A_TitleMatchMode and A_TitleMatchModeSpeed.
 * Links:
 *     GitHub      - http://goo.gl/JfzFTh
 *     Forum Topic - http://goo.gl/sMufTt
 */
OnWin(event, WinTitle, CbProc, reserved:=0)
{
	static host
	if !IsObject(host)
		host := new OnWinHost()
	host.AddClient(client := new OnWinClient(event, WinTitle, CbProc))

	code := Format("
	(LTrim Join`n
	{5}
	ListLines Off
	OnWin_Main({1}{2}{1}, {1}{3}{1})
	ExitApp
	#Include {4}
	#NoTrayIcon
	#KeyHistory 0
	)", Chr(34), host.Id, client.Id, A_LineFile, A_AhkVersion<"2" ? "SetBatchLines -1" : "")

	cmd := Format("{1}{2}{1} /ErrorStdOut *", Chr(34), A_AhkPath)
	exec := ComObjCreate("WScript.Shell").Exec(cmd)
	exec.StdIn.Write(code), exec.StdIn.Close()
	while !client.__Handle && (exec.Status == 0)
		Sleep 10

	; taken from Lexikos' LoadFile() [http://goo.gl/y6ctxp], make script #Persistent
	Hotkey IfWinActive, % host.Id
	Hotkey vk07, _onwin_persistent, Off
_onwin_persistent:
}

class OnWinHost
{
	__New()
	{
		this.Clients := {}

		proxy := ObjClone(this)
		VarSetCapacity(CLSID, 16, 0)
		if DllCall("ole32\CoCreateGuid", "Ptr", &CLSID) != 0
			throw Exception("Failed to generate CLSID", -1)

		HR := DllCall("oleaut32\RegisterActiveObject"
		      , "Ptr", &proxy, "Ptr", &CLSID, "UInt", 0, "UInt*", hReg, "UInt")
		if (HR < 0)
			throw Exception(Format("HRESULT: 0x{:x}", HR), -1)
		this.__Handle := hReg, proxy.__Handle := 0 ; avoid calling RevokeActiveObject twice

		VarSetCapacity(sGUID, 38 * 2 + 1)
		DllCall("ole32\StringFromGUID2", "Ptr", &CLSID, "Ptr", &sGUID, "Int", 38 + 1)
		this.Id := StrGet(&sGUID, "UTF-16")
	}

	__Delete() ; called on script's exit
	{
		if hReg := this.__Handle ; 0 if proxy(active object)
		{
			DllCall("oleaut32\RevokeActiveObject", "UInt", hReg, "Ptr", 0)
			for i, client in ObjRemove(this, "Clients") ; terminate any running listener(s)
				client.Terminate()
		}
	}

	AddClient(client)
	{
		this.Clients[ client.Id ] := client
	}

	FreeClient(client)
	{
		return ObjRemove(this.Clients, client.Id)
	}
}

class OnWinClient
{
	__New(event, WinTitle, CbProc)
	{
		if (WinTitle ~= "i)^ahk_group .*$")
			throw Exception("Invalid argument. To specify a window group, pass an array of WinTitle(s).", -1, WinTitle)
		
		this.Event          := event
		this.Window         := WinTitle
		this.Callback       := IsObject(CbProc) ? CbProc : Func(CbProc)
		this.MatchMode      := A_TitleMatchMode
		this.MatchModeSpeed := A_TitleMatchModeSpeed
		this.Id             := "#" . &this
		this.__Handle       := 0
	}

	__Call(callee, args*)
	{
		if (callee == "") || (callee = "Call") || IsObject(callee)
		{
			if CbProc := this.Callback
				return %CbProc%(this)
		}
	}

	Terminate()
	{
		if hWnd := this.__Handle
			return DllCall("PostMessage", "Ptr", hWnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0) ; WM_CLOSE
	}
}

OnWin_Main(HostId, ClientId)
{
	host := ComObjActive(HostId)
	client := host.Clients[ClientId], client.__Handle := A_ScriptHwnd + 0

	event := client.Event
	if !(event ~= "i)^(Exist|(Not|!)?Active|(Close|(Not|!)Exist)(All)?|Show|Hide|M(in|ax)imize|Move)$")
		return

	prev_DHW := A_DetectHiddenWindows
	DetectHiddenWindows On
	SetWinDelay -1
	SetTitleMatchMode % client.MatchMode
	SetTitleMatchMode % client.MatchModeSpeed

	if IsObject(WinTitle := client.Window) ; ahk_group GroupName workaround
	{
		Loop % WinTitle[A_AhkVersion<"2" ? "MaxIndex" : "Length"]() ; can't use for-loop :(
			GroupAdd WinGroup, % WinTitle[A_Index]
		WinTitle := "ahk_group WinGroup"
	}

	if InStr(" Exist Show Minimize Maximize Move ", Format(" {} ", event))
		WinWait %WinTitle%

	if (event = "Active")
		WinWaitActive %WinTitle%

	else if (event = "NotActive" || event = "!Active")
		WinWaitNotActive %WinTitle%

	else if (event ~= "i)^(Close|(Not|!)Exist)(All)?$") && WinExist(WinTitle)
		WinWaitClose % InStr(event, "All") ? WinTitle : ""

	else if (event = "Show") || (event = "Hide" && WinExist(WinTitle))
	{
		DetectHiddenWindows Off
		if (event = "Show")
			WinWait %WinTitle%
		else
			WinWaitClose
	}

	else if (event = "Minimize" || event = "Maximize")
	{
		hWnd := WinExist() ; get handle of "Last Found" Window
		showCmd := event="Minimize" ? 2 : 3
		VarSetCapacity(WINDOWPLACEMENT, 44, 0)
		NumPut(44, WINDOWPLACEMENT, 0, "UInt") ; sizeof(WINDOWPLACEMENT)
		Loop
			DllCall("GetWindowPlacement", "Ptr", hWnd, "Ptr", &WINDOWPLACEMENT)
		until NumGet(WINDOWPLACEMENT, 8, "UInt") == showCmd
	}

	else if (event = "Move")
	{
		WinGetPos prevX, prevY, prevW, prevH ; use last found (for ahk_group WinGroup)
		Loop
			WinGetPos x, y, w, h
		until (x != prevX || y != prevY || w != prevW || h != prevH)
	}

	DetectHiddenWindows %prev_DHW%
	
	try %client%() ; suppress error
	return host.FreeClient(client)
}