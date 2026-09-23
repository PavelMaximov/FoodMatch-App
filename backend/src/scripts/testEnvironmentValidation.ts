import { validateProductionEnvironment } from '../config/env';

const base = {
  NODE_ENV: 'production',
  PORT: '4000',
  DATA_STORE: 'supabase',
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_ANON_KEY: 'fake_anon_value',
  SUPABASE_SERVICE_ROLE_KEY: 'fake_service_value',
  SUPABASE_DB_URL: 'postgresql://fake_user:fake_password@db.project.supabase.co:5432/postgres',
  CORS_ORIGINS: 'https://app.foodmatch.example'
} as NodeJS.ProcessEnv;

const assertRejected = (values: NodeJS.ProcessEnv, expected: string) => {
  const errors = validateProductionEnvironment(values);
  if (!errors.some((error) => error.includes(expected))) {
    throw new Error(`Expected rejection containing ${expected}; got ${errors}`);
  }
};

if (validateProductionEnvironment(base).length) throw new Error('Valid production environment was rejected');
assertRejected({ ...base, PORT: undefined }, 'PORT');
assertRejected({ ...base, SUPABASE_URL: undefined }, 'SUPABASE_URL');
assertRejected({ ...base, SUPABASE_URL: 'http://127.0.0.1:54321' }, 'localhost');
assertRejected({ ...base, SUPABASE_DB_URL: 'postgresql://fake_user:fake_password@localhost:5432/postgres' }, 'localhost');
assertRejected({ ...base, SUPABASE_SERVICE_ROLE_KEY: 'replace_me' }, 'placeholder');
assertRejected({ ...base, CORS_ORIGINS: '*' }, 'Wildcard');
console.log('PASS production environment validation');
