import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { CoupleService } from '../services/coupleService';
import { CoupleDeckService } from '../services/coupleDeckService';
import { CoupleInvitationService } from '../services/coupleInvitationService';

const coupleService = new CoupleService();
const coupleDeckService = new CoupleDeckService();
const coupleInvitationService = new CoupleInvitationService();

export class CoupleController {
  async create(req: AuthRequest, res: Response) { res.status(201).json({ session: await coupleService.createSession(req.userId!) }); }
  async join(req: AuthRequest, res: Response) { res.json({ session: await coupleService.joinSession(req.userId!, req.body.inviteCode, { replaceEmptyCurrentSession: req.body.replaceEmptyCurrentSession === true }) }); }
  async me(req: AuthRequest, res: Response) { res.json({ session: await coupleService.getMyActiveSession(req.userId!) }); }
  async leave(req: AuthRequest, res: Response) { res.json(await coupleService.leaveSession(req.userId!)); }
  async reset(req: AuthRequest, res: Response) { res.json(await coupleService.resetSession(req.userId!)); }
  async partnerDisconnect(req: AuthRequest, res: Response) { res.json(await coupleService.markPartnerDisconnected(req.userId!)); }
  async startFilterChange(req: AuthRequest, res: Response) { res.json(await coupleService.markFilterChangeStarted(req.userId!)); }
  async commitFilterChange(req: AuthRequest, res: Response) { res.json(await coupleService.commitFilterChange(req.userId!)); }
  async getFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.getFilterState(req.userId!)); }
  async updateMyFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.updateMyFilterState(req.userId!, req.body)); }
  async confirmFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.confirmMyFilterState(req.userId!)); }
  async resetFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.resetFilterState(req.userId!)); }
  async prepareDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.prepareDeckForActiveSession(req.userId!)); }
  async getDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.getDeckForActiveSession(req.userId!)); }
  async resetDeck(req: AuthRequest, res: Response) { res.json(await coupleDeckService.resetDeckForActiveSession(req.userId!)); }
  async requestDeckRestart(req: AuthRequest, res: Response) { res.json(await coupleDeckService.requestDeckRestart(req.userId!)); }
  async getDeckRestartStatus(req: AuthRequest, res: Response) { res.json(await coupleDeckService.getDeckRestartStatus(req.userId!)); }
  async continueAsBefore(req: AuthRequest, res: Response) { res.status(201).json({ invite: await coupleInvitationService.createContinueAsBeforeInvite(req.userId!) }); }
  async pendingInvitations(req: AuthRequest, res: Response) { res.json({ invitations: await coupleInvitationService.getPending(req.userId!) }); }
  async acceptInvitation(req: AuthRequest, res: Response) { res.json(await coupleInvitationService.accept(req.userId!, req.params.id as string)); }
  async declineInvitation(req: AuthRequest, res: Response) { res.json({ invite: await coupleInvitationService.decline(req.userId!, req.params.id as string) }); }
}

export const coupleController = new CoupleController();
