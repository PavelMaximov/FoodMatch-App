import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';
import { UserDocument, UserModel } from '../../users/models/User';
import { normalizeEmail } from '../utils/normalizeEmail';
import { EmailVerificationTokenModel } from '../models/EmailVerificationToken';
import { emailService } from './emailService';
import { hashToken, tokenService, TokenMetadata } from './tokenService';

function parseDuration(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) return 24 * 60 * 60 * 1000;
  const n = Number(match[1]);
  return n * ({ s: 1000, m: 60000, h: 3600000, d: 86400000 }[match[2] as 's'|'m'|'h'|'d']);
}

export class AuthService {
  async register(email: string, password: string, displayName: string, metadata: TokenMetadata = {}) {
    const normalizedEmail = normalizeEmail(email);
    if (await UserModel.findOne({ email: normalizedEmail })) throw new AppError('Email already in use', 409);
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await UserModel.create({ email: normalizedEmail, passwordHash, displayName, emailVerified: false });
    await this.sendVerification(user);
    return this.authResponse(await tokenService.issueTokenPair(user, metadata));
  }

  async login(email: string, password: string, metadata: TokenMetadata = {}) {
    const normalizedEmail = normalizeEmail(email);
    const user = await UserModel.findOne({ email: normalizedEmail });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) throw new AppError('Invalid credentials', 401);
    return this.authResponse(await tokenService.issueTokenPair(user, metadata));
  }

  async refresh(refreshToken: string, metadata: TokenMetadata = {}) {
    console.log('[AuthRefresh] refresh request received');
    if (!refreshToken) {
      console.warn('[AuthRefresh] refresh failed reason=missing_token');
      throw new AppError('Refresh token is required', 400);
    }
    const pair = await tokenService.rotateRefreshToken(refreshToken, metadata);
    console.log(`[AuthRefresh] refresh success userId=${pair.user.id}`);
    return this.authResponse(pair);
  }

  async logout(refreshToken?: string) { await tokenService.revokeRefreshToken(refreshToken); return { success: true }; }
  async logoutAll(userId: string) { await tokenService.revokeAllUserRefreshTokens(userId); return { success: true }; }

  async me(userId: string) {
    const user = await UserModel.findById(userId);
    if (!user) throw new AppError('User not found', 404);
    const publicUser = this.toPublicUser(user);
    return { user: publicUser, requireEmailVerification: env.REQUIRE_EMAIL_VERIFICATION && !publicUser.emailVerified };
  }

  async resendVerification(userId: string) {
    const user = await UserModel.findById(userId);
    if (!user) throw new AppError('User not found', 404);
    if (user.emailVerified === true) return { success: true, user: this.toPublicUser(user) };
    await this.sendVerification(user);
    return { success: true, user: this.toPublicUser(user) };
  }

  async verifyEmail(rawToken: string) {
    if (!rawToken) throw new AppError('Verification token is required', 400);
    const tokenDoc = await EmailVerificationTokenModel.findOne({ tokenHash: hashToken(rawToken) });
    if (!tokenDoc || tokenDoc.usedAt || tokenDoc.expiresAt <= new Date()) throw new AppError('Invalid or expired verification token', 400);
    const user = await UserModel.findById(tokenDoc.userId);
    if (!user) throw new AppError('Invalid or expired verification token', 400);
    user.emailVerified = true;
    user.emailVerifiedAt = user.emailVerifiedAt ?? new Date();
    tokenDoc.usedAt = new Date();
    await Promise.all([user.save(), tokenDoc.save()]);
    return { success: true, user: this.toPublicUser(user) };
  }

  private async sendVerification(user: UserDocument) {
    await EmailVerificationTokenModel.updateMany({ userId: user._id, usedAt: { $exists: false } }, { $set: { usedAt: new Date() } });
    const raw = crypto.randomBytes(48).toString('base64url');
    await EmailVerificationTokenModel.create({ userId: user._id, tokenHash: hashToken(raw), sentToEmail: user.email, expiresAt: new Date(Date.now() + parseDuration(env.EMAIL_VERIFICATION_EXPIRES_IN)) });
    await emailService.sendVerificationEmail(user.email, raw);
  }

  private authResponse(pair: { token: string; accessToken: string; refreshToken: string; user: UserDocument }) {
    const user = this.toPublicUser(pair.user);
    return { token: pair.accessToken, accessToken: pair.accessToken, refreshToken: pair.refreshToken, user, requireEmailVerification: env.REQUIRE_EMAIL_VERIFICATION && !user.emailVerified };
  }

  private toPublicUser(user: UserDocument) {
    return { id: user.id, email: user.email, displayName: user.displayName, avatarUrl: user.avatarUrl ?? null, avatarPublicId: user.avatarPublicId ?? null, isActive: user.isActive, emailVerified: user.emailVerified === undefined ? true : user.emailVerified, emailVerifiedAt: user.emailVerifiedAt ?? null, createdAt: user.createdAt };
  }
}
