Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Main Form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Web File Downloader Studio"
$Form.Size = New-Object System.Drawing.Size(550, 480)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false

# Input Dump File Picker
$LblInput = New-Object System.Windows.Forms.Label
$LblInput.Location = New-Object System.Drawing.Point(20, 20)
$LblInput.Size = New-Object System.Drawing.Size(100, 20)
$LblInput.Text = "Dump File:"
$Form.Controls.Add($LblInput)

$TxtInput = New-Object System.Windows.Forms.TextBox
$TxtInput.Location = New-Object System.Drawing.Point(120, 20)
$TxtInput.Size = New-Object System.Drawing.Size(300, 20)
$Form.Controls.Add($TxtInput)

$BtnInput = New-Object System.Windows.Forms.Button
$BtnInput.Location = New-Object System.Drawing.Point(430, 18)
$BtnInput.Size = New-Object System.Drawing.Size(75, 23)
$BtnInput.Text = "Browse"
$BtnInput.Add_Click({
    $OpenDlg = New-Object System.Windows.Forms.OpenFileDialog
    $OpenDlg.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    if ($OpenDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtInput.Text = $OpenDlg.FileName
    }
})
$Form.Controls.Add($BtnInput)

# Config File Picker (domains.json)
$LblConfig = New-Object System.Windows.Forms.Label
$LblConfig.Location = New-Object System.Drawing.Point(20, 60)
$LblConfig.Size = New-Object System.Drawing.Size(100, 20)
$LblConfig.Text = "Config File:"
$Form.Controls.Add($LblConfig)

$TxtConfig = New-Object System.Windows.Forms.TextBox
$TxtConfig.Location = New-Object System.Drawing.Point(120, 60)
$TxtConfig.Size = New-Object System.Drawing.Size(300, 20)
$Form.Controls.Add($TxtConfig)

$BtnConfig = New-Object System.Windows.Forms.Button
$BtnConfig.Location = New-Object System.Drawing.Point(430, 58)
$BtnConfig.Size = New-Object System.Drawing.Size(75, 23)
$BtnConfig.Text = "Browse"
$BtnConfig.Add_Click({
    $OpenDlg = New-Object System.Windows.Forms.OpenFileDialog
    $OpenDlg.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
    if ($OpenDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtConfig.Text = $OpenDlg.FileName
    }
})
$Form.Controls.Add($BtnConfig)

# Download Directory Picker
$LblOutput = New-Object System.Windows.Forms.Label
$LblOutput.Location = New-Object System.Drawing.Point(20, 100)
$LblOutput.Size = New-Object System.Drawing.Size(100, 20)
$LblOutput.Text = "Download Dir:"
$Form.Controls.Add($LblOutput)

$TxtOutput = New-Object System.Windows.Forms.TextBox
$TxtOutput.Location = New-Object System.Drawing.Point(120, 100)
$TxtOutput.Size = New-Object System.Drawing.Size(300, 20)
$Form.Controls.Add($TxtOutput)

$BtnOutput = New-Object System.Windows.Forms.Button
$BtnOutput.Location = New-Object System.Drawing.Point(430, 98)
$BtnOutput.Size = New-Object System.Drawing.Size(75, 23)
$BtnOutput.Text = "Browse"
$BtnOutput.Add_Click({
    $FolderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($FolderDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtOutput.Text = $FolderDlg.SelectedPath
    }
})
$Form.Controls.Add($BtnOutput)

# Log Text Box
$TxtLog = New-Object System.Windows.Forms.TextBox
$TxtLog.Location = New-Object System.Drawing.Point(20, 140)
$TxtLog.Size = New-Object System.Drawing.Size(485, 235)
$TxtLog.Multiline = $true
$TxtLog.ScrollBars = "Vertical"
$TxtLog.ReadOnly = $true
$Form.Controls.Add($TxtLog)

# Execution Button
$BtnRun = New-Object System.Windows.Forms.Button
$BtnRun.Location = New-Object System.Drawing.Point(185, 390)
$BtnRun.Size = New-Object System.Drawing.Size(150, 35)
$BtnRun.Text = "Start File Download"
$BtnRun.Add_Click({
    $InputFile = $TxtInput.Text
    $ConfigFile = $TxtConfig.Text
    $DownloadDir = $TxtOutput.Text

    if (-not (Test-Path $InputFile)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid input dump file.", "Error", 'OK', 'Error')
        return
    }
    if (-not (Test-Path $ConfigFile)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid domains.json config file.", "Error", 'OK', 'Error')
        return
    }
    if (-not (Test-Path $DownloadDir)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid download directory.", "Error", 'OK', 'Error')
        return
    }

    $TxtLog.AppendText("Initializing file download sequence...`r`n")
    
    try {
        $DomainMap = Get-Content -Path $ConfigFile | ConvertFrom-Json
    }
    catch {
        $TxtLog.AppendText("[ERROR] Failed to load config JSON: $_`r`n")
        return
    }

    try {
        $DumpData = Import-Csv -Path $InputFile -Delimiter "|" -Header "Timestamp", "Company", "FilePath"
    }
    catch {
        $TxtLog.AppendText("[ERROR] Failed to parse dump file: $_`r`n")
        return
    }

    $SuccessCount = 0
    $FailCount = 0

    foreach ($Row in $DumpData) {
        $CleanCompany = $Row.Company.Trim()
        $CleanPath = $Row.FilePath.Trim()

        if ($DomainMap.PSObject.Properties.Match($CleanCompany).Count -eq 0) {
            $TxtLog.AppendText("[SKIPPED] Unmapped Company: $CleanCompany`r`n")
            continue
        }

        $BaseUrl = $DomainMap.$CleanCompany
        $DocumentRoot = "/home3/$CleanCompany/public_html"

        if ($CleanPath -like "$DocumentRoot*") {
            $RelativePath = $CleanPath.Substring($DocumentRoot.Length) -replace "\\", "/"
            $Url = "$BaseUrl$RelativePath"
        } else {
            $TxtLog.AppendText("[SKIPPED] Outside Root: $CleanPath`r`n")
            continue
        }

        # Create company-specific subfolder
        $CompanyFolder = Join-Path $DownloadDir $CleanCompany
        if (-not (Test-Path $CompanyFolder)) {
            New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null
        }

        $FileName = Split-Path -Leaf $CleanPath
        if ([string]::IsNullOrWhiteSpace($FileName)) {
            $FileName = "index.html"
        }
        $DestinationFile = Join-Path $CompanyFolder $FileName

        try {
            Invoke-WebRequest -Uri $Url -OutFile $DestinationFile -TimeoutSec 15 -ErrorAction Stop
            $TxtLog.AppendText("[SUCCESS] Downloaded: $CleanCompany/$FileName`r`n")
            $SuccessCount++
        }
        catch {
            $TxtLog.AppendText("[FAILED] $FileName - $($_.Exception.Message)`r`n")
            $FailCount++
        }
    }

    $TxtLog.AppendText("Download complete! Success: $SuccessCount, Failed: $FailCount`r`n")
    [System.Windows.Forms.MessageBox]::Show("Download process completed!`nSuccess: $SuccessCount | Failed: $FailCount", "Finished", 'OK', 'Information')
})
$Form.Controls.Add($BtnRun)

[void]$Form.ShowDialog()