$ErrorActionPreference = 'Stop'

$folderId = "1sammjfDopJvJCNzfd2NUGhPvZvRAwDIN"
$pageId = "1340333599167943"
$token = $env:META_ACCESS_TOKEN
$stateFile = "image_state.json"

$caption = @"
剧集《爱无止境》现已在 HeroDrama 平台上线！
可在 Google Play 和 App Store 下载，立即观看最新热播内容，享受超高清画质！
下载 HeroDrama，精彩不间断！
#HeroDrama #爱无止境 #热门短剧 #追剧 #高清画质 #短剧推荐 #好剧推荐 #必看剧集 #GooglePlay #AppStore #下载观看 #电视剧
"@

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Error "META_ACCESS_TOKEN غير متوفر في البيئة!"
    exit 1
}

$processedImages = @()
if (Test-Path $stateFile) {
    try {
        $json = Get-Content $stateFile -Raw | ConvertFrom-Json
        if ($json.processed_images) {
            $processedImages = [System.Collections.ArrayList]@($json.processed_images)
        }
    } catch {
        $processedImages = [System.Collections.ArrayList]@()
    }
}

Write-Host "جاري فحص الصور في مجلد Google Drive..." -ForegroundColor Yellow
$driveApiUrl = "https://www.googleapis.com/drive/v3/files?q='$folderId'+in+parents+and+trashed=false&fields=files(id,name,mimeType)&pageSize=100"

try {
    $driveResponse = Invoke-RestMethod -Uri $driveApiUrl -Method Get
    $files = $driveResponse.files | Where-Object { $_.mimeType -like "image/*" } | Sort-Object name
} catch {
    Write-Host "فشل الاتصال المباشر بالـ API، تأكد أن المجلد عام." -ForegroundColor Red
    $files = @()
}

if (-not $files -or $files.Count -eq 0) {
    Write-Host "لم يتم العثور على صور جديدة في المجلد." -ForegroundColor Yellow
    exit 0
}

$targetImage = $null
foreach ($file in $files) {
    if ($processedImages -notcontains $file.id) {
        $targetImage = $file
        break
    }
}

if (-not $targetImage) {
    Write-Host "تم نشر جميع الصور الموجودة في مجلد الدرايف مسبقاً!" -ForegroundColor Green
    exit 0
}

Write-Host "جاري سحب ونشر الصورة: $($targetImage.name)" -ForegroundColor Cyan

$tempImagePath = Join-Path $env:TEMP $targetImage.name
$downloadUrl = "https://www.googleapis.com/drive/v3/files/$($targetImage.id)?alt=media"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempImagePath
} catch {
    $altDownloadUrl = "https://drive.google.com/uc?export=download&id=$($targetImage.id)"
    Invoke-WebRequest -Uri $altDownloadUrl -OutFile $tempImagePath
}

$fbUrl = "https://graph.facebook.com/v18.0/$pageId/photos"

try {
    $postResponse = Invoke-RestMethod -Uri $fbUrl -Method Post -Form @{
        caption      = $caption
        access_token = $token
        source       = Get-Item $tempImagePath
    }

    Write-Host "[نجاح] تم نشر الصورة من الدرايف بنجاح! ID المنشور: $($postResponse.id)" -ForegroundColor Green

    $processedImages.Add($targetImage.id) | Out-Null
    $newState = @{
        last_processed_image = $targetImage.name
        last_published_time  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        processed_images     = $processedImages
    }
    $newState | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8
    Write-Host "تم تحديث ملف تتبع الصور image_state.json بنجاح." -ForegroundColor Green

} catch {
    Write-Error "فشل النشر على فيسبوك: $_"
    exit 1
} finally {
    if (Test-Path $tempImagePath) {
        Remove-Item $tempImagePath -Force
    }
}
