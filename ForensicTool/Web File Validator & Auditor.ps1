try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create Main Form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Web File Validator & Auditor"
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

    # Output Directory Picker
    $LblOutput = New-Object System.Windows.Forms.Label
    $LblOutput.Location = New-Object System.Drawing.Point(20, 100)
    $LblOutput.Size = New-Object System.Drawing.Size(100, 20)
    $LblOutput.Text = "Output Dir:"
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

    # Mode Selector
    $LblMode = New-Object System.Windows.Forms.Label
    $LblMode.Location = New-Object System.Drawing.Point(20, 140)
    $LblMode.Size = New-Object System.Drawing.Size(100, 20)
    $LblMode.Text = "Execution Mode:"
    $Form.Controls.Add($LblMode)

    $CmbMode = New-Object System.Windows.Forms.ComboBox
    $CmbMode.Location = New-Object System.Drawing.Point(120, 138)
    $CmbMode.Size = New-Object System.Drawing.Size(150, 20)
    [void]$CmbMode.Items.AddRange(@("Test (Dry Run)", "Scan (Live HEAD)"))
    $CmbMode.SelectedIndex = 0
    $Form.Controls.Add($CmbMode)

    # Log Text Box
    $TxtLog = New-Object System.Windows.Forms.TextBox
    $TxtLog.Location = New-Object System.Drawing.Point(20, 175)
    $TxtLog.Size = New-Object System.Drawing.Size(485, 210)
    $TxtLog.Multiline = $true
    $TxtLog.ScrollBars = "Vertical"
    $TxtLog.ReadOnly = $true
    $Form.Controls.Add($TxtLog)

    # Execution Button
    $BtnRun = New-Object System.Windows.Forms.Button
    $BtnRun.Location = New-Object System.Drawing.Point(200, 395)
    $BtnRun.Size = New-Object System.Drawing.Size(120, 30)
    $BtnRun.Text = "Run Audit"
    $BtnRun.Add_Click({
        $InputFile = $TxtInput.Text
        $ConfigFile = $TxtConfig.Text
        $OutputDir = $TxtOutput.Text
        $SelectedMode = if ($CmbMode.SelectedItem -like "Test*") { "Test" } else { "Scan" }

        if (-not (Test-Path $InputFile)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid input dump file.", "Error", 'OK', 'Error')
            return
        }
        if (-not (Test-Path $ConfigFile)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid domains.json config file.", "Error", 'OK', 'Error')
            return
        }
        if (-not (Test-Path $OutputDir)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid output directory.", "Error", 'OK', 'Error')
            return
        }

        $TxtLog.AppendText("Initializing audit in [$SelectedMode] mode...`r`n")
        
        try {
            $DomainMap = Get-Content -Path $ConfigFile | ConvertFrom-Json
        }
        catch {
            $TxtLog.AppendText("[ERROR] Failed to load config JSON: $_`r`n")
            return
        }

        $Timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
        $TempCsvPath = Join-Path $OutputDir "Accessible_URLs_$Timestamp.csv"
        $TempLogPath = Join-Path $OutputDir "ScanLog_$Timestamp.txt"
        
        $VerifiedRecords = @()
        $LogEntries = @()

        try {
            $DumpData = Import-Csv -Path $InputFile -Delimiter "|" -Header "Timestamp", "Company", "FilePath"
        }
        catch {
            $TxtLog.AppendText("[ERROR] Failed to parse dump file: $_`r`n")
            return
        }

        foreach ($Row in $DumpData) {
            $CleanTimestamp = $Row.Timestamp.Trim()
            $CleanCompany   = $Row.Company.Trim()
            $CleanPath      = $Row.FilePath.Trim()

            if ($DomainMap.PSObject.Properties.Match($CleanCompany).Count -eq 0) {
                $LogEntries += "[SKIPPED] Unmapped Company: $CleanCompany"
                continue
            }

            $BaseUrl = $DomainMap.$CleanCompany
            $DocumentRoot = "/home3/$CleanCompany/public_html"

            if ($CleanPath -like "$DocumentRoot*") {
                $RelativePath = $CleanPath.Substring($DocumentRoot.Length) -replace "\\", "/"
                $Url = "$BaseUrl$RelativePath"
            } else {
                $LogEntries += "[SKIPPED] Path outside Document Root: $CleanPath"
                continue
            }

            if ($SelectedMode -eq "Test") {
                $LogEntries += "[TEST-OK] Simulated URL: $Url"
                $VerifiedRecords += [PSCustomObject]@{
                    Timestamp = $CleanTimestamp
                    Company   = $CleanCompany
                    Status    = "Simulated-OK"
                    Url       = $Url
                }
            } else {
                try {
                    $Response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 5 -ErrorAction Stop
                    if ($Response.StatusCode -eq 200) {
                        $LogEntries += "[LIVE-SUCCESS] 200 OK -> $Url"
                        $VerifiedRecords += [PSCustomObject]@{
                            Timestamp = $CleanTimestamp
                            Company   = $CleanCompany
                            Status    = "200 OK"
                            Url       = $Url
                        }
                    } else {
                        $LogEntries += "[LIVE-WARN] Status $($Response.StatusCode) -> $Url"
                    }
                }
                catch {
                    $LogEntries += "[LIVE-FAILED] $Url - $($_.Exception.Message)"
                }
            }
        }

        $LogEntries | Out-File -FilePath $TempLogPath -Encoding utf8
        if ($VerifiedRecords.Count -gt 0) {
            $VerifiedRecords | Export-Csv -Path $TempCsvPath -NoTypeInformation -Encoding utf8
        }

        $ZipPath = Join-Path $OutputDir "ScanResults_$Timestamp.zip"
        try {
            $FilesToZip = @($TempLogPath)
            if (Test-Path $TempCsvPath) { $FilesToZip += $TempCsvPath }
            Compress-Archive -Path $FilesToZip -DestinationPath $ZipPath -Force
            Remove-Item -Path $FilesToZip -Force
            $TxtLog.AppendText("Audit complete! Archive packaged: $ZipPath`r`n")
        }
        catch {
            $TxtLog.AppendText("[ERROR] Failed to compress reports: $_`r`n")
        }
    })
    $Form.Controls.Add($BtnRun)

    [void]$Form.ShowDialog()
}
catch {
    [System.Windows.Forms.MessageBox]::Show("A startup error occurred: $($_.Exception.Message)", "GUI Error", 'OK', 'Error')
}