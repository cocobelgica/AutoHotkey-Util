vtype(v, assert:="")
{
	static is_v2  := A_AhkVersion >= "2"
	static Type   := is_v2 ? Func("Type") : ""
	static RgxObj := is_v2 ? "" : (m, RegExMatch("", "O)", m))

	if is_v2
		t := %Type%(v) ;// use v2.0-a built-in Type()

	else if IsObject(v)
		t := ObjGetCapacity(v) != ""        ? "Object"
		  :  IsFunc(v)                      ? "Func"
		  :  ComObjType(v) != ""            ? "ComObject"
		  :  NumGet(&v) == NumGet(&RgxObj)  ? "RegExMatchObject"
		  :  IsFunc(v.get) || IsFunc(v.set) ? "Property"
		  :                                   "FileObject"

	else
		t := ObjGetCapacity([v], 1) != "" ? "String" : (InStr(v, ".") ? "Float" : "Integer")
	
	return assert ? InStr(t, assert) : t
}