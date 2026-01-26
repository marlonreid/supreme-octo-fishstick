# =========================================================
# CONFIGURATION
# =========================================================
# The Vault Root is ONE LEVEL UP from where this script runs
$VaultRoot = Resolve-Path ".." 

# Mapping SQL Types to Obsidian Folder Names
$TypeMap = @{
    "SQL_STORED_PROCEDURE"      = "stored procedures"
    "USER_TABLE"                = "tables"
    "SQL_SCALAR_FUNCTION"       = "functions"
    "SQL_TABLE_VALUED_FUNCTION" = "functions"
    "VIEW"                      = "views"
    "CHARACTERISTIC"            = "characteristics"
}

# =========================================================
# 1. FIND ALL DATA FOLDERS
# =========================================================
# We look for folders in the current directory
$DataFolders = Get-ChildItem -Directory

Write-Host "Found $($DataFolders.Count) object folders to process..." -ForegroundColor Cyan

foreach ($Folder in $DataFolders) {
    $ProcName = $Folder.Name
    Write-Host "Processing: $ProcName" -NoNewline
    
    # Paths to the specific CSVs inside this folder
    $CsvPath_Formal  = Join-Path $Folder.FullName "formal.csv"
    $CsvPath_Dynamic = Join-Path $Folder.FullName "dynamic.csv"
    $CsvPath_Chars   = Join-Path $Folder.FullName "characteristics.csv"

    $DownList = @()
    $ObjectType = "SQL_STORED_PROCEDURE" # Default if not found in CSV

    # =========================================================
    # 2. READ AND MERGE DATA
    # =========================================================
    
    # --- Process FORMAL Dependencies ---
    if (Test-Path $CsvPath_Formal) {
        $Data = Import-Csv $CsvPath_Formal
        foreach ($Row in $Data) {
            # Try to grab the object type from the first row of the formal export
            if ($Row.Level -eq "1" -and $Row.SourceName -eq $ProcName -and $Row.SourceObjectType) {
                $ObjectType = $Row.SourceObjectType
            }
            
            # Only add Level 1 (Direct) dependencies to the YAML
            if ($Row.Level -eq "1" -and -not [string]::IsNullOrWhiteSpace($Row.TargetName)) {
                $Link = '"[[{0}]]"' -f $Row.TargetName
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # --- Process DYNAMIC Dependencies ---
    if (Test-Path $CsvPath_Dynamic) {
        $Data = Import-Csv $CsvPath_Dynamic
        foreach ($Row in $Data) {
            if (-not [string]::IsNullOrWhiteSpace($Row.TargetName)) {
                $Link = '"[[{0}]]"' -f $Row.TargetName
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # --- Process CHARACTERISTICS ---
    # These might be better as Tags, but if you want them in 'down', keep them here.
    if (Test-Path $CsvPath_Chars) {
        $Data = Import-Csv $CsvPath_Chars
        foreach ($Row in $Data) {
            if (-not [string]::IsNullOrWhiteSpace($Row.TargetName)) {
                # Optional: Prefix with "Feature: " or just link to the flag note
                $Link = '"[[{0}]]"' -f $Row.TargetName 
                if ($DownList -notcontains $Link) { $DownList += $Link }
            }
        }
    }

    # =========================================================
    # 3. DETERMINE DESTINATION
    # =========================================================
    $TargetFolder = $TypeMap[$ObjectType]
    if (-not $TargetFolder) { $TargetFolder = "others" }
    
    $FullFolderPath = Join-Path $VaultRoot $TargetFolder
    if (-not (Test-Path $FullFolderPath)) { 
        New-Item -ItemType Directory -Force -Path $FullFolderPath | Out-Null 
    }

    # =========================================================
    # 4. BUILD MARKDOWN CONTENT
    # =========================================================
    $CleanType = $TargetFolder -replace "s$", "" # stored procedures -> stored procedure

    $Content = @()
    $Content += "---"
    $Content += "type: $CleanType"
    
    if ($DownList.Count -gt 0) {
        $Content += "down:"
        # Sort links alphabetically for neatness
        foreach ($Link in ($DownList | Sort-Object)) {
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

# ... inside the foreach loop ...

    # =========================================================
    # 5. WRITE FILE
    # =========================================================
    
    # Sanitize Filename: Allow only alphanumeric, spaces, dots, dashes, underscores
    $SafeName = $ProcName -replace '[^a-zA-Z0-9\s\.\-_]', '_'
    
    $FilePath = Join-Path $FullFolderPath "$SafeName.md"
    
    Set-Content -Path $FilePath -Value ($Content -join "`n") -Encoding UTF8
    Write-Host " -> OK ($SafeName.md)" -ForegroundColor Green
}
