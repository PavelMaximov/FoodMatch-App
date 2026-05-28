import { Types } from 'mongoose';
import { DishDocument, DishModel } from '../models/Dish';

export async function resolveDishByAnyId(value: string | Types.ObjectId): Promise<DishDocument | null> {
  const normalizedValue = String(value ?? '').trim();

  if (!normalizedValue) {
    console.debug('[DishResolver] resolved value=%s by=none', normalizedValue);
    return null;
  }

  const dishById = await DishModel.findOne({ id: normalizedValue });
  if (dishById) {
    console.debug('[DishResolver] resolved value=%s by=id', normalizedValue);
    return dishById;
  }

  const dishBySourceId = await DishModel.findOne({ sourceId: normalizedValue });
  if (dishBySourceId) {
    console.debug('[DishResolver] resolved value=%s by=sourceId', normalizedValue);
    return dishBySourceId;
  }

  if (Types.ObjectId.isValid(normalizedValue)) {
    const dishByObjectId = await DishModel.findById(normalizedValue);
    if (dishByObjectId) {
      console.debug('[DishResolver] resolved value=%s by=_id', normalizedValue);
      return dishByObjectId;
    }
  }

  console.debug('[DishResolver] resolved value=%s by=none', normalizedValue);
  return null;
}
