import { Response } from 'express';
import { AppError } from '../../../core/errors/AppError';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { userService } from '../services/userService';

export class UserController {
  async confirmAvatar(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const user = await userService.confirmAvatar(userId, {
      avatarKey: String(req.body?.avatarKey ?? ''),
      avatarMimeType: String(req.body?.avatarMimeType ?? ''),
      avatarSize: Number(req.body?.avatarSize ?? 0)
    });

    res.json({ user });
  }

  async deleteAvatar(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const result = await userService.deleteAvatar(userId);
    res.json(result);
  }

  private requireUserId(req: AuthRequest) {
    if (!req.userId) {
      throw new AppError('Unauthorized', 401);
    }

    return req.userId;
  }
}

export const userController = new UserController();
