/** Migration-only script. Not imported by runtime app code. Local/cloud data-repair tool; non-destructive inserts/upserts unless noted in its output. */
import {migrateCollection} from './migrateCatalogSupport';migrateCollection('ingredients','ingredients').catch(e=>{console.error(e);process.exit(1)});
