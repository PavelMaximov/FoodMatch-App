import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { Types } from 'mongoose';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';
import { UserDocument, UserModel } from '../../users/models/User';
import { RefreshTokenModel } from '../models/RefreshToken';

export interface TokenMetadata { ip?: string; userAgent?: string }

function parseDuration(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) return 30 * 24 * 60 * 60 * 1000;
  const n = Number(match[1]);
  return n * ({ s: 1000, m: 60000, h: 3600000, d: 86400000 }[match[2] as 's'|'m'|'h'|'d']);
}

export function hashToken(rawToken: string): string {
  return crypto.createHash('sha256').update(rawToken).digest('hex');
}

export class TokenService {
  signAccessToken(user: UserDocument): string {
    return jwt.sign({ userId: user.id, sub: user.id, email: user.email }, env.JWT_SECRET, {
      expiresIn: (env.JWT_ACCESS_EXPIRES_IN || env.JWT_EXPIRES_IN || '30d') as any
    });
  }

  async issueTokenPair(user: UserDocument, metadata: TokenMetadata = {}, familyId: string = crypto.randomUUID()) {
    const accessToken = this.signAccessToken(user);
    const refreshToken = crypto.randomBytes(64).toString('base64url');
    const tokenHash = hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + parseDuration(env.JWT_REFRESH_EXPIRES_IN));
    await RefreshTokenModel.create({ userId: user._id, tokenHash, familyId, expiresAt, createdByIp: metadata.ip, createdByUserAgent: metadata.userAgent });
    return { token: accessToken, accessToken, refreshToken, user };
  }

  async rotateRefreshToken(rawRefreshToken: string, metadata: TokenMetadata = {}) {
    const tokenHash = hashToken(rawRefreshToken);
    const existing = await RefreshTokenModel.findOne({ tokenHash });
    if (!existing) {
      console.warn('[AuthRefresh] refresh failed reason=token_not_found');
      throw new AppError('Invalid refresh token', 401);
    }
    if (existing.revokedAt) {
      console.warn('[AuthRefresh] refresh failed reason=revoked_or_reused');
      existing.reusedAt = existing.reusedAt ?? new Date();
      await existing.save();
      await this.revokeRefreshTokenFamily(existing.familyId, 'reuse');
      throw new AppError('Invalid refresh token', 401);
    }
    if (existing.expiresAt <= new Date()) {
      console.warn('[AuthRefresh] refresh failed reason=expired');
      existing.revokedAt = new Date();
      await existing.save();
      throw new AppError('Invalid refresh token', 401);
    }
    const user = await UserModel.findById(existing.userId);
    if (!user) {
      console.warn('[AuthRefresh] refresh failed reason=token_not_found');
      throw new AppError('Invalid refresh token', 401);
    }
    const pair = await this.issueTokenPair(user, metadata, existing.familyId);
    existing.revokedAt = new Date();
    existing.replacedByTokenHash = hashToken(pair.refreshToken);
    await existing.save();
    return pair;
  }

  async revokeRefreshToken(rawRefreshToken?: string) {
    if (!rawRefreshToken) return;
    await RefreshTokenModel.updateOne({ tokenHash: hashToken(rawRefreshToken), revokedAt: { $exists: false } }, { $set: { revokedAt: new Date() } });
  }

  async revokeAllUserRefreshTokens(userId: string | Types.ObjectId) {
    await RefreshTokenModel.updateMany({ userId, revokedAt: { $exists: false } }, { $set: { revokedAt: new Date() } });
  }

  async revokeRefreshTokenFamily(familyId: string, _reason?: string) {
    await RefreshTokenModel.updateMany({ familyId, revokedAt: { $exists: false } }, { $set: { revokedAt: new Date() } });
  }
}
export const tokenService = new TokenService();
