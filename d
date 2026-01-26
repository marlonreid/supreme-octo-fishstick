DECLARE @TargetObjectName NVARCHAR(255) = 'dbo.CentralStorage_Cleanup'; -- INCLUDE SCHEMA

WITH DependencyTree AS (
    -- BASE CASE: Get direct dependencies
    SELECT 
        referencing_id AS SourceID,
        referenced_id AS TargetID,
        OBJECT_SCHEMA_NAME(referencing_id) + '.' + OBJECT_NAME(referencing_id) AS SourceName,
        referenced_schema_name + '.' + referenced_entity_name AS TargetName,
        1 AS Level,
        CAST('FORMAL' AS VARCHAR(20)) AS DiscoveryMethod
    FROM sys.sql_expression_dependencies
    WHERE referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- RECURSIVE STEP: Indirect dependencies
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id),
        sed.referenced_schema_name + '.' + sed.referenced_entity_name,
        dt.Level + 1,
        'FORMAL'
    FROM sys.sql_expression_dependencies sed
    INNER JOIN DependencyTree dt ON sed.referencing_id = dt.TargetID
    WHERE sed.referenced_entity_name IS NOT NULL
),
CharacteristicScan AS (
    -- FEATURE FLAG CATCHER
    -- Looks for .Characteristic_Name = N'FlagName' or .Characteristic_Name='FlagName'
    SELECT 
        m.object_id AS SourceID,
        NULL AS TargetID,
        OBJECT_SCHEMA_NAME(m.object_id) + '.' + OBJECT_NAME(m.object_id) AS SourceName,
        -- Extract just the name between the quotes
        SUBSTRING(
            m.definition, 
            CHARINDEX('Characteristic_Name', m.definition), 
            100 -- Grab a chunk to parse
        ) AS RawMatch,
        1 AS Level,
        'CHARACTERISTIC' AS DiscoveryMethod
    FROM sys.sql_modules m
    WHERE m.object_id = OBJECT_ID(@TargetObjectName)
      AND m.definition LIKE '%Characteristic_Name%=' + '%'
)

-- Final Output
SELECT DISTINCT 
    SourceName, 
    TargetName, 
    Level, 
    DiscoveryMethod 
FROM DependencyTree
UNION ALL
-- This sub-select cleans up the characteristic string extraction
SELECT 
    SourceName,
    -- Simple cleanup logic to get the value inside the quotes
    REPLACE(REPLACE(REPLACE(
        SUBSTRING(RawMatch, CHARINDEX('=', RawMatch) + 1, 50), 
        'N''', ''), '''', ''), ';', '') AS TargetName,
    Level,
    DiscoveryMethod
FROM CharacteristicScan
ORDER BY Level, DiscoveryMethod DESC;
