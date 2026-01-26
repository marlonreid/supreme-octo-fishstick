DECLARE @TargetProc NVARCHAR(MAX) = 'dbo.CentralStorage_Cleanup'; -- Format: Schema.ProcName

-- =============================================
-- 1. FORMAL DEPENDENCIES
-- C# Index: 0=Source, 1=SourceType, 2=Target, 3=TargetType, 4=RowType
-- =============================================
SELECT 
    -- [0] SourceName
    OBJECT_SCHEMA_NAME(sed.referencing_id) + '.' + OBJECT_NAME(sed.referencing_id) AS SourceName,
    
    -- [1] SourceObjectType
    'SQL_STORED_PROCEDURE' AS SourceObjectType,
    
    -- [2] TargetName (The Dependency)
    ISNULL(sed.referenced_schema_name, '???') + '.' + ISNULL(sed.referenced_entity_name, '???') AS TargetName,
    
    -- [3] TargetType (e.g., USER_TABLE)
    ISNULL(obj.type_desc, 'BROKEN_REF') AS TargetType,
    
    -- [4] RowType
    'DEPENDENCY' AS RowType 
FROM sys.sql_expression_dependencies sed
LEFT JOIN sys.objects obj ON sed.referenced_id = obj.object_id
WHERE sed.referencing_id = OBJECT_ID(@TargetProc)

UNION ALL

-- =============================================
-- 2. INPUT PARAMETERS
-- =============================================
SELECT 
    -- [0] SourceName
    OBJECT_SCHEMA_NAME(p.object_id) + '.' + OBJECT_NAME(p.object_id) AS SourceName,
    
    -- [1] SourceObjectType
    'SQL_STORED_PROCEDURE' AS SourceObjectType,

    -- [2] TargetName (The Parameter Name)
    p.name AS TargetName,

    -- [3] TargetType (The Data Type)
    -- CRITICAL: We replace commas with spaces (e.g. DECIMAL(10,2) -> DECIMAL(10 2))
    -- This prevents breaking the C# CSV split logic.
    REPLACE(
        TYPE_NAME(p.user_type_id) + 
        CASE 
            WHEN TYPE_NAME(p.user_type_id) IN ('varchar', 'nvarchar', 'char', 'nchar') 
            THEN '(' + CAST(CASE WHEN p.max_length = -1 THEN 'MAX' ELSE CAST(p.max_length AS VARCHAR) END AS VARCHAR) + ')'
            WHEN TYPE_NAME(p.user_type_id) IN ('decimal', 'numeric')
            THEN '(' + CAST(p.precision AS VARCHAR) + ' ' + CAST(p.scale AS VARCHAR) + ')'
            ELSE '' 
        END +
        CASE WHEN p.is_output = 1 THEN ' (OUTPUT)' ELSE '' END,
        ',', ' '
    ) AS TargetType,

    -- [4] RowType
    'PARAMETER' AS RowType
FROM sys.parameters p
WHERE p.object_id = OBJECT_ID(@TargetProc);
