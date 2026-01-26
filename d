SELECT DISTINCT
    referencing_obj.name AS [SourceObjectName],
    referencing_obj.type_desc AS [SourceObjectType],
    referenced_entity_name AS [ReferencedEntityName],
    -- Check if it's a Table, View, or another Function
    COALESCE(referenced_obj.type_desc, 'EXTERNAL/UNKNOWN') AS [ReferencedObjectType]
FROM sys.sql_expression_dependencies AS sed
INNER JOIN sys.objects AS referencing_obj 
    ON sed.referencing_id = referencing_obj.object_id
LEFT JOIN sys.objects AS referenced_obj 
    ON sed.referenced_id = referenced_obj.object_id
WHERE 
    referencing_obj.type IN ('P', 'FN', 'IF', 'TF') -- Procs and various Function types
    AND sed.referenced_entity_name IS NOT NULL
ORDER BY [SourceObjectName], [ReferencedEntityName];



SELECT name, type_desc 
FROM sys.procedures p
JOIN sys.sql_modules m ON p.object_id = m.object_id
WHERE m.definition LIKE '%EXEC(%' OR m.definition LIKE '%sp_executesql%';
