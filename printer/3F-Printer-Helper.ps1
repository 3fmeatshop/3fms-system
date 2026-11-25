# =====================================================================
#  3F PRINTER HELPER  (runs quietly in the background on the POS computer)
#  Lets the 3FMS staff app (www.3fmeatshop.com) print receipts straight
#  to the receipt printer - no print window - cut the paper and open
#  the cash drawer, like a mall POS.
#  Only listens on this computer (127.0.0.1) and only accepts the 3F site.
# =====================================================================
$ErrorActionPreference = 'Stop'
$Port    = 17890
$Allowed = @('https://www.3fmeatshop.com', 'https://3fmeatshop.com', 'https://3fmeatshop.github.io')
if ($env:THREEF_TEST_ORIGIN) { $Allowed += $env:THREEF_TEST_ORIGIN }   # testing only
$TestOut = $env:THREEF_TEST_OUT          # testing only: write the bytes to this file instead of a printer

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ThreeFRaw {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public class DOCINFO {
    [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
  }
  [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool OpenPrinter(string name, out IntPtr h, IntPtr def);
  [DllImport("winspool.drv", SetLastError = true)] public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int StartDocPrinter(IntPtr h, int level, [In] DOCINFO di);
  [DllImport("winspool.drv", SetLastError = true)] public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)] public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)] public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)] public static extern bool WritePrinter(IntPtr h, byte[] bytes, int count, out int written);
  public static void Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) throw new Exception("Cannot open the printer '" + printer + "'");
    try {
      DOCINFO di = new DOCINFO(); di.pDocName = "3F receipt"; di.pDataType = "RAW";
      if (StartDocPrinter(h, 1, di) == 0) throw new Exception("The printer did not accept the job");
      StartPagePrinter(h);
      int w; WritePrinter(h, data, data.Length, out w);
      EndPagePrinter(h); EndDocPrinter(h);
      if (w != data.Length) throw new Exception("Only part of the receipt was sent");
    } finally { ClosePrinter(h); }
  }
}
"@

function Get-Printers {
  $list = @(); $def = ''
  try {
    Get-CimInstance Win32_Printer | ForEach-Object { $list += [string]$_.Name; if ($_.Default) { $def = [string]$_.Name } }
  } catch { }
  return @{ printers = $list; default = $def }
}

function Send-Reply($stream, [int]$code, [string]$origin, [string]$json) {
  $status = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 500 = 'Error' }[$code]
  $body = [System.Text.Encoding]::UTF8.GetBytes($json)
  $h  = "HTTP/1.1 $code $status`r`n"
  $h += "Content-Type: application/json; charset=utf-8`r`n"
  if ($origin) { $h += "Access-Control-Allow-Origin: $origin`r`nVary: Origin`r`n" }
  $h += "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n"
  $h += "Access-Control-Allow-Headers: Content-Type`r`n"
  $h += "Access-Control-Allow-Private-Network: true`r`n"
  $h += "Access-Control-Max-Age: 600`r`n"
  $h += "Content-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
  $hb = [System.Text.Encoding]::ASCII.GetBytes($h)
  $stream.Write($hb, 0, $hb.Length); if ($body.Length) { $stream.Write($body, 0, $body.Length) }; $stream.Flush()
}

function Esc([string]$s) { return ($s -replace '\\', '\\' -replace '"', '\"') }

function Handle($client) {
  $client.ReceiveTimeout = 5000
  $stream = $client.GetStream()
  $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
  $first = $reader.ReadLine(); if (-not $first) { return }
  $parts = $first.Split(' '); $method = $parts[0]; $path = ($parts[1] -split '\?')[0]
  $len = 0; $origin = ''
  while ($true) {
    $line = $reader.ReadLine(); if ($line -eq $null -or $line -eq '') { break }
    $i = $line.IndexOf(':'); if ($i -lt 1) { continue }
    $k = $line.Substring(0, $i).Trim().ToLower(); $v = $line.Substring($i + 1).Trim()
    if ($k -eq 'content-length') { $len = [int]$v }
    if ($k -eq 'origin') { $origin = $v }
  }
  $ok = ($origin -eq '') -or ($Allowed -contains $origin)
  $ao = ''; if ($origin -and $ok) { $ao = $origin }
  if (-not $ok) { Send-Reply $stream 403 '' '{"ok":false,"error":"This website is not allowed to print"}'; return }
  if ($method -eq 'OPTIONS') { Send-Reply $stream 204 $ao ''; return }

  if ($method -eq 'GET' -and $path -eq '/ping') {
    $p = Get-Printers
    $names = ($p.printers | ForEach-Object { '"' + (Esc $_) + '"' }) -join ','
    Send-Reply $stream 200 $ao ('{"ok":true,"app":"3F Printer Helper","ver":1,"default":"' + (Esc $p.default) + '","printers":[' + $names + ']}')
    return
  }

  if ($method -eq 'POST' -and $path -eq '/print') {
    $buf = New-Object char[] $len; $got = 0
    while ($got -lt $len) { $n = $reader.Read($buf, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    try {
      $req = (New-Object string($buf, 0, $got)) | ConvertFrom-Json
      $bytes = [Convert]::FromBase64String([string]$req.data)
      $printer = [string]$req.printer
      if (-not $printer) { $printer = (Get-Printers).default }
      if ($TestOut) { [System.IO.File]::WriteAllBytes($TestOut, $bytes) }
      else {
        if (-not $printer) { throw 'No receipt printer chosen' }
        [ThreeFRaw]::Send($printer, $bytes)
      }
      Send-Reply $stream 200 $ao ('{"ok":true,"printer":"' + (Esc $printer) + '","bytes":' + $bytes.Length + '}')
    } catch {
      Send-Reply $stream 500 $ao ('{"ok":false,"error":"' + (Esc $_.Exception.Message) + '"}')
    }
    return
  }
  Send-Reply $stream 404 $ao '{"ok":false,"error":"not found"}'
}

# one copy only: if the port is taken, the helper is already running
try {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
  $listener.Start()
} catch { exit 0 }

while ($true) {
  $c = $null
  try { $c = $listener.AcceptTcpClient(); Handle $c }
  catch { }
  finally { if ($c) { $c.Close() } }
}
