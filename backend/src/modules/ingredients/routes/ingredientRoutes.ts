import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { ingredientController } from '../controllers/ingredientController';

const router = Router();

router.use(authMiddleware);
router.get('/search', asyncHandler(ingredientController.search.bind(ingredientController)));

export default router;
