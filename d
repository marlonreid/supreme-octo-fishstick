DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup'; -- Format: Schema.ProcName

WITH FormalTree AS (
    -- =============================================
    -- 1. ANCHOR: Direct Dependencies (Level 1)
    -- =============================================
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        
        -- Safe Source Name
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) 
             AS NVARCHAR(MAX)) AS SourceName,

        -- Safe Target Name (Handles missing schemas for broken objects)
        CAST(
            ISNULL(sed.referenced_schema_name, '???') + '.' + ISNULL(sed.referenced_entity_name, '???') 
            AS NVARCHAR(MAX)
        ) AS TargetName,
        
        1 AS Level,
        
        -- Path Tracking for Cycle Detection
        CAST('/' + CAST(sed.referencing_id AS VARCHAR(MAX)) + '/' + 
             ISNULL(CAST(sed.referenced_id AS VARCHAR(MAX)), '0') + '/' 
             AS VARCHAR(MAX)) AS Path

    FROM sys.sql_expression_dependencies sed
    WHERE sed.referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- =============================================
    -- 2. RECURSIVE MEMBER: Indirect Dependencies (Level 2+)
    -- =============================================
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) 
             AS NVARCHAR(MAX)),

        CAST(
            ISNULL(sed.referenced_schema_name, '???') + '.' + ISNULL(sed.referenced_entity_name, '???') 
            AS NVARCHAR(MAX)
        ),
        
        t.Level + 1,
        
        -- Update Path
        CAST(t.Path + ISNULL(CAST(sed.referenced_id AS VARCHAR(MAX)), '0') + '/' AS VARCHAR(MAX))

    FROM sys.sql_expression_dependencies sed
    INNER JOIN FormalTree t ON sed.referencing_id = t.referenced_id
    WHERE sed.referenced_entity_name IS NOT NULL
      -- STOP if we have seen this ID before in the current chain (Cycle Check)
      AND t.Path NOT LIKE '%/' + ISNULL(CAST(sed.referenced_id AS VARCHAR(MAX)), '0') + '/%'
)

-- =============================================
-- 3. FINAL OUTPUT
-- =============================================
SELECT DISTINCT 
    SourceName, 
    TargetName, 
    Level, 
    'FORMAL' AS Method
FROM FormalTree
ORDER BY Level, TargetName
OPTION (MAXRECURSION 300);


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
