import { validateProductionEnvironment } from '../config/env';
const base = { NODE_ENV: 'production', DATA_STORE: 'supabase', SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'valid-anon-value', SUPABASE_SERVICE_ROLE_KEY: 'valid-service-value', SUPABASE_DB_URL: 'postgresql://user:password@db.project.supabase.co:5432/postgres', CORS_ORIGINS: 'https://app.foodmatch.example' } as NodeJS.ProcessEnv;
const assertRejected = (values: NodeJS.ProcessEnv, expected: string) => { const errors=validateProductionEnvironment(values); if(!errors.some(e=>e.includes(expected))) throw new Error(`Expected rejection containing ${expected}; got ${errors}`); };
if(validateProductionEnvironment(base).length) throw new Error('Valid production environment was rejected');
assertRejected({...base,SUPABASE_URL:'http://127.0.0.1:54321'},'localhost');
assertRejected({...base,SUPABASE_DB_URL:'postgresql://postgres:postgres@localhost:5432/postgres'},'localhost');
assertRejected({...base,SUPABASE_SERVICE_ROLE_KEY:'replace_me'},'placeholder');
assertRejected({...base,CORS_ORIGINS:'*'},'Wildcard');
console.log('PASS production environment validation');
