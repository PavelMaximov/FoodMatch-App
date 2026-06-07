import { UploadApiOptions, UploadApiResponse, v2 as cloudinary } from 'cloudinary';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';

export const CLOUDINARY_FOLDERS = {
  userAvatars: 'foodmatch/users/avatars',
  customDishes: 'foodmatch/dishes/custom',
  catalogDishes: 'foodmatch/dishes/catalog',
  appBanners: 'foodmatch/app/banners',
  appPromos: 'foodmatch/app/promos'
} as const;

export const CLOUDINARY_TRANSFORMATIONS = {
  avatar: [{ width: 512, height: 512, crop: 'fill', quality: 'auto', fetch_format: 'auto' }],
  customDish: [{ quality: 'auto', fetch_format: 'auto' }]
} as const;

interface UploadImageInput {
  fileBuffer: Buffer;
  mimeType: string;
  folder: (typeof CLOUDINARY_FOLDERS)[keyof typeof CLOUDINARY_FOLDERS];
  publicIdPrefix?: string;
  transformation?: UploadApiOptions['transformation'];
}

export interface NormalizedUploadResult {
  url: string;
  secureUrl: string;
  publicId: string;
  width?: number;
  height?: number;
  format?: string;
  bytes?: number;
}

let configured = false;

function configureCloudinary(): void {
  if (configured) {
    return;
  }

  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new AppError('Image service is not available right now.', 500, 'CLOUDINARY_NOT_CONFIGURED');
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true
  });
  configured = true;
}

export async function uploadImage(input: UploadImageInput): Promise<NormalizedUploadResult> {
  configureCloudinary();

  try {
    const result = await new Promise<UploadApiResponse>((resolve, reject) => {
      const options: UploadApiOptions = {
        folder: input.folder,
        resource_type: 'image',
        use_filename: false,
        unique_filename: true,
        overwrite: false,
        transformation: input.transformation
      };

      if (input.publicIdPrefix?.trim()) {
        options.public_id = `${input.publicIdPrefix.trim()}-${Date.now()}`;
      }

      const stream = cloudinary.uploader.upload_stream(options, (error, uploadResult) => {
        if (error || !uploadResult) {
          reject(error ?? new Error('Cloudinary upload returned no result.'));
          return;
        }
        resolve(uploadResult);
      });

      stream.end(input.fileBuffer);
    });

    return normalizeUploadResult(result);
  } catch (error) {
    console.error('[Uploads] Cloudinary upload failed', safeCloudinaryLog(error));
    throw new AppError('Image upload failed. Please try again.', 500, 'CLOUDINARY_UPLOAD_FAILED');
  }
}

export async function deleteImage(publicId: string): Promise<void> {
  if (!publicId.trim()) {
    return;
  }

  configureCloudinary();

  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
  } catch (error) {
    console.error('[Uploads] Cloudinary delete failed', safeCloudinaryLog(error));
    throw new AppError('Image deletion failed. Please try again.', 500, 'CLOUDINARY_DELETE_FAILED');
  }
}

function normalizeUploadResult(result: UploadApiResponse): NormalizedUploadResult {
  if (!result.secure_url || !result.public_id) {
    throw new AppError('Image upload failed. Please try again.', 500, 'CLOUDINARY_UPLOAD_FAILED');
  }

  return {
    url: result.url,
    secureUrl: result.secure_url,
    publicId: result.public_id,
    width: result.width,
    height: result.height,
    format: result.format,
    bytes: result.bytes
  };
}

function safeCloudinaryLog(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return { name: error.name, message: error.message };
  }

  return { message: 'Unknown Cloudinary error' };
}
