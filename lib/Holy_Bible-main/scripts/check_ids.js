const fs = require('fs');
const shell = fs.readFileSync('app/js/shell.js', 'utf8');
const chrome = (shell.match(/function chromeHTML\(\) \{\s*return `([\s\S]*?)`;\s*\}/) || [])[1] || '';
const pages = { 'home.js': 'index.html', 'reader.js': 'read.html', 'search.js': 'search.html', 'plan.js': 'plan.html', 'quiz-page.js': 'quiz.html', 'library.js': 'library.html' };
function ids(code) {
  const set = new Set();
  const re = /[\$]\("#([^"]+)"\)|[\$]\(`#([^`]+)`\)/g; let m;
  while ((m = re.exec(code))) set.add(m[1] || m[2]);
  return set;
}
let fail = false;
for (const [js, html] of Object.entries(pages)) {
  const jsCode = fs.readFileSync('app/js/' + js, 'utf8');
  const htmlCode = fs.readFileSync(html, 'utf8');
  const need = ids(jsCode);
  const avail = htmlCode + chrome;
  const missing = [...need].filter(id => !avail.includes('id="' + id + '"') && !avail.includes("id='" + id + "'"));
  if (missing.length) { fail = true; console.log(html + ' (' + js + '): MISSING ' + JSON.stringify(missing)); }
  else console.log(html + ' (' + js + '): OK');
}
process.exit(fail ? 1 : 0);
