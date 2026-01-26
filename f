# =========================================================
# CONFIGURATION
# =========================================================
# The Vault Root is ONE LEVEL UP from where this script runs
$VaultRoot = Resolve-Path ".." 

# Map SQL Types to Obsidian Folder Names
$TypeMap = @{
    "SQL_STORED_PROCEDURE"      = "stored procedures"
    "USER_TABLE"                = "tables"
    "SQL_SCALAR_FUNCTION"       = "functions"
    "SQL_TABLE_VALUED_FUNCTION" = "functions"
    "VIEW"                      = "views"
    "CHARACTERISTIC"            = "characteristics"
}

# =========================================================
# 1. PROCESS FOLDERS
# =========================================================
$DataFolders = Get-ChildItem -Directory

Write-Host "Found $($DataFolders.Count) object folders. Processing..." -ForegroundColor Cyan

foreach ($Folder in $DataFolders) {
    $ProcName = $Folder.Name
    
    # Paths to the CSVs inside the current Proc's folder
    $CsvPath_Formal  = Join-Path $Folder.FullName "formal.csv"
    $CsvPath_Dynamic = Join-Path $Folder.FullName "dynamic.csv"
    $CsvPath_Chars   = Join-Path $Folder.FullName "characteristics.csv"

    $DownList = @()
    $ObjectType = "SQL_STORED_PROCEDURE" # Default

    # --- 1A. Process FORMAL CSV ---
    if (Test-Path $CsvPath_Formal) {
        $Data = Import-Csv $CsvPath_Formal
        foreach ($Row in $Data) {
            # Capture Object Type from the first row that defines the source
            if ($Row.Level -eq "1" -and $Row.SourceName -eq $ProcName -and $Row.SourceObjectType) {
                $ObjectType = $Row.SourceObjectType
            }
            
            # Add Direct Dependencies (Level 1)
            if ($Row.Level -eq "1" -and !([string]::IsNullOrWhiteSpace($Row.TargetName))) {
                $Link = '"[[{0}]]"' -f $Row.TargetName
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # --- 1B. Process DYNAMIC CSV ---
    if (Test-Path $CsvPath_Dynamic) {
        $Data = Import-Csv $CsvPath_Dynamic
        foreach ($Row in $Data) {
            if (!([string]::IsNullOrWhiteSpace($Row.TargetName))) {
                $Link = '"[[{0}]]"' -f $Row.TargetName
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # --- 1C. Process CHARACTERISTICS CSV ---
    if (Test-Path $CsvPath_Chars) {
        $Data = Import-Csv $CsvPath_Chars
        foreach ($Row in $Data) {
            if (!([string]::IsNullOrWhiteSpace($Row.TargetName))) {
                $Link = '"[[{0}]]"' -f $Row.TargetName
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # =========================================================
    # 2. FILE CREATION
    # =========================================================
    
    # Determine Target Folder based on Type
    $TargetFolder = $TypeMap[$ObjectType]
    if (-not $TargetFolder) { $TargetFolder = "others" }
    
    # Ensure Folder Exists in Parent Root
    $FullFolderPath = Join-Path $VaultRoot $TargetFolder
    if (-not (Test-Path $FullFolderPath)) { 
        New-Item -ItemType Directory -Force -Path $FullFolderPath | Out-Null 
    }

    # Build File Content
    $CleanType = $TargetFolder.TrimEnd('s') # e.g. "tables" -> "table"
    
    $Content = @()
    $Content += "---"
    $Content += "type: $CleanType"
    
    if ($DownList.Count -gt 0) {
        $Content += "down:"
        $SortedLinks = $DownList | Sort-Object
        foreach ($Link in $SortedLinks) {
            $Content += "  - $Link"
        }
    } else {
        $Content += "down: []"
    }
    
    $Content += "---"
    $Content += ""
    $Content += "```dataviewjs"
    $Content += 'await dv.view("_scripts/dependencies")'
    $Content += "```"

    # Write File - Assuming ProcName is a valid filename
    $FilePath = Join-Path $FullFolderPath "$ProcName.md"
    
    Set-Content -Path $FilePath -Value ($Content -join "`n") -Encoding UTF8
    Write-Host "Created: $ProcName.md" -ForegroundColor Green
}
