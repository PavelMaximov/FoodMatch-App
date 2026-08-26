import { execFileSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const repository = path.resolve(__dirname, '../../..');
const files = execFileSync('git', ['ls-files'], { cwd: repository, encoding: 'utf8' }).trim().split('\n').filter(Boolean);
const findings: string[] = [];
const secretPatterns = [
  /postgres(?:ql)?:\/\/[^\s:'"]+:[^\s@<'"]+@/i,
  /mongodb(?:\+srv)?:\/\/[^\s:'"]+:[^\s@<'"]+@/i,
  /(?:JWT_SECRET|SUPABASE_SERVICE_ROLE_KEY)\s*=\s*(?!$|<|replace|changeme)[^\s#]+/i,
];
for (const relative of files) {
  if (relative.includes('node_modules/') || relative.endsWith('package-lock.json')) continue;
  const file = path.join(repository, relative);
  if (!fs.existsSync(file) || !fs.lstatSync(file).isFile()) continue;
  const source = fs.readFileSync(file, 'utf8');
  if (relative.startsWith('food_match/') && /SUPABASE_SERVICE_ROLE_KEY|service_role/i.test(source)) findings.push(`${relative}: backend service-role reference in client tree`);
  source.split(/\r?\n/).forEach((line, index) => secretPatterns.forEach((pattern) => {
    if (pattern.test(line) && !/postgres:postgres@127\.0\.0\.1|example|placeholder|test-only/i.test(line)) findings.push(`${relative}:${index + 1}: possible committed secret`);
  }));
}
if (findings.length) { console.error(findings.join('\n')); process.exit(1); }
console.log(`PASS secrets audit (${files.length} tracked files inspected; Flutter contains no service-role references)`);
