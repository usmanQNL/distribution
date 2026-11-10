// Stands in for a real SPA build: writes static files into dist/.
const fs = require("fs");
fs.mkdirSync("dist", { recursive: true });
fs.writeFileSync("dist/index.html", "<h1>Hello from Node</h1>\n");
console.log("built dist/");
