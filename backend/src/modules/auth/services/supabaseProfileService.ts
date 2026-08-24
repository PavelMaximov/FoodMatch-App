import { User } from '@supabase/supabase-js';
import { AppError } from '../../../core/errors/AppError';
import { queryPostgres } from '../../../shared/db/postgresClient';
import { getSupabaseAdminClient } from '../../../shared/db/supabaseAdminClient';

export type MeasurementPreference = 'auto' | 'metric' | 'imperial';

export interface SupabaseProfile {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  measurementSystemPreference: MeasurementPreference;
  createdAt: string;
  updatedAt: string;
}

function metadataString(user: User, key: string): string | undefined {
  const value = user.user_metadata?.[key];
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

export class SupabaseProfileService {
  constructor(private readonly databaseQuery: typeof queryPostgres = queryPostgres) {}

  async verifyAccessToken(token: string): Promise<User> {
    const { data, error } = await getSupabaseAdminClient().auth.getUser(token);
    if (error || !data.user) throw new AppError('Invalid token', 401);
    return data.user;
  }

  async ensureProfile(user: User): Promise<SupabaseProfile> {
    const email = user.email?.trim().toLowerCase();
    if (!email) throw new AppError('Authenticated user has no email', 401);
    const displayName = metadataString(user, 'display_name') ??
      metadataString(user, 'displayName') ?? email.split('@')[0];
    const avatarUrl = metadataString(user, 'avatar_url') ?? null;
    try {
      // Use the exact pool used by domain repositories. This prevents a hosted
      // Auth/local database split from appearing to repair the wrong project.
      const result = await this.databaseQuery<Record<string, unknown>>(
        `insert into public.profiles
           (id,email,display_name,avatar_url,measurement_system_preference)
         values ($1,$2,$3,$4,'auto')
         on conflict (id) do update set
           email=excluded.email,
           display_name=coalesce(nullif(public.profiles.display_name,''),excluded.display_name),
           avatar_url=coalesce(excluded.avatar_url,public.profiles.avatar_url)
         returning id,email,display_name,avatar_url,measurement_system_preference,created_at,updated_at`,
        [user.id, email, displayName, avatarUrl]
      );
      console.info(`[AuthProfile] ensured user=${user.id} source=domain-db`);
      return this.mapProfile(result.rows[0], email, displayName);
    } catch (error) {
      console.error(`[AuthProfile] ensure failed user=${user.id}`, error);
      console.error(`[AuthProfile] missing profile before domain write user=${user.id}`);
      console.error('[AuthProfile] hint=Run repair:supabase-profiles or verify profile upsert uses the same DB as domain repositories.');
      throw new AppError('User profile is not ready', 500, 'SUPABASE_PROFILE_MISSING');
    }
  }

  async updatePreference(user: User, preference: MeasurementPreference): Promise<SupabaseProfile> {
    await this.ensureProfile(user);
    const result = await this.databaseQuery<Record<string, unknown>>(
      `update public.profiles set measurement_system_preference=$2,updated_at=now()
       where id=$1 returning id,email,display_name,avatar_url,
       measurement_system_preference,created_at,updated_at`,
      [user.id, preference]
    );
    if (!result.rows[0]) throw new AppError('User profile is not ready', 500, 'SUPABASE_PROFILE_MISSING');
    return this.mapProfile(result.rows[0], user.email ?? '', metadataString(user, 'display_name') ?? 'FoodMatch user');
  }

  async updateAvatar(supabaseUserId: string, avatarUrl: string | null): Promise<void> {
    const result = await this.databaseQuery(
      'update public.profiles set avatar_url=$2,updated_at=now() where id=$1',
      [supabaseUserId, avatarUrl]
    );
    if (!result.rowCount) throw new AppError('User profile is not ready', 500, 'SUPABASE_PROFILE_MISSING');
  }

  toUserDto(profile: SupabaseProfile, authUser: User) {
    return { id: profile.id, runtimeUserId: null, supabaseUserId: profile.id, email: profile.email, displayName: profile.displayName, avatarUrl: profile.avatarUrl, avatarPublicId: null, authProvider: 'supabase', isActive: true, emailVerified: Boolean(authUser.email_confirmed_at), emailVerifiedAt: authUser.email_confirmed_at ?? null, measurementSystemPreference: profile.measurementSystemPreference, createdAt: profile.createdAt };
  }

  private mapProfile(row: Record<string, unknown>, fallbackEmail: string, fallbackName: string): SupabaseProfile {
    return {
      id: String(row.id),
      email: typeof row.email === 'string' ? row.email : fallbackEmail,
      displayName: typeof row.display_name === 'string' && row.display_name ? row.display_name : fallbackName,
      avatarUrl: typeof row.avatar_url === 'string' ? row.avatar_url : null,
      measurementSystemPreference: (row.measurement_system_preference ?? 'auto') as MeasurementPreference,
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    };
  }
}

export const supabaseProfileService = new SupabaseProfileService();
