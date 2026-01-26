using System.Text;

// CONFIGURATION
string vaultRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), ".."));
string currentDir = Directory.GetCurrentDirectory();

// MAPPING: SQL Type -> Folder Name
// The "type: ..." frontmatter will be the Folder Name minus the 's' (e.g., "tables" -> "table")
var typeMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
{
    { "SQL_STORED_PROCEDURE",      "stored procedures" },
    { "USER_TABLE",                "tables" },
    { "SQL_SCALAR_FUNCTION",       "functions" },
    { "SQL_TABLE_VALUED_FUNCTION", "functions" },
    { "VIEW",                      "views" },
    // Fallback for generic table types if SQL varies
    { "U",                         "tables" },
    { "P",                         "stored procedures" }
};

Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine($"Scanning for CSVs in: {currentDir}");
Console.WriteLine($"Vault Root: {vaultRoot}");
Console.ResetColor();

// TRACKING
var createdFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
var potentialLeaves = new List<LeafNode>();

// 1. GET ALL CSV FILES
var csvFiles = Directory.GetFiles(currentDir, "*.csv");

// =========================================================
// PASS 1: PROCESS SOURCE FILES (The CSVs)
// =========================================================
foreach (var filePath in csvFiles)
{
    string procName = Path.GetFileNameWithoutExtension(filePath);
    var downLinks = new HashSet<string>();
    var paramsList = new List<string>();
    string objectType = "SQL_STORED_PROCEDURE"; // Default

    // Read CSV Lines
    var lines = File.ReadAllLines(filePath).Skip(1); // Skip Header

    foreach (var line in lines)
    {
        // Simple CSV Split (Assumes no commas inside quotes for simplicity)
        var cols = line.Split(',');
        if (cols.Length < 4) continue; // Skip bad rows

        // CSV Structure expected: SourceName, SourceObjectType, TargetName, TargetType, RowType
        // Adjust indices based on your actual CSV columns. 
        // Based on previous script: 
        // 0:Source, 1:SourceType, 2:Target, 3:TargetType, 4:RowType
        
        string rowSourceType = cols[1];
        string targetName    = cols[2];
        string targetType    = cols[3];
        string rowType       = cols.Length > 4 ? cols[4] : "DEPENDENCY";

        // Update Master Object Type (if valid)
        if (!string.IsNullOrWhiteSpace(rowSourceType)) objectType = rowSourceType;

        if (rowType == "PARAMETER")
        {
            paramsList.Add($"{targetName}: {targetType}");
        }
        else // DEPENDENCY
        {
            if (!string.IsNullOrWhiteSpace(targetName))
            {
                string link = $"\"[[{targetName}]]\"";
                downLinks.Add(link);

                // STORE FOR PASS 2
                potentialLeaves.Add(new LeafNode(targetName, targetType));
            }
        }
    }

    // GENERATE FILE
    CreateObsidianFile(vaultRoot, procName, objectType, paramsList, downLinks.ToList());
    createdFiles.Add(procName);
}

// =========================================================
// PASS 2: PROCESS LEAF NODES (Tables/Views)
// =========================================================
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("PASS 2: Generating leaf nodes...");
Console.ResetColor();

// Group by Name to avoid duplicates
var uniqueLeaves = potentialLeaves
    .GroupBy(x => x.Name)
    .Select(g => g.First())
    .ToList();

foreach (var leaf in uniqueLeaves)
{
    // If we already created this file in Pass 1 (it was a source), skip it
    if (createdFiles.Contains(leaf.Name)) continue;

    // Check if it's a known type (like USER_TABLE)
    // If leaf.Type is "USER_TABLE", GetFolder returns "tables"
    // The CreateObsidianFile method strips the 's', setting type: "table"
    string folder = GetFolder(leaf.Type);
    
    // If mapped, create it. If not (e.g. BROKEN_REF), skip or put in others.
    if (folder != "others") 
    {
        CreateObsidianFile(vaultRoot, leaf.Name, leaf.Type, new List<string>(), new List<string>(), isLeaf: true);
        Console.WriteLine($" -> Created Leaf: {leaf.Name} ({leaf.Type})");
        createdFiles.Add(leaf.Name);
    }
}

Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine("Vault Update Complete.");
Console.ResetColor();


// =========================================================
// HELPER METHODS & CLASSES
// =========================================================

void CreateObsidianFile(string root, string name, string sqlType, List<string> parameters, List<string> dependencies, bool isLeaf = false)
{
    string folder = GetFolder(sqlType);
    string dirPath = Path.Combine(root, folder);
    Directory.CreateDirectory(dirPath);

    string typeProperty = folder.TrimEnd('s'); // "tables" -> "table"

    var sb = new StringBuilder();
    sb.AppendLine("---");
    sb.AppendLine($"type: {typeProperty}");
    
    if (parameters.Any())
    {
        sb.AppendLine("params:");
        foreach (var p in parameters) sb.AppendLine($"  - {p}");
    }

    if (dependencies.Any())
    {
        sb.AppendLine("down:");
        foreach (var d in dependencies.OrderBy(x => x)) sb.AppendLine($"  - {d}");
    }
    else
    {
        sb.AppendLine("down: []");
    }

    sb.AppendLine("---");
    sb.AppendLine();
    if (isLeaf) sb.AppendLine("*(Auto-generated leaf node)*");
    sb.AppendLine();
    sb.AppendLine("```dataviewjs");
    sb.AppendLine("await dv.view(\"_scripts/dependencies\")");
    sb.AppendLine("```");

    // Sanitize filename if needed
    string safeName = name.Replace("/", "_").Replace("\\", "_");
    File.WriteAllText(Path.Combine(dirPath, $"{safeName}.md"), sb.ToString());
}

string GetFolder(string sqlType)
{
    if (string.IsNullOrEmpty(sqlType)) return "others";
    return typeMap.ContainsKey(sqlType) ? typeMap[sqlType] : "others";
}

record LeafNode(string Name, string Type);
