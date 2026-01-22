const startPage = dv.current().file.path;
const results = [];
const visited = new Set();

function findDescendants(pagePath) {
    if (visited.has(pagePath)) return;
    visited.add(pagePath);
    
    let page = dv.page(pagePath);
    if (!page) return;

    // Check if the current note in the recursion is a table
    // (And make sure we don't list the starting page itself)
    if (page.type === "table" && page.file.path !== startPage) {
        results.push(page.file.link);
    }

    // Look at everything in the "down" property (Breadcrumbs field)
    let children = dv.array(page.down);
    for (let child of children) {
        if (child && child.path) {
            findDescendants(child.path);
        }
    }
}

findDescendants(startPage);
dv.list(results);
