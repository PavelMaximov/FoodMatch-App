import { auditSource } from './auditSecrets';

const assertClean = (source: string) => {
  const findings = auditSource('backend/src/scripts/__fixtures__/fake.env', source);
  if (findings.length) throw new Error(`Fake fixture was rejected: ${findings.join(', ')}`);
};
const assertDetected = (source: string) => {
  const findings = auditSource('backend/src/config/accidental-secret.env', source);
  if (!findings.length) throw new Error(`Realistic secret was not detected: ${source.slice(0, 24)}...`);
};

assertClean('SUPABASE_SERVICE_ROLE_KEY=fake_service_role_key');
assertClean('DATABASE_URL=postgresql://test_user:test_password@localhost:5432/postgres');

// Construct regression samples so this test verifies the scanner without committing
// a scanner-shaped credential that the repository audit would correctly reject.
assertDetected(['JWT', 'SECRET'].join('_') + '=' + 'r3alistic-' + 'secret-value-with-more-than-32-characters');
assertDetected('postgresql://' + 'application:unguessable-password@db.example.invalid:5432/app');
assertDetected(['PAYMENTS', 'API', 'KEY'].join('_') + '=' + 'sk_live_' + '1234567890abcdefghijklmnop');
assertDetected('-----BEGIN ' + 'PRIVATE KEY-----');

console.log('PASS secrets audit regression tests');
