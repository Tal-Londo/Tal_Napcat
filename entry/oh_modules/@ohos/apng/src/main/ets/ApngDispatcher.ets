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

import { ApngRequest, ApngRequestState } from './ApngRequest';
import { LightWeightMap } from '@kit.ArkTS';
import { IJobQueue } from './utils/IJobQueue';
import { DefaultJobQueue } from './utils/DefaultJobQueue';
import { APNG } from './components/structs';
import APngManager, { getAPNGInstance, loadData } from './components/manager';
import bufferUtil from '@ohos.buffer';
import emitter from '@ohos.events.emitter';
import taskpool from '@ohos.taskpool';
import { Apng } from './Apng';
import { DefaultEngineKey } from './utils/DefaultEngineKey';
import { GlobalContext } from './components/GlobalContext';

const errText = $r("app.string.network_error");

export class ApngDispatcher {
  // 最大并发
  private maxRequests: number = 4;
  // 排队队列
  private jobQueue: IJobQueue = new DefaultJobQueue();
  // 执行中的请求
  public executingJobMap: LightWeightMap<string, ApngRequest> = new LightWeightMap();

  async enqueue(request: ApngRequest): Promise<void> {
    if (Apng.getInstance().getEnableCache()) {
      // 先从缓存获取数据
      let key = DefaultEngineKey.generateMemoryKey(request.imageSrc);
      let value = Apng.getInstance().loadFromMemoryCache(key);
      if (value !== undefined && value) {
        await this.getCacheRequest(value, request);
        return;
      }
      request.key = key;
    }
    // 判断是否要排队
    if (this.executingJobMap.length > this.maxRequests) {
      this.jobQueue.add(request);
      return;
    }
    this.executeJob(request)
  }

  async getCacheRequest(value: ApngRequest, request: ApngRequest) {
    let tempRequest =
      new ApngRequest(request.requestId, ApngRequestState.PROGRESS, request.context, request.apngWidth,
        request.apngHeight)
    tempRequest.apngWidth = await parsingLength(request.apngWidth, request.context);
    tempRequest.apngHeight = await parsingLength(request.apngHeight, request.context);
    tempRequest.styleInfo = value.styleInfo;
    tempRequest.timeTaken = value.timeTaken;
    tempRequest.imageArr = value.imageArr;
    tempRequest.requestId = request.requestId;
    tempRequest.isAPNG = value.isAPNG;
    if (tempRequest.apngWidth != 0 || tempRequest.apngHeight != 0) {
      tempRequest.styleInfo.forEach((item) => {
        tempRequest.maxWidth = tempRequest.maxWidth > item.width ? tempRequest.maxWidth : item.width;
        tempRequest.maxHeight = tempRequest.maxHeight > item.height ? tempRequest.maxHeight : item.height;
      })
    }

    let eventData: emitter.EventData = {
      data: {
        "requestId": tempRequest.requestId
      }
    }
    Apng.getInstance().setExecutingJobMap(tempRequest);
    emitter.emit(tempRequest.requestId, eventData);
  }

  async executeJob(request: ApngRequest) {
    try {
      if (!this.executingJobMap.hasKey(request.requestId)) {
        this.executingJobMap.set(request.requestId, request);
      }
    } catch (error) {
      console.error('Failed to add request to executing map:', error);
    }
    let imageSrc = request.imageSrc;
    if (typeof imageSrc === 'string' && (imageSrc as string).startsWith('http')) {
      let eventData: emitter.EventData = { data: { "requestId": '' } }
      if (request.requestState === ApngRequestState.DESTROY) {
        Apng.getInstance().setExecutingJobMap(request);
        emitter.emit(request.requestId, eventData);
        this.dispatchNextJob();
        return;
      }
      taskpool.execute(loadData, imageSrc).then(async (data) => {
        if (!data) {
          request.timeTaken = errText;
          Apng.getInstance().setExecutingJobMap(request);
          emitter.emit(request.requestId, eventData);
        } else {
          let apng = data as APNG;
          if (apng) {
            await this.getImageArr(apng, request);
          }
        }
        this.dispatchNextJob();
        return;
      }).catch((e: string) => {
        console.error(`apng>> taskpool execute task error ! ${e}`);
        Apng.getInstance().setExecutingJobMap(request);
        emitter.emit(request.requestId, eventData);
        this.dispatchNextJob();
        return;
      })
    } else {
      const apngManager = new APngManager();
      if (imageSrc instanceof Uint8Array) {
        this.executeTask(request, imageSrc, false);
      } else if (typeof imageSrc === 'string') {
        let buffer = await apngManager.getAPNGInstanceFormSandbox(imageSrc as string);
        this.executeTask(request, buffer, false);
      } else if ((imageSrc as Resource).id) {
        let buffer = await apngManager.getResource(imageSrc as Resource, request.context);
        this.executeTask(request, buffer, true);
      }
    }
  }

  executeTask(request: ApngRequest, buffer: Uint8Array, isResource: boolean) {
    let apng: APNG = new APNG();
    let eventData: emitter.EventData = { data: { "requestId": '' } }
    if (request.requestState === ApngRequestState.DESTROY || !buffer || buffer.length === 0) {
      Apng.getInstance().setExecutingJobMap(request);
      emitter.emit(request.requestId, eventData);
      this.dispatchNextJob();
      return;
    }
    let copieArray = buffer;
    if (isResource) {
      copieArray = buffer.slice()
      buffer = new Uint8Array();
    }
    taskpool.execute(getAPNGInstance, copieArray).then(async (data) => {
      if (!data) {
        emitter.emit(request.requestId, eventData);
      } else {
        apng = data as APNG;
        await this.getImageArr(apng, request);
      }
      this.dispatchNextJob();
    }).catch((e: string) => {
      console.error('taskpool execute task error :' + e);
    })
  }

  dispatchNextJob() {
    while (true) {
      let request = this.jobQueue.pop();
      if (request === undefined) {
        break;
      } else if (request.requestState === ApngRequestState.PROGRESS) {
        this.executeJob(request);
        break;
      }
    }
  }

  async getImageArr(apng: APNG, request: ApngRequest): Promise<void> {
    if (apng.frames?.length) {
      let imagePixelArr: Array<string> = [];
      request.numPlays = apng.numPlays;
      request.styleInfo = apng.frames;
      request.apngWidth = await parsingLength(request.apngWidth, request.context);
      request.apngHeight = await parsingLength(request.apngHeight, request.context);
      apng.frames.forEach((item) => {
        if (request.apngWidth != 0 || request.apngHeight != 0) {
          request.maxWidth = request.maxWidth > item.width ? request.maxWidth : item.width;
          request.maxHeight = request.maxHeight > item.height ? request.maxHeight : item.height;
        }
        const bufferArr = item.imageBuffer;
        const buffer = bufferArr.reduce((rst, item) => {
          return typedArrayConcat(rst, item)
        }, new ArrayBuffer(0))
        try {
          const b = bufferUtil.from(buffer);
          const pbase64 = `data:image/png;base64,${b.toString('base64')}`;
          imagePixelArr.push(pbase64);
        } catch (error) {
          console.log('FG error ' + JSON.stringify(error));
        }
        item.imageBuffer = [];

        if (imagePixelArr.length === apng.frames.length) {
          request.imageArr = imagePixelArr;
          imagePixelArr = [];
        }
      })
      request.isAPNG = true;
    } else {
      request.isAPNG = false;
      if(request.imageSrc){
        if(typeof request.imageSrc === 'string'){
          request.timeTaken = '';
        } else if (typeof request.imageSrc === 'object'){
          request.timeTaken = '';
        }
        if(request.apngWidth){
          request.apngWidth = await parsingLength(request.apngWidth, request.context);
        }
        if(request.apngHeight){
          request.apngHeight = await parsingLength(request.apngHeight, request.context);
        }
      }
    }

    let eventData: emitter.EventData = {
      data: {
        "requestId": request.requestId
      }
    }
    if (Apng.getInstance().getEnableCache()) {
      this.saveDataToCache(request);
    }
    Apng.getInstance().setExecutingJobMap(request);
    emitter.emit(request.requestId, eventData);
  }

  private saveDataToCache(request: ApngRequest) {
    let tempRequest =
      new ApngRequest(request.requestId, ApngRequestState.PROGRESS, request.context, request.apngWidth,
        request.apngHeight)
    tempRequest.apngWidth = request.apngWidth;
    tempRequest.apngHeight = request.apngHeight;
    tempRequest.styleInfo = request.styleInfo;
    tempRequest.timeTaken = request.timeTaken;
    tempRequest.imageArr = request.imageArr;
    tempRequest.maxWidth = request.maxWidth;
    tempRequest.maxHeight = request.maxHeight;
    tempRequest.isAPNG = request.isAPNG;
    if (!Apng.getInstance().existMemoryCache(request.key)) {
      Apng.getInstance().saveMemoryCache(request.key, tempRequest);
    }
  }
}


async function parsingLength(value: Length, context: Context): Promise<Length> {
  if (!value) {
    return 0;
  }
  if (typeof value === 'number') {
    return value;
  } else if (typeof value === 'string') {
    return parseString(value);
  } else {
    const apngManager = new APngManager();
    let string = await apngManager.getStringResource(value as Resource, context);
    return parseString(string);
  }
}

function parseString(str: string): number {
  if (!str) {
    return 0;
  }
  if (str.endsWith('vp')) {
    return Number(str.substring(0, str.indexOf('vp')));
  } else if (str.endsWith('px')) {
    let uiContext = GlobalContext.getContext().getObject('uiContext') as UIContext;
    return uiContext?.px2vp(Number(str.substring(0, str.indexOf('px'))));
  } else {
    return Number(str);
  }
}

function typedArrayConcat(buffer1: ArrayBuffer | Uint8Array, buffer2: ArrayBuffer | Uint8Array): ArrayBuffer {
  const u1 = new Uint8Array(buffer1);
  const u2 = new Uint8Array(buffer2);
  const length = u1.byteLength + u2.byteLength;
  const buffer = new ArrayBuffer(length);
  const uintBuffer = new Uint8Array(buffer);
  uintBuffer.set(u1, 0);
  uintBuffer.set(u2, buffer1.byteLength);
  return uintBuffer.buffer;
}