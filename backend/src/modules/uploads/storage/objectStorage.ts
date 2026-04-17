import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../../../config/env';
import { AppError } from '../../../core/errors/AppError';

export interface SignedUploadRequest {
  key: string;
  contentType: string;
  sizeBytes: number;
}

export class ObjectStorage {
  private client: S3Client | null = null;

  private getClient(): S3Client {
    if (this.client) {
      return this.client;
    }

    if (!env.STORAGE_BUCKET || !env.STORAGE_ACCESS_KEY_ID || !env.STORAGE_SECRET_ACCESS_KEY) {
      throw new AppError('Storage is not configured', 500);
    }

    this.client = new S3Client({
      region: env.STORAGE_REGION,
      endpoint: env.STORAGE_ENDPOINT || undefined,
      forcePathStyle: Boolean(env.STORAGE_ENDPOINT),
      credentials: {
        accessKeyId: env.STORAGE_ACCESS_KEY_ID,
        secretAccessKey: env.STORAGE_SECRET_ACCESS_KEY
      }
    });

    return this.client;
  }

  async createSignedUploadUrl(input: SignedUploadRequest) {
    const command = new PutObjectCommand({
      Bucket: env.STORAGE_BUCKET,
      Key: input.key,
      ContentType: input.contentType,
      ContentLength: input.sizeBytes
    });

    const uploadUrl = await getSignedUrl(this.getClient(), command, { expiresIn: env.STORAGE_UPLOAD_URL_TTL_SECONDS });

    return {
      uploadUrl,
      method: 'PUT' as const,
      headers: {
        'Content-Type': input.contentType
      }
    };
  }

  async createSignedReadUrl(key: string) {
    const command = new GetObjectCommand({
      Bucket: env.STORAGE_BUCKET,
      Key: key
    });

    return getSignedUrl(this.getClient(), command, { expiresIn: env.STORAGE_READ_URL_TTL_SECONDS });
  }

  async deleteObject(key: string) {
    const command = new DeleteObjectCommand({
      Bucket: env.STORAGE_BUCKET,
      Key: key
    });

    await this.getClient().send(command);
  }
}

export const objectStorage = new ObjectStorage();
