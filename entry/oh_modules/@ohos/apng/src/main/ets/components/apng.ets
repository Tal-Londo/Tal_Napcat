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
import { ApngRequest, ApngRequestState } from '../ApngRequest';

import { ApngController, Frame, PlayStatus } from './structs';
import util from '@ohos.util';
import { Apng } from '../Apng';
import emitter from '@ohos.events.emitter';
import { HashMap } from '@kit.ArkTS';
import APngManager from './manager';
import { LogUtils } from '../utils/LogUtils';
import { FrameNode } from '@kit.ArkUI';
import Animator, { AnimatorOptions, AnimatorResult } from '@ohos.animator';
import { GlobalContext } from './GlobalContext';


// canvas组件绘制单位为vp,与px的转换过程中存在精度丢失，需要手动转换成px
export function floor(n: number) {
  let uiContext = GlobalContext.getContext().getObject('uiContext') as UIContext;
  return Math.floor(uiContext?.px2vp(n));
}

export function ceil(n: number) {
  let uiContext = GlobalContext.getContext().getObject('uiContext') as UIContext;
  return Math.ceil(uiContext?.px2vp(n));
}

declare type Length = string | number | Resource;

const defaultSpeed = 1;

@Component
export struct apng {
  @State appearState: boolean = false;
  @Prop @Watch('resetSrc') src: ResourceStr | Uint8Array = new Uint8Array(0);
  @Prop speedRate: number = defaultSpeed;
  @Prop apngWidth: Length = 0;
  @Prop apngHeight: Length = 0;
  @Prop loadingText: string | Resource= $r("app.string.loading");
  @State @Watch('onImageArrChange') imageArr: Array<string> = [];

  resetSrc() {
    this.init();
  }

  onImageArrChange() {
    if (this.appearState == false) {
      return;
    }
    const imageArr = this.imageArr;
    this.getAllImage(imageArr);
    if (!imageArr.length) {
      return;
    }
    if (imageArr.length === 1) {
      this.currentImage = imageArr[0];
      return;
    }
    if (this.animator === null) {
      this.loop(this.count, imageArr.length);
    }
  }

  @State currentImage: string = '';
  @State styleInfo: Array<Frame> = [];
  @State isVisible: boolean = false;
  @State _numPlays: number = 0;
  scroller: Scroller = new Scroller();
  @State count: number = 0;
  @State frameTime: number = 100 / this.speedRate;
  @State timeTaken: string | Resource = this.loadingText;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private prevFrameData: ImageData | null = null;
  private prevFrame: Frame = new Frame();
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;
  @State context: Context | null = null;
  private maxWidth: number = 0;
  private maxHeight: number = 0;
  private xRatio: number = 1;
  private yRatio: number = 1;
  private request: ApngRequest | undefined;
  private imageMap: HashMap<number, ImageBitmap> = new HashMap();
  @State controller: ApngController | null = null;
  private animator: AnimatorResult | null = null;
  private nextRenderTime: number = 0;
  private currentFrameNumber: number = 0;
  private uiContext: UIContext | null = null;
  @State numPlays: number = 0;
  @State isAPNG: boolean = true;
  @State imgSrc: ResourceStr| PixelMap| undefined = undefined;
  @State imageFit: ImageFit = ImageFit.Contain;
  @State alignItems: HorizontalAlign = HorizontalAlign.Start;
  @State justifyContent: FlexAlign = FlexAlign.Start;

  aboutToAppear() {
    this.appearState = true;
    this.uiContext = this.getUIContext();
    let context = this.uiContext.getHostContext();
    if(context && this.uiContext){
      GlobalContext.getContext().setObject('resContext',context);
      GlobalContext.getContext().setObject('uiContext',this.uiContext);
    }
    this.init();
  }

  clear() {
    this.animator?.finish();
    this.animator = null;
    this.canvasContext.clearRect(this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top), this.uiContext?.px2vp(this.prevFrame.width),
      this.uiContext?.px2vp(this.prevFrame.height));
    this.timeTaken = this.loadingText;
    this.count = -1;
    this.styleInfo = [];
    this.canvasWidth = 0;
    this.canvasHeight = 0;
    try {
      this.imageMap?.forEach((item) => {
        item?.close()
      })
      this.imageMap?.clear();
    } catch (error) {
      console.error('Failed image to map:', error);
    }
  }

  aboutToDisappear(): void {
    this.appearState = false;
    this.destroy();
  }

  destroy() {
    this.animator?.finish();
    this.animator = null;
    this.canvasContext.clearRect(this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top), this.uiContext?.px2vp(this.prevFrame.width),
      this.uiContext?.px2vp(this.prevFrame.height));
    if (this.request !== undefined) {
      this.request.styleInfo = [];
      this.request.imageArr = [];
      this.request.requestState = ApngRequestState.DESTROY;
      this.request = undefined;
    }
    this.styleInfo = [];
    this.imageArr = [];
    try {
      this.imageMap?.forEach((item) => {
        item?.close()
      })
      this.imageMap?.clear();
    } catch (error) {
      console.error('Failed image to map:', error);
    }
  }

  aboutToRecycle(): void {
    this.destroy();
  }

  getAllImage: (allImages: Array<string>) => void = () => {
  };

  loop(c: number, max: number) {
    if (this.styleInfo.length === 0) {
      return;
    }
    let frameInfo = this.styleInfo[1] as Frame;
    if (this.speedRate < 0.1 || this.speedRate > 2) {
      this.speedRate = defaultSpeed;
    }
    this.frameTime = frameInfo.delay == 0 ? 100 : frameInfo.delay / this.speedRate;
    this.xRatio = (this.apngWidth as number) === 0 ? 1 : ((this.apngWidth as number) / this.uiContext!.px2vp(this.maxWidth));
    this.yRatio = (this.apngHeight as number) === 0 ? 1 : ((this.apngHeight as number) / this.uiContext!.px2vp(this.maxHeight));
    let options: AnimatorOptions = {
      duration: 20000,
      easing: "linear",
      delay: 0,
      fill: "forwards",
      direction: "normal",
      iterations: -1,
      begin: 0,
      end: 1
    };
    if (this.animator) {
      this.animator.finish();
    }
    if(!this.uiContext){
      return;
    }
    this.animator = this.uiContext.createAnimator(options);
    this.animator.onFrame = () => {
      this.tick(max, Date.now());
    }
    this.animator.play();
    let now = Date.now();
    this.nextRenderTime = now + this.frameTime / this.speedRate;
    this.tick(max, now);
  }

  transformFrameSize(frameStyle: Frame | null) {
    if (frameStyle) {
      frameStyle.top = frameStyle.top * this.yRatio;
      frameStyle.left = frameStyle.left * this.xRatio;
      frameStyle.width = frameStyle.width * this.xRatio;
      frameStyle.height = frameStyle.height * this.yRatio;
    }
    return frameStyle;
  }

  tick(max: number, now: number) {
    if (now < this.nextRenderTime) {
      return
    }
    let count = this.count;
    if (this.controller) {
      let controllerStatus: PlayStatus = this.controller.playStatus;
      if (controllerStatus === PlayStatus.PAUSE) {
        return;
      }

      if (controllerStatus === PlayStatus.STOP) {
        if (count === 1) {
          return;
        }
        count = 0;
      }
    }

    count >= (max - 1) ? count = 0 : count++;
    this.count = count;
    this.currentImage = this.imageArr[count];
    let styleInfoitem: Frame | null = this.styleInfo[count];
    let jsonData = JSON.parse(JSON.stringify(styleInfoitem)) as Frame | null;
    let frameStyle = styleInfoitem ? this.transformFrameSize(jsonData) : styleInfoitem;
    let img: ImageBitmap | null = null;
    try {
      const imageTemp = this.imageMap.get(count);
      if (imageTemp) {
        img = imageTemp;
      } else {
        img = new ImageBitmap(this.currentImage);
        this.imageMap.set(count, img);
      }
    } catch (error) {
      console.error('Failed to add image to map:', error);
    }
    let eventData: emitter.EventData = {
      data: {
        "count": count,
        "max": max,
      }
    };
    emitter.emit(this.controller?.uuid + 'frame', eventData);
    if (count === 0) {
      if (!frameStyle) {
        this.canvasContext.clearRect(this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top),
          this.uiContext?.px2vp(this.prevFrame.width),
          this.uiContext?.px2vp(this.prevFrame.height));
        return;
      }
      this.canvasContext.clearRect(0, 0, ceil(frameStyle.width), ceil(frameStyle.height));
      this.prevFrameData = null;
      if (frameStyle.disposeOp === 2) {
        frameStyle.disposeOp = 1;
      }
    }

    if (this.prevFrame && this.prevFrame.disposeOp == 1) {
      this.canvasContext.clearRect(this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top), this.uiContext?.px2vp(this.prevFrame.width),
        this.uiContext?.px2vp(this.prevFrame.height));
    } else if (this.prevFrame && this.prevFrame.disposeOp == 2) {
      this.canvasContext.putImageData(this.prevFrameData, this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top));
    }

    let frame: Frame | null = frameStyle;
    if (!frame) {
      this.canvasContext.clearRect(this.uiContext?.px2vp(this.prevFrame.left), this.uiContext?.px2vp(this.prevFrame.top), this.uiContext?.px2vp(this.prevFrame.width),
        this.uiContext?.px2vp(this.prevFrame.height));
      return;
    }
    this.prevFrame = frame;
    this.prevFrameData = null;
    if (frame.disposeOp == 2) {
      this.prevFrameData = this.canvasContext.getImageData(this.uiContext?.px2vp(frame.left), this.uiContext?.px2vp(frame.top), this.uiContext?.px2vp(frame.width),  this.uiContext?.px2vp(frame.height));
    }
    if (frame.blendOp == 0) {
      this.canvasContext.clearRect(this.uiContext?.px2vp(frame.left), this.uiContext?.px2vp(frame.top), this.uiContext?.px2vp(frame.width), this.uiContext?.px2vp(frame.height));
    }
    this.canvasContext.imageSmoothingEnabled = false;
    this.canvasContext.drawImage(img, this.uiContext?.px2vp(frame.left), this.uiContext?.px2vp(frame.top), this.uiContext?.px2vp(frame.width), this.uiContext?.px2vp(frame.height));

    if (this.timeTaken) {
      this.canvasWidth = Number(this.uiContext?.px2vp(frame.width).toFixed(1));
      this.canvasHeight = Number(this.uiContext?.px2vp(frame.height).toFixed(1));
    }
    this.timeTaken = '';
    frameStyle = null;
    frame = null;
    if (!this.isVisible) {
      return;
    }

    this.nextRenderTime = this.getNextFrame(count, max, now);
    if(count >= (max - 1)){
      this.currentFrameNumber++;
      LogUtils.getInstance().debug("currentFrameNumber: " + this.currentFrameNumber + ", numPlays: " + this.numPlays);
      if(this.numPlays > 0 && this.currentFrameNumber === this.numPlays){
        this.controller?.pause();
        this.currentFrameNumber = 0;
      }
    }
  }

  getNextFrame(count: number, max: number, now: number): number {
    let nextCount = count + 1;
    if (count >= (max - 1)) {
      nextCount = 0;
    }
    let frameInfo = this.styleInfo[nextCount] as Frame;
    if (this.speedRate < 0.1 || this.speedRate > 2) {
      this.speedRate = defaultSpeed;
    }
    this.frameTime = frameInfo.delay == 0 ? 100 : frameInfo.delay / this.speedRate;
    return now + this.frameTime
  }

  async init() {
    this.clear();
    if (this.request !== undefined) {
      this.request.requestState = ApngRequestState.DESTROY;
      this.request = undefined;
    }

    if (this.src) {
      let requestId = util.generateRandomUUID();
      Apng.getInstance().execute(this.getRequest(requestId));

      // 开启一次监听
      emitter.once(requestId, (data) => {
        let request: ApngRequest = Apng.getInstance().getExecutingJobMap().get(requestId);
        if (!data || request === undefined) {
          Apng.getInstance().getExecutingJobMap().remove(requestId);
          return
        }
        this.apngWidth = request.apngWidth;
        this.apngHeight = request.apngHeight;
        this.styleInfo = request.styleInfo;
        this.maxWidth = request.maxWidth;
        this.maxHeight = request.maxHeight;
        this.timeTaken = request.timeTaken;
        this.imageArr = request.imageArr;
        this.numPlays = this.numPlays !== 0 ? this.numPlays : request.numPlays;
        this.isAPNG = request.isAPNG;
        Apng.getInstance().getExecutingJobMap().remove(requestId);
        if (!this.isAPNG) {
          if (typeof this.src === 'object') {
            this.imgSrc = this.src as ResourceStr;
          } else if (typeof this.src === 'string') {
            if (this.src && this.src.startsWith('http')) {
              this.imgSrc = this.src;
            } else {
              this.imgSrc = `file://${this.src}`;
            }
          }
        }
      })
    }
  }

  canvasVisible() {
    let context2D: ESObject = this.canvasContext;
    let node: FrameNode = context2D?.canvas;
    if (node) {
      node.commonEvent.setOnVisibleAreaApproximateChange(
        { ratios: [0], expectedUpdateInterval: 200 },
        (isVisible: boolean, currentRatio: number) => {
          this.isVisible = isVisible;
          LogUtils.getInstance().info(`${this.src} -- Invisible state of APNG loading canvas -- '${isVisible}'`)
          if (isVisible) {
            (this.animator !== null) ? undefined : this.loop(this.count, this.imageArr.length)
          } else {
            this.animator?.finish();
            this.animator = null;
          }
        }
      )
      let isVisible: boolean | undefined = node?.isVisible();
      if (isVisible) {
        // 子组件canvas节点可见，遍历父节点是否隐藏状态，如果父节点是隐藏状态，则把动画停止绘制
        isVisible = this.isNodeVisible(node);
      }
      if (isVisible !== undefined && !isVisible) {
        this.animator?.finish();
        this.animator = null;
      }
      node?.commonEvent.setOnDisappear(() => {
        LogUtils.getInstance().info(`${this.src} -- APNG canvas disappeared.`);
        this.animator?.finish();
        this.animator = null;
      });
    } else {
      this.isVisible = true;
    }
  }

  isNodeVisible(node: FrameNode | null | undefined): boolean | undefined {
    let isVisible: boolean | undefined = true;
    while (isVisible) {
      isVisible = node?.isVisible();
      node = node?.getParent();
    }
    return isVisible
  }

  getRequest(requestId: string): ApngRequest {
    if (this.request === undefined) {
      this.context = APngManager.getCurContext(this.context);
      this.request =
        new ApngRequest(requestId, ApngRequestState.PROGRESS, this.context, this.apngWidth, this.apngHeight, this.src,
          this.timeTaken)
    }
    return this.request;
  }

  build() {
    Column() {
      Canvas(this.canvasContext)
        .width(this.canvasWidth)
        .height(this.canvasHeight)
        .visibility(!this.timeTaken ? Visibility.Visible : Visibility.Hidden)
        .onReady(() => {
          this.animator?.pause();
          this.isVisible = true;
        })
        .onVisibleAreaChange([0], (isVisible: boolean) => {
          if (isVisible) {
            this.animator?.play();
          } else {
            this.animator?.pause();
          }
        }).visibility(this.isAPNG?Visibility.Visible:Visibility.None)

      Image(this.imgSrc)
        .width(this.apngWidth?this.apngWidth:undefined)
        .height(this.apngHeight?this.apngHeight:undefined)
        .objectFit(this.imageFit)
        .visibility(!this.isAPNG?Visibility.Visible:Visibility.None)

      Text(this.timeTaken)
        .visibility(this.timeTaken ? Visibility.Visible : Visibility.None)
    }
    .width('100%')
    .height('100%')
    .alignItems(this.alignItems)
    .justifyContent(this.justifyContent)
  }
}
