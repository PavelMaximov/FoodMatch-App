import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { userSavedDishController } from '../controllers/userSavedDishController';

const router = Router();

router.use(authMiddleware);

router.get('/saved-dishes', asyncHandler(userSavedDishController.list.bind(userSavedDishController)));
router.post('/saved-dishes/:dishId', asyncHandler(userSavedDishController.save.bind(userSavedDishController)));
router.delete('/saved-dishes/:dishId', asyncHandler(userSavedDishController.unsave.bind(userSavedDishController)));

export default router;
