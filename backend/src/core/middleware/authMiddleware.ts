import { NextFunction, Request, Response } from 'express';
import { User } from '@supabase/supabase-js';
import { AppError } from '../errors/AppError';
import { SupabaseProfile, supabaseProfileService } from '../../modules/auth/services/supabaseProfileService';

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
    next(new AppError('Unauthorized', 401));
    return;
  }
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    console.warn('[Auth] rejected reason=missing_token');
    next(new AppError('Unauthorized', 401));
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
    next(new AppError('Invalid token', 401));
  }
}
