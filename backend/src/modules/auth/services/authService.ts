import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';
import { uploadService } from '../../uploads/services/uploadService';
import { UserDocument, UserModel } from '../../users/models/User';

const AVATAR_URL_TIMEOUT_MS = 1200;

export class AuthService {
  async register(email: string, password: string, displayName: string) {
    console.log('[auth][service] register:start email=%s', email ?? '');

    const existing = await UserModel.findOne({ email });
    if (existing) {
      throw new AppError('Email already in use', 409);
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await UserModel.create({ email, passwordHash, displayName });
    const token = this.signToken(user.id);

    const publicUser = await this.toPublicUser(user);
    console.log('[auth][service] register:success userId=%s', publicUser.id);

    return { token, user: publicUser };
  }

  async login(email: string, password: string) {
    console.log('[auth][service] login:start email=%s', email ?? '');

    const user = await UserModel.findOne({ email });
    if (!user) {
      throw new AppError('Invalid credentials', 401);
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      throw new AppError('Invalid credentials', 401);
    }

    const token = this.signToken(user.id);
    const publicUser = await this.toPublicUser(user);
    console.log('[auth][service] login:success userId=%s', publicUser.id);

    return { token, user: publicUser };
  }

  async me(userId: string) {
    console.log('[auth][service] me:start userId=%s', userId ?? '');

    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const publicUser = await this.toPublicUser(user);
    console.log('[auth][service] me:success userId=%s', publicUser.id);

    return publicUser;
  }

  private signToken(userId: string): string {
    return jwt.sign({ userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as any });
  }

  private async toPublicUser(user: UserDocument) {
    console.log('[auth][dto] map-user:start userId=%s hasAvatarKey=%s', user.id, Boolean(user.avatarKey));
    const avatarUrl = await this.resolveAvatarUrlSafe(user);
    console.log('[auth][dto] map-user:done userId=%s avatarUrlPresent=%s', user.id, Boolean(avatarUrl));

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl,
      isActive: user.isActive,
      createdAt: user.createdAt
    };
  }

  private async resolveAvatarUrlSafe(user: UserDocument): Promise<string | null> {
    if (!user.avatarKey) {
      return user.avatarUrl ?? null;
    }

    try {
      const signedUrl = await Promise.race<string>([
        uploadService.resolveReadUrl(user.avatarKey),
        new Promise<string>((_, reject) => {
          setTimeout(() => reject(new Error('avatar signed URL timeout')), AVATAR_URL_TIMEOUT_MS);
        })
      ]);

      return signedUrl || null;
    } catch (error) {
      console.warn('[auth][dto] avatar-url:fallback userId=%s reason=%s', user.id, (error as Error)?.message ?? 'unknown');
      return user.avatarUrl ?? null;
    }
  }
}
