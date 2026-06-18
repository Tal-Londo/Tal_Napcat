import { CachedMessage, ChatStore, GroupMember } from '../model/ChatStore';
import { CacheManager, CacheType } from '../model/CacheManager';
import { FaceStore } from '../model/FaceStore';
import { OneBotRequest } from '../model/OneBotModel';
import { stripCQCode } from '../model/MessageFormatter';
import { RefreshLogger } from '../model/RefreshLogger';
import { WebSocketManager } from '../model/WebSocketManager';
import { router } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';
import http from '@ohos.net.http';

class MsgSegment {
  type: string = 'text';
  text: string = '';
  url: string = '';
  subType: number = 0;  // 0=normal, 1=animated sticker
  cachedPath: string = '';
  qq: string = '';
  faceId: string = '';
  fileName: string = '';
  replyId: string = '';
  recordFile: string = '';
  videoFile: string = '';       // video file path from data
  videoThumb: string = '';      // video thumbnail URL from data
  forwardId: string = '';       // forward message ID
  forwardContent: string = '';  // JSON array of sub-messages
}

@Component
export struct MsgBubble {
  @Prop msg: CachedMessage;
  @Prop selfId: number;
  @Prop showTime: boolean = false;
  @Prop allMediaUrls: string[] = [];
  @Prop allMessages: CachedMessage[] = [];
  @Prop groupPeerId: number = 0;
  onLongPress?: (msg: CachedMessage) => void;
  onSwipeReply?: (msg: CachedMessage) => void;
  onReplyTap?: (messageId: number) => void;
  @State voicePlaying: boolean = false;
  @State voiceLoading: boolean = false;
  @State stickerCacheVersion: number = 0;
  private avPlayer: media.AVPlayer | null = null;
  private voiceFd: number = -1;

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
    // allMediaUrls format: "type|url" (e.g. "image|http://..." or "video|http://...")
    let urls: string[] = [];
    let types: string[] = [];
    let matchIdx = -1;
    for (let i = 0; i < this.allMediaUrls.length; i++) {
      let item = this.allMediaUrls[i];
      let sep = item.indexOf('|');
      let itemType = item.substring(0, sep);
      let itemUrl = item.substring(sep + 1);
      urls.push(itemUrl);
      types.push(itemType);
      if (matchIdx < 0 && url !== '' && itemUrl === url) {
        matchIdx = i;
      }
    }
    if (matchIdx < 0) {
      // fallback: find by current type
      for (let i = 0; i < types.length; i++) {
        if (types[i] === type && matchIdx < 0) {
          matchIdx = i;
        }
      }
      if (matchIdx < 0) { matchIdx = 0; }
    }
    router.pushUrl({
      url: 'pages/MediaViewerPage',
      params: {
        mediaUrls: JSON.stringify(urls),
        mediaTypes: JSON.stringify(types),
        currentIndex: matchIdx,
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
        return m.nickname + ': ' + stripCQCode(m.rawMessage || '[消息]');
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

  openProfile(): void {
    if (this.groupPeerId > 0) {
      router.pushUrl({
        url: 'pages/ProfilePage',
        params: {
          type: 'member',
          peerId: this.msg.userId,
          peerName: this.msg.nickname,
          groupId: this.groupPeerId,
          userId: this.msg.userId
        }
      });
    } else {
      router.pushUrl({
        url: 'pages/ProfilePage',
        params: {
          type: 'private',
          peerId: this.msg.userId,
          peerName: this.msg.nickname,
          userId: this.msg.userId
        }
      });
    }
  }

  getAtName(seg: MsgSegment): string {
    if (seg.qq === 'all') {
      return '@全体成员';
    }
    if (seg.text !== '') {
      return '@' + seg.text;
    }
    // 尝试从群成员缓存查找昵称
    if (this.groupPeerId > 0) {
      let member = ChatStore.getInstance().getGroupMember(this.groupPeerId, parseInt(seg.qq));
      if (member !== null) {
        return '@' + member.getDisplayName();
      }
    }
    return '@' + seg.qq;
  }

  getRoleBadge(): string {
    let role = this.msg.senderRole || '';
    if (role === 'owner') {
      return '群主';
    }
    if (role === 'admin') {
      return '管理员';
    }
    return '';
  }

  getRoleBadgeColor(): string {
    let role = this.msg.senderRole || '';
    if (role === 'owner') {
      return '#FFB347';
    }
    if (role === 'admin') {
      return '#00CC88';
    }
    return '';
  }

  getSenderTitle(): string {
    if (this.msg.senderRole === '' || this.msg.senderRole === 'member') {
      if (this.groupPeerId > 0) {
        let member = ChatStore.getInstance().getGroupMember(this.groupPeerId, this.msg.userId);
        if (member !== null && member.title !== '') {
          return member.title;
        }
      }
    }
    return '';
  }

  getFaceEmoji(faceId: string): string {
    return FaceStore.getFace(parseInt(faceId) || 0);
  }

  getFaceImageUrl(faceId: string): string {
    return '';
  }

  getFaceResource(faceId: string): Resource {
    return $rawfile('face/' + faceId + '.png');
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
          s.subType = parseInt(String(data['sub_type'] || '0')) || 0;
          s.faceId = data['id'] as string || '';
          s.fileName = data['name'] as string || '';
          s.replyId = data['id'] as string || '';
          if (s.type === 'record') {
            s.recordFile = data['file'] as string || '';
            s.url = data['url'] as string || '';
            // 缓存语音 base64 结果（避免重复请求 get_record）
            s.cachedPath = this.getVoiceCache(s.recordFile);
          }
          if (s.type === 'video') {
            s.videoFile = data['file'] as string || data['url'] as string || '';
            s.videoThumb = data['thumb'] as string || '';
            // 缩略图尝试从缓存加载
            if (s.videoThumb !== '' && s.videoThumb.startsWith('http')) {
              let cache = CacheManager.getInstance();
              let key = cache.makeKey(s.videoThumb, CacheType.IMAGE);
              s.cachedPath = cache.getPath(key);
            }
          }
          if (s.type === 'forward') {
            s.forwardId = data['id'] as string || '';
            let content = data['content'];
            if (content !== undefined && content !== null) {
              s.forwardContent = JSON.stringify(content);
            }
          }
        }
        result.push(s);
      }
      let faceCount = 0;
      let uncached: string[] = [];
      for (let seg of result) {
        if (seg.type === 'face') { faceCount++; }
        if (seg.subType === 1 && seg.url !== '' && seg.cachedPath === '') {
          uncached.push(seg.url);
        }
      }
      if (faceCount > 0) {
        RefreshLogger.getInstance().log('APNG-PARSE', 'face segments: ' + faceCount + ' of ' + result.length + ' total');
      }
      if (uncached.length > 0) {
        let urls = new Array<string>(uncached.length);
        for (let i = 0; i < uncached.length; i++) { urls[i] = uncached[i]; }
        setTimeout(() => {
          for (let u of urls) { this.downloadStickerToCache(u); }
        }, 100);
      }
    } catch (_e) {
      let seg = new MsgSegment();
      seg.text = this.msg.rawMessage || '';
      result.push(seg);
    }
    return result;
  }

  getVoiceCache(fileUuid: string): string {
    if (fileUuid === '') { return ''; }
    let cache = CacheManager.getInstance();
    let key = cache.makeKey(fileUuid, CacheType.STICKER);
    return cache.getPath(key);
  }

  saveVoiceCache(fileUuid: string, data: ArrayBuffer): void {
    if (fileUuid === '' || data.byteLength === 0) { return; }
    let cache = CacheManager.getInstance();
    let key = cache.makeKey(fileUuid, CacheType.STICKER);
    cache.save(key, CacheType.STICKER, data);
    RefreshLogger.getInstance().log('VOICE-CACHED', 'uuid=' + fileUuid.substring(0,30) + ' size=' + data.byteLength);
  }

  async downloadStickerToCache(url: string): Promise<string> {
    try {
      let cache = CacheManager.getInstance();
      let key = cache.makeKey(url, CacheType.STICKER);
      let existingPath = cache.getPath(key);
      if (existingPath !== '') {
        return existingPath;
      }
      let httpRequest: http.HttpRequest = http.createHttp();
      let chunks: Array<ArrayBuffer> = new Array<ArrayBuffer>();
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        chunks.push(data);
      });
      let resultCode: number = await httpRequest.requestInStream(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        usingCache: false
      }).catch((_err: Error) => {
        httpRequest.destroy();
        return -1;
      }) as number;
      httpRequest.destroy();
      if (resultCode !== 200 || chunks.length === 0) {
        return '';
      }
      let totalLen = 0;
      for (let ab of chunks) { totalLen += ab.byteLength; }
      let combined = new ArrayBuffer(totalLen);
      let view = new Uint8Array(combined);
      let offset = 0;
      for (let ab of chunks) {
        view.set(new Uint8Array(ab), offset);
        offset += ab.byteLength;
      }
      let path = cache.save(key, CacheType.STICKER, combined);
      RefreshLogger.getInstance().log('STICKER-CACHED', 'url=' + url.substring(0,40) + ' size=' + totalLen);
      this.stickerCacheVersion++;
      return path;
    } catch (_e) {
      return '';
    }
  }

  toggleVoicePlay(seg: MsgSegment): void {
    if (this.voicePlaying) {
      this.stopVoice();
      return;
    }
    if (this.voiceLoading) {
      return;
    }
    if (this.voiceFd >= 0) {
      this.doPlayFromFd(this.voiceFd);
      return;
    }
    let file = seg.recordFile;
    if (file === '') {
      RefreshLogger.getInstance().log('VOICE-NOURL', 'no recordFile');
      return;
    }
    // 检查缓存
    let cached = this.getVoiceCache(file);
    if (cached !== '') {
      RefreshLogger.getInstance().log('VOICE-CACHEHIT', 'cached file=' + cached.substring(0,60));
      let fd = fileIo.openSync(cached, fileIo.OpenMode.READ_ONLY);
      this.voiceFd = fd.fd;
      this.voiceLoading = true;
      this.doPlayFromFd(fd.fd);
      return;
    }
    this.voiceLoading = true;
    RefreshLogger.getInstance().log('VOICE-GETREC', 'req file=' + file);
    let wsm = WebSocketManager.getInstance();
    let req = OneBotRequest.createGetRecord(file, 'mp3');
    wsm.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let retcode = data['retcode'] as number ?? 1;
      let inner = data['data'] as Record<string, Object> || {};
      let b64 = inner['base64'] as string || '';
      RefreshLogger.getInstance().log('VOICE-GETREC-RSP', 'rc=' + retcode + ' b64len=' + b64.length);
      if (b64 !== '') {
        this.saveAndPlayBase64(b64, file);
      } else {
        this.voiceLoading = false;
        RefreshLogger.getInstance().log('VOICE-NOPLAY', 'no base64 from get_record');
      }
    });
  }

  saveAndPlayBase64(b64: string, fileUuid?: string): void {
    try {
      let buf = buffer.from(b64, 'base64');
      let cacheFile = '/data/storage/el2/base/cache/voice_' + Date.now() + '.mp3';
      let file = fileIo.openSync(cacheFile, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, buf.buffer);
      fileIo.closeSync(file);
      RefreshLogger.getInstance().log('VOICE-SAVED', 'size=' + buf.length + ' path=' + cacheFile);
      // 写入长期缓存
      if (fileUuid !== undefined && fileUuid !== '') {
        this.saveVoiceCache(fileUuid, buf.buffer);
      }
      let fd = fileIo.openSync(cacheFile, fileIo.OpenMode.READ_ONLY);
      let fdNum = fd.fd;
      RefreshLogger.getInstance().log('VOICE-FD', 'opened fd=' + fdNum);
      this.voiceFd = fdNum;
      this.doPlayFromFd(fdNum);
    } catch (e) {
      this.voiceLoading = false;
      RefreshLogger.getInstance().log('VOICE-SAVE-ERR', 'save failed: ' + (e as Error).message);
    }
  }

  doPlayFromFd(fd: number): void {
    RefreshLogger.getInstance().log('VOICE-PLAY', 'playing from fd=' + fd);
    try {
      if (this.avPlayer !== null) {
        this.avPlayer.release();
      }
      media.createAVPlayer().then((player: media.AVPlayer) => {
        this.avPlayer = player;
        let prepared = false;
        player.on('stateChange', (state: string) => {
          RefreshLogger.getInstance().log('VOICE-STATE', 'state=' + state);
          if (state === 'initialized' && !prepared) {
            prepared = true;
            player.prepare().then(() => {
              RefreshLogger.getInstance().log('VOICE-PREPARED', 'prepare OK, playing');
              player.play();
              this.voicePlaying = true;
              this.voiceLoading = false;
            }).catch((err: Error) => {
              RefreshLogger.getInstance().log('VOICE-PREP-ERR', 'prepare failed: ' + (err.message || 'unknown'));
              this.voicePlaying = false;
              this.voiceLoading = false;
            });
          }
          if (state === 'stopped' || state === 'completed') {
            this.voicePlaying = false;
          }
        });
        player.on('error', () => {
          RefreshLogger.getInstance().log('VOICE-ERR', 'AVPlayer error callback');
          this.voicePlaying = false;
          this.voiceLoading = false;
        });
        // AVPlayer 需要 fd:// 协议而不是 file://
        player.url = 'fd://' + fd;
      }).catch((err: Error) => {
        RefreshLogger.getInstance().log('VOICE-CREATE-ERR', 'createAVPlayer failed: ' + (err.message || 'unknown'));
        this.voicePlaying = false;
        this.voiceLoading = false;
      });
    } catch (e) {
      RefreshLogger.getInstance().log('VOICE-CATCH', 'exception: ' + (e as Error).message);
      this.voicePlaying = false;
      this.voiceLoading = false;
    }
  }

  startVoicePlay(pathOrUrl: string): void {
    RefreshLogger.getInstance().log('VOICE-PLAY', 'start url=' + pathOrUrl);
    try {
      if (this.avPlayer !== null) {
        this.avPlayer.release();
      }
      media.createAVPlayer().then((player: media.AVPlayer) => {
        this.avPlayer = player;
        let prepared = false;
        player.on('stateChange', (state: string) => {
          RefreshLogger.getInstance().log('VOICE-STATE', 'state=' + state);
          // url 设置后异步进入 initialized，此时才能 prepare
          if (state === 'initialized' && !prepared) {
            prepared = true;
            player.prepare().then(() => {
              RefreshLogger.getInstance().log('VOICE-PREPARED', 'prepare OK, playing');
              player.play();
              this.voicePlaying = true;
            }).catch((err: Error) => {
              RefreshLogger.getInstance().log('VOICE-PREP-ERR', 'prepare failed: ' + (err.message || 'unknown'));
              this.voicePlaying = false;
            });
          }
          if (state === 'stopped' || state === 'completed') {
            this.voicePlaying = false;
          }
        });
        player.on('error', () => {
          RefreshLogger.getInstance().log('VOICE-ERR', 'AVPlayer error callback');
          this.voicePlaying = false;
        });
        player.url = pathOrUrl.startsWith('http') ? pathOrUrl : ('file://' + pathOrUrl);
      }).catch((err: Error) => {
        RefreshLogger.getInstance().log('VOICE-CREATE-ERR', 'createAVPlayer failed: ' + (err.message || 'unknown'));
        this.voicePlaying = false;
      });
    } catch (e) {
      RefreshLogger.getInstance().log('VOICE-CATCH', 'exception: ' + (e as Error).message);
      this.voicePlaying = false;
    }
  }

  stopVoice(): void {
    this.voicePlaying = false;
    if (this.avPlayer !== null) {
      try {
        this.avPlayer.release();
      } catch (_e) {
      }
      this.avPlayer = null;
    }
    if (this.voiceFd >= 0) {
      try {
        // AVPlayer 释放了 fd 后可以关闭
        setTimeout(() => {
          try { fileIo.closeSync({ fd: this.voiceFd } as fileIo.File); } catch (_e) {}
          this.voiceFd = -1;
        }, 200);
      } catch (_e) {
        this.voiceFd = -1;
      }
    }
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
          .onClick(() => { this.openProfile(); })
        }

        Column() {
          if (!this.isSelf()) {
            Row() {
              Text(this.msg.nickname || ('用户' + this.msg.userId))
                .fontSize(10)
                .fontColor('#888888')
                .maxLines(1)
              if (this.getRoleBadge() !== '') {
                Text(this.getRoleBadge())
                  .fontSize(9)
                  .fontColor(this.getRoleBadgeColor())
                  .backgroundColor(this.getRoleBadgeColor() + '22')
                  .borderRadius(3)
                  .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                  .margin({ left: 4 })
              }
              if (this.getSenderTitle() !== '') {
                Text(this.getSenderTitle())
                  .fontSize(9)
                  .fontColor('#C0B8E0')
                  .backgroundColor('#C0B8E022')
                  .borderRadius(3)
                  .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                  .margin({ left: 4 })
              }
            }
            .margin({ bottom: 2, left: 2 })
          }

          if (this.msg.isRevoked()) {
            Text('消息已被撤回')
              .fontSize(11)
              .fontColor('#888888')
              .fontStyle(FontStyle.Italic)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          } else {
            Column() {
            ForEach(this.getSegments(), (seg: MsgSegment, i: number) => {
              if (seg.type === 'text') {
                Text(seg.text || '')
                  .fontSize(13)
                  .fontColor(this.isSelf() ? '#111111' : '#EEEEEE')
                  .wordBreak(WordBreak.BREAK_ALL)
              }
              if (seg.type === 'image') {
                if (seg.subType === 1 && seg.url !== '') {
                  // 弃用 apng：动态贴图降级为静态 Image（缓存优先，点击进查看器）
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
                } else if (seg.url !== '') {
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
                // 弃用 apng：QQ 表情降级为静态 png（rawfile/face/<id>.png）
                Image(this.getFaceResource(seg.faceId))
                  .width(22)
                  .height(22)
                  .margin({ left: 1, right: 1, top: 1, bottom: 1 })
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
                    .onClick(() => {
                      if (this.onReplyTap) {
                        this.onReplyTap(parseInt(seg.replyId));
                      }
                    })
                } else {
                  Text('[回复]')
                    .fontSize(11)
                    .fontColor(this.isSelf() ? '#555555' : '#888888')
                    .fontStyle(FontStyle.Italic)
                    .padding({ bottom: 2 })
                }
              }
              if (seg.type === 'record') {
                Row() {
                  SymbolGlyph($r('sys.symbol.play_circle'))
                    .fontSize(18)
                    .fontColor([this.isSelf() ? '#333333' : '#C0B8E0'])
                  Text(this.voiceLoading ? ' 加载中...' : (this.voicePlaying ? ' 播放中' : ' 语音'))
                    .fontSize(12)
                    .fontColor(this.isSelf() ? '#333333' : '#EEEEEE')
                }
                .width('100%')
                .height(36)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .onClick(() => { this.toggleVoicePlay(seg); })
              }
              if (seg.type === 'video') {
                Column() {
                  if (seg.videoThumb !== '') {
                    Stack({ alignContent: Alignment.Center }) {
                      Image(seg.videoThumb)
                        .width(120)
                        .height(90)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(6)
                      SymbolGlyph($r('sys.symbol.play_circle'))
                        .fontSize(28)
                        .fontColor([Color.White])
                    }
                    .margin({ top: 2, bottom: 2 })
                    .onClick(() => { this.openMediaViewer(seg.url || seg.videoFile || 'video_placeholder', 'video'); })
                  } else {
                    Row() {
                      SymbolGlyph($r('sys.symbol.play_circle'))
                        .fontSize(16)
                        .fontColor([this.isSelf() ? '#333333' : '#C0B8E0'])
                      Text('视频消息')
                        .fontSize(12)
                        .fontColor(this.isSelf() ? '#333333' : '#EEEEEE')
                        .margin({ left: 4 })
                    }
                    .padding({ top: 4, bottom: 4, left: 6, right: 10 })
                    .onClick(() => { this.openMediaViewer(seg.url || seg.videoFile || 'video_placeholder', 'video'); })
                  }
                }
              }
              if (seg.type === 'file') {
                Text(seg.fileName || '[文件]')
                  .fontSize(12)
                  .fontColor(this.isSelf() ? '#555555' : '#AAAAAA')
              }
              if (seg.type === 'forward') {
                Column() {
                  Text('合并转发')
                    .fontSize(12)
                    .fontColor(this.isSelf() ? '#333333' : '#C0B8E0')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 4 })
                  Text('点击查看详情')
                    .fontSize(11)
                    .fontColor(this.isSelf() ? '#555555' : '#888888')
                }
                .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                .borderWidth(1)
                .borderColor(this.isSelf() ? '#999999' : '#555555')
                .borderRadius(6)
                .width('100%')
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/ForwardDetailPage',
                    params: {
                      forward_id: seg.forwardId,
                      content: seg.forwardContent
                    }
                  });
                })
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
            GestureGroup(GestureMode.Parallel,
              LongPressGesture({ repeat: false, duration: 500 })
                .onAction(() => {
                  if (this.onLongPress) {
                    this.onLongPress(this.msg);
                  }
                }),
              PanGesture({ direction: PanDirection.Left, distance: 30 })
                .onActionEnd((event: GestureEvent) => {
                  if (event.offsetX < -20 && this.onSwipeReply) {
                    this.onSwipeReply(this.msg);
                  }
                })
            )
          )

          Text(this.getTimeStr())
            .fontSize(10)
            .fontColor('#555555')
            .margin({ top: 2, left: 4 })
          }
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
    .onClick(() => {})
  }
}
