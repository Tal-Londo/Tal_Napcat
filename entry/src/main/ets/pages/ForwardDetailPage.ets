import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
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
          let segType = s['type'] as string || '';
          let segData = s['data'] as Record<string, Object> || {};
          if (segType === 'text') { fm.segments.push((segData['text'] as string) || ''); }
          else if (segType === 'image') { fm.segments.push('[图片]'); }
          else if (segType === 'face') { fm.segments.push('[表情]'); }
          else if (segType === 'at') { fm.segments.push('@' + (segData['qq'] || '')); }
          else if (segType === 'record') { fm.segments.push('[语音]'); }
          else if (segType === 'video') { fm.segments.push('[视频]'); }
          else if (segType === 'file') { fm.segments.push('[文件]'); }
          else if (segType === 'reply') { fm.segments.push('[回复]'); }
          else if (segType === 'forward') { fm.segments.push('[聊天记录]'); }
        }
      }
      result.push(fm);
    }
    this.items = result;
    this.subCount = result.length;
    this.loading = false;
  }

  build() {
    ArcList() {
      // 标题
      ArcListItem() {
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
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      }
      .width('82%')

      // 加载/错误
      if (this.loading) {
        ArcListItem() {
          Column() {
            LoadingProgress()
              .width(30)
              .height(30)
              .color('#C0B8E0')
            Text('加载中...')
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 20, bottom: 20 })
        }
        .width('82%')
      }

      if (this.error !== '') {
        ArcListItem() {
          Column() {
            Text(this.error)
              .fontSize(13)
              .fontColor('#FF6666')
            Button('重试')
              .margin({ top: 8 })
              .fontSize(12)
              .fontColor('#C0B8E0')
              .backgroundColor('#2a2a2a')
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.loading = true;
                this.error = '';
                this.fetchForward();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 12, bottom: 12 })
        }
        .width('82%')
      }

      // 消息列表
      ForEach(this.items, (fm: FwdSubMsg, i: number) => {
        ArcListItem() {
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
          .padding({ top: 8, bottom: 8, left: 10, right: 10 })
          .borderRadius(10)
          .backgroundColor('#1a1a1a')
        }
        .width('82%')
        .margin({ bottom: 6 })
      }, (_fm: FwdSubMsg, i: number) => i.toString())
    }
    .width('100%')
    .height('100%')
    .space(LengthMetrics.vp(4))
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .groupDefaultFocus(true)
    .id('forwardArcList')
    .scrollBar(BarState.Auto)
    .backgroundColor(Color.Black)
    .padding({ left: 12, right: 12 })
  }
}
