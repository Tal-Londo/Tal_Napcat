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

import util from '@ohos.util';
import { IMemoryCache } from './IMemoryCache';
import { ApngRequest } from '../ApngRequest';

export class MemoryLruCache implements IMemoryCache {
  maxMemory: number = 0
  currentMemory: number = 0
  maxSize: number = 0
  private lruCache: util.LRUCache<string, ApngRequest>
  readonly defaultMaxSize: number = 256
  readonly defaultSize: number = 128
  readonly defaultMaxMemorySize: number = 256 * 1024 * 1024
  readonly defaultMemorySize: number = 128 * 1024 * 1024

  constructor(size: number, memory: number) {
    if (size <= 0 || size > this.defaultMaxSize) {
      size = this.defaultSize
    }
    if (memory <= 0 || memory > this.defaultMaxMemorySize) {
      memory = this.defaultMemorySize
    }

    this.lruCache = new util.LRUCache(size);
    this.maxMemory = memory
    this.maxSize = size
    this.currentMemory = 0
  }

  // 添加缓存键值对
  put(key: string, value: ApngRequest): void {
    if (key == null || value == null) {
      throw new Error('key or value is invalid ');
    }

    // 如果size满了的话，需要按照LRU的方式删除第一个
    if (this.lruCache.length == this.maxSize && !this.lruCache.contains(key)) {
      this.remove(this.lruCache.keys()[0])
    } else if (this.lruCache.contains(key)) {
      this.remove(key)
    }

    let pre: ApngRequest = this.lruCache.put(key, value)
    this.addMemorySize(value)
    this.trimToSize();
  }

  get(key: string): ApngRequest | undefined {
    return this.lruCache.get(key)
  }

  // 移除键为key的缓存
  remove(key: string): ApngRequest | undefined {
    if (key == null) {
      throw new Error('key is null,checking the parameter');
    }

    let remove: ApngRequest | undefined = this.lruCache.remove(key)
    if (remove !== undefined) {
      this.removeMemorySize(remove)
    }
    return remove
  }

  removeAll(): void {
    this.lruCache.clear()
    this.currentMemory = 0;
  }

  size(): number {
    return this.lruCache.length
  }

  // 移除较少使用的缓存数据
  trimToSize(): void {
    while (true) {
      if (this.currentMemory <= this.maxMemory || this.lruCache.isEmpty()) {
        break
      }
      let delkey = this.lruCache.keys()[0]
      let data: ApngRequest | undefined = this.lruCache.get(delkey)
      if (data != undefined) {
        this.removeMemorySize(data)
      }
      this.lruCache.remove(delkey)
    }
  }

  private removeMemorySize(value: ApngRequest): void {
    if (value != undefined) {
      this.currentMemory -= JSON.stringify(value).length
    }
  }

  private addMemorySize(value: ApngRequest): void {
    if (value != undefined) {
      this.currentMemory += JSON.stringify(value).length
    }
  }
}