import { Request, Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { AuthService } from '../services/authService';

const authService = new AuthService();
const metadata = (req: Request) => ({ ip: req.ip, userAgent: req.get('user-agent') });

export class AuthController {
  async register(req: Request, res: Response) {
    const { email, password, displayName } = req.body;
    res.status(201).json(await authService.register(email, password, displayName, metadata(req)));
  }
  async login(req: Request, res: Response) {
    const { email, password } = req.body;
    res.json(await authService.login(email, password, metadata(req)));
  }
  async refresh(req: Request, res: Response) { res.json(await authService.refresh(req.body.refreshToken, metadata(req))); }
  async logout(req: Request, res: Response) { res.json(await authService.logout(req.body?.refreshToken)); }
  async logoutAll(req: AuthRequest, res: Response) { res.json(await authService.logoutAll(req.userId!)); }
  async me(req: AuthRequest, res: Response) { res.json({ user: await authService.me(req.userId!) }); }
  async resendVerification(req: AuthRequest, res: Response) { res.json(await authService.resendVerification(req.userId!)); }
  async verifyEmail(req: Request, res: Response) { res.json(await authService.verifyEmail(req.body.token ?? req.query.token)); }
}
export const authController = new AuthController();
