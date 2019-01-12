/*
	Requires:
		CreateFormData.ahk - https://gist.github.com/tmplinshi/8428a280bba58d25ef0b
		BinArr.ahk         - https://gist.github.com/tmplinshi/a97d9a99b9aa5a65fd20
		Jxon.ahk (by Coco) - https://www.autohotkey.com/boards/viewtopic.php?t=627

	Supported methods:
		CreateBookmark(name, url)
		ListItems(paramters := "page=1&per_page=5")
		DeleteItem(url)
		ViewItem(url)
		uploadFile(FilePath)

	Example:
		api := New CloudApp("your email", "your password")
		objResult := api.uploadFile("D:\Desktop\1.jpg")
		MsgBox % Jxon_Dump(objResult)
*/


; CloudApp API Document: https://github.com/cloudapp/api/blob/master/README.md

class CloudApp
{
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")

	__New(email, password) {
		this.http("GET", "https://my.cl.ly/account")
		auth := DigestAuth.Build(email, password, "GET", "/account", this.whr.getResponseHeader("WWW-Authenticate"))

		oHeaders := {"Authorization": auth}
		this.http("GET", "https://my.cl.ly/account",, oHeaders)
		this.getCookie()

		if (this.whr.Status != 200)
			throw "Login failed"
	}

	CreateBookmark(name, url) {
		body := {item: {name: name, redirect_url: url}}
		return this.http("POST", "https://my.cl.ly/items", body)
	}

	/*
		Optional paramters:
			page=1 : Page number starting at 1.
			per_page=5 : Number of items per page.
			type=image : Filter items by type (image, bookmark, text, archive, audio, video, or unknown).
			deleted=true : Show trashed items.
			source=MyApp : Filter items by all or part of the User-Agent.
	*/
	ListItems(paramters := "page=1&per_page=5") {
		return this.http("GET", "https://my.cl.ly/items?" paramters)
	}

	DeleteItem(url) {
		return this.http("DELETE", url)
	}

	ViewItem(url) {
		return this.http("GET", url)
	}

	uploadFile(FilePath) {
		ret := this.http("GET", "https://my.cl.ly/items/new")

		objParam := ret.params
		objParam.file := [FilePath]
		CreateFormData(body, vContentType, objParam)

		oHeaders := {"Content-Type": vContentType}
		return this.http("POST", ret.url, body, oHeaders, 600)
	}

	http(method, url, body := "", oHeaders := "", timeoutSeconds := 30) {
		whr := this.whr
		whr.Open(method, url, true)

		whr.SetRequestHeader("Accept", "application/json")
		if !oHeaders.HasKey("Content-Type") {
			whr.SetRequestHeader("Content-Type", "application/json")
		}
		if this.cookie {
			whr.SetRequestHeader("Cookie", this.cookie)
		}
		for k, v in oHeaders
			whr.SetRequestHeader(k, v)

		try {
			if IsObject(body)
				body := Jxon_Dump(body)
		}

		If (timeoutSeconds > 30)
			whr.SetTimeouts(0, 60000, 30000, timeoutSeconds * 1000)

		whr.Send(body)
		whr.WaitForResponse()

		if InStr(whr.getResponseHeader("Content-Type"), "application/json")
			return Jxon_Load(whr.responseText)
	}

	getCookie() {
		hdrs := this.whr.getAllResponseHeaders()

		pos := 1
		while pos := RegExMatch(hdrs, "`am)^Set-Cookie: \K[^;]+", m, pos+StrLen(m))
			this.cookie .= (A_Index>1 ? "; " : "") . m
	}
}

; https://en.wikipedia.org/wiki/Digest_access_authentication
class DigestAuth
{
	Build(username, password, method, uri, ByRef WWWAuthenticate) {
		Loop, Parse, % "realm|qop|algorithm|nonce|opaque", |
			RegExMatch(WWWAuthenticate, A_LoopField "=""?\K[^,""]+", %A_LoopField%)

		cnonce := this.create_cnonce()
		nonceCount := "00000001"

		ha1 := this.StrMD5(username ":" realm ":" password)
		ha2 := this.StrMD5(method ":" uri)
		response := this.StrMD5(ha1 ":" nonce ":" nonceCount ":" cnonce ":" qop ":" ha2)

		return "
		(Join, LTrim
			Digest username=""" username """
			realm=""" realm """
			nonce=""" nonce """
			uri=""" uri """
			algorithm=""" algorithm """
			cnonce=""" cnonce """
			nc=" nonceCount "
			qop=""" qop """
			response=""" response """
			opaque=""" opaque """
		)"
	}

	StrMD5( V ) { ; www.autohotkey.com/forum/viewtopic.php?p=376840#376840
		VarSetCapacity( MD5_CTX,104,0 ), DllCall( "advapi32\MD5Init", UInt,&MD5_CTX ) 
		DllCall( "advapi32\MD5Update", UInt,&MD5_CTX, A_IsUnicode ? "AStr" : "Str",V 
		, UInt,StrLen(V) ), DllCall( "advapi32\MD5Final", UInt,&MD5_CTX ) 
		Loop % StrLen( Hex:="123456789abcdef0" ) 
			N := NumGet( MD5_CTX,87+A_Index,"Char"), MD5 .= SubStr(Hex,N>>4,1) . SubStr(Hex,N&15,1)
		Return MD5 
	}

	CreateGUID() { ; https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4732
		VarSetCapacity(pguid, 16, 0)
		if !(DllCall("ole32.dll\CoCreateGuid", "ptr", &pguid)) {
			size := VarSetCapacity(sguid, (38 << !!A_IsUnicode) + 1, 0)
			if (DllCall("ole32.dll\StringFromGUID2", "ptr", &pguid, "ptr", &sguid, "int", size))
				return StrGet(&sguid)
		}
		return ""
	}

	create_cnonce() {
		guid := this.CreateGUID()
		StringLower, guid, guid
		return RegExReplace(guid, "[{}-]")
	}
}