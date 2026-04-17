import { Request, Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { AuthService } from '../services/authService';

const authService = new AuthService();

export class AuthController {
  async register(req: Request, res: Response) {
    console.log('[auth][controller] register:start email=%s', req.body?.email ?? '');
    const { email, password, displayName } = req.body;
    const result = await authService.register(email, password, displayName);
    console.log('[auth][controller] register:success userId=%s', result.user?.id ?? '');
    res.status(201).json(result);
  }

  async login(req: Request, res: Response) {
    console.log('[auth][controller] login:start email=%s', req.body?.email ?? '');
    const { email, password } = req.body;
    const result = await authService.login(email, password);
    console.log('[auth][controller] login:success userId=%s', result.user?.id ?? '');
    res.json(result);
  }

  async me(req: AuthRequest, res: Response) {
    console.log('[auth][controller] me:start userId=%s', req.userId ?? '');
    const user = await authService.me(req.userId!);
    console.log('[auth][controller] me:success userId=%s', user?.id ?? '');
    res.json({ user });
  }
}

export const authController = new AuthController();
