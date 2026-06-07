import path from 'path';
import multer from 'multer';
import { AppError } from '../../../core/errors/AppError';

const allowedMimeTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const allowedExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);
export const maxImageFileSizeBytes = 5 * 1024 * 1024;
export const uploadFieldName = 'file';

const storage = multer.memoryStorage();

export const imageUpload = multer({
  storage,
  limits: { fileSize: maxImageFileSizeBytes },
  fileFilter: (_req, file, callback) => {
    const extension = path.extname(file.originalname ?? '').toLowerCase();
    if (!allowedMimeTypes.has(file.mimetype) || !allowedExtensions.has(extension)) {
      callback(new AppError('Only JPG, PNG, and WEBP images are allowed.', 400, 'INVALID_IMAGE_TYPE'));
      return;
    }

    callback(null, true);
  }
});

export function requireUploadedImage(file?: Express.Multer.File): Express.Multer.File {
  if (!file) {
    throw new AppError('Image file is required.', 400, 'IMAGE_REQUIRED');
  }

  return file;
}

export function mapMulterError(error: unknown): AppError | unknown {
  if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
    return new AppError('Image file is too large. Maximum size is 5 MB.', 413, 'IMAGE_TOO_LARGE');
  }

  return error;
}
