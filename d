/* THE ULTIMATE LEGACY DEPENDENCY SCANNER
   Targets: Procs, Functions, Tables, Views.
   Captures: Formal Dependencies + Dynamic SQL Text Matches.
*/

WITH AllObjects AS (
    -- Get all potential 'Source' objects (Procs and Functions)
    SELECT object_id, name, type_desc, type
    FROM sys.objects 
    WHERE type IN ('P', 'FN', 'IF', 'TF')
),
FormalDependencies AS (
    -- Method 1: The Formal SQL Engine
    SELECT 
        referencing_id AS SourceID,
        referenced_entity_name AS TargetName,
        'FORMAL' AS DiscoveryMethod
    FROM sys.sql_expression_dependencies
),
DynamicDependencies AS (
    -- Method 2: Text Mining for Dynamic SQL (The 'Gibberish' catcher)
    -- We cross-join Procs against Table/Function names
    SELECT 
        obj.object_id AS SourceID,
        target.name AS TargetName,
        'TEXT_MATCH' AS DiscoveryMethod
    FROM AllObjects obj
    JOIN sys.sql_modules mod ON obj.object_id = mod.object_id
    CROSS JOIN (
        -- Everything we might want to link to
        SELECT name FROM sys.objects WHERE type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
    ) target
    WHERE obj.name <> target.name -- Don't link an object to itself
      -- This regex-like check ensures we don't get partial word matches (e.g., 'Order' in 'OrderBy')
      AND mod.definition LIKE '%[^a-z0-9]' + target.name + '[^a-z0-9]%'
)

SELECT DISTINCT
    src.name AS [SourceObjectName],
    src.type_desc AS [SourceObjectType],
    deps.TargetName AS [ReferencedObjectName],
    deps.DiscoveryMethod
FROM (
    SELECT SourceID, TargetName, DiscoveryMethod FROM FormalDependencies
    UNION
    SELECT SourceID, TargetName, DiscoveryMethod FROM DynamicDependencies
) deps
JOIN AllObjects src ON deps.SourceID = src.object_id
-- Optional: Filter out system objects
WHERE src.name NOT LIKE 'sp_%' 
  AND deps.TargetName NOT IN ('sysname', 'dtproperties')
ORDER BY SourceObjectName, ReferencedObjectName;
