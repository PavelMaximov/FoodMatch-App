import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { AppError } from '../../../core/errors/AppError';
import { LastFilterPresetService } from '../services/lastFilterPresetService';
const service = new LastFilterPresetService();
export class LastFilterPresetController { async get(req:AuthRequest,res:Response){ const mode = req.query.mode === 'paired' ? 'paired' : 'solo'; const preset = await service.getLast(req.userId!, mode); const legacyPresetAvailable = mode === 'paired' && !preset ? await service.hasLegacyPairedPreset(req.userId!) : false; res.json({preset, ...(legacyPresetAvailable ? { legacyPresetAvailable } : {})}); } async put(req:AuthRequest,res:Response){ const mode = req.body?.mode === 'paired' ? 'paired' : req.body?.mode === 'solo' ? 'solo' : null; if(!mode) throw new AppError('Invalid filter mode',400); const preset = await service.saveLast(req.userId!, {...req.body, mode}); res.json({preset}); }}
export const lastFilterPresetController = new LastFilterPresetController();
