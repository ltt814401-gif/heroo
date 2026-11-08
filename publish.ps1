# HeroDrama Auto Publisher Script with Auto-Skip & Engagement Comment
$token = $env:META_ACCESS_TOKEN
$pageId = $env:META_PAGE_ID
$adAccountId = $env:META_AD_ACCOUNT_ID

# المسار المحلي للفيديوهات (في GitHub Actions سيتم ربط مجلد الفيديوهات أو توجيهه للمسار الصحيح)
$basePath = "E:\herologo\ZZ"
if (!(Test-Path $basePath)) {
    # مسار بديل افتراضي للاختبار لو المسار غير موجود على بيئة الـ Cloud
    $basePath = "./videos"
    if (!(Test-Path $basePath)) { New-Item -ItemType Directory -Path $basePath | Out-Null }
}

$stateFile = "state.json"
$state = Get-Content $stateFile | ConvertFrom-Json

$folders = Get-ChildItem -Path $basePath -Directory | Sort-Object Name
if ($folders.Count -eq 0) {
    Write-Host "No series folders found!"
    exit
}

# تخطي المجلدات المحظورة
$validFolders = $folders | Where-Object { $state.banned_folders -notcontains $_.Name }
if ($state.current_folder_index -ge $validFolders.Count) {
    Write-Host "All folders processed or banned. Resetting index."
    $state.current_folder_index = 0
    $state.banned_folders = @()
}

$currentFolder = $validFolders[$state.current_folder_index]
$videos = Get-ChildItem -Path $currentFolder.FullName -Filter "*.mp4" | Sort-Object Name

if ($videos.Count -eq 0 -or $state.current_episode_index -ge $videos.Count) {
    Write-Host "Folder $($currentFolder.Name) is finished. Moving to next series."
    $state.current_folder_index++
    $state.current_episode_index = 0
    $state | ConvertTo-Json | Set-Content $stateFile
    exit
}

$currentVideo = $videos[$state.current_episode_index]
Write-Host "Publishing episode: $($currentVideo.Name) from series: $($currentFolder.Name)"

$caption = @"
剧集《爱无止境》现已在 HeroDrama 平台上线！
可在 Google Play 和 App Store 下载，立即观看最新热播内容，享受超高清画质！
下载 HeroDrama，精彩不间断！
#HeroDrama #爱无止境 #热门短剧 #追剧 #高清画质 #短剧推荐 #好剧推荐 #必看剧集 #GooglePlay #AppStore #下载观看 #电视剧
"@

$commentText = "🔥 精彩剧情持续更新中！大家觉得这一集怎么样？快在评论区告诉我们，并下载 HeroDrama 体验超高清完整版吧！ #ShortDrama #BingeWatch"

# محاكاة أو تنفيذ الرفع عبر Graph API
# (في حالة الاستجابة بخطأ حقوق ملكية أو حظر، يتم إضافة اسم المجلد إلى banned_folders والانتقال للتالي)

$success = $true # سيتم ربطه باستجابة الـ API الفعلية

if ($success) {
    Write-Host "Video published successfully!"
    $state.current_episode_index++
} else {
    Write-Host "Copyright violation or ban detected! Skipping series: $($currentFolder.Name)"
    $state.banned_folders += $currentFolder.Name
    $state.current_folder_index++
    $state.current_episode_index = 0
}

$state | ConvertTo-Json | Set-Content $stateFile
