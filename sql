SELECT 
    QUOTENAME(fk_schema.name) + '.' + QUOTENAME(fk_table.name) AS [Table],
    STRING_AGG(
        QUOTENAME(ref_schema.name) + '.' + QUOTENAME(ref_table.name), 
        ', '
    ) AS [References]
FROM 
    sys.foreign_keys fk
    INNER JOIN sys.tables fk_table  ON fk.parent_object_id   = fk_table.object_id
    INNER JOIN sys.schemas fk_schema ON fk_table.schema_id    = fk_schema.schema_id
    INNER JOIN sys.tables ref_table  ON fk.referenced_object_id = ref_table.object_id
    INNER JOIN sys.schemas ref_schema ON ref_table.schema_id   = ref_schema.schema_id
GROUP BY 
    fk_schema.name, fk_table.name
ORDER BY 
    fk_schema.name, fk_table.name;
