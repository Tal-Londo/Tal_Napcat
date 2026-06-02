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

import hilog from '@ohos.hilog';

export class LogUtils {
  private mLogOpen: boolean = false;
  public static readonly TAG: string = "ohos-apng";
  private static instance: LogUtils;
  public static readonly DOMAIN: number = 0x0001;

  private constructor() {
  };

  public static getInstance() {
    if (!LogUtils.instance) {
      LogUtils.instance = new LogUtils();
    }
    return LogUtils.instance;
  }

  setLogSwitch(logOpen: boolean) {
    this.mLogOpen = logOpen;
  }

  LOGI(message: string, ...args: Object[]) {
    hilog.info(LogUtils.DOMAIN, LogUtils.TAG, message, args)
  }

  debug(message: string, ...args: Object[]) {
    hilog.debug(LogUtils.DOMAIN, LogUtils.TAG, message, args)
  }

  info(message: string, ...args: Object[]) {
    hilog.info(LogUtils.DOMAIN, LogUtils.TAG, message, args)
  }

  warn(message: string, ...args: Object[]) {
    hilog.warn(LogUtils.DOMAIN, LogUtils.TAG, message, args)
  }

  error(message: string, ...args: Object[]) {
    hilog.error(LogUtils.DOMAIN, LogUtils.TAG, message, args)
  }
}