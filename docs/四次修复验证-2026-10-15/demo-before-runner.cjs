const fs = require("node:fs");
const path = require("node:path");
const Module = require("node:module");

// Execute the current formal cases against the preserved pre-fix data source.
for (const name of ["data.test.cjs", "data-boundaries.test.cjs"]) {
  const filename = path.join(__dirname, "../../Workspace/tests", name);
  const source = fs.readFileSync(filename, "utf8").replace(
    'require("../data.js")',
    'require(' + JSON.stringify(path.join(__dirname, "demo-data-before.js")) + ')',
  );
  const loaded = new Module(filename, module);
  loaded.filename = filename;
  loaded.paths = Module._nodeModulePaths(path.dirname(filename));
  loaded._compile(source, filename);
}
