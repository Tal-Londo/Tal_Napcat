/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { ApngDispatcher } from './ApngDispatcher';
import { ApngRequest } from './ApngRequest';
import { LightWeightMap } from '@kit.ArkTS';
import { IMemoryCache } from './utils/IMemoryCache';
import { MemoryLruCache } from './utils/MemoryLruCache';
import { DefaultEngineKey } from './utils/DefaultEngineKey';

export class Apng {
  private static instance: Apng;
  private dispatcher: ApngDispatcher = new ApngDispatcher();
  // 内存缓存
  private memoryCache: IMemoryCache = new MemoryLruCache(128, 128 * 1024 * 1024);
  private enableCache: boolean = false;

  public static getInstance(): Apng {
    if (!Apng.instance) {
      Apng.instance = new Apng();
    }
    return Apng.instance;
  }

  async execute(request: ApngRequest): Promise<void> {
    this.dispatcher.enqueue(request);
  }

  public getExecutingJobMap(): LightWeightMap<string, ApngRequest> {
    return this.dispatcher.executingJobMap;
  }

  public setExecutingJobMap(request: ApngRequest): void {
    try {
      this.dispatcher.executingJobMap.set(request.requestId, request);
    } catch (error) {
      console.error('Failed to setExecutingJobMap:', error);
    }
  }

  getEnableCache(): boolean {
    return this.enableCache;
  }

  setEnableCache(enableCache: boolean): void {
    this.enableCache = enableCache;
  }

  /**
   * 设置自定义的内存缓存
   * @param newMemoryCache 自定义内存缓存
   */
  initMemoryCache(newMemoryCache: IMemoryCache): void {
    if (newMemoryCache) {
      this.memoryCache = newMemoryCache;
    }
  }

  /**
   * 清除所有内存缓存
   */
  removeAllMemoryCache(): void {
    this.memoryCache.removeAll()
  }

  /*
   * 清除指定内存缓存
   * */
  removeMemoryCache(src?: ResourceStr | Uint8Array) {
    let key = DefaultEngineKey.generateMemoryKey(src)
    this.memoryCache.remove(key);
  }

  loadFromMemoryCache(key: string): ApngRequest | undefined {
    if (key !== "") {
      return this.memoryCache.get(key)
    }
    return undefined
  }

  saveMemoryCache(key: string, data: ApngRequest): void {
    if (key !== "") {
      this.memoryCache.put(key, data)
    }
  }

  existMemoryCache(key: string): boolean {
    if (key !== "") {
      if (this.memoryCache.get(key)) {
        return true;
      } else {
        return false;
      }
    }
    return false;
  }
}