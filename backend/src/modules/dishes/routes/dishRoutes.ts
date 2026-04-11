import { Router } from 'express';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { dishController } from '../controllers/dishController';

const router = Router();

router.get('/', asyncHandler(dishController.list.bind(dishController)));
router.get('/random', asyncHandler(dishController.random.bind(dishController)));
router.get('/search', asyncHandler(dishController.search.bind(dishController)));
router.get('/:id', asyncHandler(dishController.getById.bind(dishController)));

export default router;
