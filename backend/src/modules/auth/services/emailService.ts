import { env } from '../../../config/env';

export class EmailService {
  async sendVerificationEmail(email: string, token: string): Promise<void> {
    const link = `${env.APP_PUBLIC_URL.replace(/\/$/, '')}/api/auth/verify-email?token=${encodeURIComponent(token)}`;
    if (env.EMAIL_PROVIDER === 'dev' && env.NODE_ENV !== 'production') {
      console.log(`[EmailVerification][DEV ONLY] Send to ${email}: ${link}`);
      return;
    }
    if (env.REQUIRE_EMAIL_VERIFICATION && env.NODE_ENV === 'production') {
      console.warn('[EmailVerification] Production provider is not configured; verification email was not sent.');
    }
  }
}
export const emailService = new EmailService();
