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

import fs from '@ohos.file.fs';
import parseAPNG from './parser';
import { APNG } from './structs';
import http from '@ohos.net.http';
import { buffer } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { GlobalContext } from './GlobalContext';

type File = fs.File;

function getMainContext(): Context {
  return GlobalContext.getContext().getObject('MainContext') as Context;
}

@Concurrent
export function getAPNGInstance(buffer: Uint8Array): APNG {
  let apng = {} as APNG;
  try {
    apng = parseAPNG(buffer);
  } catch (err) {
    console.log('get parse apng err: ' + err);
  }
  return apng;
}

class APngManager {
  constructor() {
  }

  async getResource(resource: Resource, context: Context | null): Promise<Uint8Array> {
    let rsContext = GlobalContext.getContext().getObject('resContext') as Context;
    let resourceManager = rsContext?.resourceManager;
    if (context) {
      resourceManager = context.resourceManager;
    } else if (getMainContext()) {
      resourceManager = getMainContext().resourceManager;
    }
    try {
      return await resourceManager.getMediaContent(resource.id);
    } catch (err) {
      console.error('Failed to get resource:', err);
      return new Uint8Array(); // 返回空的 Uint8Array
    }
  }

  static getCurContext(context: Context | null): Context {
    if (context) {
      return context;
    } else if (getMainContext()) {
      return getMainContext();
    } else {
      return GlobalContext.getContext().getObject('resContext') as Context;
    }
  }

  async getStringResource(resource: Resource, context: Context): Promise<string> {
    let rsContext = GlobalContext.getContext().getObject('resContext') as Context;
    let resourceManager = rsContext?.resourceManager;
    if (context) {
      resourceManager = context.resourceManager;
    } else if (getMainContext()) {
      resourceManager = getMainContext().resourceManager;
    }
    try {
      return await resourceManager.getStringValue(resource.id);
    } catch (err) {
      return '';
    }
  }

  async open(url: string): Promise<File> {
    let file = {} as File;
    try {
      file = await fs.open(url);
    } catch (err) {
      console.log('open apng err: ' + err);
    }
    return file;
  }

  async getAPNGInstanceFormSandbox(filePath: string): Promise<Uint8Array> {
    try {
      let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      let stat = fs.lstatSync(filePath);
      let arrayBuffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, arrayBuffer).then((readLen: number) => {
        console.log('read file data succeed');
        buffer.from(arrayBuffer, 0, readLen);
      }).catch((err: BusinessError) => {
        console.error('read file data failed with error message :' + err.message + ', error code: ' + err.code);
      }).finally(() => {
        fs.closeSync(file);
      })
      return new Uint8Array(arrayBuffer);
    } catch (err) {
      console.log('get Sandbox apng err: ' + err);
      return new Uint8Array();
    }
  }
}

@Concurrent
export async function loadData(src: string): Promise<APNG | null> {
  let apng: APNG | null = null;
  try {
    let httpRequest = http.createHttp();
    let arrayBuffers = new Array<ArrayBuffer>();
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      // 下载数据流多次返回
      arrayBuffers.push(data);
    })

    const resultCode = await httpRequest.requestInStream(
      src as string,
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: http.HttpProtocol.HTTP1_1,
        usingCache: false
      }).catch((err: Error) => {
      console.error(`apng>> HttpDownloadClient has error,http code = ${JSON.stringify(err)}`)
      httpRequest.destroy();
      return apng;
    })

    if (resultCode === 200) {
      // 计算多个ArrayBuffer的总字节大小
      let totalByteLength = 0;
      for (const arrayBuffer of arrayBuffers) {
        totalByteLength += arrayBuffer.byteLength;
      }
      // 创建一个新的ArrayBuffer
      const combinedArrayBuffer = new ArrayBuffer(totalByteLength);
      // 创建一个新的Uint8Array来操作新的ArrayBuffer
      const combinedUint8Buffer = new Uint8Array(combinedArrayBuffer);

      let offset = 0;
      for (const arrayBuffer of arrayBuffers) {
        const sourceUint8Buffer = new Uint8Array(arrayBuffer);
        combinedUint8Buffer.set(sourceUint8Buffer, offset);
        offset += sourceUint8Buffer.length;
      }
      apng = parseAPNG(new Uint8Array(combinedArrayBuffer));
      return apng;
    }
  } catch (err) {
    console.error(`apng>>> catch error request uuid = ${err}`);
  }
  return apng;
}

export default APngManager;