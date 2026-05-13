import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { toDishDto, type DishDto } from '../../dishes/dto/dishDto';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { UserModel } from '../models/User';

export class UserSavedDishService {
  async addSavedDish(userId: string, dishId: string): Promise<void> {
    console.log('\n📝 [AddSavedDish] Starting for user:', userId, 'dishId:', dishId);
    
    const dish = await this.findActiveDishByPublicOrObjectId(dishId);
    if (!dish) {
      console.log('❌ [AddSavedDish] Dish not found');
      throw new AppError('Dish not found', 404);
    }

    console.log('📝 [AddSavedDish] Found dish, saving:', dish._id.toString());
    
    const result = await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $addToSet: { savedDishes: dish._id } }
    );
    
    console.log('📝 [AddSavedDish] Update result:', {
      matchedCount: result.matchedCount,
      modifiedCount: result.modifiedCount
    });
    
    // Verify the dish was actually added
    const userAfter = await UserModel.findById(userId);
    console.log('📝 [AddSavedDish] User now has', userAfter?.savedDishes.length || 0, 'saved dishes');
    console.log('📝 [AddSavedDish] Saved dishes:', userAfter?.savedDishes.map(id => id.toString()));
  }

  async removeSavedDish(userId: string, dishId: string): Promise<void> {
    const dish = await this.findActiveDishByPublicOrObjectId(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $pull: { savedDishes: dish._id } }
    );
  }

  async listSavedDishes(userId: string): Promise<DishDto[]> {
    console.log('\n📂 [ListSavedDishes] Getting saved dishes for user:', userId);
    
    const user = await UserModel.findById(userId)
      .orFail(() => new AppError('User not found', 404));
    
    console.log('📂 [ListSavedDishes] User found, has', user.savedDishes.length, 'saved dish IDs');
    console.log('📂 [ListSavedDishes] Saved dish IDs:', user.savedDishes.map(id => id.toString()));
    
    // First, let's check what's actually in the database
    if (user.savedDishes.length > 0) {
      console.log('\n📊 [ListSavedDishes] Checking what\'s in the database...');
      const firstId = user.savedDishes[0];
      const dishRaw = await DishModel.findById(firstId);
      console.log('📊 [ListSavedDishes] First dish raw data:');
      console.log('   _id:', dishRaw?._id?.toString());
      console.log('   status field exists:', dishRaw?.hasOwnProperty('status'));
      console.log('   status value:', dishRaw?.status);
      console.log('   status type:', typeof dishRaw?.status);
      console.log('   entire doc:', JSON.stringify(dishRaw?.toObject?.() || dishRaw));
    }
    
    // Manually fetch the dishes instead of using populate
    const dishes = await DishModel.find({
      _id: { $in: user.savedDishes }
    });
    
    console.log('📂 [ListSavedDishes] Found', dishes.length, 'dishes total');
    console.log('📂 [ListSavedDishes] Dishes details:');
    dishes.forEach(d => {
      console.log(`   - _id: ${d._id}, status: "${d.status}", name: ${d.name}`);
    });
    
    // Filter by active status
    const activeDishes = dishes.filter(d => d.status === 'active');
    console.log('📂 [ListSavedDishes] After filtering status=active:', activeDishes.length, 'dishes');
    
    return activeDishes.map((dish) => toDishDto(dish));
  }

  private async findActiveDishByPublicOrObjectId(dishId: string): Promise<DishDocument | null> {
    console.log('\n🔍 [FindDish] Looking for dish with id:', dishId);
    
    const normalizedDishId = dishId.trim();
    if (!normalizedDishId) {
      console.log('❌ [FindDish] Empty dishId');
      return null;
    }

    // Try to find as ObjectId first
    if (Types.ObjectId.isValid(normalizedDishId)) {
      console.log('🔎 [FindDish] Valid ObjectId format, searching...');
      
      // Check if dish exists at all
      const dishExists = await DishModel.findById(normalizedDishId);
      if (dishExists) {
        console.log('✅ [FindDish] Found dish by _id');
        console.log('   _id:', dishExists._id.toString());
        console.log('   status:', dishExists.status);
        console.log('   sourceType:', dishExists.sourceType || 'NOT SET');
        console.log('   name:', dishExists.name);
        
        // Check if status is active
        if (dishExists.status === 'active') {
          console.log('✅ [FindDish] Status is active, returning dish');
          return dishExists;
        } else {
          console.log('⚠️  [FindDish] Status is not active:', dishExists.status);
          return null;
        }
      } else {
        console.log('❌ [FindDish] Not found by _id');
      }
    } else {
      console.log('ℹ️  [FindDish] Not a valid ObjectId format');
    }

    // Search by sourceId
    console.log('🔎 [FindDish] Searching by sourceId:', normalizedDishId);
    const dishBySourceId = await DishModel.findOne({ 
      sourceId: normalizedDishId, 
      status: 'active' 
    });
    if (dishBySourceId) {
      console.log('✅ [FindDish] Found by sourceId');
      return dishBySourceId;
    }

    console.log('❌ [FindDish] Dish not found\n');
    return null;
  }
}

export const userSavedDishService = new UserSavedDishService();
