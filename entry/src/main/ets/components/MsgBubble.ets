import { CachedMessage } from '../model/ChatStore';
import { CacheManager, CacheType } from '../model/CacheManager';
import { FaceStore } from '../model/FaceStore';
import { router } from '@kit.ArkUI';

class MsgSegment {
  type: string = 'text';
  text: string = '';
  url: string = '';
  cachedPath: string = '';
  qq: string = '';
  faceId: string = '';
  fileName: string = '';
  replyId: string = '';
}

@Component
export struct MsgBubble {
  @Prop msg: CachedMessage;
  @Prop selfId: number;
  @Prop showTime: boolean = false;
  @Prop allMediaUrls: string[] = [];
  @Prop allMessages: CachedMessage[] = [];
  onLongPress?: (msg: CachedMessage) => void;

  isSelf(): boolean {
    return this.msg.isSelf;
  }

  getTimeStr(): string {
    let d = new Date(this.msg.timestamp);
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    return h + ':' + m;
  }

  getTimeLineStr(): string {
    let d = new Date(this.msg.timestamp);
    let now = new Date();
    let days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    if (d.toDateString() === now.toDateString()) {
      return '';
    }
    let yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (d.toDateString() === yesterday.toDateString()) {
      let h = d.getHours().toString().padStart(2, '0');
      let min = d.getMinutes().toString().padStart(2, '0');
      return '昨天 ' + h + ':' + min;
    }
    let dayDiff = Math.floor((now.getTime() - d.getTime()) / 86400000);
    if (dayDiff < 7 && d.getDay() !== now.getDay()) {
      let h = d.getHours().toString().padStart(2, '0');
      let min = d.getMinutes().toString().padStart(2, '0');
      return days[d.getDay()] + ' ' + h + ':' + min;
    }
    let mon = (d.getMonth() + 1).toString();
    let day = d.getDate().toString();
    let h = d.getHours().toString().padStart(2, '0');
    let min = d.getMinutes().toString().padStart(2, '0');
    return mon + '/' + day + ' ' + h + ':' + min;
  }

  getAvatarColor(name: string): string {
    let colors: string[] = ['#C0B8E0', '#FFB347', '#4DA6FF', '#00CC88', '#FF7777', '#77BBFF'];
    let sum = 0;
    for (let i = 0; i < name.length; i++) {
      sum += name.charCodeAt(i);
    }
    return colors[sum % colors.length];
  }

  getInitial(name: string): string {
    if (name.length > 0) {
      return name.charAt(0);
    }
    return '?';
  }

  getAvatarUrl(): string {
    return 'https://q1.qlogo.cn/g?b=qq&nk=' + this.msg.userId + '&s=100';
  }

  openMediaViewer(url: string, type: string): void {
    let idx = this.allMediaUrls.indexOf(url);
    if (idx < 0) {
      idx = 0;
    }
    let urlsStr = JSON.stringify(this.allMediaUrls);
    router.pushUrl({
      url: 'pages/MediaViewerPage',
      params: {
        mediaUrls: urlsStr,
        currentIndex: idx,
        mediaType: type
      }
    });
  }

  getQuotedMsg(replyId: string): string {
    let idNum = parseInt(replyId);
    if (isNaN(idNum)) {
      return '';
    }
    for (let m of this.allMessages) {
      if (m.messageId === idNum) {
        return m.nickname + ': ' + (m.rawMessage || '[消息]');
      }
    }
    return '';
  }

  getAtColor(qq: string): string {
    if (qq === 'all' || parseInt(qq) === this.selfId) {
      return '#FFB347';
    }
    return '#4DA6FF';
  }

  getAtName(seg: MsgSegment): string {
    if (seg.qq === 'all') {
      return '@全体成员';
    }
    if (seg.text !== '') {
      return '@' + seg.text;
    }
    return '@' + seg.qq;
  }

  getFaceEmoji(faceId: string): string {
    return FaceStore.getFace(parseInt(faceId) || 0);
  }

  getSegments(): MsgSegment[] {
    let result: MsgSegment[] = [];
    try {
      let arr = JSON.parse(this.msg.content || '[]') as Object[];
      if (!arr || arr.length === 0) {
        let seg = new MsgSegment();
        seg.text = this.msg.rawMessage || '';
        result.push(seg);
        return result;
      }
      for (let item of arr) {
        let s = new MsgSegment();
        let obj = item as Record<string, Object>;
        s.type = obj['type'] as string || 'text';
        let data = obj['data'] as Record<string, Object>;
        if (data !== undefined && data !== null) {
          s.text = data['text'] as string || '';
          s.url = data['url'] as string || data['file'] as string || '';
          if (s.url !== '') {
            let cache = CacheManager.getInstance();
            let key = cache.makeKey(s.url, s.type === 'image' ? CacheType.IMAGE : CacheType.STICKER);
            s.cachedPath = cache.getPath(key);
          }
          s.qq = data['qq'] as string || '';
          s.faceId = data['id'] as string || '';
          s.fileName = data['name'] as string || '';
          s.replyId = data['id'] as string || '';
        }
        result.push(s);
      }
    } catch (_e) {
      let seg = new MsgSegment();
      seg.text = this.msg.rawMessage || '';
      result.push(seg);
    }
    return result;
  }

  build() {
    Column() {
      if (this.showTime && this.getTimeLineStr() !== '') {
        Text(this.getTimeLineStr())
          .fontSize(10)
          .fontColor('#555555')
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 10, bottom: 6 })
      }

      Row() {
        if (this.isSelf()) {
          Blank()
        }

        if (!this.isSelf()) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.getInitial(this.msg.nickname || ''))
              .fontSize(12)
              .fontColor(Color.White)
            Image(this.getAvatarUrl())
              .width(30)
              .height(30)
              .borderRadius(15)
              .objectFit(ImageFit.Cover)
          }
          .width(30)
          .height(30)
          .borderRadius(15)
          .backgroundColor(this.getAvatarColor(this.msg.nickname || ''))
          .clip(true)
          .margin({ right: 6, top: 10 })
        }

        Column() {
          if (!this.isSelf()) {
            Text(this.msg.nickname || ('用户' + this.msg.userId))
              .fontSize(10)
              .fontColor('#888888')
              .maxLines(1)
              .margin({ bottom: 2, left: 2 })
          }

          Column() {
            ForEach(this.getSegments(), (seg: MsgSegment, i: number) => {
              if (seg.type === 'text') {
                Text(seg.text || '')
                  .fontSize(13)
                  .fontColor(this.isSelf() ? '#111111' : '#EEEEEE')
                  .wordBreak(WordBreak.BREAK_ALL)
              }
              if (seg.type === 'image') {
                if (seg.url !== '') {
                  if (seg.cachedPath !== '') {
                    Image('file://' + seg.cachedPath)
                      .width(120)
                      .height(120)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(8)
                      .margin({ top: 2, bottom: 2 })
                      .onClick(() => { this.openMediaViewer(seg.url, 'image'); })
                  } else {
                    Image(seg.url)
                      .width(120)
                      .height(120)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(8)
                      .margin({ top: 2, bottom: 2 })
                      .onClick(() => { this.openMediaViewer(seg.url, 'image'); })
                  }
                } else {
                  Text('[图片]')
                    .fontSize(12)
                    .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
                }
              }
              if (seg.type === 'face') {
                if (this.getFaceEmoji(seg.faceId) !== '') {
                  Text(this.getFaceEmoji(seg.faceId))
                    .fontSize(20)
                    .margin({ left: 1, right: 1 })
                } else {
                  Text('[表情' + (seg.faceId !== '' ? ':' + seg.faceId : '') + ']')
                    .fontSize(12)
                    .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
                }
              }
              if (seg.type === 'at') {
                Text(this.getAtName(seg) + ' ')
                  .fontSize(13)
                  .fontColor(this.getAtColor(seg.qq))
                  .fontWeight(FontWeight.Bold)
              }
              if (seg.type === 'reply') {
                if (this.getQuotedMsg(seg.replyId) !== '') {
                  Text(this.getQuotedMsg(seg.replyId))
                    .fontSize(11)
                    .fontColor(this.isSelf() ? '#555555' : '#888888')
                    .fontStyle(FontStyle.Italic)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '95%' })
                    .borderWidth({ left: 3 })
                    .borderColor(this.isSelf() ? '#777777' : '#888888')
                    .padding({ left: 6, top: 2, bottom: 2 })
                    .margin({ bottom: 3 })
                } else {
                  Text('[回复]')
                    .fontSize(11)
                    .fontColor(this.isSelf() ? '#555555' : '#888888')
                    .fontStyle(FontStyle.Italic)
                    .padding({ bottom: 2 })
                }
              }
              if (seg.type === 'record') {
                Text('[语音]')
                  .fontSize(12)
                  .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
              }
              if (seg.type === 'video') {
                Text('[视频]')
                  .fontSize(12)
                  .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
                  .onClick(() => { this.openMediaViewer(seg.url || 'video_placeholder', 'video'); })
              }
              if (seg.type === 'file') {
                Text(seg.fileName || '[文件]')
                  .fontSize(12)
                  .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
              }
            }, (_seg: MsgSegment, i: number) => i.toString())
          }
          .borderRadius(12)
          .backgroundColor(this.isSelf() ? '#C0B8E0' : '#2a2a2a')
          .constraintSize({ maxWidth: '60%' })
          .align(Alignment.Start)
          .clip(true)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction(() => {
                if (this.onLongPress) {
                  this.onLongPress(this.msg);
                }
              })
          )

          Text(this.getTimeStr())
            .fontSize(10)
            .fontColor('#555555')
            .margin({ top: 2, left: 4 })
        }
        .alignItems(this.isSelf() ? HorizontalAlign.End : HorizontalAlign.Start)

        if (!this.isSelf()) {
          Blank()
        }
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(this.isSelf() ? HorizontalAlign.End : HorizontalAlign.Start)
  }
}
