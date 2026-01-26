DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup';

WITH FormalTree AS (
    -- ANCHOR: Direct Dependencies
-- ANCHOR: Direct Dependencies
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS NVARCHAR(MAX)) AS SourceName,
        -- FIXED: Handle NULL Schemas
        CAST(ISNULL(sed.referenced_schema_name, '???') + '.' + ISNULL(sed.referenced_entity_name, '???') AS NVARCHAR(MAX)) AS TargetName,
        1 AS Level,
        CAST('/' + CAST(sed.referencing_id AS VARCHAR(MAX)) + '/' + CAST(sed.referenced_id AS VARCHAR(MAX)) + '/' AS VARCHAR(MAX)) AS Path
    FROM sys.sql_expression_dependencies sed
    WHERE sed.referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- RECURSIVE: What do those dependencies call?
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS NVARCHAR(MAX)),
        CAST(sed.referenced_schema_name + '.' + sed.referenced_entity_name AS NVARCHAR(MAX)),
        t.Level + 1,
        CAST(t.Path + CAST(sed.referenced_id AS VARCHAR(MAX)) + '/' AS VARCHAR(MAX))
    FROM sys.sql_expression_dependencies sed
    INNER JOIN FormalTree t ON sed.referencing_id = t.referenced_id
    WHERE sed.referenced_entity_name IS NOT NULL
      -- STOP if we have seen this ID before in the current chain
      AND t.Path NOT LIKE '%/' + CAST(sed.referenced_id AS VARCHAR(MAX)) + '/%'
)
SELECT DISTINCT 
    SourceName, 
    TargetName, 
    Level, 
    'FORMAL' AS Method
FROM FormalTree
ORDER BY Level
OPTION (MAXRECURSION 300); -- Bump limit slightly, but the Path logic handles the loops



-------------------------------------


DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup';

SELECT 
    OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) AS SourceName,
    -- Extract the flag name, cleaning up N', ', and ;
    REPLACE(REPLACE(REPLACE(REPLACE(
        SUBSTRING(
            definition, 
            PATINDEX('%Characteristic_Name%=[N'']%', definition) + 20, 
            50 -- Grab enough characters to catch the name
        ), 
    'N''', ''), '''', ''), ';', ''), ' ', '') AS TargetName,
    1 AS Level,
    'CHARACTERISTIC' AS Method
FROM sys.sql_modules
WHERE object_id = OBJECT_ID(@TargetObjectName)
  AND definition LIKE '%Characteristic_Name%=[N'']%';



-------------------------


DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup';

SELECT DISTINCT
    OBJECT_SCHEMA_NAME(m.object_id) + '.' + OBJECT_NAME(m.object_id) AS SourceName,
    t.name AS TargetName,
    1 AS Level,
    'DYNAMIC_TEXT' AS Method
FROM sys.sql_modules m
CROSS JOIN sys.tables t
WHERE m.object_id = OBJECT_ID(@TargetObjectName)
  -- Find table name surrounded by non-alphanumeric chars
  AND m.definition LIKE '%[^a-z0-9]' + t.name + '[^a-z0-9]%'
ORDER BY TargetName;    
