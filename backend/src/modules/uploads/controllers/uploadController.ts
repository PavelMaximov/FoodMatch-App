import { Response } from 'express';
import { AppError } from '../../../core/errors/AppError';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { uploadService } from '../services/uploadService';

export class UploadController {
  async getAvatarUploadUrl(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const result = await uploadService.createAvatarUploadUrl({
      userId,
      originalFileName: req.body?.fileName ? String(req.body.fileName) : undefined,
      mimeType: String(req.body?.mimeType ?? ''),
      sizeBytes: Number(req.body?.sizeBytes ?? 0)
    });

    res.json(result);
  }

  async getDishImageUploadUrl(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const result = await uploadService.createDishImageUploadUrl({
      userId,
      originalFileName: req.body?.fileName ? String(req.body.fileName) : undefined,
      mimeType: String(req.body?.mimeType ?? ''),
      sizeBytes: Number(req.body?.sizeBytes ?? 0)
    });

    res.json(result);
  }

  private requireUserId(req: AuthRequest) {
    if (!req.userId) {
      throw new AppError('Unauthorized', 401);
    }

    return req.userId;
  }
}

export const uploadController = new UploadController();
