import { router } from '@kit.ArkUI';
import { ChatStore, CachedMessage } from '../model/ChatStore';
import { OneBotRequest } from '../model/OneBotModel';
import { WebSocketManager } from '../model/WebSocketManager';
import { RefreshLogger } from '../model/RefreshLogger';
import { stripCQCode } from '../model/MessageFormatter';

class FwdSubMsg {
  senderName: string = '';
  timeStr: string = '';
  segments: string[] = [];
}

@Entry
@Component
struct ForwardDetailPage {
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  @State title: string = '合并转发';
  @State subCount: number = 0;
  @State items: FwdSubMsg[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  forwardId: string = '';
  contentRaw: string = '';

  aboutToAppear(): void {
    let params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      this.forwardId = params['forward_id'] as string || '';
      this.contentRaw = params['content'] as string || '';
    }
    // 优先用内嵌 content 解析
    if (this.contentRaw !== '') {
      this.parseContent(this.contentRaw);
    } else if (this.forwardId !== '') {
      this.fetchForward();
    } else {
      this.error = '无转发数据';
      this.loading = false;
    }
  }

  parseContent(raw: string): void {
    try {
      let arr = JSON.parse(raw) as Object[];
      this.renderMessages(arr);
    } catch (_e) {
      this.error = '解析失败';
      this.loading = false;
    }
  }

  fetchForward(): void {
    RefreshLogger.getInstance().log('FWD-FETCH', 'id=' + this.forwardId);
    let req = OneBotRequest.createGetForwardMsg(this.forwardId);
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode !== 0) {
        RefreshLogger.getInstance().log('FWD-FAIL', 'retcode=' + retcode);
        this.error = '获取转发消息失败 (retcode=' + retcode + ')';
        this.loading = false;
        return;
      }
      let inner = data['data'] as Record<string, Object> || {};
      let msgArr = inner['messages'] as Object[];
      if (msgArr !== undefined && msgArr.length > 0) {
        RefreshLogger.getInstance().log('FWD-OK', 'got ' + msgArr.length + ' messages');
        this.renderMessages(msgArr);
      } else {
        this.error = '转发消息为空';
        this.loading = false;
      }
    });
  }

  renderMessages(msgArr: Object[]): void {
    let result: FwdSubMsg[] = [];
    for (let item of msgArr) {
      let obj = item as Record<string, Object>;
      let fm = new FwdSubMsg();
      let sender = obj['sender'] as Record<string, Object> || {};
      fm.senderName = (sender['card'] as string) || (sender['nickname'] as string) || String(sender['user_id'] || '');
      let t = parseInt(String(obj['time'] || '0'));
      if (t > 0) {
        let d = new Date(t * 1000);
        fm.timeStr = (d.getMonth()+1).toString() + '/' + d.getDate().toString() + ' ' +
          d.getHours().toString().padStart(2,'0') + ':' + d.getMinutes().toString().padStart(2,'0');
      }
      let segs = obj['message'] as Object[];
      if (segs !== undefined) {
        for (let seg of segs) {
          let s = seg as Record<string, Object>;
          let t = s['type'] as string || '';
          let d = s['data'] as Record<string, Object> || {};
          if (t === 'text') {
            fm.segments.push((d['text'] as string) || '');
          } else if (t === 'image') {
            fm.segments.push('[图片]');
          } else if (t === 'face') {
            fm.segments.push('[表情]');
          } else if (t === 'at') {
            fm.segments.push('@' + (d['qq'] || ''));
          } else if (t === 'record') {
            fm.segments.push('[语音]');
          } else if (t === 'video') {
            fm.segments.push('[视频]');
          } else if (t === 'file') {
            fm.segments.push('[文件]');
          } else if (t === 'reply') {
            fm.segments.push('[回复]');
          } else if (t === 'forward') {
            fm.segments.push('[聊天记录]');
          }
        }
      }
      result.push(fm);
    }
    this.items = result;
    this.subCount = result.length;
    this.loading = false;
  }

  build() {
    Column() {
      Row() {
        Text('合并转发 (' + this.subCount + '条)')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
        Text('关闭')
          .fontSize(12)
          .fontColor('#C0B8E0')
          .onClick(() => { router.back(); })
      }
      .width('90%')
      .padding({ top: 10, bottom: 10 })

      if (this.loading) {
        LoadingProgress()
          .width(30)
          .height(30)
          .color('#C0B8E0')
          .margin({ top: 20 })
        Text('加载中...')
          .fontSize(12)
          .fontColor('#888888')
          .margin({ top: 8 })
      }

      if (this.error !== '') {
        Text(this.error)
          .fontSize(13)
          .fontColor('#FF6666')
          .margin({ top: 20 })
        Button('重试')
          .margin({ top: 10 })
          .fontSize(12)
          .fontColor('#C0B8E0')
          .onClick(() => {
            this.loading = true;
            this.error = '';
            this.fetchForward();
          })
      }

      if (this.items.length > 0) {
        List() {
          ForEach(this.items, (fm: FwdSubMsg, i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Text(fm.senderName)
                    .fontSize(12)
                    .fontColor('#C0B8E0')
                    .maxLines(1)
                  Blank()
                  Text(fm.timeStr)
                    .fontSize(10)
                    .fontColor('#666666')
                }
                .width('100%')

                Text(fm.segments.join(''))
                  .fontSize(13)
                  .fontColor('#CCCCCC')
                  .wordBreak(WordBreak.BREAK_ALL)
                  .margin({ top: 4 })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8, left: 6, right: 6 })
              .borderRadius(8)
              .backgroundColor('#1a1a1a')
            }
            .width('88%')
            .margin({ bottom: 6 })
          }, (_fm: FwdSubMsg, i: number) => i.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 6, right: 6 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
