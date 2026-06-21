import { Router } from 'express';
import authRoutes from '../modules/auth/routes/authRoutes';
import coupleRoutes from '../modules/couples/routes/coupleRoutes';
import dishRoutes from '../modules/dishes/routes/dishRoutes';
import swipeRoutes from '../modules/swipes/routes/swipeRoutes';
import matchRoutes from '../modules/matches/routes/matchRoutes';
import ingredientRoutes from '../modules/ingredients/routes/ingredientRoutes';
import userRoutes from '../modules/users/routes/userRoutes';
import uploadRoutes from '../modules/uploads/uploadRoutes';
import soloSwipeRoutes from '../modules/solo-swipes/routes/soloSwipeRoutes';
import filterRoutes from '../modules/filters/routes/lastFilterPresetRoutes';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

router.use('/auth', authRoutes);
router.use('/couples', coupleRoutes);
router.use('/dishes', dishRoutes);
router.use('/swipes', swipeRoutes);
router.use('/matches', matchRoutes);
router.use('/ingredients', ingredientRoutes);
router.use('/users', userRoutes);
router.use('/uploads', uploadRoutes);
router.use('/solo-swipes', soloSwipeRoutes);
router.use('/filters', filterRoutes);

export default router;
