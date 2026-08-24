import assert from 'assert';import fs from 'fs';
const middleware=fs.readFileSync('src/core/middleware/authMiddleware.ts','utf8');
assert(middleware.includes('req.userId = profile.id'));assert(!middleware.includes('ensureMongoRuntimeUser'));
console.log('PASS Supabase profile UUID is the sole runtime user id');
