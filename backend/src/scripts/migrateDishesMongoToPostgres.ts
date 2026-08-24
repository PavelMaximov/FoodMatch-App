import {migrateCollection} from './migrateCatalogSupport';migrateCollection('dishes','dishes').catch(e=>{console.error(e);process.exit(1)});
