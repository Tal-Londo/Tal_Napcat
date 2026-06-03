import { router } from '@kit.ArkUI';
import { apngV2, ApngController, Apng } from '@ohos/apng';
import { RefreshLogger } from '../model/RefreshLogger';
import emitter from '@ohos.events.emitter';
import { fileIo } from '@kit.CoreFileKit';
import http from '@ohos.net.http';

@Entry
@Component
struct ApngDebugPage {

  private localFaces: string[] = ['0', '1', '2', '3', '4', '5', '10', '14', '18', '20', '21', '26', '35'];
  private networkApng: string = 'https://lib.stapxs.cn/download/stapxs-qq-lite/qq_emoji/0/apng/0.png';

  // Controller test
  private controller: ApngController = new ApngController();
  @State controllerStatus: string = 'PLAY';
  @State speedRate: number = 1;
  @State selectedFace: string = '0';
  @State frameInfo: string = '-/-';
  @State numPlays: number = 0;

  // Cache
  @State cacheEnabled: boolean = false;

  // Uint8Array
  @State uint8Ready: boolean = false;
  private uint8Data: Uint8Array | undefined = undefined;

  // fd:// 本地文件加载测试
  @State fdReady: boolean = false;
  @State fdPath: string = '';
  @State fdResult: string = '';
  private openFd: number = -1;

  aboutToAppear(): void {
    RefreshLogger.getInstance().log('APNGDBG-OPEN', 'page opened');

    this.controller.emit('frame', (data: emitter.EventData) => {
      let d = data.data as Record<string, number>;
      if (d) {
        this.frameInfo = (d['count'] as number) + '/' + (d['max'] as number);
      }
    });

    this.loadUint8Array();
    this.loadFdTest();
  }

  async loadFdTest(): Promise<void> {
    try {
      // 下载网络 APNG 到本地缓存
      let cachePath = '/data/storage/el2/base/cache/apng_fd_test.png';
      let httpRequest: http.HttpRequest = http.createHttp();
      let chunks: Array<ArrayBuffer> = new Array<ArrayBuffer>();
      httpRequest.on('dataReceive', (data: ArrayBuffer) => { chunks.push(data); });
      let code: number = await httpRequest.requestInStream(this.networkApng, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        usingCache: false
      }).catch(() => -1) as number;
      httpRequest.destroy();
      if (code !== 200 || chunks.length === 0) {
        RefreshLogger.getInstance().log('APNGDBG-FD', 'download failed code=' + code);
        return;
      }
      let totalLen = 0;
      for (let ab of chunks) { totalLen += ab.byteLength; }
      let combined = new ArrayBuffer(totalLen);
      let view = new Uint8Array(combined);
      let off = 0;
      for (let ab of chunks) { view.set(new Uint8Array(ab), off); off += ab.byteLength; }
      let file = fileIo.openSync(cachePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, combined);
      fileIo.fsyncSync(file.fd);
      fileIo.closeSync(file);
      // 重新打开只读保持 fd 存活供 Image fd:// 测试
      let roFile = fileIo.openSync(cachePath, fileIo.OpenMode.READ_ONLY);
      this.openFd = roFile.fd;
      this.fdPath = cachePath;
      this.fdResult = 'size=' + totalLen + ' roFd=' + roFile.fd;
      this.fdReady = true;
      RefreshLogger.getInstance().log('APNGDBG-FD', 'file=' + cachePath + ' size=' + totalLen + ' fd=' + roFile.fd);
    } catch (e) {
      RefreshLogger.getInstance().log('APNGDBG-FDERR', 'fd test setup failed: ' + JSON.stringify(e));
    }
  }

  async loadUint8Array(): Promise<void> {
    try {
      this.uint8Data = await getContext().resourceManager.getRawFileContent('face/0.png');
      this.uint8Ready = true;
    } catch (e) {
      RefreshLogger.getInstance().log('APNGDBG-U8ERR', 'Uint8Array load failed: ' + JSON.stringify(e));
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('APNG 调试')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
        Text('返回')
          .fontSize(12)
          .fontColor('#C0B8E0')
          .onClick(() => { router.back(); })
      }
      .width('90%')
      .padding({ top: 8, bottom: 4 })

      Scroll() {
        Column() {
          // ====== Controller Test ======
          SectionLabel({ label: '控制器测试', color: '#FFB347' })

          Row() {
            apngV2({
              src: $rawfile('face/' + this.selectedFace + '.png'),
              speedRate: this.speedRate,
              apngWidth: 52,
              apngHeight: 52,
              context: getContext(),
              controller: this.controller,
              numPlays: this.numPlays
            })
              .width(52)
              .height(52)

            Column() {
              Text('帧: ' + this.frameInfo)
                .fontSize(10).fontColor('#888888')
              Text('速率: ' + this.speedRate.toFixed(1) + 'x')
                .fontSize(10).fontColor('#888888')
              Text('状态: ' + this.controllerStatus)
                .fontSize(10).fontColor('#FFB347')
              Text('次数: ' + (this.numPlays === 0 ? '无限' : this.numPlays.toString()))
                .fontSize(10).fontColor('#888888')
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 8 })
          }
          .width('90%')

          Row() {
            Button('暂停').fontSize(10).width(52).height(28)
              .onClick(() => { this.controller.pause(); this.controllerStatus = 'PAUSE'; })
            Button('停止').fontSize(10).width(52).height(28)
              .onClick(() => { this.controller.stop(); this.controllerStatus = 'STOP'; })
            Button('播放').fontSize(10).width(52).height(28)
              .onClick(() => { this.controller.play(); this.controllerStatus = 'PLAY'; })
          }
          .width('90%')
          .justifyContent(FlexAlign.SpaceEvenly)
          .margin({ top: 4 })

          Row() {
            Text('速率').fontSize(10).fontColor('#888888').width(36)
            Slider({
              value: this.speedRate,
              min: 0.1,
              max: 2,
              step: 0.1
            })
              .onChange((value: number) => { this.speedRate = value; })
              .layoutWeight(1)
          }
          .width('90%')

          Row() {
            Text('Face').fontSize(10).fontColor('#888888').width(36)
            TextInput({ text: this.selectedFace })
              .fontSize(10).width(52).height(28)
              .onChange((value: string) => { this.selectedFace = value; })
            Text('次').fontSize(10).fontColor('#888888').margin({ left: 6 })
            TextInput({ text: this.numPlays === 0 ? '0' : this.numPlays.toString() })
              .fontSize(10).width(36).height(28)
              .onChange((value: string) => {
                let n = parseInt(value);
                this.numPlays = (isNaN(n) || n < 0) ? 0 : n;
              })
          }
          .width('90%')
          .margin({ top: 4 })

          SectionDivider()

          // ====== Local Gallery ======
          SectionLabel({ label: '本地 Gallery (rawfile)', color: '#C0B8E0' })

          Grid() {
            ForEach(this.localFaces, (faceId: string) => {
              GridItem() {
                Column() {
                  apngV2({
                    src: $rawfile('face/' + faceId + '.png'),
                    speedRate: 1,
                    apngWidth: 28,
                    apngHeight: 28,
                    context: getContext()
                  })
                    .width(28)
                    .height(28)
                  Text(faceId)
                    .fontSize(8)
                    .fontColor('#666666')
                }
                .alignItems(HorizontalAlign.Center)
              }
              .width(36)
              .height(42)
            }, (faceId: string) => faceId)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
          .rowsGap(4)
          .columnsGap(4)
          .width('90%')
          .height(130)
          .scrollBar(BarState.Auto)

          SectionDivider()

          // ====== Network APNG ======
          SectionLabel({ label: '网络 APNG (Stapxs CDN)', color: '#4DA6FF' })

          apngV2({
            src: this.networkApng,
            speedRate: 1,
            apngWidth: 56,
            apngHeight: 56,
            context: getContext()
          })
            .width(56)
            .height(56)

          Text(this.networkApng)
            .fontSize(7)
            .fontColor('#444444')
            .width('90%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })

          SectionDivider()

          // ====== Uint8Array Load ======
          SectionLabel({ label: 'Uint8Array 加载', color: '#4DA6FF' })

          if (this.uint8Ready && this.uint8Data) {
            apngV2({
              src: this.uint8Data,
              speedRate: 1,
              apngWidth: 48,
              apngHeight: 48,
              context: getContext()
            })
              .width(48)
              .height(48)
            Text('face/0.png → Uint8Array')
              .fontSize(8)
              .fontColor('#666666')
              .margin({ top: 2 })
          } else {
            Text('加载 Uint8Array 中...')
              .fontSize(10)
              .fontColor('#888888')
          }

          SectionDivider()

          // ====== 本地文件 APNG (fd:// & sandbox path) ======
          SectionLabel({ label: '本地文件加载 (fd:// & sandbox)', color: '#7B68EE' })

          if (this.fdReady) {
            Column() {
              Text('路径: ' + this.fdPath)
                .fontSize(7)
                .fontColor('#666666')
                .width('90%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })

              Row() {
                // 1. apngV2 直接用 sandbox 路径
                Column() {
                  apngV2({
                    src: '/data/storage/el2/base/cache/apng_fd_test.png',
                    speedRate: 1,
                    apngWidth: 56,
                    apngHeight: 56,
                    context: getContext()
                  })
                    .width(56)
                    .height(56)
                  Text('sandbox路径')
                    .fontSize(7)
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Center)
                .margin({ right: 6 })

                // 2. apngV2 用 file:// 前缀
                Column() {
                  apngV2({
                    src: 'file:///data/storage/el2/base/cache/apng_fd_test.png',
                    speedRate: 1,
                    apngWidth: 56,
                    apngHeight: 56,
                    context: getContext()
                  })
                    .width(56)
                    .height(56)
                  Text('file://前缀')
                    .fontSize(7)
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Center)
                .margin({ right: 6 })

                // 3. 普通 Image + fd://
                Column() {
                  Image('fd://' + this.openFd)
                    .width(56)
                    .height(56)
                    .objectFit(ImageFit.Cover)
                  Text('Image fd://')
                    .fontSize(7)
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Center)
                .margin({ right: 6 })

                // 4. apngV2 + fd://
                Column() {
                  apngV2({
                    src: 'fd://' + this.openFd,
                    speedRate: 1,
                    apngWidth: 56,
                    apngHeight: 56,
                    context: getContext()
                  })
                    .width(56)
                    .height(56)
                  Text('apngV2 fd://')
                    .fontSize(7)
                    .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Center)
              }
              .width('90%')
              .justifyContent(FlexAlign.Start)

              Text(this.fdResult)
                .fontSize(7)
                .fontColor('#444444')
                .width('90%')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Center)
          } else {
            Text('下载本地 APNG 测试中...')
              .fontSize(10)
              .fontColor('#888888')
          }

          SectionDivider()

          // ====== Size Variants ======
          SectionLabel({ label: '尺寸测试 (faceId=0)', color: '#FFB347' })

          Row() {
            ForEach([20, 36, 52, 68], (size: number, index: number) => {
              Column() {
                apngV2({
                  src: $rawfile('face/0.png'),
                  speedRate: 1,
                  apngWidth: size,
                  apngHeight: size,
                  context: getContext()
                })
                  .width(size)
                  .height(size)
                Text(size.toString())
                  .fontSize(8)
                  .fontColor('#666666')
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ left: index === 0 ? 0 : 6 })
            })
          }
          .width('90%')

          SectionDivider()

          // ====== Animation Variants ======
          SectionLabel({ label: '不同表情放大 (faceId=0,14,35)', color: '#C0B8E0' })

          Row() {
            ForEach(['0', '14', '35'], (faceId: string, index: number) => {
              Column() {
                apngV2({
                  src: $rawfile('face/' + faceId + '.png'),
                  speedRate: 1,
                  apngWidth: 56,
                  apngHeight: 56,
                  context: getContext()
                })
                  .width(56)
                  .height(56)
                Text(faceId)
                  .fontSize(8)
                  .fontColor('#666666')
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ left: index === 0 ? 0 : 6 })
            })
          }
          .width('90%')

          SectionDivider()

          // ====== Cache Management ======
          SectionLabel({ label: '缓存管理', color: '#FFB347' })

          Row() {
            Text('启用内存缓存')
              .fontSize(10)
              .fontColor('#888888')
            Toggle({ type: ToggleType.Switch, isOn: this.cacheEnabled })
              .onChange((isOn: boolean) => {
                this.cacheEnabled = isOn;
                Apng.getInstance().setEnableCache(isOn);
                RefreshLogger.getInstance().log('APNGDBG-CACHE', 'cache ' + (isOn ? 'ON' : 'OFF'));
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.SpaceBetween)

          Row() {
            Button('清全部缓存')
              .fontSize(9).height(28)
              .onClick(() => {
                Apng.getInstance().removeAllMemoryCache();
                RefreshLogger.getInstance().log('APNGDBG-CACHE', 'clear all');
              })
            Button('清 face/0')
              .fontSize(9).height(28)
              .onClick(() => {
                Apng.getInstance().removeMemoryCache($rawfile('face/0.png'));
                RefreshLogger.getInstance().log('APNGDBG-CACHE', 'clear face/0');
              })
            Button('清 CDN')
              .fontSize(9).height(28)
              .onClick(() => {
                Apng.getInstance().removeMemoryCache(this.networkApng);
                RefreshLogger.getInstance().log('APNGDBG-CACHE', 'clear CDN');
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.SpaceEvenly)
          .margin({ top: 4 })

          // Bottom spacer
          Blank().height(24)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}

@Component
struct SectionLabel {
  @Prop label: string = '';
  @Prop color: string = '#FFFFFF';

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(this.color)
      .width('90%')
      .margin({ top: 10, bottom: 6 })
  }
}

@Component
struct SectionDivider {
  build() {
    Divider()
      .width('90%')
      .color('#2A2A2A')
      .margin({ top: 10, bottom: 4 })
  }
}
