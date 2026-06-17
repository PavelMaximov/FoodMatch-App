import { z } from 'zod';

const objectIdPattern = /^[a-f\d]{24}$/i;
const publicIdPattern = /^[A-Za-z0-9][A-Za-z0-9_:\-/.]{0,199}$/;

export const mongoObjectIdSchema = z.string().trim().regex(objectIdPattern, 'Invalid id');
export const dishIdSchema = z.string().trim().min(1).max(200).refine((value) => !value.includes('$'), 'Invalid id');

export const safeImageUrlSchema = z.string().trim().max(2048).optional().or(z.literal('')).refine((value) => {
  if (!value) return true;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:';
  } catch {
    return false;
  }
}, 'Image URL must be a valid HTTPS URL');

export const cloudinaryCustomDishPublicIdSchema = z.string().trim().max(200).regex(publicIdPattern).optional();
