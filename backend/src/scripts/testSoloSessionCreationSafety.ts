import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { isActiveSoloSessionUniqueViolation } from '../core/utils/postgresErrors';

const root = path.resolve(__dirname, '..');
const service = fs.readFileSync(path.join(root, 'modules/solo-swipes/services/soloSwipeService.ts'), 'utf8');
const catalog = fs.readFileSync(path.join(root, 'infrastructure/postgres/repositories/PostgresCatalogRepositories.ts'), 'utf8');
const flutter = fs.readFileSync(path.resolve(root, '../../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart'), 'utf8');

assert(isActiveSoloSessionUniqueViolation({ code: '23505', constraint: 'solo_sessions_one_active_per_user' }));
assert(!isActiveSoloSessionUniqueViolation({ code: '23505', constraint: 'another_constraint' }));
assert(service.includes('if(existing&&!options.startOver)') && service.includes('resumedExisting:true'), 'active sessions must be resumed unless start-over is explicit');
assert(service.includes('const raced=await domainRepositories.soloSessions.findActive(userId)'), 'a unique-violation race must re-read the winner');
assert(service.includes('domainRepositories.soloSessions.replaceActive(write)'), 'start-over must atomically replace the active session');
assert(service.includes("sessionSwipes.filter((swipe)=>swipe.direction==='like').length"), 'likes must be scoped to the new solo session');
assert(service.includes('postgresDishes.listLightweight(userId)'), 'solo deck creation must use lightweight catalog rows');
assert(catalog.includes('full ingredient hydration skipped for deck=true'));
assert(!catalog.slice(catalog.indexOf('async listLightweight'), catalog.indexOf('async getByPublicId')).includes('hydrateListRows'));
assert(flutter.includes('if (_submitInFlight) return;'));
assert(flutter.includes('_loading || _submitInFlight ? null : _next'));
console.log('Solo session creation safety regression checks passed.');
