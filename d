DECLARE @TargetObjectName NVARCHAR(255) = 'dbo.CentralStorage_Cleanup'; 

WITH DependencyTree AS (
    -- 1. ANCHOR: Direct dependencies
    SELECT 
        referencing_id AS SourceID,
        referenced_id AS TargetID,
        CAST(OBJECT_SCHEMA_NAME(referencing_id) + '.' + OBJECT_NAME(referencing_id) AS NVARCHAR(500)) AS SourceName,
        CAST(referenced_schema_name + '.' + referenced_entity_name AS NVARCHAR(500)) AS TargetName,
        1 AS Level,
        CAST('FORMAL' AS VARCHAR(20)) AS DiscoveryMethod
    FROM sys.sql_expression_dependencies
    WHERE referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- 2. RECURSIVE: Indirect dependencies
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS NVARCHAR(500)),
        CAST(sed.referenced_schema_name + '.' + sed.referenced_entity_name AS NVARCHAR(500)),
        dt.Level + 1,
        CAST('FORMAL' AS VARCHAR(20)) -- Type match for recursion
    FROM sys.sql_expression_dependencies sed
    INNER JOIN DependencyTree dt ON sed.referencing_id = dt.TargetID
    WHERE sed.referenced_entity_name IS NOT NULL
),
CharacteristicScan AS (
    -- 3. CHARACTERISTIC CATCHER
    SELECT 
        m.object_id AS SourceID,
        CAST(OBJECT_SCHEMA_NAME(m.object_id) + '.' + OBJECT_NAME(m.object_id) AS NVARCHAR(500)) AS SourceName,
        -- Extract the chunk containing the flag
        CAST(SUBSTRING(m.definition, CHARINDEX('Characteristic_Name', m.definition), 200) AS NVARCHAR(500)) AS RawMatch
    FROM sys.sql_modules m
    WHERE m.object_id = OBJECT_ID(@TargetObjectName)
      AND m.definition LIKE '%Characteristic_Name%=' + '%'
)

-- FINAL OUTPUT: Merging all discovered links
SELECT DISTINCT 
    SourceName, 
    TargetName, 
    Level, 
    DiscoveryMethod 
FROM DependencyTree

UNION ALL

-- Adding cleaned Characteristic results
SELECT 
    SourceName,
    -- Cleaning the extracted N'name' or 'name' string
    CAST(REPLACE(REPLACE(REPLACE(
        SUBSTRING(RawMatch, CHARINDEX('=', RawMatch) + 1, 100), 
        'N''', ''), '''', ''), ';', '') AS NVARCHAR(500)) AS TargetName,
    1 AS Level,
    CAST('CHARACTERISTIC' AS VARCHAR(20)) AS DiscoveryMethod
FROM CharacteristicScan

ORDER BY Level, DiscoveryMethod DESC;
