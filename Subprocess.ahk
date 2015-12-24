Subprocess_Run(args*)
{
	return new Subprocess(args*)
}

class Subprocess
{
	; implement as Functor to encapsulate helper functions
	class __New extends Subprocess.Functor
	{
		; instance is passed as 'self'
		Call(self, cmd, cwd:="", StartInfo:="") ; StartInfo=reserved
		{
			stdin := this.CreatePipe()
				this.SetHandleInformation(stdin.read, 1, 1) ; HANDLE_FLAG_INHERIT
			stdout := this.CreatePipe()
				this.SetHandleInformation(stdout.write, 1, 1) ; HANDLE_FLAG_INHERIT
			stderr := this.CreatePipe()
				this.SetHandleInformation(stderr.write, 1, 1) ; HANDLE_FLAG_INHERIT

			if !(pStartupInfo := ObjGetAddress(this, "_STARTUPINFO")) {
				sizeof_SI := A_PtrSize==8 ? 104 : 68 ; 40 + 7*A_PtrSize + 2*(pad := A_PtrSize==8 ? 4 : 0)
				pStartupInfo := this.NewBuffer("_STARTUPINFO", sizeof_SI)
					NumPut(sizeof_SI, pStartupInfo + 0, "UInt")
					NumPut(0x100, pStartupInfo + (A_PtrSize==8 ? 60 : 44), "UInt") ; dwFlags=STARTF_USESTDHANDLES
			}
			
			  NumPut(stderr.write
			, NumPut(stdout.write
			, NumPut(stdin.read, pStartupInfo + (A_PtrSize==8 ? 80 : 56))))

			static sizeof_PI := 8 + 2*A_PtrSize
			pProcessInfo := this.NewBuffer.Call(self, "PROCESS_INFORMATION", sizeof_PI)

			; stringify arguments
			if IsObject(cmd) {
				static quot := Func("Format").Bind("{1}{2}{1}", Chr(34))
				
				len := ObjLength(args := cmd), cmd := ""
				for i, arg in args
					cmd .= (InStr(arg, " ") ? quot.Call(arg) : arg) . (i<len ? " " : "")
			}

			; create the process
			if (!this.CreateProcess(cmd,,,,,, cwd=="" ? A_WorkingDir : cwd, pStartupInfo, pProcessInfo))
				throw Exception("Failed to create process", -1, cmd)

			self.StdIn  := new Subprocess.StreamWriter(stdin.write)
			self.StdOut := new Subprocess.StreamReader(stdout.read)
			self.StdErr := new Subprocess.StreamReader(stderr.read)

			this.CloseHandle(stdin.read)
			this.CloseHandle(stdout.write)
			this.CloseHandle(stderr.write)

			return self ; return instance
		}

		CreateProcess(CmdLine, ProcAttrib:=0, ThreadAttrib:=0, InheritHandles:=true, flags:=0x8000000, pEnv:=0, cwd:="", pStartupInfo:=0, pProcessInfo:=0)
		{
			return DllCall("CreateProcess", "Ptr", 0, "Str", CmdLine, "Ptr", ProcAttrib
				, "Ptr", ThreadAttrib, "Int", InheritHandles, "UInt", flags, "Ptr", pEnv
				, "Str", cwd, "Ptr", pStartupInfo, "Ptr", pProcessInfo)
		}

		CreatePipe(PipeAttributes:=0, size:=0)
		{
			if !DllCall("CreatePipe", "Ptr*", hRead, "Ptr*", hWrite, "Ptr", PipeAttributes, "UInt", 0)
				throw Exception("Failed to create anonymous pipe", -1, A_LastError)
			
			return { read: hRead, write: hWrite }
		}

		SetHandleInformation(handle, mask, flags)
		{
			return DllCall("SetHandleInformation", "Ptr", handle, "UInt", mask, "UInt", flags)
		}

		CloseHandle(handle)
		{
			return DllCall("CloseHandle", "Ptr", handle)
		}

		NewBuffer(key, length)
		{
			if !(addr := ObjGetAddress(this, key)) {
				ObjSetCapacity(this, key, length)
				addr := ObjGetAddress(this, key)
					DllCall("RtlZeroMemory", "Ptr", addr, "UPtr", length)
			}
			return addr
		}
	}

	__Delete()
	{
		pProcessInfo := ObjGetAddress(this, "PROCESS_INFORMATION")
		DllCall("CloseHandle", "Ptr", NumGet(pProcessInfo + 0))         ; hProcess
		DllCall("CloseHandle", "Ptr", NumGet(pProcessInfo + A_PtrSize)) ; hThread
	}

	__Handle[] ; hProcess
	{
		get {
			return NumGet(ObjGetAddress(this, "PROCESS_INFORMATION"))
		}
	}

	ProcessID[]
	{
		get {
			pProcessInfo := ObjGetAddress(this, "PROCESS_INFORMATION")
			return NumGet(pProcessInfo + 2*A_PtrSize, "UInt") ; dwProcessId
		}
	}

	Status[] ; Running=0 , Done=1
	{
		get {
			return !(this.ExitCode == 259) ; STILL_ACTIVE=259
		}
	}

	ExitCode[] ; STILL_ACTIVE=259
	{
		get {
			hProcess := this.__Handle
			if DllCall("GetExitCodeProcess", "Ptr", hProcess, "UInt*", ExitCode)
				return ExitCode
		}
	}

	Terminate(ExitCode:=0)
	{
		if (ExitCode == 259) ; STILL_ACTIVE
			throw Exception("Exit code 'STILL_ACTIVE' is reserved", -1, ExitCode)
		
		; use gentler method - attempt to close window(s) first
		prev_DHW := A_DetectHiddenWindows
		DetectHiddenWindows, On

			WinTitle := "ahk_pid " . this.ProcessID
			while (hwnd := WinExist(WinTitle)) {
				WinClose
				if WinExist("ahk_id " . hwnd)
					WinKill
			}

		DetectHiddenWindows, %prev_DHW%

		; still running, force kill
		if (this.Status == 0) {
			hProcess := this.__Handle
			DllCall("TerminateProcess", "Ptr", hProcess, "UInt", ExitCode)
		}
	}

	class Pipe
	{
		__New(handle)
		{
			this.__Handle := handle
		}

		__Delete()
		{
			this.Close()
		}

		Close()
		{
			try this._Stream.Close(), this._Stream := ""
			DllCall("CloseHandle", "Ptr", this.__Handle)
		}

		_Stream := ""
		Stream[]
		{
			get {
				if !this._Stream
					this._Stream := FileOpen(this.__Handle, "h")
				return this._Stream
			}
		}

		Encoding[]
		{
			get {
				return this.Stream.Encoding
			}
			set {
				return this.Stream.Encoding := value
			}
		}
	}

	class StreamReader extends Subprocess.Pipe
	{
		Read(chars*)
		{
			return this.Stream.Read(chars*)
		}

		ReadLine()
		{
			return this.Stream.ReadLine()
		}

		ReadAll()
		{
			VarSetCapacity(buf, 4096), all := "", enc := this.Encoding
			while read := this.Stream.RawRead(buf, 4096)
				NumPut(0, buf, read, "UShort"), all .= StrGet(&buf, read, enc)
			return all
		}

		Peek(ByRef data:="", bytes:=4096, ByRef read:="", ByRef avail:="", ByRef left:="")
		{
			VarSetCapacity(data, bytes)
			return DllCall("PeekNamedPipe", "Ptr", this.__Handle, "Ptr", &data, "UInt", bytes, "UInt*", read, "UInt*", avail, "UInt*", left)
		}

		; alternative - returns info as object(instead of ByRef) to allow usage in IPC(ComObjActive, etc.)
		PeekEx(bytes:=4096)
		{
			if this.Peek(data, bytes, read, avail, left)
				return { Data: StrGet(&data, read, this.Encoding), BytesRead: read, BytesAvail: avail, BytesLeft: left }
		}
	}

	class StreamWriter extends Subprocess.Pipe
	{
		Write(str)
		{
			return this.Stream.Write(str)
		}

		WriteLine(str)
		{
			return this.Stream.WriteLine(str)
		}
	}

	; base object for methods implemented as "custom function object(s)"
	class Functor
	{
		__Call(method, args*)
		{
			if IsObject(method)
				return this.Call(method, args*)
			else if (method == "")
				return this.Call(args*)
		}
	}
}