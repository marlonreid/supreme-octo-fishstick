# =========================================================
# CONFIGURATION
# =========================================================
$VaultRoot = "C:\Obsidian\MyVault\AI"  # Change this to your vault path
$CsvPath_Formal = ".\formal.csv"       # Output from Script 1
$CsvPath_Dynamic = ".\dynamic.csv"     # Output from Script 3 (Text Scan)
$CsvPath_Chars = ".\characteristics.csv" # Output from Script 2 (Flags)

# Folder Mapping: SQL Type -> Obsidian Folder Name
$TypeMap = @{
    "SQL_STORED_PROCEDURE" = "stored procedures"
    "USER_TABLE"           = "tables"
    "SQL_SCALAR_FUNCTION"  = "functions"
    "SQL_TABLE_VALUED_FUNCTION" = "functions"
    "VIEW"                 = "views"
    "CHARACTERISTIC"       = "characteristics"
}

# =========================================================
# 1. LOAD AND PREPARE DATA
# =========================================================
Write-Host "Reading CSV files..." -ForegroundColor Cyan

$Dependencies = @()

# Import Formal (Expects: SourceName, TargetName, SourceType, TargetType)
if (Test-Path $CsvPath_Formal) { 
    $Dependencies += Import-Csv $CsvPath_Formal | Select-Object *, @{N='Origin';E={'Formal'}} 
}

# Import Dynamic (Expects: SourceName, TargetName) - We assume SourceType is Proc
if (Test-Path $CsvPath_Dynamic) {
    $Dependencies += Import-Csv $CsvPath_Dynamic | Select-Object *, @{N='Origin';E={'Dynamic'}} 
}

# Import Characteristics (Expects: SourceName, TargetName)
if (Test-Path $CsvPath_Chars) {
    $Dependencies += Import-Csv $CsvPath_Chars | Select-Object *, @{N='Origin';E={'Characteristic'}} 
}

# Group by the Source Object (The file we are creating)
$FilesToCreate = $Dependencies | Group-Object SourceName

# =========================================================
# 2. GENERATE MARKDOWN FILES
# =========================================================
foreach ($File in $FilesToCreate) {
    $ObjectName = $File.Name
    
    # Determine Object Type (Take the first non-null type found for this object)
    $RawType = $File.Group | Where-Object { $_.SourceObjectType -ne $null } | Select-Object -ExpandProperty SourceObjectType -First 1
    if (-not $RawType) { $RawType = "SQL_STORED_PROCEDURE" } # Default fallback
    
    # Map to Folder Name
    $Folder = $TypeMap[$RawType]
    if (-not $Folder) { $Folder = "others" }
    
    # Create Directory if missing
    $FullFolderPath = Join-Path $VaultRoot $Folder
    if (-not (Test-Path $FullFolderPath)) { New-Item -ItemType Directory -Force -Path $FullFolderPath | Out-Null }

    # Build the 'down' list (Dependencies)
    $DownList = @()
    
    # Process Formal/Dynamic Links
    foreach ($Row in $File.Group) {
        if (-not [string]::IsNullOrWhiteSpace($Row.TargetName)) {
            # Format: "[[schema.Object]]"
            # We use distinct to avoid duplicates if found in multiple scripts
            $Link = '"[[{0}]]"' -f $Row.TargetName
            if ($DownList -notcontains $Link) {
                $DownList += $Link
            }
        }
    }

    # =========================================================
    # 3. CONSTRUCT FILE CONTENT
    # =========================================================
    $Content = @()
    $Content += "---"
    
    # Property: Type (Clean up 'SQL_' prefix for readability if desired, or use raw)
    $CleanType = $Folder -replace "s$", "" # e.g. "tables" -> "table"
    $Content += "type: $CleanType"
    
    # Property: Down (Direct Dependencies)
    if ($DownList.Count -gt 0) {
        $Content += "down:"
        foreach ($Link in $DownList) {
            $Content += "  - $Link"
        }
    } else {
        $Content += "down: []"
    }
    
    $Content += "---"
    $Content += ""
    $Content += "### Description"
    $Content += "*(Auto-generated placeholder)*"
    $Content += ""
    $Content += "```dataviewjs"
    $Content += 'await dv.view("_scripts/dependencies")'
    $Content += "```"

    # =========================================================
    # 4. WRITE FILE
    # =========================================================
    # Sanitize Filename (Just in case)
    $SafeName = $ObjectName -replace '[\\/*?:"<>|]', '_'
    $FilePath = Join-Path $FullFolderPath "$SafeName.md"
    
    Set-Content -Path $FilePath -Value ($Content -join "`n") -Encoding UTF8
    Write-Host "Created: $Folder\$SafeName.md" -ForegroundColor Green
}

Write-Host "Done! Vault updated." -ForegroundColor Cyan
