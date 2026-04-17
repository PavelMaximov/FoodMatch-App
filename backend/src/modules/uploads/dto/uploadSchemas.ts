import { z } from 'zod';

export const uploadUrlSchema = z.object({
  fileName: z.string().trim().min(1).max(256).optional(),
  mimeType: z.string().trim().min(1),
  sizeBytes: z.number().int().positive()
});
