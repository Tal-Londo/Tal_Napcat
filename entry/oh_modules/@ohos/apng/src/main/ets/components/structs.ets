/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Based on crc32.js originally written by
 * Copyright (c) 2016 David Mzareulyan
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

import emitter from '@ohos.events.emitter';
import util from '@ohos.util';
import { LogUtils } from '../utils/LogUtils';

export class APNG {
  isAPNG = true;
  width = 0;
  height = 0;
  numPlays = 0;
  playTime = 0;
  frames: Frame[] = [];
}

export enum PlayStatus {
  STOP,
  PAUSE,
  PLAY
}

export class ApngController {
  status = PlayStatus.PLAY;  //0, stop; 1, pause; 2, play;
  uuid = util.generateRandomUUID();

  public emit(event: string, callback: Callback<emitter.EventData>) {
    emitter.on(this.uuid + event, callback);
  }

  public play() {
    LogUtils.getInstance().debug("play");
    this.status = PlayStatus.PLAY;
    let eventData: emitter.EventData = {
      data: {
        "playStatus": this.status,
      }
    };
    emitter.emit(this.uuid + 'play', eventData);
  }
  public pause() {
    LogUtils.getInstance().debug("pause");
    if (this.status === PlayStatus.PLAY) {
      this.status = PlayStatus.PAUSE;
      let eventData: emitter.EventData = {
        data: {
          "playStatus": this.status,
        }
      };
      emitter.emit(this.uuid + 'pause', eventData);
    }
  }
  public stop() {
    LogUtils.getInstance().debug("stop");
    this.status = PlayStatus.STOP;
    let eventData: emitter.EventData = {
      data: {
        "playStatus": this.status,
      }
    };
    emitter.emit(this.uuid + 'stop', eventData);
  }
  public get playStatus() {
    return this.status;
  }
}

export class Frame {
  left = 0;
  top = 0;
  width = 0;
  height = 0;
  delay = 0;
  disposeOp = 0;
  blendOp = 0;
  dataParts: Uint8Array[] = [];
  imageBuffer: Uint8Array[] = [];
}