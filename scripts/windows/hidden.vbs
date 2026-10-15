' Launch a PowerShell script with no window: wscript hidden.vbs <script.ps1> [args]
Set sh = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1: cmd = cmd & " " & WScript.Arguments(i): Next
sh.Run cmd, 0, True
