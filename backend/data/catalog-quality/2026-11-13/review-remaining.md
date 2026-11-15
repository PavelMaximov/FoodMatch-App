# Content decisions still needed before translation approval

This is an evidence-based cleanup of the stored catalog, not a certification that every recipe is correct. Never replace unknown nutritional values with invented numbers or collapse recipes by name alone.

## Nutrition and dietary classification

239 curated recipes have only 82 distinct complete nutrition JSON objects. The most common object is repeated on 23 different dishes (including Avocado Toast, Beef Tacos, Blini with Sour Cream and Focaccia): 280 kcal, 12 g protein, 28 g carbohydrate, 14 g fat, 3 g fibre, 4 g sugar, 480 mg sodium. Further groups contain 18, 15, 14 and 13 recipes. Repetition is a strong quality signal, not proof that every repeated value is wrong.

Before approving nutrition, establish whether the values describe one serving or a full batch, verify quantities/yields, then calculate against a documented ingredient dataset or a verified recipe source. `source=[cook,order]` is an availability channel, not a citation. Leave these numbers unchanged pending that work. The current DTO reads nutrition without honoring `nutrition_visibility`; simply changing that flag would not reliably hide unverified values. Any decision to hide them needs a coordinated API/UI change.

The two obvious ambiguous vegetarian claims (dashi and roast gravy) are withdrawn in this patch. Rennet-sensitive cheeses, stock variants, sauces and ingredient substitutions still need a dietary policy; a tag cannot guarantee an allergen-free or vegetarian recipe without specifying these variants.

## Likely duplicate recipes

Keep all IDs until a deliberate alias/archive migration preserves favorites, matches and historical decks:

- Fresh Spring Rolls / Spring Rolls: same ingredient list and near-identical cold-assembly instructions.
- Roast Red Pepper Soup / Roasted Red Pepper Soup: same ingredient list and near-identical steps.
- French Onion Omelette (renamed French Mushroom Omelette in this patch) / Mushroom Omelette: both describe mushroom-and-cheese omelettes. Review whether the former should become a distinct onion recipe or be archived via an alias.
- Hungarian Goulash / Hungarian Goulash (Bogrács): compare quantities and cooking vessel before treating them as duplicates.

## Timing/editorial ambiguities

The patch resolves explicit contradictions, but these still require a coherent recipe edit or tested timing rather than a blind sum:

- Croissant: clarify whether “repeat 3 times” means three folds total or three additional folds. Egg wash is mentioned in the instructions but egg is absent from the ingredient list. The current correction follows the literal four-chill interpretation.
- New York Cheesecake: eight hours is a planning convention for “overnight”, not a duration stated in the recipe. Confirm chilling and serving expectations.
- BBQ Ribs, Medovik, Napoleon, Pašticada, Falafel and Tavče Gravče: settle the required overnight durations and account for sequential cooking/batch sizes. Existing long totals have not been replaced with speculative exact numbers in this package.
- Lobio, Fasolada, Pasulj and Revithia: canned and dried legumes require different timelines. Choose one default ingredient variant and give the alternative explicitly.
- Blini, Burek/Byrek, Bratkartoffeln, Butter Chicken, Cherry/Potato Varenyky, Khinkali, Manti, Pierogi, Moussaka, Nalysnyky, Pirog and Spanakopita: verify batch sizes, parallel work, rests and cooling against a tested preparation flow. Some totals may remain optimistic.
- Ribeye, Roasted Beet Salad and chilled desserts: define whether tempering/cooling is included in the displayed estimate; the beet correction includes an explicit editorial cooling allowance.
- Rote Grütze: refrigeration is required but no duration is specified. Define it before changing the total.
- Satsivi and other dishes described as cold/chilled: check that the instructions actually include the cooling required by the description.

## API filtering follow-up

On the audited develop revision, `DishService.filter` accepts `timeTier` and `maxTotalTime` in its interface/controller but does not use either predicate. Updating catalog metadata alone cannot make these filters correct. Implement and regression-test the predicates before judging the quick-recipe collection from the UI. This package deliberately contains no runtime behavior changes.

## Localization architecture

Do not duplicate `dishes` or the database for German. Keep dish, component, ingredient and step IDs stable across languages. Time, quantities, cuisine/diet codes, ratings, ownership, matches and session data remain shared.

Suggested translation keys (schema to be implemented in the localization PR):

| Entity | Unique key | Localized content |
|---|---|---|
| Dish | dish_id + locale | name, description, thumbnail alt text, human-readable yield |
| Instruction | instruction_id + locale | display_text |
| Section | section_id + locale | section name |
| Ingredient | ingredient_id + locale | singular/plural display names |
| Component wording | component_id + locale | preparation qualifier, extra comment, source wording |

Translate units and taxonomy labels from stable codes using the UI dictionaries. Store translation status and source revision so an English correction marks German text for review. Publish a German recipe only when all required recipe text is translated; otherwise return the complete English version with an explicit resolved locale. This avoids partially translated instructions.

The API must accept a validated `locale=en|de`, return the resolved language, localize search, and include locale in response/cache keys. Switching the UI language invalidates recipe caches but preserves dish IDs, deck order, likes and the shared pair session. Shopping-list deduplication must continue to use canonical ingredient IDs, never translated display strings. Custom recipes remain in the author's language unless their owner explicitly requests a translation.

Acceptance tests: locale switching on an existing deck; paired users with different languages seeing the same dish IDs; localized recipe search; English fallback for incomplete translations; source-edit invalidation; shopping-list merge by ID; no cross-user/custom-data leakage through translation endpoints or RLS.
