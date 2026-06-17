import { connectDatabase } from '../config/database';
import { UserModel } from '../modules/users/models/User';

async function main() {
  if (process.env.CONFIRM_MIGRATION !== 'true') {
    console.error('Refusing to run. Set CONFIRM_MIGRATION=true to mark legacy users verified.');
    process.exit(1);
  }
  await connectDatabase();
  const result = await UserModel.updateMany({ emailVerified: { $exists: false } }, { $set: { emailVerified: true, emailVerifiedAt: new Date() } });
  console.log(`Marked ${result.modifiedCount} legacy users as verified.`);
  process.exit(0);
}
main().catch((error) => { console.error('Migration failed', error); process.exit(1); });
