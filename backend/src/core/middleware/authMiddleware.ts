import { NextFunction, Request, Response } from 'express';
import { User } from '@supabase/supabase-js';
import jwt from 'jsonwebtoken';
import { AppError } from '../errors/AppError';
import { SupabaseProfile, supabaseProfileService } from '../../modules/auth/services/supabaseProfileService';
import { supabaseConfig } from '../../config/supabase';

export interface AuthRequest extends Request {
  userId?: string;
  authUser?: User;
  profile?: SupabaseProfile;
  user?: {
    id: string; email: string; displayName: string; avatarUrl: string | null;
    authProvider: 'supabase'; runtimeUserId: string;
  };
}

export async function authMiddleware(req: AuthRequest, _res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    console.warn('[Auth] rejected reason=missing_token');
    next(new AppError('Unauthorized', 401, 'AUTH_TOKEN_MISSING'));
    return;
  }
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    console.warn('[Auth] rejected reason=missing_token');
    next(new AppError('Unauthorized', 401, 'AUTH_TOKEN_MISSING'));
    return;
  }
  try {
    const authUser = await supabaseProfileService.verifyAccessToken(token);
    console.info(`[Auth] Supabase token verified user=${authUser.id}`);
    const profile = await supabaseProfileService.ensureProfile(authUser);
    const runtimeUser = await supabaseProfileService.ensureMongoRuntimeUser(authUser, profile);
    req.userId = runtimeUser.id;
    req.authUser = authUser;
    req.profile = profile;
    req.user = {
      id: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      authProvider: 'supabase',
      runtimeUserId: runtimeUser.id,
    };
    next();
  } catch (error) {
    if (error instanceof AppError && error.statusCode !== 401) {
      next(error);
      return;
    }
    console.warn('[Auth] rejected reason=invalid_token');
    logInvalidTokenDiagnostics(token);
    next(new AppError('Invalid token', 401, 'SUPABASE_TOKEN_INVALID'));
  }
}

function logInvalidTokenDiagnostics(token: string): void {
  let decoded: ReturnType<typeof jwt.decode> = null;
  try { decoded = jwt.decode(token); } catch { decoded = null; }
  const payload = typeof decoded === 'object' && decoded !== null ? decoded : {};
  const issuer = typeof payload.iss === 'string' ? payload.iss : undefined;
  let issuerHost = 'unknown';
  if (issuer) {
    try { issuerHost = new URL(issuer).host; } catch { issuerHost = 'invalid'; }
  }
  const audience = typeof payload.aud === 'string'
    ? payload.aud
    : Array.isArray(payload.aud) ? payload.aud.join(',') : 'unknown';
  const backendHost = new URL(supabaseConfig.url).host;
  console.warn(`[Auth] token diagnostics issHost=${issuerHost} aud=${audience} hasSub=${typeof payload.sub === 'string' && payload.sub.length > 0} hasExp=${typeof payload.exp === 'number'} issuerMatchesBackend=${issuerHost === backendHost}`);
  console.warn(`[Auth] backend supabase host=${backendHost}`);
  console.warn('[Auth] hint=Check that Flutter SUPABASE_URL/ANON_KEY and backend SUPABASE_URL/SERVICE_ROLE_KEY belong to the same Supabase project.');
}
