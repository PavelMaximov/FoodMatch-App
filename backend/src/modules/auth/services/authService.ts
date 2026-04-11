import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';
import { UserDocument, UserModel } from '../../users/models/User';

export class AuthService {
  async register(email: string, password: string, displayName: string) {
    const existing = await UserModel.findOne({ email });
    if (existing) {
      throw new AppError('Email already in use', 409);
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await UserModel.create({ email, passwordHash, displayName });
    const token = this.signToken(user.id);

    return { token, user: this.toPublicUser(user) };
  }

  async login(email: string, password: string) {
    const user = await UserModel.findOne({ email });
    if (!user) {
      throw new AppError('Invalid credentials', 401);
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      throw new AppError('Invalid credentials', 401);
    }

    const token = this.signToken(user.id);
    return { token, user: this.toPublicUser(user) };
  }

  async me(userId: string) {
    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    return this.toPublicUser(user);
  }

  private signToken(userId: string): string {
    return jwt.sign({ userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as any });
  }

  private toPublicUser(user: UserDocument) {
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl ?? null,
      isActive: user.isActive,
      createdAt: user.createdAt
    };
  }
}
