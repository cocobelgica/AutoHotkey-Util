vtype(var, assert:="") {
	static is_v2 := A_AhkVersion >= "2"
	     , type  := is_v2 ? Func("Type") : ""
	     , regex := RegExMatch("", is_v2? "" : "O)", regex) ? regex : 0

	if is_v2
		t := %type%(var) ;// use v2.0-a buil-in Type()

	else if IsObject(var) {
		t := ObjGetCapacity(var) != ""      ? "Object"
		  :  IsFunc(var)                    ? "Func"
		  :  ComObjType(var) != ""          ? "ComObject"
		  :  NumGet(&var) == NumGet(&regex) ? "RegExMatchObject"
		  :                                   "FileObject"
	}

	else t := ObjGetCapacity([var], 1) != "" ? "String"
	       :  InStr(var, ".") ? "Float" : "Integer"
	
	return assert ? InStr(t, assert) : t
}