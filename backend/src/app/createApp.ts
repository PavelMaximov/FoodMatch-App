import compression from 'compression';
import cors, { CorsOptions } from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import routes from './routes';
import { env } from '../config/env';
import { errorHandler } from '../core/middleware/errorHandler';
import { applyWriteRateLimiter } from '../core/middleware/rateLimiters';
import { requestTiming } from '../core/middleware/requestTiming';

const corsOptions: CorsOptions = {
  origin(origin, callback) {
    if (!origin) {
      callback(null, true);
      return;
    }

    if (env.CORS_ORIGINS.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error('CORS origin not allowed'));
  },
  credentials: false
};

export function createApp() {
  const app = express();
  app.set('etag', false);

  app.use(helmet());
  app.use(cors(corsOptions));
  app.use(express.json({ limit: '200kb' }));
  app.use(express.urlencoded({ extended: false, limit: '50kb' }));
  if (process.env.NODE_ENV !== 'production') {
    app.use(morgan('dev'));
  }
  app.use(compression());
  app.use(requestTiming);
  app.use(applyWriteRateLimiter);

  app.use('/api', routes);
  app.use(errorHandler);

  return app;
}
