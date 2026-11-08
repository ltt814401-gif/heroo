$ErrorActionPreference = 'Stop'
$token  = $env:META_ACCESS_TOKEN
$pageId = $env:META_PAGE_ID
$api    = 'https://graph.facebook.com/v21.0'
if (-not $token -or -not $pageId) { throw 'META_ACCESS_TOKEN or META_PAGE_ID is missing.' }

$titles = @{ 'Series_01'='爱无止境'; 'Series_02'='爱无止境'; 'Series_03'='爱无止境'; 'Series_04'='爱无止境' }

$captionTemplate = @"
剧集《{0}》现已在 HeroDrama 平台上线！
可在 Google Play 和 App Store 下载，立即观看最新热播内容，享受超高清画质！
下载 HeroDrama，精彩不间断！
#HeroDrama #{0} #热门短剧 #追剧 #高清画质 #短剧推荐 #好剧推荐 #必看剧集 #GooglePlay #AppStore #下载观看 #电视剧
"@

$stateFile = 'state.json'
if (!(Test-Path 'videos')) { throw "'videos' folder not found." }
if (!(Test-Path $stateFile)) { '{"current_folder_index": 0, "current_episode_index": 0, "banned_folders": []}' | Set-Content $stateFile -Encoding utf8 }
$state = Get-Content $stateFile -Raw | ConvertFrom-Json
$state.banned_folders = @($state.banned_folders)
function Save-State { $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8 }

$folders = @(Get-ChildItem 'videos' -Directory | Sort-Object Name)
$video = $null
for ($i = 0; $i -le $folders.Count + 1; $i++) {
    $valid = @($folders | Where-Object { $state.banned_folders -notcontains $_.Name })
    if ($valid.Count -eq 0) { $state.banned_folders = @(); $state.current_folder_index = 0; $state.current_episode_index = 0; $valid = $folders }
    if ($state.current_folder_index -ge $valid.Count) { $state.current_folder_index = 0; $state.current_episode_index = 0 }
    $folder = $valid[$state.current_folder_index]
    $videos = @(Get-ChildItem $folder.FullName -Filter '*.mp4' | Sort-Object Name)
    if ($videos.Count -eq 0 -or $state.current_episode_index -ge $videos.Count) { $state.current_folder_index++; $state.current_episode_index = 0; continue }
    $video = $videos[$state.current_episode_index]
    break
}
if (-not $video) { Save-State; throw 'No publishable video found.' }

$title   = if ($titles.ContainsKey($folder.Name)) { $titles[$folder.Name] } else { $folder.Name }
$caption = $captionTemplate -f $title
Write-Host "Publishing $($video.Name) from $($folder.Name) ..."

try {
    $size = (Get-Item $video.FullName).Length
    $s = Invoke-RestMethod -Method Post -Uri "$api/$pageId/video_reels" -Body @{ upload_phase = 'start'; access_token = $token }
    Invoke-RestMethod -Method Post -Uri $s.upload_url -Headers @{ Authorization = "OAuth $token"; offset = '0'; file_size = "$size" } -InFile $video.FullName -ContentType 'application/octet-stream' | Out-Null
    $fin = Invoke-RestMethod -Method Post -Uri "$api/$pageId/video_reels" -Body @{ upload_phase = 'finish'; video_id = $s.video_id; video_state = 'PUBLISHED'; description = $caption; access_token = $token }
    Write-Host "SUCCESS. Reel video id: $($s.video_id) $($fin | ConvertTo-Json -Compress)"
    $state.current_episode_index++
    Save-State
}
catch {
    $msg = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Write-Host "Facebook API error: $msg"
    if ($msg -match 'copyright|rights manager|violat') {
        $state.banned_folders += $folder.Name
        $state.current_episode_index = 0
        Save-State
        exit 0
    }
    throw
}
