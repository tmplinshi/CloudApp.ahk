Example:
```AutoHotkey
#Include CloudApp.ahk

; Register your account at https://www.getcloudapp.com/

; Login
api := New CloudApp("your email", "your password")

; Create Bookmark
objResult := api.CreateBookmark("ahk forum", "https://www.autohotkey.com/boards")
MsgBox % Jxon_Dump(objResult)

; Upload File
objResult := api.uploadFile("D:\Desktop\1.jpg")
MsgBox % Jxon_Dump(objResult)
```
