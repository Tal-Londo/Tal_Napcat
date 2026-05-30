import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ConfigManager';
const DOMAIN = 0x0002;

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'napcatwatch.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS app_config (key TEXT PRIMARY KEY, value TEXT)';

export class ConfigManager {
  private static instance: ConfigManager;
  private rdbStore: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;

  static getInstance(): ConfigManager {
    if (ConfigManager.instance === undefined) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  async initDb(context: Context): Promise<void> {
    if (this.initialized && this.rdbStore !== null) {
      return;
    }
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.rdbStore.executeSql(SQL_CREATE_TABLE);
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'ConfigManager initialized');
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, `initDb failed. Code:${e.code}, message:${e.message}`);
    }
  }

  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (this.rdbStore === null) {
      return defaultValue;
    }
    try {
      let predicates = new relationalStore.RdbPredicates('app_config');
      predicates.equalTo('key', key);
      let resultSet = await this.rdbStore.query(predicates, ['value']);
      if (resultSet.goToFirstRow()) {
        let value: string = resultSet.getString(resultSet.getColumnIndex('value'));
        resultSet.close();
        return value;
      }
      resultSet.close();
      return defaultValue;
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, `getString failed. Code:${e.code}, message:${e.message}`);
      return defaultValue;
    }
  }

  async setString(key: string, value: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    let valueBucket: relationalStore.ValuesBucket = {
      key: key,
      value: value
    };
    try {
      await this.rdbStore.insert('app_config', valueBucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, `setString failed. Code:${e.code}, message:${e.message}`);
    }
  }

  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    let str: string = await this.getString(key, '');
    if (str === '') {
      return defaultValue;
    }
    let num: number = Number.parseInt(str);
    if (Number.isNaN(num)) {
      return defaultValue;
    }
    return num;
  }

  async setNumber(key: string, value: number): Promise<void> {
    await this.setString(key, value.toString());
  }

  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    let str: string = await this.getString(key, '');
    if (str === '') {
      return defaultValue;
    }
    return str === '1' || str === 'true';
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    await this.setString(key, value ? '1' : '0');
  }

  async remove(key: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    try {
      let predicates = new relationalStore.RdbPredicates('app_config');
      predicates.equalTo('key', key);
      await this.rdbStore.delete(predicates);
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, `remove failed. Code:${e.code}, message:${e.message}`);
    }
  }
}
