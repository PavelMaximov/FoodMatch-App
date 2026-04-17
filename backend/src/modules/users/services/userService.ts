import { AppError } from '../../../core/errors/AppError';
import { uploadService } from '../../uploads/services/uploadService';
import { UserModel } from '../models/User';

export class UserService {
  async confirmAvatar(userId: string, input: { avatarKey: string; avatarMimeType: string; avatarSize: number }) {
    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const validated = uploadService.validateAndNormalizeAvatarMeta(userId, {
      key: input.avatarKey,
      mimeType: input.avatarMimeType,
      sizeBytes: input.avatarSize
    });

    const previousAvatarKey = user.avatarKey;

    user.avatarKey = validated.key;
    user.avatarMimeType = validated.mimeType;
    user.avatarSize = validated.sizeBytes;
    user.avatarUpdatedAt = new Date();
    user.avatarUrl = '';
    await user.save();

    if (previousAvatarKey && previousAvatarKey !== validated.key) {
      await uploadService.deleteByKey(previousAvatarKey);
    }

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: await uploadService.resolveReadUrl(user.avatarKey),
      isActive: user.isActive,
      createdAt: user.createdAt
    };
  }

  async deleteAvatar(userId: string) {
    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const previousAvatarKey = user.avatarKey;

    user.avatarKey = undefined;
    user.avatarMimeType = undefined;
    user.avatarSize = undefined;
    user.avatarUpdatedAt = undefined;
    user.avatarUrl = '';
    await user.save();

    if (previousAvatarKey) {
      await uploadService.deleteByKey(previousAvatarKey);
    }

    return { deleted: true };
  }
}

export const userService = new UserService();
