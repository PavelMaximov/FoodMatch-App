import { Document, Schema, Types, model } from 'mongoose';
import { RecommendationMeta } from '../../recommendations/recommendationTypes';

export interface SoloSwipeEntry { dishId: Types.ObjectId; direction: 'like' | 'dislike'; createdAt: Date; }
export interface SoloSwipeFilter { dishRegisters: string[]; includeCustomDishesFirst: boolean; cuisines: string[]; moods: string[]; diet: string[]; exclusions: string[]; }
export interface SoloSwipeSessionDocument extends Document {
  userId: Types.ObjectId; mode: 'solo'; status: 'active' | 'completed' | 'abandoned'; filter: SoloSwipeFilter;
  deckDishIds: Types.ObjectId[]; deckIndex: number; swipes: SoloSwipeEntry[]; resultDishIds: Types.ObjectId[];
  matchedCount: number; recommendationMeta?: RecommendationMeta | null; lastActivityAt: Date; completedAt?: Date | null; createdAt: Date; updatedAt: Date;
}
const filterSchema = new Schema<SoloSwipeFilter>({ dishRegisters:{type:[String],default:[]}, includeCustomDishesFirst:{type:Boolean,default:false}, cuisines:{type:[String],default:[]}, moods:{type:[String],default:[]}, diet:{type:[String],default:[]}, exclusions:{type:[String],default:[]} },{_id:false});
const swipeEntrySchema = new Schema<SoloSwipeEntry>({ dishId:{type:Schema.Types.ObjectId,ref:'Dish',required:true}, direction:{type:String,enum:['like','dislike'],required:true}, createdAt:{type:Date,default:Date.now} },{_id:false});
const soloSwipeSessionSchema = new Schema<SoloSwipeSessionDocument>({
  userId:{type:Schema.Types.ObjectId,ref:'User',required:true,index:true}, mode:{type:String,enum:['solo'],default:'solo'}, status:{type:String,enum:['active','completed','abandoned'],default:'active',index:true},
  filter:{type:filterSchema,required:true}, deckDishIds:[{type:Schema.Types.ObjectId,ref:'Dish'}], deckIndex:{type:Number,default:0}, swipes:{type:[swipeEntrySchema],default:[]}, resultDishIds:[{type:Schema.Types.ObjectId,ref:'Dish'}], matchedCount:{type:Number,default:0}, recommendationMeta:{type:Schema.Types.Mixed,default:null}, lastActivityAt:{type:Date,default:Date.now,index:true}, completedAt:{type:Date,default:null}
},{timestamps:true});
soloSwipeSessionSchema.index({userId:1,status:1});
soloSwipeSessionSchema.index({userId:1,createdAt:-1});
soloSwipeSessionSchema.index({status:1,lastActivityAt:1});
export const SoloSwipeSessionModel = model<SoloSwipeSessionDocument>('SoloSwipeSession', soloSwipeSessionSchema);
