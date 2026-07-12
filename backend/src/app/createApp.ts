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

function isAllowedDevOrigin(origin: string) {
  if (env.NODE_ENV === 'production') return false;
  try {
    const url = new URL(origin);
    const host = url.hostname;
    return host === 'localhost' ||
      host === '127.0.0.1' ||
      /^192\.168\.\d{1,3}\.\d{1,3}$/.test(host) ||
      /^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host) ||
      /^172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}$/.test(host);
  } catch {
    return false;
  }
}

const corsOptions: CorsOptions = {
  origin(origin, callback) {
    if (!origin) {
      callback(null, true);
      return;
    }

    if (origin === env.FRONTEND_URL || env.CORS_ORIGINS.includes(origin) || isAllowedDevOrigin(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error('CORS origin not allowed'));
  },
  credentials: false,
  allowedHeaders: ['Authorization', 'Content-Type'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
};

export function createApp() {
  const app = express();

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
