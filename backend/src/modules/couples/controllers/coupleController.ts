import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { CoupleService } from '../services/coupleService';
import { CoupleDeckService } from '../services/coupleDeckService';
import { CoupleInvitationService } from '../services/coupleInvitationService';

const coupleService = new CoupleService();
const coupleDeckService = new CoupleDeckService();
const coupleInvitationService = new CoupleInvitationService();

export class CoupleController {
  async create(req: AuthRequest, res: Response) { res.status(201).json({ session: await coupleService.createSession(req.user!.id) }); }
  async join(req: AuthRequest, res: Response) { res.json({ session: await coupleService.joinSession(req.user!.id, req.body.inviteCode, { replaceEmptyCurrentSession: req.body.replaceEmptyCurrentSession === true }) }); }
  async me(req: AuthRequest, res: Response) { res.json({ session: await coupleService.getMyActiveSession(req.user!.id) }); }
  async leave(req: AuthRequest, res: Response) { res.json(await coupleService.leaveSession(req.user!.id)); }
  async reset(req: AuthRequest, res: Response) { res.json(await coupleService.resetSession(req.user!.id)); }
  async partnerDisconnect(req: AuthRequest, res: Response) { res.json(await coupleService.markPartnerDisconnected(req.user!.id)); }
  async startFilterChange(req: AuthRequest, res: Response) { res.json(await coupleService.markFilterChangeStarted(req.user!.id)); }
  async commitFilterChange(req: AuthRequest, res: Response) { res.json(await coupleService.commitFilterChange(req.user!.id)); }
  async getFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.getFilterState(req.user!.id)); }
  async updateMyFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.updateMyFilterState(req.user!.id, req.body)); }
  async confirmFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.confirmMyFilterState(req.user!.id)); }
  async resetFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.resetFilterState(req.user!.id)); }
  async prepareDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.prepareDeckForActiveSession(req.user!.id)); }
  async getDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.getDeckForActiveSession(req.user!.id)); }
  async resetDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.resetDeckForActiveSession(req.user!.id)); }
  async requestDeckRestart(req: AuthRequest, res: Response) { res.json(await coupleDeckService.requestDeckRestart(req.user!.id)); }
  async getDeckRestartStatus(req: AuthRequest, res: Response) { res.json(await coupleDeckService.getDeckRestartStatus(req.user!.id)); }
  async continueAsBefore(req: AuthRequest, res: Response) { res.status(201).json({ invite: await coupleInvitationService.createContinueAsBeforeInvite(req.user!.id) }); }
  async pendingInvitations(req: AuthRequest, res: Response) { res.json({ invitations: await coupleInvitationService.getPending(req.user!.id) }); }
  async invitationStatus(req: AuthRequest, res: Response) { res.json({ invite: await coupleInvitationService.getInvitationStatus(req.user!.id, req.params.id as string) }); }
  async acceptInvitation(req: AuthRequest, res: Response) { res.json(await coupleInvitationService.accept(req.user!.id, req.params.id as string)); }
  async declineInvitation(req: AuthRequest, res: Response) { res.json({ invite: await coupleInvitationService.decline(req.user!.id, req.params.id as string) }); }
}

export const coupleController = new CoupleController();
