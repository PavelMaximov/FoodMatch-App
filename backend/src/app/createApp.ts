import cors from 'cors';
import express from 'express';
import morgan from 'morgan';
import routes from './routes';
import { errorHandler } from '../core/middleware/errorHandler';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(morgan('dev'));

  app.use('/api', routes);
  app.use(errorHandler);

  return app;
}
