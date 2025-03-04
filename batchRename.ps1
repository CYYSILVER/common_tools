# 文件重命名工具 - 按EXIF日期（毫秒级）排序
# 保存时请使用 ANSI

# 参数配置区
$Prefix = ""  # 文件前缀
$StartNumber = 136  # 开始数字 
$ZeroPadding = 3      # 填充0的个数
$Order = "Descending"  # 排序 Ascending 升序/ Descending 降序

# 自保护机制
$selfPath = $MyInvocation.MyCommand.Path

# 主程序
try {
    # 初始化提示
    Write-Host "`n=== 脚本启动 ===" -ForegroundColor Cyan
    Write-Host "参数配置：前缀='$Prefix' 起始编号=$StartNumber 补零位数=$ZeroPadding 排序方式=$Order`n"

    Add-Type -AssemblyName System.Drawing

    # 文件处理阶段
    Write-Host "[1/3] 正在扫描目录: $PSScriptRoot" -ForegroundColor Yellow
    $files = Get-ChildItem -Path $PSScriptRoot -File | 
             Where-Object { $_.FullName -ne $selfPath } |
             ForEach-Object {
                 $file = $_
                 $image = $null
                 $dateTaken = $null
                 try {
                     Write-Host "  正在分析: $($file.Name)" -ForegroundColor Gray
                     $image = [System.Drawing.Image]::FromFile($file.FullName)
                     
                     # 获取EXIF数据
                     $propDateTime = $image.GetPropertyItem(36867)
                     $dateStr = [System.Text.Encoding]::ASCII.GetString($propDateTime.Value).Trim(" `0")
                     
                     $milliseconds = "000"
                     try {
                         $propSubsec = $image.GetPropertyItem(37521)
                         $subsecStr = [System.Text.Encoding]::ASCII.GetString($propSubsec.Value).Trim(" `0")
                         $milliseconds = $subsecStr.PadRight(3, '0').Substring(0,3)
                         Write-Host "    检测到毫秒值: $milliseconds" -ForegroundColor DarkCyan
                     } catch {
                         Write-Host "    [!] 未找到毫秒数据" -ForegroundColor DarkYellow
                     }
                     
                     $dateTaken = [datetime]::ParseExact("$dateStr.$milliseconds", "yyyy:MM:dd HH:mm:ss.fff", $null)
                     Write-Host "    解析时间: $dateTaken" -ForegroundColor Green
                 } catch {
                     $dateTaken = $file.CreationTime
                     Write-Host "    [!] EXIF解析失败，使用创建时间: $dateTaken" -ForegroundColor Red
                 } finally {
                     if ($image -ne $null) { 
                         $image.Dispose()
                     }
                 }
                 
                 $_ | Add-Member -NotePropertyName "HighPrecisionDate" -NotePropertyValue $dateTaken -PassThru
             } |
             Sort-Object @{ 
                 Expression = { $_.HighPrecisionDate.Ticks }
                 Descending = ($Order -eq "Descending") 
             }

    # 临时重命名阶段
    Write-Host "`n[2/3] 正在执行临时重命名..." -ForegroundColor Yellow
    $tempFiles = New-Object System.Collections.Generic.List[string]
    foreach ($file in $files) {
        try {
            $tempName = [Guid]::NewGuid().ToString("N") + $file.Extension
            Rename-Item -Path $file.FullName -NewName $tempName
            $tempFiles.Add($tempName)
            Write-Host "  $($file.Name) → 临时文件" -ForegroundColor DarkGray
        } catch {
            Write-Host "  [!] 临时重命名失败: $($file.Name)" -ForegroundColor Red
            throw
        }
    }

    # 最终重命名阶段
    Write-Host "`n[3/3] 正在执行最终重命名..." -ForegroundColor Yellow
    $counter = $StartNumber
    foreach ($tempFile in $tempFiles) {
        try {
            $ext = [IO.Path]::GetExtension($tempFile)
            if ([string]::IsNullOrEmpty($Prefix)) {
                $formatString = "{0:D$ZeroPadding}{1}" -f $counter, $ext
            } else {
                $formatString = "{0}_{1:D$ZeroPadding}{2}" -f $Prefix, $counter, $ext
            }
            
            Rename-Item -Path $tempFile -NewName $formatString
            Write-Host "  $tempFile → $formatString" -ForegroundColor Cyan
            $counter++
        } catch {
            Write-Host "  [!] 重命名失败: $tempFile" -ForegroundColor Red
            throw
        }
    }

    # 完成报告
    $totalFiles = $counter - $StartNumber
    Write-Host "`n=== 操作完成 ===" -ForegroundColor Cyan
    Write-Host "成功重命名文件数: $totalFiles" -ForegroundColor Green
    Write-Host "文件名格式: $(if ($Prefix) { "${Prefix}_数字" } else { "纯数字" })`n" -ForegroundColor Magenta

} catch {
    Write-Host "`n[!] 发生致命错误: $_" -ForegroundColor White -BackgroundColor DarkRed
} finally {
    # 等待用户确认
    Read-Host "按回车键退出..."
}