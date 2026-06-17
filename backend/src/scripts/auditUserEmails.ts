import mongoose from 'mongoose';
import { UserModel } from '../modules/users/models/User';

async function main() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI is required to audit user emails. Use the foodmatch database URI.');
  }

  await mongoose.connect(mongoUri);
  console.log(`[EmailAudit] Connected db=${mongoose.connection.name || 'unknown'}`);

  const duplicates = await UserModel.aggregate([
    {
      $group: {
        _id: { $toLower: { $trim: { input: '$email' } } },
        count: { $sum: 1 },
        emails: { $addToSet: '$email' },
        userIds: { $addToSet: '$_id' }
      }
    },
    { $match: { count: { $gt: 1 } } },
    { $sort: { count: -1, _id: 1 } }
  ]);

  if (duplicates.length === 0) {
    console.log('[EmailAudit] No case/trim duplicate email groups found.');
    return;
  }

  console.log('[EmailAudit] Duplicate normalized email groups found. Review manually before any cleanup.');
  for (const group of duplicates) {
    console.log(`[EmailAudit] normalized=${group._id} count=${group.count} emails=${group.emails.join(',')} userIds=${group.userIds.join(',')}`);
  }
}

main()
  .catch((error) => {
    console.error('[EmailAudit] Failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
