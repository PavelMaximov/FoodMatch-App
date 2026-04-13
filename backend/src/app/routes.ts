import { Router } from 'express';
import authRoutes from '../modules/auth/routes/authRoutes';
import coupleRoutes from '../modules/couples/routes/coupleRoutes';
import dishRoutes from '../modules/dishes/routes/dishRoutes';
import swipeRoutes from '../modules/swipes/routes/swipeRoutes';
import matchRoutes from '../modules/matches/routes/matchRoutes';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

router.use('/auth', authRoutes);
router.use('/couples', coupleRoutes);
router.use('/dishes', dishRoutes);
router.use('/swipes', swipeRoutes);
router.use('/matches', matchRoutes);

export default router;
