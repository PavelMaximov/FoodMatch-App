import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadMongoDishesInPostgresOrder } from '../../../shared/db/dishIdMapping';
import { toDishDto } from '../../dishes/dto/dishDto';
export class MatchService { async listForCouple(coupleId:string){const matches=await domainRepositories.matches.listForCouple(coupleId);const dishes=await loadMongoDishesInPostgresOrder(matches.map(m=>m.dishId));return matches.map((m,i)=>({id:m.id,coupleId:m.coupleSessionId,users:[],createdAt:m.createdAt,dish:toDishDto(dishes[i])})).filter(x=>x.dish);}}
