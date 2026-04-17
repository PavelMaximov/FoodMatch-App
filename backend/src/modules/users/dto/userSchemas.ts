import { z } from 'zod';

export const confirmAvatarSchema = z.object({
  avatarKey: z.string().trim().min(1),
  avatarMimeType: z.string().trim().min(1),
  avatarSize: z.number().int().positive()
});
