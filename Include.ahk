Include(incl, args*) {
	if FileExist(incl) {
		fspec := incl, incl := ""
		if (A_AhkVersion < "2")
			Loop %fspec%, 0, 0
				incl .= "#Include " . A_LoopFileLongPath . "`n"
		
		else Loop Files, %fspec%, % "F" ;// force expression to avoid v1.1 error
				incl .= "#Include " . A_LoopFileFullPath . "`n"
		incl := Trim(incl, "`n")
	}

	pipe_name := "\\.\pipe\f8e5a38f-24fe-4962-9f13-6c9d7fc32197"
	;// Create named pipe(s)
	for each, pipe in ["__PIPE_GA_", "__PIPE_"]
		%pipe% := DllCall(
		(Join Q C
			"CreateNamedPipe",   ;// http://goo.gl/3aJQg7
			"Str",  pipe_name,   ;// lpName
			"UInt", 2,           ;// dwOpenMode = PIPE_ACCESS_OUTBOUND
			"UInt", 0,           ;// dwPipeMode = PIPE_TYPE_BYTE
			"UInt", 255,         ;// nMaxInstances
			"UInt", 0,           ;// nOutBufferSize
			"UInt", 0,           ;// nInBufferSize
			"Ptr",  0,           ;// nDefaultTimeOut
			"Ptr",  0            ;// lpSecurityAttributes
		))

	if (__PIPE_ == -1 || __PIPE_GA_ == -1)
		throw "Failed to create named pipe"

	sargs := "", q := Chr(34), count := NumGet(&args+4*A_PtrSize)
	for each, arg in args
		sargs .= q . arg . q . (A_Index < count ? " " : "")
	;// Reload script passing args(if any)
	Run "%A_AhkPath%" "%A_ScriptFullPath%" %sargs%

	DllCall("ConnectNamedPipe", "Ptr", __PIPE_GA_, "Ptr", 0) ;// http://goo.gl/pwTnxj
	DllCall("CloseHandle", "Ptr", __PIPE_GA_)
	DllCall("ConnectNamedPipe", "Ptr", __PIPE_, "Ptr", 0)

	incl := ( A_IsUnicode ? Chr(0xfeff) : Chr(239) . Chr(187) . Chr(191) ) . incl
	if !DllCall(
	(Join Q C
		"WriteFile",                                ;// http://goo.gl/fdyWm0
		"Ptr",   __PIPE_,                           ;// hFile
		"Str",   incl,                              ;// lpBuffer
		"UInt",  (StrLen(incl)+1)*(A_IsUnicode+1),  ;// nNumberOfBytesToWrite
		"UInt*", 0,                                 ;// lpNumberOfBytesWritten
		"Ptr",   0                                  ;// lpOverlapped
	))
		return A_LastError
	
	DllCall("CloseHandle", "Ptr", __PIPE_)
}
;// pipe, do not remove, UUID generated using Python's uuid.uuid4()
#Include *i \\.\pipe\f8e5a38f-24fe-4962-9f13-6c9d7fc32197 