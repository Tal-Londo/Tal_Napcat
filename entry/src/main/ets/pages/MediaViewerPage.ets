import { router, display } from '@kit.ArkUI';
import { CacheManager, CacheType } from '../model/CacheManager';
import { RefreshLogger } from '../model/RefreshLogger';
import { OneBotRequest } from '../model/OneBotModel';
import { WebSocketManager } from '../model/WebSocketManager';

class MediaItem {
  url: string = '';
  type: string = 'image';
}

@Entry
@Component
struct MediaViewerPage {
  @State items: MediaItem[] = [];
  @State currentIndex: number = 0;
  @State imgScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  private baseScale: number = 1.0;
  private baseOffsetX: number = 0;
  private baseOffsetY: number = 0;
  private cacheMgr: CacheManager = CacheManager.getInstance();
  private screenW: number = 300;
  private videoController: VideoController = new VideoController();

  aboutToAppear(): void {
    let params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      let urlsStr = params['mediaUrls'] as string || '[]';
      let typesStr = params['mediaTypes'] as string || '[]';
      try {
        let urls = JSON.parse(urlsStr) as string[];
        let types = JSON.parse(typesStr) as string[];
        for (let i = 0; i < urls.length; i++) {
          let mi = new MediaItem();
          mi.type = types[i] || 'image';
          if (mi.type === 'video') {
            let parts = urls[i].split('|');
            mi.url = parts[0];
            let fileUuid = parts[1] || '';
            this.items.push(mi);
            if (fileUuid !== '') {
              this.refreshVideoUrl(mi, fileUuid);
            }
          } else {
            mi.url = urls[i];
            this.items.push(mi);
          }
        }
      } catch (_e) {
        try {
          let urls = JSON.parse(urlsStr) as string[];
          for (let i = 0; i < urls.length; i++) {
            let mi = new MediaItem();
            mi.type = params['mediaType'] as string || 'image';
            mi.url = urls[i];
            this.items.push(mi);
          }
        } catch (_e2) {
        }
      }
      this.currentIndex = params['currentIndex'] as number || 0;
    }
    try {
      let defaultDisplay = display.getDefaultDisplaySync();
      this.screenW = defaultDisplay.width;
    } catch (_e) {
    }
  }

  refreshVideoUrl(item: MediaItem, fileUuid: string): void {
    RefreshLogger.getInstance().log('VIDEO-REFRESH', 'calling get_file for ' + fileUuid);
    let wsm = WebSocketManager.getInstance();
    let req = OneBotRequest.createGetFile(fileUuid);
    wsm.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let inner = data['data'] as Record<string, Object> || {};
      let newUrl = inner['url'] as string || '';
      if (newUrl !== '') {
        RefreshLogger.getInstance().log('VIDEO-FRESH-OK', 'new URL len=' + newUrl.length);
        item.url = newUrl;
      }
    });
  }

  getCurrent(): MediaItem {
    if (this.currentIndex >= 0 && this.currentIndex < this.items.length) {
      return this.items[this.currentIndex];
    }
    return new MediaItem();
  }

  fixVideoUrl(url: string): string {
    // QQ CDN 需要仿安卓客户端参数才能访问，否则 5411006
    if (url.includes('multimedia.nt.qq.com.cn') && !url.includes('client_proto=')) {
      return url + '&client_proto=ntv2&client_appid=537324442&client_type=android&client_ver=9.2.30&client_down_type=manual&client_aio_type=bigs';
    }
    return url;
  }

  getCachedUrl(url: string): string {
    let key = this.cacheMgr.makeKey(url, CacheType.IMAGE);
    let cached = this.cacheMgr.getPath(key);
    return cached !== '' ? 'file://' + cached : url;
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
    if (isNaN(maxR) || maxR <= 0) { maxR = 200; }
    let extra = (this.imgScale - 1) * this.screenW * 0.3;
    if (extra < 0) { extra = 0; }
    let bound = maxR + extra;
    let dist = Math.sqrt(this.offsetX * this.offsetX + this.offsetY * this.offsetY);
    if (dist > bound && dist > 0) {
      let ratio = bound / dist;
      this.offsetX = this.offsetX * ratio;
      this.offsetY = this.offsetY * ratio;
    }
  }

  swipeNext(): void {
    if (this.videoController !== undefined) {
      this.videoController.stop();
    }
    if (this.currentIndex < this.items.length - 1) {
      this.currentIndex++;
      this.resetView();
    }
  }

  swipePrev(): void {
    if (this.videoController !== undefined) {
      this.videoController.stop();
    }
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.resetView();
    }
  }

  close(): void {
    if (this.videoController !== undefined) {
      this.videoController.stop();
    }
    router.back();
  }

  handleTap(): void {
    if (this.imgScale < 1.01) {
      this.close();
    }
  }

  handlePanEnd(event: GestureEvent, isImage: boolean): void {
    if (isImage && this.imgScale > 1.01) {
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

      if (this.items.length > 0) {
        if (this.getCurrent().type === 'image') {
          Column() {
            Image(this.getCachedUrl(this.getCurrent().url))
              .width('100%')
              .height('92%')
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
                      this.handlePanEnd(event, true);
                    })
                )
              )
            Blank()
          }
          .width('100%')
          .height('100%')
        } else {
          // video — use Video component (official wearable approach)
          Column() {
            Row() {
              Blank()
              SymbolGlyph($r('sys.symbol.xmark_circle'))
                .fontSize(16)
                .fontColor([Color.White])
                .onClick(() => { this.close(); })
            }
            .width('100%')
            .padding({ top: 4, right: 4 })

            Video({
              src: this.fixVideoUrl(this.getCurrent().url),
              controller: this.videoController
            })
              .autoPlay(true)
              .controls(false)
              .loop(false)
              .objectFit(ImageFit.Contain)
              .height('70%')
              .width('90%')
              .onStart(() => {
                RefreshLogger.getInstance().log('VIDEO-ONSTART', 'url=' + this.getCurrent().url);
              })
              .onPause(() => {
                RefreshLogger.getInstance().log('VIDEO-ONPAUSE', 'paused');
              })
              .onFinish(() => {
                RefreshLogger.getInstance().log('VIDEO-ONFINISH', 'finished');
              })
              .onError((event) => {
                RefreshLogger.getInstance().log('VIDEO-ONERR', 'code=' + (event?.code ?? '?') + ' msg=' + (event?.message ?? '?') + ' url=' + this.getCurrent().url);
              })
              .onPrepared((event) => {
                RefreshLogger.getInstance().log('VIDEO-ONPREPARED', 'duration=' + event?.duration + ' url=' + this.getCurrent().url);
              })
              .onUpdate((event) => {
                if (event?.time !== undefined) {
                  RefreshLogger.getInstance().log('VIDEO-TIME', 'time=' + event.time);
                }
              })

            // pan for swipe between items
            Row()
              .width('100%')
              .height(40)
              .gesture(
                PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 20 })
                  .onActionEnd((event: GestureEvent) => {
                    this.handlePanEnd(event, false);
                  })
              )
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
        }
      }

      // 页码指示器
      if (this.items.length > 1) {
        Row() {
          ForEach(this.items, (item: MediaItem, i: number) => {
            Circle({ width: 5, height: 5 })
              .fill(i === this.currentIndex ? '#FFFFFF' : '#555555')
              .margin({ left: 3, right: 3 })
          }, (_item: MediaItem, i: number) => i.toString())
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
    .groupDefaultFocus(true)
    .onDigitalCrown((e: CrownEvent) => {
      if (this.getCurrent().type === 'image') {
        let delta = Math.floor(e.degree * 100) / 100;
        let newScale = Math.max(0.5, Math.min(this.imgScale - delta * 0.1, 5.0));
        if (Math.abs(newScale - 1.0) < 0.03) {
          newScale = 1.0;
          this.offsetX = 0;
          this.offsetY = 0;
          this.baseOffsetX = 0;
          this.baseOffsetY = 0;
        }
        this.imgScale = newScale;
        this.baseScale = newScale;
      }
    })
    .onClick(() => { this.handleTap(); })
  }
}
