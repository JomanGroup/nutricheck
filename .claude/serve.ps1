$ErrorActionPreference = 'Stop'
$port = 8767
$root = Split-Path -Parent $PSScriptRoot
$mime = @{
  '.html'='text/html; charset=utf-8'
  '.htm' ='text/html; charset=utf-8'
  '.js'  ='application/javascript; charset=utf-8'
  '.mjs' ='application/javascript; charset=utf-8'
  '.css' ='text/css; charset=utf-8'
  '.json'='application/json; charset=utf-8'
  '.svg' ='image/svg+xml'
  '.png' ='image/png'
  '.jpg' ='image/jpeg'
  '.jpeg'='image/jpeg'
  '.gif' ='image/gif'
  '.ico' ='image/x-icon'
  '.woff'='font/woff'
  '.woff2'='font/woff2'
  '.txt' ='text/plain; charset=utf-8'
  '.webp'='image/webp'
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/"
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
      if ($path -eq '/' -or $path -eq '') { $path = '/index.html' }
      $full = Join-Path $root ($path.TrimStart('/'))
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $res.StatusCode = 404
        $b = [Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
        $res.OutputStream.Write($b,0,$b.Length)
      } else {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $ct = $mime[$ext]
        if (-not $ct) { $ct = 'application/octet-stream' }
        $res.ContentType = $ct
        $res.Headers.Add('Cache-Control','no-cache')
        $bytes = [IO.File]::ReadAllBytes($full)
        $res.ContentLength64 = $bytes.LongLength
        $res.OutputStream.Write($bytes,0,$bytes.Length)
      }
    } catch {
      $res.StatusCode = 500
      $b = [Text.Encoding]::UTF8.GetBytes("500: $($_.Exception.Message)")
      $res.OutputStream.Write($b,0,$b.Length)
    } finally {
      $res.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
}
