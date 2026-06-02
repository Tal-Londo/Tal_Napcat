import { ArcList, ArcListItem, router, promptAction, ArcButton, ArcButtonOptions, ArcButtonStyleMode, ArcButtonPosition, LengthUnit, ColorMetrics, LengthMetrics } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { RefreshLogger, RefreshLogEntry } from '../model/RefreshLogger';

@Entry
@Component
struct RefreshLogPage {
  @State entries: RefreshLogEntry[] = [];
  @State uploading: boolean = false;

  aboutToAppear(): void {
    this.entries = RefreshLogger.getInstance().getEntries();
  }

  formatTime(ts: number): string {
    let d = new Date(ts);
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    let s = d.getSeconds().toString().padStart(2, '0');
    let ms = d.getMilliseconds().toString().padStart(3, '0');
    return h + ':' + m + ':' + s + '.' + ms;
  }

  upload(): void {
    if (this.entries.length === 0) {
      promptAction.showToast({ message: '暂无日志' });
      return;
    }
    this.uploading = true;
    let items = RefreshLogger.getInstance().getEntriesForUpload();
    let body: Record<string, Object> = {
      'app': 'NapcatWatch',
      'type': 'refresh_log',
      'time': Date.now(),
      'count': items.length,
      'entries': items
    };
    let httpReq = http.createHttp();
    // 默认上传到 192.168.0.119:8899
    httpReq.request('http://192.168.0.119:8899/upload', {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 10000
    }, (_err, _data) => {
      this.uploading = false;
      promptAction.showToast({ message: '已上传' });
    });
  }

  clear(): void {
    RefreshLogger.getInstance().clear();
    this.entries = [];
    promptAction.showToast({ message: '已清除' });
  }

  build() {
    Stack() {
      ArcList() {
        ArcListItem() {
          Row() {
            Text('刷新日志 ' + this.entries.length + ' 条')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)
            Button('清除')
              .fontSize(11)
              .fontColor('#FF6666')
              .backgroundColor('#1a1a1a')
              .height(28)
              .borderRadius(14)
              .padding({ left: 8, right: 8 })
              .onClick(() => { this.clear(); })
            Button(this.uploading ? '上传中' : '上传')
              .fontSize(11)
              .fontColor('#00FF88')
              .backgroundColor('#1a1a1a')
              .height(28)
              .borderRadius(14)
              .padding({ left: 8, right: 8 })
              .margin({ left: 6 })
              .onClick(() => { this.upload(); })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ top: 14, bottom: 10 })
        }
        .width('82%')

        if (this.entries.length === 0) {
          ArcListItem() {
            Text('暂无日志')
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 40, bottom: 40 })
          }
          .width('82%')
        }

        ForEach(this.entries, (entry: RefreshLogEntry) => {
          ArcListItem() {
            Column() {
              Row() {
                Text(entry.step)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getStepColor(entry.step))
                  .margin({ right: 6 })
                Text(this.formatTime(entry.time))
                  .fontSize(10)
                  .fontColor('#555555')
              }
              .width('100%')
              .margin({ bottom: 3 })

              Text(entry.detail)
                .fontSize(12)
                .fontColor('#CCCCCC')
                .width('100%')
                .fontFamily('monospace')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }
          .width('82%')
        }, (entry: RefreshLogEntry, index: number) => index.toString())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .focusable(true)
      .focusOnTouch(true)
      .defaultFocus(true)
      .id('refreshLogList')
      .scrollBar(BarState.Off)
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })

      ArcButton({
        options: new ArcButtonOptions({
          label: '返回',
          position: ArcButtonPosition.BOTTOM_EDGE,
          styleMode: ArcButtonStyleMode.CUSTOM,
          backgroundColor: ColorMetrics.resourceColor('#C0B8E0'),
          fontSize: new LengthMetrics(15, LengthUnit.FP),
          onClick: () => { router.back(); }
        })
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  getStepColor(step: string): string {
    if (step.startsWith('WS')) {
      return '#00FF88';
    }
    if (step.startsWith('MC')) {
      return '#4DA6FF';
    }
    if (step.startsWith('CDP')) {
      return '#C0B8E0';
    }
    return '#888888';
  }
}
