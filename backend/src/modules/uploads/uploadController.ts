import { Response } from 'express';
import { AppError } from '../../core/errors/AppError';
import { AuthRequest } from '../../core/middleware/authMiddleware';
import { UserModel } from '../users/models/User';
import {
  CLOUDINARY_FOLDERS,
  CLOUDINARY_TRANSFORMATIONS,
  deleteImage,
  uploadImage
} from './services/cloudinaryService';
import { requireUploadedImage } from './middleware/uploadMiddleware';
import { supabaseProfileService } from '../auth/services/supabaseProfileService';

export class UploadController {
  async uploadAvatar(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const file = requireUploadedImage(req.file);
    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const previousPublicId = user.avatarPublicId;
    const result = await uploadImage({
      fileBuffer: file.buffer,
      mimeType: file.mimetype,
      folder: CLOUDINARY_FOLDERS.userAvatars,
      publicIdPrefix: `user-${user.id}-avatar`,
      transformation: CLOUDINARY_TRANSFORMATIONS.avatar
    });

    if (previousPublicId) {
      try {
        await deleteImage(previousPublicId);
      } catch (error) {
        console.warn('[Uploads] Failed to delete previous avatar', { userId: user.id, error });
      }
    }

    user.avatarUrl = result.secureUrl;
    user.avatarPublicId = result.publicId;
    await user.save();
    if (req.authUser) await supabaseProfileService.updateAvatar(req.authUser.id, result.secureUrl);

    res.json({ avatarUrl: result.secureUrl, avatarPublicId: result.publicId });
  }

  async deleteAvatar(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const user = await UserModel.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    if (!user.avatarPublicId) {
      user.avatarUrl = undefined;
      await user.save();
      if (req.authUser) await supabaseProfileService.updateAvatar(req.authUser.id, null);
      res.json({ message: 'No avatar to delete' });
      return;
    }

    const previousPublicId = user.avatarPublicId;
    try {
      await deleteImage(previousPublicId);
    } catch (error) {
      console.warn('[Uploads] Failed to delete avatar', { userId: user.id, error });
    }

    user.avatarUrl = undefined;
    user.avatarPublicId = undefined;
    await user.save();
    if (req.authUser) await supabaseProfileService.updateAvatar(req.authUser.id, null);

    res.json({ message: 'Avatar deleted' });
  }

  async uploadCustomDishImage(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const file = requireUploadedImage(req.file);

    const result = await uploadImage({
      fileBuffer: file.buffer,
      mimeType: file.mimetype,
      folder: CLOUDINARY_FOLDERS.customDishes,
      publicIdPrefix: `user-${userId}-custom-dish`,
      transformation: CLOUDINARY_TRANSFORMATIONS.customDish
    });

    res.json({ imageUrl: result.secureUrl, imagePublicId: result.publicId });
  }

  private requireUserId(req: AuthRequest): string {
    if (!req.userId) {
      throw new AppError('Unauthorized', 401);
    }

    return req.userId;
  }
}

export const uploadController = new UploadController();
