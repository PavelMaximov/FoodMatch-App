import { Types } from 'mongoose';
import { toDishDto } from '../../dishes/dto/dishDto';
import { MatchModel } from '../models/Match';

export class MatchService {
  async listForCouple(coupleId: string) {
    const matches = await MatchModel.find({ coupleId: new Types.ObjectId(coupleId) })
      .sort({ createdAt: -1 })
      .populate({ path: 'dishId', select: 'sourceId name description imageUrl imagePublicId cuisine type mood diet ingredients cookTime calories nutrition effort source servings season popular steps rawSourceData status' })
      .lean();
    return matches.map((match) => ({
      id: match._id?.toString() ?? '',
      coupleId: match.coupleId,
      users: match.users,
      createdAt: match.createdAt,
      dish: toDishDto(match.dishId)
    }));
  }
}
