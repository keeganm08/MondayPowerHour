[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $true)]
    [string]$DownloadDir
)

Begin {
    Write-Host "Starting Web File Downloader Tool..." -ForegroundColor Cyan
    
    # 1. Load the Domain Configuration mapping
    try {
        $DomainMap = Get-Content -Path $ConfigFile | ConvertFrom-Json
        Write-Host "Successfully loaded domain configuration." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to load ConfigFile. Ensure it is valid JSON."
        exit
    }

    # Ensure download base directory exists
    if (-not (Test-Path -Path $DownloadDir)) {
        New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
    }

    $DownloadedFilesRecord = @()
    $LogEntries = @()
    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $TempCsvPath = ".\Downloaded_Report_$Timestamp.csv"
    $TempLogPath = ".\DownloadLog_$Timestamp.txt"
}

Process {
    # 2. Parse the Input File
    Write-Host "Parsing input file: $InputFile"
    $DumpData = Import-Csv -Path $InputFile -Delimiter "|" -Header "Timestamp", "Company", "FilePath"

    foreach ($Row in $DumpData) {
        $CleanTimestamp = $Row.Timestamp.Trim()
        $CleanCompany   = $Row.Company.Trim()
        $CleanPath      = $Row.FilePath.Trim()

        # 3. Domain Mapping Validation
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

        # 4. Download Execution
        # Create a company-specific subfolder to keep downloads organized
        $CompanyFolder = Join-Path $DownloadDir $CleanCompany
        if (-not (Test-Path -Path $CompanyFolder)) {
            New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null
        }

        # Extract filename from path, handling edge cases where path ends in a slash
        $FileName = Split-Path -Leaf $CleanPath
        if ([string]::IsNullOrWhiteSpace($FileName)) {
            $FileName = "index.html"
        }

        $DestinationFile = Join-Path $CompanyFolder $FileName

        try {
            # Execute download with a timeout
            Invoke-WebRequest -Uri $Url -OutFile $DestinationFile -TimeoutSec 10 -ErrorAction Stop
            
            $DownloadedFilesRecord += [PSCustomObject]@{
                DownloadedAt = Get-Date
                Company      = $CleanCompany
                SourceUrl    = $Url
                LocalPath    = $DestinationFile
            }
            $LogEntries += "[SUCCESS] Downloaded: $Url -> $DestinationFile"
        }
        catch {
            $LogEntries += "[FAILED] Could not download $Url - $($_.Exception.Message)"
        }
    }
}

End {
    # 5. Output Reporting and Zipping
    Write-Host "Download process complete. Packaging results..." -ForegroundColor Cyan

    $FilesToZip = @()

    # Write Log File
    $LogEntries | Out-File -FilePath $TempLogPath
    $FilesToZip += $TempLogPath

    # Write CSV Report if we successfully downloaded files
    if ($DownloadedFilesRecord.Count -gt 0) {
        $DownloadedFilesRecord | Export-Csv -Path $TempCsvPath -NoTypeInformation
        $FilesToZip += $TempCsvPath
    }

    # Also optionally include the downloaded folder structure into the zip, or keep it separate. 
    # Here we zip the report and log, while leaving the downloaded files safely in their directory.
    if ($FilesToZip.Count -gt 0) {
        $ZipDestination = ".\DownloadReport_$Timestamp.zip"
        Compress-Archive -Path $FilesToZip -DestinationPath $ZipDestination -Force
        Remove-Item -Path $FilesToZip -Force
        Write-Host "Report and logs zipped successfully: $ZipDestination" -ForegroundColor Green
    }
}