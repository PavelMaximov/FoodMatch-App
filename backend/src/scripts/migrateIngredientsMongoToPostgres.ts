import {migrateCollection} from './migrateCatalogSupport';migrateCollection('ingredients','ingredients').catch(e=>{console.error(e);process.exit(1)});
