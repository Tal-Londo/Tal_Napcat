import { router, display } from '@kit.ArkUI';
import { CacheManager, CacheType } from '../model/CacheManager';
import { media } from '@kit.MediaKit';

@Entry
@Component
struct MediaViewerPage {
  @State urls: string[] = [];
  @State currentIndex: number = 0;
  @State mediaType: string = 'image';
  @State imgScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State videoPlaying: boolean = false;
  @State videoLoading: boolean = false;
  private baseScale: number = 1.0;
  private baseOffsetX: number = 0;
  private baseOffsetY: number = 0;
  private cacheMgr: CacheManager = CacheManager.getInstance();
  private screenW: number = 300;
  private avPlayer: media.AVPlayer | null = null;

  aboutToDisappear(): void {
    this.stopVideo();
  }

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
      this.resetVideo();
    }
  }

  swipePrev(): void {
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.resetView();
      this.resetVideo();
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
        this.resetVideo();
      } else if (event.offsetX > 80) {
        this.swipePrev();
        this.resetVideo();
      }
      this.offsetX = 0;
      this.offsetY = 0;
      this.baseOffsetX = 0;
      this.baseOffsetY = 0;
    }
  }

  toggleVideoPlay(): void {
    if (this.videoPlaying) {
      this.stopVideo();
      return;
    }
    let url = '';
    if (this.currentIndex >= 0 && this.currentIndex < this.urls.length) {
      url = this.urls[this.currentIndex];
    }
    if (url === '') {
      return;
    }
    this.videoLoading = true;
    if (this.avPlayer !== null) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
    media.createAVPlayer().then((player: media.AVPlayer) => {
      this.avPlayer = player;
      player.on('stateChange', (state: string) => {
        if (state === 'playing') {
          this.videoLoading = false;
          this.videoPlaying = true;
        }
        if (state === 'stopped' || state === 'completed') {
          this.videoPlaying = false;
        }
      });
      player.on('error', () => {
        this.videoLoading = false;
        this.videoPlaying = false;
      });
      player.url = url.startsWith('http') ? url : ('file://' + url);
      player.prepare().then(() => {
        player.play();
      }).catch(() => {
        this.videoLoading = false;
      });
    }).catch(() => {
      this.videoLoading = false;
    });
  }

  stopVideo(): void {
    this.videoPlaying = false;
    this.videoLoading = false;
    if (this.avPlayer !== null) {
      try {
        this.avPlayer.release();
      } catch (_e) {
      }
      this.avPlayer = null;
    }
  }

  resetVideo(): void {
    this.stopVideo();
    if (this.mediaType === 'video') {
      this.videoLoading = false;
      this.videoPlaying = false;
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
          // 顶部关闭按钮
          Row() {
            Blank()
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(18)
              .fontColor([Color.White])
              .onClick(() => {
                this.stopVideo();
                this.close();
              })
          }
          .width('100%')
          .padding({ top: 6, right: 6 })

          Blank()

          if (this.videoLoading) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color('#C0B8E0')
          } else if (this.videoPlaying) {
            Text('播放中')
              .fontSize(14)
              .fontColor('#C0B8E0')
          } else {
            SymbolGlyph($r('sys.symbol.play_circle'))
              .fontSize(48)
              .fontColor(['#C0B8E0'])
              .onClick(() => { this.toggleVideoPlay(); })
          }

          Text(this.videoPlaying ? '点击暂停' : this.videoLoading ? '加载中...' : '点击播放视频')
            .fontSize(12)
            .fontColor('#888888')
            .margin({ top: 12 })

          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .onClick(() => {
          if (this.videoPlaying) {
            this.stopVideo();
          }
        })
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
