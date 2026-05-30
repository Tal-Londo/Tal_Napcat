import { ArcList, ArcListItem, LengthMetrics } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { WebSocketManager, WsLogEntry, WsEventType } from '../model/WebSocketManager';
import { WsState } from '../model/OneBotModel';

@CustomDialog
struct UploadIpDialog {
  controller: CustomDialogController;
  onConfirm: (ip: string) => void = () => {};

  @State ipText: string = '';

  build() {
    Column() {
      Text('上传日志到电脑')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 8, bottom: 10 })

      Text('输入服务器 IP 地址')
        .fontSize(11)
        .fontColor('#888888')
        .margin({ bottom: 6 })

      TextInput({ text: this.ipText, placeholder: '192.168.0.119' })
        .fontSize(14)
        .fontColor(Color.White)
        .placeholderColor('#555555')
        .backgroundColor('#1a1a1a')
        .width('100%')
        .height(38)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .type(InputType.Normal)
        .onChange((v: string) => { this.ipText = v; })
        .margin({ bottom: 14 })

      Row() {
        Button('取消')
          .fontSize(13)
          .fontColor('#888888')
          .backgroundColor('#2a2a2a')
          .width('42%')
          .height(36)
          .borderRadius(18)
          .onClick(() => { this.controller.close(); })

        Button('上传')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#C0B8E0')
          .width('42%')
          .height(36)
          .borderRadius(18)
          .onClick(() => {
            let ip = this.ipText.trim();
            if (ip === '') {
              promptAction.showToast({ message: '请输入 IP 地址' });
              return;
            }
            this.onConfirm(ip);
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#1a1a1a')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct DebugPage {
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  @State entries: WsLogEntry[] = [];
  @State wsState: WsState = WsState.DISCONNECTED;
  @State totalCount: number = 0;
  @State uploading: boolean = false;
  @State uploadDone: boolean = false;
  listScroller: Scroller = new Scroller();
  private refreshTimer: number = -1;

  uploadDialogController: CustomDialogController = new CustomDialogController({
    builder: UploadIpDialog({
      onConfirm: (ip: string) => {
        this.doUpload(ip);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    this.wsState = this.wsManager.getState();
    this.entries = [...this.wsManager.getLogEntries()];
    this.wsManager.onLogUpdate = () => {
      this.entries = [...this.wsManager.getLogEntries()];
      this.totalCount = this.entries.length;
    };
    this.wsManager.onStateChange = (state: WsState) => {
      this.wsState = state;
    };
    this.totalCount = this.entries.length;
    this.refreshTimer = setInterval(() => {
      this.entries = [...this.wsManager.getLogEntries()];
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  getStateColor(): string {
    switch (this.wsState) {
      case WsState.CONNECTED:
        return '#00FF88';
      case WsState.CONNECTING:
        return '#FFB347';
      default:
        return '#FF6666';
    }
  }

  getStateText(): string {
    switch (this.wsState) {
      case WsState.CONNECTED:
        return '已连接';
      case WsState.CONNECTING:
        return '连接中';
      default:
        return '未连接';
    }
  }

  clearLog(): void {
    this.wsManager.clearLog();
    this.entries = [];
    this.totalCount = 0;
    this.uploadDone = false;
  }

  openUploadDialog(): void {
    if (this.entries.length === 0) {
      promptAction.showToast({ message: '暂无日志可上传' });
      return;
    }
    this.uploadDialogController.open();
  }

  doUpload(ip: string): void {
    this.uploading = true;
    this.uploadDone = false;

    // 构建完整日志数据
    let logItems: Record<string, Object>[] = [];
    // entries 是倒序的（最新在前），发送时正序
    let cloned = [...this.entries];
    cloned.reverse();
    for (let e of cloned) {
      let item: Record<string, Object> = {
        'id': e.id,
        'type': e.getTypeLabel(),
        'message': e.message,
        'time': e.timestamp
      };
      logItems.push(item);
    }

    let logData: Record<string, Object> = {
      'app': 'NapcatWatch',
      'version': '1.0.0',
      'uploadTime': Date.now(),
      'connectionState': this.getStateText(),
      'total': logItems.length,
      'logs': logItems
    };

    let url = 'http://' + ip + ':8899/upload';

    let httpReq = http.createHttp();
    httpReq.request(url, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify(logData),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 15000
    }, (err, data) => {
      this.uploading = false;
      if (err) {
        promptAction.showToast({ message: '失败: ' + err.message });
        return;
      }
      let body: string;
      if (data !== null && data !== undefined) {
        body = data.result as string;
      } else {
        body = '';
      }
      try {
        let obj = JSON.parse(body) as Record<string, Object>;
        if (obj['status'] === 'ok') {
          this.uploadDone = true;
          promptAction.showToast({ message: '已上传 ' + logItems.length.toString() + ' 条' });
        } else {
          promptAction.showToast({ message: '服务器拒绝' });
        }
      } catch (_e) {
        promptAction.showToast({ message: '已收到响应' });
      }
    });
  }

  formatTime(timestamp: number): string {
    let date = new Date(timestamp);
    let h = date.getHours().toString().padStart(2, '0');
    let m = date.getMinutes().toString().padStart(2, '0');
    let s = date.getSeconds().toString().padStart(2, '0');
    let ms = date.getMilliseconds().toString().padStart(3, '0');
    return `${h}:${m}:${s}.${ms}`;
  }

  build() {
    ArcList({ scroller: this.listScroller }) {
      ArcListItem() {
        Column() {
          Row() {
            Text('WebSocket Debug')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ right: 10 })
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontColor(['#FF6666'])
                .fontSize(16)
            }
            .width(36)
            .height(36)
            .onClick(() => {
              this.clearLog();
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 6 })

          Row() {
            Circle({ width: 8, height: 8 })
              .fill(this.getStateColor())
              .margin({ right: 4 })
            Text(this.getStateText())
              .fontSize(12)
              .fontColor(this.getStateColor())
              .margin({ right: 10 })
            Text(`共 ${this.totalCount} 条`)
              .fontSize(12)
              .fontColor('#888888')
              .margin({ right: 10 })
            Text('底部最新')
              .fontSize(10)
              .fontColor('#666666')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 4 })

          Row() {
            Text('●收')
              .fontSize(10)
              .fontColor('#00FF88')
              .margin({ right: 6 })
            Text('●发')
              .fontSize(10)
              .fontColor('#FFB347')
              .margin({ right: 6 })
            Text('●态')
              .fontSize(10)
              .fontColor('#4DA6FF')
              .margin({ right: 6 })
            Text('●错')
              .fontSize(10)
              .fontColor('#FF6666')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 6 })

          Row() {
            Button('快速测试')
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor('#2a2a2a')
              .width(70)
              .height(32)
              .borderRadius(10)
              .margin({ right: 4 })
              .onClick(() => {
                let req: Record<string, Object> = { 'action': 'get_login_info' };
                this.wsManager.sendRequest(req);
              })
            Button('断开')
              .fontSize(12)
              .fontColor('#FF6666')
              .backgroundColor('#2a2a2a')
              .width(50)
              .height(32)
              .borderRadius(10)
              .margin({ right: 4 })
              .onClick(() => {
                this.wsManager.disconnect();
              })
            Button(this.uploading ? '上传中' : (this.uploadDone ? '已上传' : '上传日志'))
              .fontSize(12)
              .fontColor(this.uploading ? '#888888' : (this.uploadDone ? '#C0B8E0' : '#00FF88'))
              .backgroundColor('#2a2a2a')
              .width(70)
              .height(32)
              .borderRadius(10)
              .onClick(() => {
                if (!this.uploading) { this.openUploadDialog(); }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 12, bottom: 6, left: 8, right: 8 })
      }
      .width('84%')

      if (this.entries.length === 0) {
        ArcListItem() {
          Column() {
            Text('等待事件...')
              .fontSize(14)
              .fontColor('#666666')
            Text('连接服务器后此处将显示实时日志')
              .fontSize(11)
              .fontColor('#444444')
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 40, bottom: 40 })
        }
        .width('84%')
      }

      ForEach(this.entries, (entry: WsLogEntry, index: number) => {
        ArcListItem() {
          Column() {
            Row() {
              Text(entry.getTypeLabel())
                .fontSize(10)
                .fontColor(entry.getTypeColor())
                .fontWeight(FontWeight.Bold)
                .backgroundColor(this.hexToRgba(entry.getTypeColor(), 0.2))
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .margin({ right: 6 })
              Text(`#${entry.id}`)
                .fontSize(10)
                .fontColor('#555555')
                .margin({ right: 6 })
              Text(this.formatTime(entry.timestamp))
                .fontSize(10)
                .fontColor('#555555')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 4 })

            Text(entry.message)
              .fontSize(12)
              .fontColor('#CCCCCC')
              .width('100%')
              .textAlign(TextAlign.Center)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontFamily('monospace')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 8, left: 8, right: 8 })
          .border({
            width: { bottom: 0.5 },
            color: '#1a1a1a'
          })
        }
        .width('84%')
        .autoScale(false)
      }, (entry: WsLogEntry) => entry.id.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .space(LengthMetrics.vp(1))
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .groupDefaultFocus(true)
    .id('arcListDebug')
    .scrollBar(BarState.Off)
    .padding({ left: 8, right: 8 })
  }

  hexToRgba(hex: string, alpha: number): string {
    let r: number = 0;
    let g: number = 0;
    let b: number = 0;
    if (hex.length === 7) {
      r = parseInt(hex.substring(1, 3), 16);
      g = parseInt(hex.substring(3, 5), 16);
      b = parseInt(hex.substring(5, 7), 16);
    }
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}
