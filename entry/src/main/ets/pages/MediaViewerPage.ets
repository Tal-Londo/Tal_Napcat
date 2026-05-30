import { router, display } from '@kit.ArkUI';
import { CacheManager, CacheType } from '../model/CacheManager';

@Entry
@Component
struct MediaViewerPage {
  @State urls: string[] = [];
  @State currentIndex: number = 0;
  @State mediaType: string = 'image';
  @State imgScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  private baseScale: number = 1.0;
  private baseOffsetX: number = 0;
  private baseOffsetY: number = 0;
  private cacheMgr: CacheManager = CacheManager.getInstance();
  private screenW: number = 300;

  aboutToAppear(): void {
    let params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      let urlsStr = params['mediaUrls'] as string || '[]';
      try {
        this.urls = JSON.parse(urlsStr) as string[];
      } catch (_e) {
        this.urls = [];
      }
      this.currentIndex = params['currentIndex'] as number || 0;
      this.mediaType = params['mediaType'] as string || 'image';
    }
    try {
      let defaultDisplay = display.getDefaultDisplaySync();
      this.screenW = defaultDisplay.width;
    } catch (_e) {
    }
  }

  getDisplayUrl(): string {
    if (this.currentIndex < 0 || this.currentIndex >= this.urls.length) {
      return '';
    }
    let url = this.urls[this.currentIndex];
    let key = this.cacheMgr.makeKey(url, CacheType.IMAGE);
    let cached = this.cacheMgr.getPath(key);
    if (cached !== '') {
      return 'file://' + cached;
    }
    return url;
  }

  resetView(): void {
    this.imgScale = 1.0;
    this.offsetX = 0;
    this.offsetY = 0;
    this.baseScale = 1.0;
    this.baseOffsetX = 0;
    this.baseOffsetY = 0;
  }

  clampOffset(): void {
    let maxR = this.screenW * 0.55;
    if (isNaN(maxR) || maxR <= 0) {
      maxR = 200;
    }
    let extra = (this.imgScale - 1) * this.screenW * 0.3;
    if (extra < 0) {
      extra = 0;
    }
    let bound = maxR + extra;
    let dist = Math.sqrt(this.offsetX * this.offsetX + this.offsetY * this.offsetY);
    if (dist > bound && dist > 0) {
      let ratio = bound / dist;
      this.offsetX = this.offsetX * ratio;
      this.offsetY = this.offsetY * ratio;
    }
  }

  swipeNext(): void {
    if (this.currentIndex < this.urls.length - 1) {
      this.currentIndex++;
      this.resetView();
    }
  }

  swipePrev(): void {
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.resetView();
    }
  }

  close(): void {
    router.back();
  }

  handleTap(): void {
    if (this.imgScale < 1.01) {
      this.close();
    }
  }

  handlePanEnd(event: GestureEvent): void {
    if (this.imgScale > 1.01) {
      this.baseOffsetX = this.offsetX;
      this.baseOffsetY = this.offsetY;
      this.clampOffset();
    } else {
      if (event.offsetX < -80) {
        this.swipeNext();
      } else if (event.offsetX > 80) {
        this.swipePrev();
      }
      this.offsetX = 0;
      this.offsetY = 0;
      this.baseOffsetX = 0;
      this.baseOffsetY = 0;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      if (this.urls.length > 0 && this.mediaType === 'image') {
        Image(this.getDisplayUrl())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .scale({ x: this.imgScale, y: this.imgScale })
          .translate({ x: this.offsetX, y: this.offsetY })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionUpdate((event: GestureEvent) => {
                  this.imgScale = this.baseScale * event.scale;
                })
                .onActionEnd(() => {
                  this.baseScale = this.imgScale;
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 8 })
                .onActionUpdate((event: GestureEvent) => {
                  this.offsetX = this.baseOffsetX + event.offsetX;
                  this.offsetY = this.baseOffsetY + event.offsetY;
                })
                .onActionEnd((event: GestureEvent) => {
                  this.handlePanEnd(event);
                })
            )
          )
      }

      if (this.urls.length > 0 && this.mediaType === 'video') {
        Column() {
          Text('?')
            .fontSize(48)
            .fontColor('#888888')
            .margin({ bottom: 12 })
          Text('视频')
            .fontSize(16)
            .fontColor(Color.White)
          Text('暂不支持播放')
            .fontSize(11)
            .fontColor('#666666')
            .margin({ top: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // 页码指示器
      if (this.urls.length > 1) {
        Row() {
          ForEach(this.urls, (_url: string, i: number) => {
            Circle({ width: 5, height: 5 })
              .fill(i === this.currentIndex ? '#FFFFFF' : '#555555')
              .margin({ left: 3, right: 3 })
          }, (_url: string, i: number) => i.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: '90%' })
      }
    }
    .width('100%')
    .height('100%')
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .onDigitalCrown((e: CrownEvent) => {
      let delta = Math.floor(e.degree * 100) / 100;
      let newScale = Math.max(0.5, Math.min(this.imgScale - delta * 0.5, 5.0));
      if (Math.abs(newScale - 1.0) < 0.03) {
        newScale = 1.0;
        this.offsetX = 0;
        this.offsetY = 0;
        this.baseOffsetX = 0;
        this.baseOffsetY = 0;
      }
      this.imgScale = newScale;
      this.baseScale = newScale;
    })
    .onClick(() => { this.handleTap(); })
  }
}
