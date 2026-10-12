import assert from 'node:assert/strict';
import { once } from 'node:events';
import express from 'express';
import { AuthRequest } from '../core/middleware/authMiddleware';
import { errorHandler } from '../core/middleware/errorHandler';
import { CoupleSessionRecord } from '../domain/repositories/types';
import { EntitlementService } from '../modules/entitlements/services/entitlementService';
import { createEntitlementRouter } from '../modules/entitlements/routes/entitlementRoutes';

export async function testEntitlementResolution() {
  for (const failure of ['subscription', 'grants'] as const) {
    const storageError = new Error(`${failure} storage unavailable`);
    const service = new EntitlementService({
      findSubscription: async () => { if (failure === 'subscription') throw storageError; return null; },
      findActiveGrants: async () => { if (failure === 'grants') throw storageError; return []; },
    });
    assert.equal((await service.getEffectiveEntitlements('user')).isPremium, false);
    assert.equal(await service.canUseFeature('user', 'advanced_filters'), false);
    await assert.rejects(service.resolveEffectiveEntitlements('user'), (error: unknown) => error === storageError);
    console.log(`PASS ${failure} failure denies authorization while strict resolution propagates it`);
  }

  for (const scenario of ['free', 'subscription-failure', 'grants-failure', 'partner-failure', 'pair-lookup-failure', 'mixed-pair'] as const) {
    const service = new EntitlementService({
      findSubscription: async (userId) => {
        if (scenario === 'subscription-failure' || (scenario === 'partner-failure' && userId === 'partner')) {
          throw Error('subscription storage unavailable');
        }
        if (scenario === 'mixed-pair' && userId === 'partner') {
          const now = new Date();
          return {tier: 'premium', status: 'active', provider: null, productId: null,
            currentPeriodStart: now, expiresAt: new Date(now.getTime() + 86400000), trialEndsAt: null, updatedAt: now};
        }
        return null;
      },
      findActiveGrants: async () => { if (scenario === 'grants-failure') throw Error('grant storage unavailable'); return []; },
    });
    const app = express();
    app.use('/api/entitlements', createEntitlementRouter({
      entitlements: service,
      authenticate: (req, _res, next) => { (req as AuthRequest).userId = 'free'; next(); },
      findActivePair: async () => {
        if (scenario === 'pair-lookup-failure') throw Error('pair storage unavailable');
        return scenario === 'partner-failure' || scenario === 'mixed-pair'
          ? {id: 'pair', status: 'active', memberIds: ['free', 'partner']} as CoupleSessionRecord : null;
      },
    }));
    app.use(errorHandler);
    const server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');
    try {
      const address = server.address();
      assert.ok(address && typeof address !== 'string');
      const response = await fetch(`http://127.0.0.1:${address.port}/api/entitlements/me`);
      const body = await response.json() as Record<string, any>;
      assert.ok(response.headers.get('cache-control')?.includes('no-store'));
      if (scenario === 'free' || scenario === 'mixed-pair') {
        assert.equal(response.status, 200); assert.equal(body.tier, 'free'); assert.equal(body.isPremium, false);
        assert.equal(body.features.sharedShoppingList, scenario === 'mixed-pair');
        assert.equal(body.features.advancedFilters, false);
      } else {
        assert.equal(response.status, 503);
        assert.equal(body.code, 'ENTITLEMENT_RESOLUTION_UNAVAILABLE');
        assert.equal('tier' in body, false); assert.equal('isPremium' in body, false);
        assert.equal('features' in body, false, 'An outage must not return a normal Free entitlement');
      }
      console.log(`PASS GET /api/entitlements/me ${scenario}`);
    } finally {
      await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    }
  }
}
