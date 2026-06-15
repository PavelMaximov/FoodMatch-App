import compression from 'compression';
import cors from 'cors';
import express from 'express';
import morgan from 'morgan';
import routes from './routes';
import { errorHandler } from '../core/middleware/errorHandler';
import { requestTiming } from '../core/middleware/requestTiming';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  if (process.env.NODE_ENV !== 'production') {
    app.use(morgan('dev'));
  }
  app.use(compression());
  app.use(requestTiming);

  app.use('/api', routes);
  app.use(errorHandler);

  return app;
}
