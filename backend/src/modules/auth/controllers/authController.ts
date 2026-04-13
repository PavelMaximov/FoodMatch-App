import { Request, Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { AuthService } from '../services/authService';

const authService = new AuthService();

export class AuthController {
  async register(req: Request, res: Response) {
    const { email, password, displayName } = req.body;
    const result = await authService.register(email, password, displayName);
    res.status(201).json(result);
  }

  async login(req: Request, res: Response) {
    const { email, password } = req.body;
    const result = await authService.login(email, password);
    res.json(result);
  }

  async me(req: AuthRequest, res: Response) {
    const user = await authService.me(req.userId!);
    res.json({ user });
  }
}

export const authController = new AuthController();
