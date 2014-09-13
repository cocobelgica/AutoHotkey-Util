/* Function:    CpyData_Send
 *     Send a string to another script using WM_COPYDATA
 * Syntax:    el := CpyData_Send( str, rcvr )
 * Return Value:
 *     SendMessage %WM_COPYDATA% ErrorLevel
 * Parameters:
 *     str   [in, ByRef] - string to send
 *     rcvr         [in] - receiver script, argument can be anything that fits
 *                         the WinTitle parameter.
 */
CpyData_Send(ByRef str, rcvr) {
	VarSetCapacity(CDS, 3*A_PtrSize, 0)
	, NumPut( (StrLen(str)+1) * (A_IsUnicode ? 2 : 1), CDS, A_PtrSize )
	, NumPut(&str, CDS, 2*A_PtrSize)
	
	DetectHiddenWindows % (dhw := A_DetectHiddenWindows) ? "On" : "On"
	SetTitleMatchMode % (tmm := A_TitleMatchMode) ? 2 : 2
	SendMessage 0x4a, %A_ScriptHwnd%, % &CDS,, % "ahk_id " WinExist(rcvr)
	DetectHiddenWindows %dhw%
	SetTitleMatchMode %tmm%
	
	return ErrorLevel
}
/* Function:    CpyData_SetF
 *     Set the handler function to call anytime a scripts receives WM_COPYDATA
 * Syntax:    CpyData_SetF( fn )
 * Parameters:
 *     fn      [in, opt] - name of the function, accepts a Func object. If
 *                         omitted, The current function (Func object) used as
 *                         the handler is returned. If explicitly blank (""),
 *                         monitoring is disabled.
 */
CpyData_SetF(fn:=0) {
	if IsFunc(fn) {
		_CpyDataRcv( fn := IsObject(fn) ? fn : Func(fn), [] )
		if ( OnMessage(0x4a) != "_CpyDataRcv" )
			OnMessage(0x4a, "_CpyDataRcv")
		return true
	}
	if (fn == "")
		OnMessage(0x4a, "")
	return !fn ? _CpyDataRcv( fn, [] ) : ""
}
/* PRIVATE
 */
_CpyDataRcv(wParam, lParam) {
	static handler, data, str, sender
	
	if IsObject(lParam) ;// called by CpyData_SetF()
		return wParam == 0 ? handler : handler := wParam
	
	data     := NumGet(lParam + 0)
	, str    := StrGet( NumGet(lParam + 2*A_PtrSize) )
	, sender := wParam
	if IsFunc(handler)
		SetTimer _cpydata_rcv, -1
	return true

_cpydata_rcv:
	%handler%(str, sender, data)
	return
}