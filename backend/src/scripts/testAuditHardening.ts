import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { getPostgresPool, queryPostgres, withPostgresTransaction } from '../shared/db/postgresClient';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { AuthService } from '../modules/auth/services/authService';
import { getSupabaseAdminClient } from '../shared/db/supabaseAdminClient';
import { SoloSwipeService } from '../modules/solo-swipes/services/soloSwipeService';
import { CoupleInvitationService } from '../modules/couples/services/coupleInvitationService';
import { DishService } from '../modules/dishes/services/dishService';

async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const originalConnect = pool.connect;
  const queries: string[] = [];
  let connects = 0;
  let released = 0;
  (pool as any).connect = async () => {
    connects++;
    return {query: async (sql:string) => {queries.push(sql); return {rows:[],rowCount:0};}, release:()=>{released++;}};
  };
  try {
    await withPostgresTransaction(async () => {
      await queryPostgres('outer');
      await withPostgresTransaction(async () => { await queryPostgres('inner'); });
    });
    assert.deepEqual(queries, ['begin','outer','inner','commit']);
    assert.equal(connects,1); assert.equal(released,1);
    queries.length=0;
    await assert.rejects(withPostgresTransaction(async()=>{await queryPostgres('write');throw new Error('failure');}));
    assert.deepEqual(queries,['begin','write','rollback']);

    const admin=getSupabaseAdminClient().auth.admin;
    const signOut=admin.signOut;
    try {
      let received='';
      admin.signOut=async(token,scope)=>{received=token;assert.equal(scope,'global');return {data:null,error:null};};
      assert.deepEqual(await new AuthService().logoutAll('verified-access-jwt'),{success:true});
      assert.equal(received,'verified-access-jwt');
      admin.signOut=async()=>({data:null,error:new Error('Invalid JWT')} as any);
      await assert.rejects(new AuthService().logoutAll('verified-access-jwt'),(e:any)=>e.code==='SIGN_OUT_FAILED');
    } finally {admin.signOut=signOut;}

    const session:any={id:'solo',userId:'user',status:'active',currentIndex:0,deckDishIds:['new'],filters:{},meta:{}};
    repos.soloSessions.findByIdForUser=async()=>session;
    repos.swipes.listForUserSession=async()=>[{id:'old-swipe',dishId:'old',direction:'like'}] as any;
    repos.matches.listForSoloSession=async()=>[];
    postgresDishes.getByIds=async()=>[];
    let deletes=0;
    repos.swipes.deleteLatest=async()=>{deletes++;return {id:'old-swipe',dishId:'old',direction:'like'} as any;};
    const solo=new SoloSwipeService();
    assert.equal((await solo.undo('user','solo')).undone,false);
    assert.equal(deletes,0,'filter reset must not delete an earlier swipe');
    session.currentIndex=1;
    assert.equal((await solo.undo('user','solo')).undone,false);
    assert.equal(deletes,0,'mismatched latest swipe must not be deleted');
    session.deckDishIds=['old'];
    repos.soloSessions.update=async()=>{throw new Error('write failed');};
    queries.length=0;
    await assert.rejects(solo.undo('user','solo'));
    assert.equal(queries[queries.length-1],'rollback','undo failure rolls back deletion');
    assert.equal(deletes,1);

    // A timed-out final swipe can be replayed without advancing the deck twice.
    session.status='completed';
    postgresDishes.getByPublicId=async()=>({id:'old',_id:'old',name:'dish',visibility:'public',status:'approved'}) as any;
    const replay=await solo.swipe('user','solo','old','like');
    assert.equal(replay.alreadySwiped,true);
    assert.equal(replay.badgeDelta,0);
    await assert.rejects(solo.swipe('user','solo','old','dislike'),(e:any)=>e.code==='SWIPE_CONFLICT');

    repos.invitations.findForParticipant=async()=>({id:'invite',toUserId:'third',fromUserId:'owner',status:'pending',expiresAt:new Date(Date.now()+60000),newCoupleSessionId:'pair'}) as any;
    repos.coupleSessions.findById=async()=>({id:'pair',status:'active',memberIds:['owner','other']}) as any;
    let memberWrites=0;
    repos.coupleSessions.update=async()=>{memberWrites++;return null;};
    queries.length=0;
    await assert.rejects(new CoupleInvitationService().accept('third','invite'),(e:any)=>e.code==='SESSION_FULL');
    assert.equal(memberWrites,0);
    assert(queries.some(q=>q.includes('couple_sessions')&&q.includes('for update')));
    assert.equal(queries[queries.length-1],'rollback');

    const update=postgresDishes.updateCustomDish;
    try {
      postgresDishes.updateCustomDish=async()=>{await queryPostgres('delete recipe children');throw new Error('ingredient insert failed');};
      queries.length=0;
      await assert.rejects(new DishService().updateMyCustomDish('user','dish',{name:'dish',cuisine:'test',mood:[],dishRegister:'test',ingredients:[],steps:[],servings:'1'} as any));
      assert(queries.includes('delete recipe children'));
      assert.equal(queries[queries.length-1],'rollback');
    } finally {postgresDishes.updateCustomDish=update;}
    console.log('PASS transaction isolation, rollback, logout JWT/error, non-destructive Undo, full-pair rejection, recipe rollback');
  } finally { pool.connect=originalConnect; await pool.end(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
