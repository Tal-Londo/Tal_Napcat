import { router, display } from '@kit.ArkUI';
import { CacheManager, CacheType } from '../model/CacheManager';
import { RefreshLogger } from '../model/RefreshLogger';
import { OneBotRequest } from '../model/OneBotModel';
import { WebSocketManager } from '../model/WebSocketManager';
import { ConfigManager } from '../model/ConfigManager';
import { media } from '@kit.MediaKit';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';

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
      let typesStr = params['mediaTypes'] as string || '[]';
      try {
        let urls = JSON.parse(urlsStr) as string[];
        let types = JSON.parse(typesStr) as string[];
        for (let i = 0; i < urls.length; i++) {
          let mi = new MediaItem();
          mi.url = urls[i];
          mi.type = types[i] || 'image';
          this.items.push(mi);
        }
      } catch (_e) {
        // fallback: old format without types
        try {
          let urls = JSON.parse(urlsStr) as string[];
          for (let i = 0; i < urls.length; i++) {
            let mi = new MediaItem();
            mi.url = urls[i];
            mi.type = params['mediaType'] as string || 'image';
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

  getCurrent(): MediaItem {
    if (this.currentIndex >= 0 && this.currentIndex < this.items.length) {
      return this.items[this.currentIndex];
    }
    return new MediaItem();
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
    this.stopVideo();
    if (this.currentIndex < this.items.length - 1) {
      this.currentIndex++;
      this.resetView();
    }
  }

  swipePrev(): void {
    this.stopVideo();
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

  toggleVideoPlay(): void {
    if (this.videoPlaying) {
      this.stopVideo();
      return;
    }
    let url = this.getCurrent().url;
    if (url === '') { return; }
    this.videoLoading = true;
    if (url.startsWith('http')) {
      // 直接 HTTP URL — 手表 AVPlayer 播放音频流（无画面）
      RefreshLogger.getInstance().log('VIDEO-DIRECT', 'play audio from ' + url.substring(0, 80));
      this.doPlayVideo(url);
      return;
    }
    // UUID — 走 get_record 获取转码 URL/路径
    RefreshLogger.getInstance().log('VIDEO-GETREC', 'resolving UUID: ' + url.substring(0, 80));
    let wsm = WebSocketManager.getInstance();
    let req = OneBotRequest.createGetRecord(url, 'mp4');
    wsm.sendRequestWithCallback(req, async (data: Record<string, Object>) => {
      let inner = data['data'] as Record<string, Object> || {};
      let resolvedUrl = inner['url'] as string || '';
      let outFile = inner['file'] as string || '';
      RefreshLogger.getInstance().log('VIDEO-GETREC-RSP', 'url=' + resolvedUrl.substring(0, 80) + ' file=' + outFile.substring(0, 80));
      if (resolvedUrl.startsWith('http')) {
        this.doPlayVideo(resolvedUrl);
      } else if (outFile.startsWith('http')) {
        this.doPlayVideo(outFile);
      } else if (outFile !== '') {
        await this.downloadAndPlayVideo(outFile);
      } else {
        RefreshLogger.getInstance().log('VIDEO-NOPLAY', 'no playable URL');
        this.videoLoading = false;
      }
    });
  }

  async downloadAndPlayVideo(serverPath: string): Promise<void> {
    try {
      let serverUrl = await ConfigManager.getInstance().getString('server_url', '');
      let base = serverUrl.replace(/^ws/, 'http').replace(/\/ws(\?.*)?$/, '');
      let downloadUrl = base + serverPath;
      RefreshLogger.getInstance().log('VIDEO-DOWNLOAD', 'download: ' + downloadUrl.substring(0, 100));
      let httpReq = http.createHttp();
      let resp = await httpReq.request(downloadUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 60000
      });
      let filePath = '/data/storage/el2/base/cache/video_' + Date.now() + '.mp4';
      if (resp.result instanceof ArrayBuffer && (resp.result as ArrayBuffer).byteLength > 0) {
        let file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
        fileIo.writeSync(file.fd, resp.result as ArrayBuffer);
        fileIo.closeSync(file);
        RefreshLogger.getInstance().log('VIDEO-DOWN-OK', 'saved size=' + (resp.result as ArrayBuffer).byteLength);
        this.doPlayVideo(filePath);
      } else {
        RefreshLogger.getInstance().log('VIDEO-DOWN-ERR', 'empty response');
        this.videoLoading = false;
        httpReq.destroy();
      }
    } catch (e) {
      RefreshLogger.getInstance().log('VIDEO-DOWN-CATCH', 'error: ' + (e as Error).message);
      this.videoLoading = false;
    }
  }

  doPlayVideo(playUrl: string): void {
    RefreshLogger.getInstance().log('VIDEO-PLAY', 'start url=' + playUrl.substring(0, 100));
    this.videoLoading = true;
    if (this.avPlayer !== null) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
    media.createAVPlayer().then((player: media.AVPlayer) => {
      this.avPlayer = player;
      let prepared = false;
      player.on('stateChange', (state: string) => {
        RefreshLogger.getInstance().log('VIDEO-STATE', 'state=' + state);
        if (state === 'initialized' && !prepared) {
          prepared = true;
          player.prepare().then(() => {
            RefreshLogger.getInstance().log('VIDEO-PREPARED', 'prepare OK, playing');
            player.play();
          }).catch((err: Error) => {
            RefreshLogger.getInstance().log('VIDEO-PREP-ERR', 'prepare failed: ' + (err.message || 'unknown'));
            this.videoLoading = false;
          });
        }
        if (state === 'playing') {
          this.videoLoading = false;
          this.videoPlaying = true;
        }
        if (state === 'stopped' || state === 'completed') {
          this.videoPlaying = false;
        }
      });
      player.on('error', () => {
        RefreshLogger.getInstance().log('VIDEO-ERR', 'AVPlayer error callback');
        this.videoLoading = false;
        this.videoPlaying = false;
      });
      player.url = playUrl.startsWith('http') ? playUrl : ('file://' + playUrl);
    }).catch((err: Error) => {
      RefreshLogger.getInstance().log('VIDEO-CREATE-ERR', 'createAVPlayer failed: ' + (err.message || 'unknown'));
      this.videoLoading = false;
    });
  }

  stopVideo(): void {
    this.videoPlaying = false;
    this.videoLoading = false;
    if (this.avPlayer !== null) {
      try { this.avPlayer.release(); } catch (_e) {}
      this.avPlayer = null;
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
          // video
          Column() {
            Row() {
              Blank()
              SymbolGlyph($r('sys.symbol.xmark_circle'))
                .fontSize(16)
                .fontColor([Color.White])
                .onClick(() => { this.stopVideo(); this.close(); })
            }
            .width('100%')
            .padding({ top: 4, right: 4 })

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

            Text(this.videoPlaying ? '点击暂停' : this.videoLoading ? '加载中...' : '点击播放')
              .fontSize(12)
              .fontColor('#888888')
              .margin({ top: 12 })

            Blank()

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
