import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { auditRuntime } from './auditNoMongoRuntime';

const directory = fs.mkdtempSync(
  path.join(os.tmpdir(), 'foodmatch-runtime-audit-'),
);
const write = (name: string, source: string) =>
  fs.writeFileSync(path.join(directory, name), source);
try {
  write('entry.ts', "import {\n service\n} from './barrel';\n");
  write('barrel.ts', "export {\n service\n} from './service';\n");
  write(
    'service.ts',
    "import mongoose from 'mongoose'; export const service = mongoose;",
  );
  let result = auditRuntime(path.join(directory, 'entry.ts'));
  assert.equal(result.visited.size, 3);
  assert.equal(result.violations.length, 1);
  assert(result.violations[0].startsWith('service.ts:1:'));
  write('service.ts', "export const service = 1; require('./cycle');");
  write('cycle.ts', "import('./entry');");
  result = auditRuntime(path.join(directory, 'entry.ts'));
  assert.equal(result.visited.size, 4);
  assert.deepEqual(result.violations, []);
  write('cycle.ts', "export * from './missing';");
  assert.throws(
    () => auditRuntime(path.join(directory, 'entry.ts')),
    /Unresolved runtime import/,
  );
  console.log(
    'PASS runtime audit follows multiline imports, barrels, require/dynamic imports and cycles; missing dependencies fail closed',
  );
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
