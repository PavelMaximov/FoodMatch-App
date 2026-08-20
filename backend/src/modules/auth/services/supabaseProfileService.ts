import crypto from 'crypto';
import { User } from '@supabase/supabase-js';
import { AppError } from '../../../core/errors/AppError';
import { getSupabaseAdminClient } from '../../../shared/db/supabaseAdminClient';
import { UserDocument, UserModel } from '../../users/models/User';

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
    const client = getSupabaseAdminClient();
    const existing = await client
      .from('profiles')
      .select('id,email,display_name,avatar_url,measurement_system_preference,created_at,updated_at')
      .eq('id', user.id)
      .maybeSingle();
    if (existing.error) throw new AppError('Unable to load user profile', 500);
    if (existing.data) {
      console.info(`[Auth] profile loaded user=${user.id}`);
      return this.mapProfile(existing.data, email, displayName);
    }
    const { data, error } = await client
      .from('profiles')
      .upsert({ id: user.id, email, display_name: displayName, avatar_url: avatarUrl }, { onConflict: 'id' })
      .select('id,email,display_name,avatar_url,measurement_system_preference,created_at,updated_at')
      .single();
    if (error || !data) throw new AppError('Unable to load user profile', 500);
    console.info(`[Auth] profile upserted user=${user.id}`);
    return this.mapProfile(data, email, displayName);
  }

  async updatePreference(user: User, preference: MeasurementPreference): Promise<SupabaseProfile> {
    await this.ensureProfile(user);
    const { data, error } = await getSupabaseAdminClient()
      .from('profiles')
      .update({ measurement_system_preference: preference })
      .eq('id', user.id)
      .select('id,email,display_name,avatar_url,measurement_system_preference,created_at,updated_at')
      .single();
    if (error || !data) throw new AppError('Unable to update user profile', 500);
    return this.mapProfile(data, user.email ?? '', metadataString(user, 'display_name') ?? 'FoodMatch user');
  }

  async updateAvatar(supabaseUserId: string, avatarUrl: string | null): Promise<void> {
    const { error } = await getSupabaseAdminClient().from('profiles').update({ avatar_url: avatarUrl }).eq('id', supabaseUserId);
    if (error) throw new AppError('Unable to update user profile', 500);
  }

  /**
   * PR2 bridge: Mongo remains the domain store and its models use ObjectId user
   * references. This shadow record contains no usable password and is not an
   * authentication source. It can be removed when those references move in PR3.
   */
  async ensureMongoRuntimeUser(user: User, profile: SupabaseProfile): Promise<UserDocument> {
    const passwordHash = `supabase-disabled:${crypto.randomBytes(32).toString('hex')}`;
    const runtimeUser = await UserModel.findOneAndUpdate(
      { $or: [{ supabaseAuthId: user.id }, { email: profile.email }] },
      {
        $set: {
          supabaseAuthId: user.id,
          email: profile.email,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl ?? undefined,
          authProvider: 'supabase',
          emailVerified: Boolean(user.email_confirmed_at),
          measurementSystemPreference: profile.measurementSystemPreference,
        },
        $setOnInsert: { passwordHash, savedDishes: [], isActive: true },
      },
      { new: true, upsert: true, runValidators: true }
    );
    return runtimeUser;
  }

  toUserDto(profile: SupabaseProfile, authUser: User, runtimeUser: UserDocument) {
    return {
      // Keep the Mongo runtime id until PR3 so Pair/Solo DTO comparisons remain stable.
      id: runtimeUser.id,
      supabaseUserId: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      avatarPublicId: runtimeUser.avatarPublicId ?? null,
      authProvider: 'supabase',
      isActive: runtimeUser.isActive,
      emailVerified: Boolean(authUser.email_confirmed_at),
      emailVerifiedAt: authUser.email_confirmed_at ?? null,
      measurementSystemPreference: profile.measurementSystemPreference,
      createdAt: profile.createdAt,
    };
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
