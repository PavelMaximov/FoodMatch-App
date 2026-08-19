import { inputDirectory, inputFile } from './supabaseImportUtils';

type ArgumentCase = {
  argv: string[];
  parse: () => string;
  expected: string;
};

const originalArgv = process.argv;
const cases: ArgumentCase[] = [
  { argv: ['node', 'script', '--file', 'named.json'], parse: inputFile, expected: 'named.json' },
  { argv: ['node', 'script', 'positional.json'], parse: inputFile, expected: 'positional.json' },
  { argv: ['node', 'script', '--dir', 'named-directory'], parse: inputDirectory, expected: 'named-directory' },
  { argv: ['node', 'script', 'positional-directory'], parse: inputDirectory, expected: 'positional-directory' },
];

try {
  for (const testCase of cases) {
    process.argv = testCase.argv;
    const actual = testCase.parse();
    if (actual !== testCase.expected) throw new Error(`Expected ${testCase.expected}, received ${actual}`);
  }

  process.argv = ['node', 'script'];
  for (const [parse, expected] of [
    [inputFile, 'Missing input file. Use --file <path> or pass the file path as the first argument.'],
    [inputDirectory, 'Missing input directory. Use --dir <path> or pass the directory path as the first argument.'],
  ] as const) {
    try {
      parse();
      throw new Error('Expected argument parsing to fail');
    } catch (error) {
      if (!(error instanceof Error) || error.message !== expected) throw error;
    }
  }

  console.log('Supabase import argument parser checks passed');
} finally {
  process.argv = originalArgv;
}
