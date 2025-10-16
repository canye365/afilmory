param(
  [string]$DindRemoteHost = "",
  [string]$ImageName,
  [string]$TagsCsv = "latest",
  [string]$Registry,
  [switch]$Push,
  [string]$DockerfilePath = "./Dockerfile",
  [switch]$NoCache    # ✅ 新增参数：禁用缓存
)

function Log($m) { Write-Host "[+] $m" -ForegroundColor Green }
function Err($m) { Write-Host "[x] $m" -ForegroundColor Red }

# 拼 tag
$tags = $TagsCsv.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$fullTags = @()
foreach ($t in $tags) {
  if ($Registry) { $fullTags += "${Registry}/${ImageName}:${t}" }
  else { $fullTags += "${ImageName}:${t}" }
}
$primaryTag = $fullTags[0]
$otherTags = $fullTags[1..($fullTags.Count - 1)]

# ============ 检查连通 ============
Log "连接远端 dind：$DindRemoteHost"
try {
  $info = docker -H $DindRemoteHost info --format "Server={{.ServerVersion}} | Name={{.Name}}" 2>$null
  if (-not $info) { throw "连接失败" }
  Log "远端信息：$info"
}
catch {
  Err "无法连接远端 Docker daemon"
  exit 1
}

# ============ 构建镜像 ============
Log "开始构建：$primaryTag"
$cmd = @("build", "-t", $primaryTag)
foreach ($t in $otherTags) { $cmd += @("-t", $t) }
if ($NoCache) {
  Log "已启用无缓存构建 (--no-cache)"
  $cmd += "--no-cache"
}
$cmd += @("-f", $DockerfilePath, ".")

docker -H $DindRemoteHost @cmd
if ($LASTEXITCODE -ne 0) { Err "构建失败"; exit 1 }
Log "构建完成：$($fullTags -join ', ')"

# ============ 推送 ============
if ($Push) {
  foreach ($t in $fullTags) {
    Log "推送：$t"
    docker -H $DindRemoteHost push $t
    if ($LASTEXITCODE -ne 0) { Err "推送失败：$t"; exit 1 }
  }
  Log "推送完成"
}

Log "全部完成 ✅"
