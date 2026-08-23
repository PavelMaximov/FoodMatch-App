import mongoose from 'mongoose';
import { getSupabaseConfigHealth } from '../../config/supabase';

export function isConfigHealthEnabled(nodeEnv: string): boolean {
  return nodeEnv !== 'production';
}

export function getConfigHealthResponse() {
  const health = getSupabaseConfigHealth();
  return {
    api: 'ok',
    supabaseHost: health.supabaseHost,
    supabaseUrlIsLocal: health.supabaseUrlIsLocal,
    hasAnonKey: health.hasAnonKey,
    hasServiceRoleKey: health.hasServiceRoleKey,
    hasDbUrl: health.hasDbUrl,
    mongoConnected: mongoose.connection.readyState === 1,
  };
}
