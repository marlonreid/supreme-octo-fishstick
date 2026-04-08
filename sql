SELECT 
    QUOTENAME(t.schema_name) + '.' + QUOTENAME(t.name) AS [Table],
    ISNULL(
        STRING_AGG(
            QUOTENAME(ref_schema.name) + '.' + QUOTENAME(ref_table.name), 
            ', '
        ),
        'none'
    ) AS [References]
FROM 
    (SELECT t.object_id, t.name, s.name AS schema_name
     FROM sys.tables t
     INNER JOIN sys.schemas s ON t.schema_id = s.schema_id) t
    LEFT JOIN sys.foreign_keys fk      ON fk.parent_object_id      = t.object_id
    LEFT JOIN sys.tables ref_table     ON fk.referenced_object_id  = ref_table.object_id
    LEFT JOIN sys.schemas ref_schema   ON ref_table.schema_id       = ref_schema.schema_id
GROUP BY 
    t.schema_name, t.name
ORDER BY 
    t.schema_name, t.name;
