import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { customDishSchema } from '../dto/dishSchemas';
import { dishController } from '../controllers/dishController';

const router = Router();

router.use(authMiddleware);

router.get('/', asyncHandler(dishController.list.bind(dishController)));
router.post('/custom', validateBody(customDishSchema), asyncHandler(dishController.createCustom.bind(dishController)));
router.get('/my', asyncHandler(dishController.listMine.bind(dishController)));
router.get('/random', asyncHandler(dishController.random.bind(dishController)));
router.get('/search', asyncHandler(dishController.search.bind(dishController)));
router.put('/:id', validateBody(customDishSchema), asyncHandler(dishController.updateMine.bind(dishController)));
router.delete('/:id', asyncHandler(dishController.deleteMine.bind(dishController)));
router.get('/:id', asyncHandler(dishController.getById.bind(dishController)));

export default router;
