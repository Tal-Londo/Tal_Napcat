import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

const TAG = 'CacheManager';
const CACHE_DIR = '/data/storage/el2/base/files/cache/';
const MAX_CACHE_SIZE = 50 * 1024 * 1024;
const EXPIRE_DAYS = 7;
const CACHE_INDEX_FILE = 'cache_index.json';

export enum CacheType {
  AVATAR = 'avatar',
  IMAGE = 'image',
  STICKER = 'sticker',
  VIDEO = 'video'
}

class CacheEntry {
  key: string = '';
  type: string = '';
  filename: string = '';
  size: number = 0;
  created: number = 0;
}

export class CacheManager {
  private static instance: CacheManager;
  private index: Map<string, CacheEntry> = new Map();
  private initialized: boolean = false;

  static getInstance(): CacheManager {
    if (CacheManager.instance === undefined) {
      CacheManager.instance = new CacheManager();
    }
    return CacheManager.instance;
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    try {
      fileIo.mkdirSync(CACHE_DIR, true);
    } catch (_e) {
    }
    try {
      await this.loadIndex();
    } catch (_e) {
    }
  }

  makeKey(url: string, type: CacheType): string {
    let raw = type + '_' + url;
    let hash = 0;
    for (let i = 0; i < raw.length; i++) {
      let ch = raw.charCodeAt(i);
      hash = ((hash << 5) - hash) + ch;
      hash = hash & hash;
    }
    return type + '_' + Math.abs(hash).toString(16);
  }

  has(key: string): boolean {
    return this.index.has(key);
  }

  getPath(key: string): string {
    let entry = this.index.get(key);
    if (entry !== undefined) {
      let path = CACHE_DIR + entry.filename;
      try {
        let stat = fileIo.statSync(path);
        if (stat.size > 0) {
          return path;
        }
      } catch (_e) {
        this.index.delete(key);
      }
    }
    return '';
  }

  save(key: string, type: CacheType, data: ArrayBuffer): string {
    if (data.byteLength === 0) {
      return '';
    }

    let ext = this.getExtension(type);
    let filename = key + '_' + Date.now().toString() + ext;
    let path = CACHE_DIR + filename;

    try {
      let file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);

      let entry = new CacheEntry();
      entry.key = key;
      entry.type = type;
      entry.filename = filename;
      entry.size = data.byteLength;
      entry.created = Date.now();
      this.index.set(key, entry);

      this.saveIndex();
      this.evict();
    } catch (_e) {
      return '';
    }

    return path;
  }

  // 从文本内容保存（JSON 等）
  saveString(key: string, type: CacheType, text: string): string {
    let encoder = new util.TextEncoder();
    let uint8 = encoder.encodeInto(text);
    let buf = new ArrayBuffer(uint8.byteLength);
    let view = new Uint8Array(buf);
    view.set(uint8);
    return this.save(key, type, buf);
  }

  async clearAll(): Promise<void> {
    try {
      let files = fileIo.listFileSync(CACHE_DIR);
      for (let f of files) {
        if (f !== CACHE_INDEX_FILE) {
          try {
            fileIo.unlinkSync(CACHE_DIR + f);
          } catch (_e) {
          }
        }
      }
      this.index.clear();
      this.saveIndex();
    } catch (_e) {
    }
  }

  getTotalSize(): number {
    let total = 0;
    this.index.forEach((entry: CacheEntry) => {
      total += entry.size;
    });
    return total;
  }

  getCount(): number {
    return this.index.size;
  }

  // ========== Private ==========

  static skipCacheForSize(bytes: number): boolean {
    return bytes > 10 * 1024 * 1024;
  }

  private getExtension(type: CacheType): string {
    switch (type) {
      case CacheType.IMAGE:
        return '.img';
      case CacheType.AVATAR:
        return '.avt';
      case CacheType.STICKER:
        return '.stk';
      case CacheType.VIDEO:
        return '.vid';
      default:
        return '.dat';
    }
  }

  private async loadIndex(): Promise<void> {
    try {
      let path = CACHE_DIR + CACHE_INDEX_FILE;
      let file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      let stat = fileIo.statSync(path);
      let buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      let decoder = new util.TextDecoder();
      let content = decoder.decodeWithStream(new Uint8Array(buf), undefined);
      if (content !== undefined && content !== '') {
        let raw = JSON.parse(content) as Object[];
        for (let item of raw) {
          let obj = item as Record<string, Object>;
          let entry = new CacheEntry();
          entry.key = obj['key'] as string;
          entry.type = obj['type'] as string;
          entry.filename = obj['filename'] as string;
          entry.size = obj['size'] as number;
          entry.created = obj['created'] as number;
          this.index.set(entry.key, entry);
        }
      }
    } catch (_e) {
      this.index.clear();
    }
  }

  private saveIndex(): void {
    try {
      let list: Record<string, Object>[] = [];
      this.index.forEach((entry: CacheEntry) => {
        let obj: Record<string, Object> = {
          'key': entry.key,
          'type': entry.type,
          'filename': entry.filename,
          'size': entry.size,
          'created': entry.created
        };
        list.push(obj);
      });
      let encoder = new util.TextEncoder();
      let rawText = JSON.stringify(list);
      let uint8 = encoder.encodeInto(rawText);
      let buf = new ArrayBuffer(uint8.byteLength);
      let view = new Uint8Array(buf);
      view.set(uint8);
      let path = CACHE_DIR + CACHE_INDEX_FILE;
      let file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, buf);
      fileIo.closeSync(file);
    } catch (_e) {
    }
  }

  private evict(): void {
    let now = Date.now();
    let expireTime = EXPIRE_DAYS * 24 * 60 * 60 * 1000;

    let sorted: CacheEntry[] = [];
    this.index.forEach((e: CacheEntry) => { sorted.push(e); });
    sorted.sort((a: CacheEntry, b: CacheEntry) => a.created - b.created);

    let totalSize = this.getTotalSize();

    for (let entry of sorted) {
      let expired = (now - entry.created) > expireTime;
      if (expired || totalSize > MAX_CACHE_SIZE) {
        try {
          fileIo.unlinkSync(CACHE_DIR + entry.filename);
        } catch (_e) {
        }
        totalSize -= entry.size;
        this.index.delete(entry.key);
      }
      if (!expired && totalSize <= MAX_CACHE_SIZE) {
        break;
      }
    }

    if (sorted.length !== this.index.size) {
      this.saveIndex();
    }
  }
}
