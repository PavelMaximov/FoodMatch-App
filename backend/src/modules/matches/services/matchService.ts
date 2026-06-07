import { Types } from 'mongoose';
import { DISH_DTO_SELECT, toDishDto } from '../../dishes/dto/dishDto';
import { MatchModel } from '../models/Match';

export class MatchService {
  async listForCouple(coupleId: string) {
    const matches = await MatchModel.find({ coupleId: new Types.ObjectId(coupleId) })
      .sort({ createdAt: -1 })
      .populate({ path: 'dishId', select: DISH_DTO_SELECT })
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
