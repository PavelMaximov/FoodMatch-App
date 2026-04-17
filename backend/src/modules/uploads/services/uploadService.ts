import crypto from 'crypto';
import path from 'path';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';
import { objectStorage } from '../storage/objectStorage';

const ALLOWED_IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);
const AVATAR_MAX_BYTES = 3 * 1024 * 1024;
const DISH_MAX_BYTES = 5 * 1024 * 1024;

interface UploadUrlInput {
  userId: string;
  originalFileName?: string;
  mimeType: string;
  sizeBytes: number;
}

interface ConfirmedUploadMeta {
  key: string;
  mimeType: string;
  sizeBytes: number;
}

export class UploadService {
  async createAvatarUploadUrl(input: UploadUrlInput) {
    this.validateImageMetadata(input.mimeType, input.sizeBytes, AVATAR_MAX_BYTES);

    const extension = this.resolveSafeExtension(input.mimeType, input.originalFileName);
    const objectKey = `avatars/${input.userId}/${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const signed = await objectStorage.createSignedUploadUrl({
      key: objectKey,
      contentType: input.mimeType,
      sizeBytes: input.sizeBytes
    });

    return {
      ...signed,
      objectKey,
      maxBytes: AVATAR_MAX_BYTES,
      expiresInSeconds:  env.STORAGE_UPLOAD_URL_TTL_SECONDS
    };
  }

  async createDishImageUploadUrl(input: UploadUrlInput) {
    this.validateImageMetadata(input.mimeType, input.sizeBytes, DISH_MAX_BYTES);

    const extension = this.resolveSafeExtension(input.mimeType, input.originalFileName);
    const objectKey = `dishes/${input.userId}/${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const signed = await objectStorage.createSignedUploadUrl({
      key: objectKey,
      contentType: input.mimeType,
      sizeBytes: input.sizeBytes
    });

    return {
      ...signed,
      objectKey,
      maxBytes: DISH_MAX_BYTES,
      expiresInSeconds: env.STORAGE_UPLOAD_URL_TTL_SECONDS
    };
  }

  validateAndNormalizeAvatarMeta(userId: string, raw: ConfirmedUploadMeta): ConfirmedUploadMeta {
    if (!raw.key.startsWith(`avatars/${userId}/`)) {
      throw new AppError('Invalid avatar key', 400);
    }

    this.validateImageMetadata(raw.mimeType, raw.sizeBytes, AVATAR_MAX_BYTES);
    return raw;
  }

  validateAndNormalizeDishMeta(userId: string, raw: ConfirmedUploadMeta): ConfirmedUploadMeta {
    if (!raw.key.startsWith(`dishes/${userId}/`)) {
      throw new AppError('Invalid dish image key', 400);
    }

    this.validateImageMetadata(raw.mimeType, raw.sizeBytes, DISH_MAX_BYTES);
    return raw;
  }

  async resolveReadUrl(key?: string | null) {
    if (!key) {
      return '';
    }

    console.log('[upload][read-url] start key=%s', key);
    try {
      const signedUrl = await objectStorage.createSignedReadUrl(key);
      console.log('[upload][read-url] success key=%s', key);
      return signedUrl;
    } catch (error) {
      console.warn('[upload][read-url] failed key=%s reason=%s', key, (error as Error)?.message ?? 'unknown');
      throw error;
    }
  }

  async deleteByKey(key?: string | null) {
    if (!key) {
      return;
    }

    await objectStorage.deleteObject(key);
  }

  private validateImageMetadata(mimeType: string, sizeBytes: number, maxBytes: number) {
    const normalizedMime = mimeType.trim().toLowerCase();
    if (!ALLOWED_IMAGE_MIME_TYPES.has(normalizedMime)) {
      throw new AppError('Unsupported image type', 400);
    }

    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > maxBytes) {
      throw new AppError(`Image size must be between 1 byte and ${maxBytes} bytes`, 400);
    }
  }

  private resolveSafeExtension(mimeType: string, originalFileName?: string) {
    const normalizedMime = mimeType.trim().toLowerCase();

    if (normalizedMime === 'image/png') return 'png';
    if (normalizedMime === 'image/webp') return 'webp';
    if (normalizedMime === 'image/jpeg' || normalizedMime === 'image/jpg') return 'jpg';

    const originalExt = path.extname(originalFileName ?? '').replace('.', '').toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp'].includes(originalExt)) {
      return originalExt === 'jpeg' ? 'jpg' : originalExt;
    }

    return 'jpg';
  }
}

export const uploadService = new UploadService();
