/* Function: Exec
 *     Mod of HotKeyIt's DynaRun() - run dynamic AHK code through named pipe(s)
 * Syntax:
 *     pid := Exec( code [ , args, kwargs* ] )
 * Return Value:
 *     PID of the newly launched script
 * Parameter(s:)
 *     code               [in] - AHK code to run/execute
 *     args          [in, opt] - array of command line arguments to pass to the
 *                               script
 *     kwargs*  [in, variadic] - string in the following format: 'option=value',
 *                               where 'option' can be any of the following:
 *                               'name' - pipe name; 'dir' - working directory;
 *                               'opt' - [Hide, Min, Max]; 'ahk' - AutoHotkey.exe
 * Example:
 *     pid := Exec("MsgBox", ["arg"], "name=some_name", "dir=C:\Users")
 * Remarks:
 *     Default for 'kwargs' "option", if 'dir' is not supplied, A_WorkingDir is
 *     used, 'ahk' defaults to A_AhkPath and 'opt' defaults to "Hide". A random
 *     value is generated if 'name' is not specified.
 * Credits:
 *     - Lexikos for his demonstration [http://goo.gl/5IkP5R]
 *     - HotKeyIt for DynaRun() [http://goo.gl/92BBMr]
 */
Exec(code, args:="", kwargs*)
{
	static default := { "name": "", "dir": "", "opt": "Hide", "ahk": A_AhkPath }
	
	n := NumGet(&kwargs + 4*A_PtrSize) ;// ObjCount()
	for option, value in default
	{
		if !kwargs.HasKey(option) ;// if not specified
			%option% := option != "name" ? value : "AHK_" . A_TickCount
		if (A_Index > n) || !(arg := kwargs[A_Index])
			continue
		if ( option := SubStr(arg, 1, (i := InStr(arg, "="))-1) )
			kwargs[option] := %option% := SubStr(arg, i+1)
	}
	static q := Chr(34) ;// double quote("), for v1.1 and v2.0-a compatibility
	for i, arg in args
		args .= " " . q . arg . q
	
	pipe := []
	Loop 2 {
		;// Create named pipe(s), throw exception on failure
		if (( pipe[A_Index] := DllCall(
		(Join Q C
			"CreateNamedPipe",            ;// http://goo.gl/3aJQg7
			"Str",  "\\.\pipe\" . name,   ;// lpName
			"UInt", 2,                    ;// dwOpenMode = PIPE_ACCESS_OUTBOUND
			"UInt", 0,                    ;// dwPipeMode = PIPE_TYPE_BYTE
			"UInt", 255,                  ;// nMaxInstances
			"UInt", 0,                    ;// nOutBufferSize
			"UInt", 0,                    ;// nInBufferSize
			"Ptr",  0,                    ;// nDefaultTimeOut
			"Ptr",  0                     ;// lpSecurityAttributes
		)) ) == -1)                       ;// INVALID_HANDLE_VALUE
			throw A_ThisFunc . "() - Failed to create named pipe."
			      . "`nA_LastError: " . A_LastError
	}

	Run "%ahk%" "\\.\pipe\%name%" %args%, %dir%, %opt% UseErrorLevel, pid
	if ErrorLevel
		MsgBox, 262144,, Could not open file:`n%ahk%\\.\pipe\%name%

	DllCall("ConnectNamedPipe", "Ptr", pipe[1], "Ptr", 0) ;// http://goo.gl/pwTnxj
	DllCall("CloseHandle", "Ptr", pipe[1])
	DllCall("ConnectNamedPipe", "Ptr", pipe[2], "Ptr", 0)

	if !(f := FileOpen(pipe[2], "h", "UTF-8")) ;// works on both Unicode and ANSI
		return A_LastError
	f.Write(code), f.Close()
	DllCall("CloseHandle", "Ptr", pipe[2])

	return pid
}