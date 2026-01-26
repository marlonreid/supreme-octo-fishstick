DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup'; -- Format: Schema.ProcName

WITH DependencyTree AS (
    -- ANCHOR: Direct Dependencies
    SELECT 
        sed.referencing_id AS SourceID,
        sed.referenced_id AS TargetID,
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS NVARCHAR(MAX)) AS SourceName,
        CAST(sed.referenced_schema_name + '.' + sed.referenced_entity_name AS NVARCHAR(MAX)) AS TargetName,
        1 AS Level,
        CAST(N'FORMAL' AS NVARCHAR(50)) AS DiscoveryMethod
    FROM sys.sql_expression_dependencies sed
    WHERE sed.referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- RECURSIVE MEMBER: Indirect Dependencies
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS NVARCHAR(MAX)),
        CAST(sed.referenced_schema_name + '.' + sed.referenced_entity_name AS NVARCHAR(MAX)),
        dt.Level + 1,
        CAST(N'FORMAL' AS NVARCHAR(50)) -- Must match Anchor Type exactly (NVARCHAR 50)
    FROM sys.sql_expression_dependencies sed
    INNER JOIN DependencyTree dt ON sed.referencing_id = dt.TargetID
    WHERE sed.referenced_entity_name IS NOT NULL
),
CharacteristicScan AS (
    -- FEATURE FLAG SCANNER (Regex-ish search)
    SELECT 
        m.object_id AS SourceID,
        CAST(NULL AS INT) AS TargetID, -- Placeholder to match column count if needed
        CAST(OBJECT_SCHEMA_NAME(m.object_id) + '.' + OBJECT_NAME(m.object_id) AS NVARCHAR(MAX)) AS SourceName,
        -- Extract the value after "Characteristic_Name="
        CAST(SUBSTRING(
            m.definition, 
            PATINDEX('%Characteristic_Name%=[N'']%', m.definition) + 20, 
            50
        ) AS NVARCHAR(MAX)) AS RawMatch,
        1 AS Level,
        CAST(N'CHARACTERISTIC' AS NVARCHAR(50)) AS DiscoveryMethod
    FROM sys.sql_modules m
    WHERE m.object_id = OBJECT_ID(@TargetObjectName)
      AND m.definition LIKE '%Characteristic_Name%=[N'']%'
)

-- FINAL OUTPUT
SELECT DISTINCT
    SourceName,
    TargetName,
    Level,
    DiscoveryMethod
FROM DependencyTree

UNION ALL

-- Clean up the Characteristic data before showing it
SELECT 
    SourceName,
    -- Clean up quotes, semi-colons, and N prefixes from the extracted value
    CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(
            LEFT(RawMatch, CHARINDEX('''', RawMatch + '''') - 1), 
        'N''', ''), '''', ''), ';', ''), ' ', '') 
    AS NVARCHAR(MAX)) AS TargetName,
    Level,
    DiscoveryMethod
FROM CharacteristicScan
WHERE RawMatch IS NOT NULL
ORDER BY Level, DiscoveryMethod DESC;
