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
import { Frame } from './components/structs';

export class ApngRequest {
  requestId: string = '';
  imageSrc?: ResourceStr | Uint8Array = '';
  requestState: ApngRequestState = ApngRequestState.PROGRESS;
  apngWidth: Length = 0;
  apngHeight: Length = 0;
  styleInfo: Array<Frame> = [];
  context: Context;
  maxWidth: number = 0;
  maxHeight: number = 0;
  timeTaken: string | Resource= $r("app.string.loading");
  imageArr: Array<string> = [];
  key: string = '';
  numPlays: number = 0;
  isAPNG: boolean = true;

  constructor(requestId: string, requestState: ApngRequestState, context: Context,
    apngWidth: Length, apngHeight: Length, imageSrc?: ResourceStr | Uint8Array, timeTaken?: string | Resource ) {
    this.requestId = requestId;
    this.requestState = requestState;
    this.context = context;
    this.apngWidth = apngWidth;
    this.apngHeight = apngHeight;
    this.imageSrc = imageSrc;
    this.timeTaken = timeTaken ? timeTaken : $r("app.string.loading")
  }
}

export enum ApngRequestState {
  PROGRESS,
  COMPLETE,
  ERROR,
  DESTROY
}