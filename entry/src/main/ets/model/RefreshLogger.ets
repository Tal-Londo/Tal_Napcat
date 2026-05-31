import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'RefreshLogger';
const DOMAIN = 0x0009;
const MAX = 200;

export class RefreshLogEntry {
  time: number = 0;
  step: string = '';
  detail: string = '';
}

export class RefreshLogger {
  private static instance: RefreshLogger;
  private entries: RefreshLogEntry[] = [];

  static getInstance(): RefreshLogger {
    if (RefreshLogger.instance === undefined) {
      RefreshLogger.instance = new RefreshLogger();
    }
    return RefreshLogger.instance;
  }

  log(step: string, detail: string): void {
    let e = new RefreshLogEntry();
    e.time = Date.now();
    e.step = step;
    e.detail = detail;
    this.entries.push(e);
    if (this.entries.length > MAX) {
      this.entries.splice(0, this.entries.length - MAX);
    }
    hilog.info(DOMAIN, TAG, `[${step}] ${detail}`);
  }

  getEntries(): RefreshLogEntry[] {
    return [...this.entries];
  }

  getEntriesForUpload(): Record<string, Object>[] {
    let result: Record<string, Object>[] = [];
    let clone = [...this.entries];
    for (let e of clone) {
      let o: Record<string, Object> = {
        'time': e.time,
        'step': e.step,
        'detail': e.detail
      };
      result.push(o);
    }
    return result;
  }

  clear(): void {
    this.entries = [];
  }
}
