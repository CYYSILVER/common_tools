# �ļ����������� - ��EXIF���ڣ����뼶������
# ����ʱ��ʹ�� ANSI

# ����������
$Prefix = ""  # �ļ�ǰ׺
$StartNumber = 136  # ��ʼ���� 
$ZeroPadding = 3      # ���0�ĸ���
$Order = "Descending"  # ���� Ascending ����/ Descending ����

# �Ա�������
$selfPath = $MyInvocation.MyCommand.Path

# ������
try {
    # ��ʼ����ʾ
    Write-Host "`n=== �ű����� ===" -ForegroundColor Cyan
    Write-Host "�������ã�ǰ׺='$Prefix' ��ʼ���=$StartNumber ����λ��=$ZeroPadding ����ʽ=$Order`n"

    Add-Type -AssemblyName System.Drawing

    # �ļ�����׶�
    Write-Host "[1/3] ����ɨ��Ŀ¼: $PSScriptRoot" -ForegroundColor Yellow
    $files = Get-ChildItem -Path $PSScriptRoot -File | 
             Where-Object { $_.FullName -ne $selfPath } |
             ForEach-Object {
                 $file = $_
                 $image = $null
                 $dateTaken = $null
                 try {
                     Write-Host "  ���ڷ���: $($file.Name)" -ForegroundColor Gray
                     $image = [System.Drawing.Image]::FromFile($file.FullName)
                     
                     # ��ȡEXIF����
                     $propDateTime = $image.GetPropertyItem(36867)
                     $dateStr = [System.Text.Encoding]::ASCII.GetString($propDateTime.Value).Trim(" `0")
                     
                     $milliseconds = "000"
                     try {
                         $propSubsec = $image.GetPropertyItem(37521)
                         $subsecStr = [System.Text.Encoding]::ASCII.GetString($propSubsec.Value).Trim(" `0")
                         $milliseconds = $subsecStr.PadRight(3, '0').Substring(0,3)
                         Write-Host "    ��⵽����ֵ: $milliseconds" -ForegroundColor DarkCyan
                     } catch {
                         Write-Host "    [!] δ�ҵ���������" -ForegroundColor DarkYellow
                     }
                     
                     $dateTaken = [datetime]::ParseExact("$dateStr.$milliseconds", "yyyy:MM:dd HH:mm:ss.fff", $null)
                     Write-Host "    ����ʱ��: $dateTaken" -ForegroundColor Green
                 } catch {
                     $dateTaken = $file.CreationTime
                     Write-Host "    [!] EXIF����ʧ�ܣ�ʹ�ô���ʱ��: $dateTaken" -ForegroundColor Red
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

    # ��ʱ�������׶�
    Write-Host "`n[2/3] ����ִ����ʱ������..." -ForegroundColor Yellow
    $tempFiles = New-Object System.Collections.Generic.List[string]
    foreach ($file in $files) {
        try {
            $tempName = [Guid]::NewGuid().ToString("N") + $file.Extension
            Rename-Item -Path $file.FullName -NewName $tempName
            $tempFiles.Add($tempName)
            Write-Host "  $($file.Name) �� ��ʱ�ļ�" -ForegroundColor DarkGray
        } catch {
            Write-Host "  [!] ��ʱ������ʧ��: $($file.Name)" -ForegroundColor Red
            throw
        }
    }

    # �����������׶�
    Write-Host "`n[3/3] ����ִ������������..." -ForegroundColor Yellow
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
            Write-Host "  $tempFile �� $formatString" -ForegroundColor Cyan
            $counter++
        } catch {
            Write-Host "  [!] ������ʧ��: $tempFile" -ForegroundColor Red
            throw
        }
    }

    # ��ɱ���
    $totalFiles = $counter - $StartNumber
    Write-Host "`n=== ������� ===" -ForegroundColor Cyan
    Write-Host "�ɹ��������ļ���: $totalFiles" -ForegroundColor Green
    Write-Host "�ļ�����ʽ: $(if ($Prefix) { "${Prefix}_����" } else { "������" })`n" -ForegroundColor Magenta

} catch {
    Write-Host "`n[!] ������������: $_" -ForegroundColor White -BackgroundColor DarkRed
} finally {
    # �ȴ��û�ȷ��
    Read-Host "���س����˳�..."
}