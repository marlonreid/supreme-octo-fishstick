DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup'; -- Format: Schema.ProcName

WITH FormalTree AS (
    -- =============================================
    -- 1. ANCHOR: Direct Dependencies (Level 1)
    -- =============================================
    SELECT 
        sed.referencing_id,
        sed.referenced_id,
        
        -- Source Name
        CAST(OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) 
             AS NVARCHAR(MAX)) AS SourceName,

        -- Target Name (Handles missing schemas)
        CAST(
            ISNULL(sed.referenced_schema_name, '???') + '.' + ISNULL(sed.referenced_entity_name, '???') 
            AS NVARCHAR(MAX)
        ) AS TargetName,
        
        1 AS Level,
        
        -- Path Tracking
        CAST('/' + CAST(sed.referencing_id AS VARCHAR(MAX)) + '/' + 
             ISNULL(CAST(sed.referenced_id AS VARCHAR(MAX)), '0') + '/' 
             AS VARCHAR(MAX)) AS Path

    FROM sys.sql_expression_dependencies sed
    WHERE sed.referencing_id = OBJECT_ID(@TargetObjectName)

    UNION ALL

    -- =============================================
    -- 2. RECURSIVE MEMBER: Indirect Dependencies (Level 2+)
    -- NO OUTER JOINS ALLOWED HERE
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
      -- Cycle Check
      AND t.Path NOT LIKE '%/' + ISNULL(CAST(sed.referenced_id AS VARCHAR(MAX)), '0') + '/%'
)

-- =============================================
-- 3. FINAL OUTPUT
-- Join to sys.objects happens HERE, outside the recursion
-- =============================================
SELECT DISTINCT 
    ft.SourceName, 
    ft.TargetName, 
    -- If join fails (ID is null or object gone), it's a broken ref
    ISNULL(obj.type_desc, 'BROKEN_REF') AS TargetType,
    ft.Level, 
    'FORMAL' AS Method
FROM FormalTree ft
LEFT JOIN sys.objects obj ON ft.referenced_id = obj.object_id
ORDER BY ft.Level, ft.TargetName
OPTION (MAXRECURSION 300);


-------------------------------------
DECLARE @TargetObjectName NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup';

-- 1. Get the Code
DECLARE @Code NVARCHAR(MAX);
SELECT @Code = definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(@TargetObjectName);

-- 2. "Token Hopping" Recursive Search
WITH FlagScanner AS (
    -- ANCHOR: Find the first occurrence
    SELECT 
        1 AS MatchID,
        -- Find 'Characteristic_Name'
        CHARINDEX('Characteristic_Name', @Code) AS KeywordPos,
        -- Find next '=' after Keyword
        CHARINDEX('=', @Code, CHARINDEX('Characteristic_Name', @Code)) AS EqualsPos,
        -- Find next "'" after '='
        CHARINDEX('''', @Code, CHARINDEX('=', @Code, CHARINDEX('Characteristic_Name', @Code))) AS OpenQuotePos
    WHERE CHARINDEX('Characteristic_Name', @Code) > 0

    UNION ALL

    -- RECURSIVE: Search for the next one starting AFTER the last match closed
    SELECT 
        MatchID + 1,
        -- Find next 'Characteristic_Name' after the previous quote closed
        CHARINDEX('Characteristic_Name', @Code, CloseQuotePos + 1),
        -- Find next '='
        CHARINDEX('=', @Code, CHARINDEX('Characteristic_Name', @Code, CloseQuotePos + 1)),
        -- Find next "'"
        CHARINDEX('''', @Code, CHARINDEX('=', @Code, CHARINDEX('Characteristic_Name', @Code, CloseQuotePos + 1)))
    FROM (
        -- Inner calculation to find the closing quote of the CURRENT match so we know where to start looking for the NEXT one
        SELECT 
            MatchID,
            KeywordPos,
            EqualsPos,
            OpenQuotePos,
            -- Find the closing quote (start looking 1 char after open quote)
            CHARINDEX('''', @Code, OpenQuotePos + 1) AS CloseQuotePos
        FROM FlagScanner
    ) AS Prev
    WHERE CHARINDEX('Characteristic_Name', @Code, CloseQuotePos + 1) > 0
)

-- 3. Extract and Clean
SELECT DISTINCT
    OBJECT_SCHEMA_NAME(OBJECT_ID(@TargetObjectName)) + '.' + OBJECT_NAME(OBJECT_ID(@TargetObjectName)) AS SourceName,
    SUBSTRING(
        @Code, 
        OpenQuotePos + 1, 
        CHARINDEX('''', @Code, OpenQuotePos + 1) - (OpenQuotePos + 1)
    ) AS TargetName,
    1 AS Level,
    'CHARACTERISTIC' AS Method
FROM (
    SELECT 
        MatchID, OpenQuotePos,
        -- Recalculate CloseQuotePos for the final extraction
        CHARINDEX('''', @Code, OpenQuotePos + 1) AS CloseQuotePos
    FROM FlagScanner
) Final
WHERE OpenQuotePos > 0 AND CloseQuotePos > 0
ORDER BY TargetName;
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
