import fs from 'node:fs';
import path from 'node:path';
import ts from 'typescript';

const forbidden =
  /\bmongoose\b|connectDatabase|MONGODB_URI|Types\.ObjectId|\b(?:Dish|User|Swipe|Match|CoupleSession|SoloSwipeSession)Model\b/;

/** Follow syntax nodes: multiline imports and barrel exports are runtime edges too. */
export function auditRuntime(entry: string) {
  const visited = new Set<string>();
  const violations: string[] = [];
  const root = path.dirname(entry);
  function visit(file: string) {
    file = path.resolve(file);
    if (visited.has(file)) return;
    visited.add(file);
    const source = fs.readFileSync(file, 'utf8');
    source.split(/\r?\n/).forEach((line, index) => {
      if (forbidden.test(line))
        violations.push(
          `${path.relative(root, file)}:${index + 1}: ${line.trim()}`,
        );
    });
    const parsed = ts.createSourceFile(
      file,
      source,
      ts.ScriptTarget.Latest,
      true,
    );
    function dependency(specifier: ts.Node | undefined) {
      if (
        !specifier ||
        !ts.isStringLiteralLike(specifier) ||
        !specifier.text.startsWith('.')
      )
        return;
      const base = path
        .resolve(path.dirname(file), specifier.text)
        .replace(/\.js$/, '');
      const target = [base, `${base}.ts`, path.join(base, 'index.ts')].find(
        (candidate) =>
          fs.existsSync(candidate) && fs.statSync(candidate).isFile(),
      );
      if (!target)
        throw new Error(
          `Unresolved runtime import ${specifier.text} in ${file}`,
        );
      if (target.endsWith('.ts')) visit(target);
    }
    function walk(node: ts.Node) {
      if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node))
        dependency(node.moduleSpecifier);
      if (
        ts.isImportEqualsDeclaration(node) &&
        ts.isExternalModuleReference(node.moduleReference)
      )
        dependency(node.moduleReference.expression);
      if (
        ts.isCallExpression(node) &&
        (node.expression.kind === ts.SyntaxKind.ImportKeyword ||
          (ts.isIdentifier(node.expression) &&
            node.expression.text === 'require'))
      )
        dependency(node.arguments[0]);
      ts.forEachChild(node, walk);
    }
    walk(parsed);
  }
  visit(entry);
  return { visited, violations };
}

if (require.main === module) {
  const result = auditRuntime(path.resolve(__dirname, '..', 'server.ts'));
  if (result.violations.length) {
    console.error(
      `Mongo runtime references found:\n${result.violations.join('\n')}`,
    );
    process.exitCode = 1;
  } else {
    console.log(
      `PASS no Mongo runtime dependency (${result.visited.size} reachable TypeScript modules audited)`,
    );
  }
}
