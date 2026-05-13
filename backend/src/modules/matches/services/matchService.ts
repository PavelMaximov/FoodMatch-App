import { Types } from 'mongoose';
import { toDishDto } from '../../dishes/dto/dishDto';
import { MatchModel } from '../models/Match';

export class MatchService {
  async listForCouple(coupleId: string) {
    const matches = await MatchModel.find({ coupleId: new Types.ObjectId(coupleId) }).populate('dishId');
    return matches.map((match) => ({
      id: match.id,
      coupleId: match.coupleId,
      users: match.users,
      createdAt: match.createdAt,
      dish: toDishDto(match.dishId)
    }));
  }
}
