import { execFileSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const repository = path.resolve(__dirname, '../../..');
const fakeValue = /^(?:test|fake|example|dummy)(?:[-_]|$)/i;

const assignmentPattern = /\b(?:JWT_SECRET|SUPABASE_SERVICE_ROLE_KEY|(?:[A-Z0-9_]+_)?API_KEY|(?:DATABASE|DB)_PASSWORD)\s*=\s*([^\s#;]+)/gi;
const databaseUrlPattern = /\b(?:postgres(?:ql)?|mongodb(?:\+srv)?):\/\/([^\s:'"/]+):([^\s@<'"/]+)@/gi;
const jwtPattern = /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/;
const privateKeyPattern = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/;
const allowedExampleDatabaseUrls = new Set([
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
]);

function unquote(value: string): string {
  return value.replace(/^["']|["',}]$/g, '');
}

/** Scan one tracked file. Fake credentials are allowed only when each credential
 * value is explicitly marked with a test/fake/example/dummy prefix. */
export function auditSource(relative: string, source: string): string[] {
  const findings: string[] = [];
  if (relative.startsWith('food_match/') && /SUPABASE_SERVICE_ROLE_KEY|service_role/i.test(source)) {
    findings.push(`${relative}: backend service-role reference in client tree`);
  }

  source.split(/\r?\n/).forEach((line, index) => {
    const scannedLine = [...allowedExampleDatabaseUrls].reduce(
      (value, allowed) => value.split(allowed).join('example-database-url'),
      line
    );
    const report = () => findings.push(`${relative}:${index + 1}: possible committed secret`);
    for (const match of scannedLine.matchAll(databaseUrlPattern)) {
      if (!fakeValue.test(match[1]) || !fakeValue.test(match[2])) report();
    }
    for (const match of scannedLine.matchAll(assignmentPattern)) {
      const value = unquote(match[1]);
      if (value && !/^<|replace(?:[_-](?:me|with))?|changeme/i.test(value) && !fakeValue.test(value)) report();
    }
    if (jwtPattern.test(scannedLine)) report();
    if (privateKeyPattern.test(scannedLine)) report();
  });
  return findings;
}

export function auditRepository(root = repository): { findings: string[]; fileCount: number } {
  const files = execFileSync('git', ['ls-files'], { cwd: root, encoding: 'utf8' }).trim().split('\n').filter(Boolean);
  const findings: string[] = [];
  for (const relative of files) {
    if (relative.includes('node_modules/') || relative.endsWith('package-lock.json')) continue;
    const file = path.join(root, relative);
    if (!fs.existsSync(file) || !fs.lstatSync(file).isFile()) continue;
    findings.push(...auditSource(relative, fs.readFileSync(file, 'utf8')));
  }
  return { findings, fileCount: files.length };
}

if (require.main === module) {
  const { findings, fileCount } = auditRepository();
  if (findings.length) {
    console.error(findings.join('\n'));
    process.exit(1);
  }
  console.log(`PASS secrets audit (${fileCount} tracked files inspected; Flutter contains no service-role references)`);
}
