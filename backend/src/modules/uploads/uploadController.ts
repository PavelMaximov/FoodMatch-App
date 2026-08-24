import { Response } from 'express';
import { AppError } from '../../core/errors/AppError';
import { AuthRequest } from '../../core/middleware/authMiddleware';
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
    const userId=this.requireUserId(req),file=requireUploadedImage(req.file);
    const result=await uploadImage({fileBuffer:file.buffer,mimeType:file.mimetype,folder:CLOUDINARY_FOLDERS.userAvatars,publicIdPrefix:`user-${userId}-avatar`,transformation:CLOUDINARY_TRANSFORMATIONS.avatar});
    await supabaseProfileService.updateAvatar(userId,result.secureUrl);res.json({avatarUrl:result.secureUrl,avatarPublicId:result.publicId});
  }
  async deleteAvatar(req: AuthRequest,res:Response){await supabaseProfileService.updateAvatar(this.requireUserId(req),null);res.json({message:'Avatar deleted'});}

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
