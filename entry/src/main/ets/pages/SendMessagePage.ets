import { router, ArcButton, ArcButtonOptions, ArcButtonStyleMode, ArcButtonPosition, LengthUnit, ColorMetrics, LengthMetrics } from '@kit.ArkUI';
import { WebSocketManager } from '../model/WebSocketManager';
import { ChatStore, CachedMessage, GroupMember } from '../model/ChatStore';
import { ConfigManager } from '../model/ConfigManager';
import { FaceStore } from '../model/FaceStore';
import { RefreshLogger } from '../model/RefreshLogger';
import { OneBotRequest } from '../model/OneBotModel';
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

class SqPlaceholder {
  key: string = '';
  segType: string = 'at';
  qq: string = '';
  name: string = '';
  faceId: string = '';
}

@Entry
@Component
struct SendMessagePage {
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private chatStore: ChatStore = ChatStore.getInstance();
  private configManager: ConfigManager = ConfigManager.getInstance();
  @State inputText: string = '';
  @State replyMsgText: string = '';
  @State replyMsgId: number = 0;
  @State renderKey: number = 0;
  @State memberList: GroupMember[] = [];
  @State showAtPicker: boolean = false;
  @State showFacePicker: boolean = false;
  @State allFaceIds: number[] = [];
  @State isRecording: boolean = false;
  @State sending: boolean = false;
  @State recordedFilePath: string = '';
  private placeholderMap: SqPlaceholder[] = [];
  private sqCounter: number = 0;
  private avRecorder: media.AVRecorder | null = null;

  private peerId: number = 0;
  private chatType: string = 'private';
  private peerName: string = '';
  private sent: boolean = false;

  getChatId(): string {
    return ChatStore.chatId(this.chatType, this.peerId);
  }

  aboutToDisappear(): void {
    if (this.sent) {
      this.clearDraft();
    } else {
      this.saveDraft();
    }
  }

  aboutToAppear(): void {
    this.allFaceIds = FaceStore.getAllFaceIds();
    let params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      this.peerId = params['peer_id'] as number || 0;
      this.peerName = params['peer_name'] as string || '';
      this.chatType = params['chat_type'] as string || 'private';

      let replyText = params['reply_text'] as string || '';
      let replyId = params['reply_id'] as number || 0;
      if (replyText !== '' && replyId > 0) {
        this.replyMsgText = replyText;
        this.replyMsgId = replyId;
      }

      let atQq = params['at_qq'] as string || '';
      let atName = params['at_name'] as string || '';
      if (atQq !== '' && this.chatType === 'group') {
        this.addPlaceholder('at', atQq, atName || atQq, '');
      }
    }
    this.loadDraft();
    if (this.chatType === 'group') {
      this.loadMembers();
    }
  }

  loadMembers(): void {
    let mList: GroupMember[] = [];
    let allMembers = this.chatStore.getAllGroupMembers(this.peerId);
    for (let m of allMembers) {
      mList.push(m);
    }
    this.memberList = mList;
  }

  addPlaceholder(segType: string, qq: string, name: string, faceId: string): void {
    let key = '[SQ:' + this.sqCounter + ']';
    this.sqCounter++;
    let sp = new SqPlaceholder();
    sp.key = key;
    sp.segType = segType;
    sp.qq = qq;
    sp.name = name;
    sp.faceId = faceId;
    this.placeholderMap.push(sp);
    let tail = this.inputText.length > 0 && !this.inputText.endsWith(' ') ? ' ' : '';
    this.inputText = this.inputText + tail + key + ' ';
  }

  openAtPicker(): void {
    if (this.memberList.length === 0) {
      return;
    }
    this.showFacePicker = false;
    this.showAtPicker = true;
  }

  openFacePicker(): void {
    this.showAtPicker = false;
    this.showFacePicker = true;
  }

  pickAtMember(member: GroupMember): void {
    let name = member.getDisplayName();
    this.addPlaceholder('at', String(member.userId), name, '');
    this.showAtPicker = false;
    this.renderKey++;
  }

  pickFace(faceId: number): void {
    this.addPlaceholder('face', '', '', String(faceId));
    this.showFacePicker = false;
    this.renderKey++;
  }

  async loadDraft(): Promise<void> {
    let chatIdValue = this.getChatId();
    RefreshLogger.getInstance().log('SMP-LOAD-0', 'chatId=' + chatIdValue +
      ' peerId=' + this.peerId + ' chatType=' + this.chatType);
    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);
    let draftStr = await this.configManager.getString('draft_' + chatIdValue, '');
    RefreshLogger.getInstance().log('SMP-LOAD', 'key=draft_' + chatIdValue +
      ' has=' + (draftStr !== '' && draftStr !== null) +
      ' len=' + (draftStr !== '' && draftStr !== null ? (draftStr || '').length : 0));
    if (draftStr === '' || draftStr === null) {
      return;
    }
    try {
      let obj = JSON.parse(draftStr) as Record<string, Object>;
      this.inputText = obj['text'] as string || this.inputText;
      this.sqCounter = obj['sqCounter'] as number || 0;
      let pmRaw = obj['pm'] as string || '[]';
      let pmArr = JSON.parse(pmRaw) as Object[];
      this.placeholderMap = [];
      for (let item of pmArr) {
        let o = item as Record<string, Object>;
        let sp = new SqPlaceholder();
        sp.key = o['key'] as string || '';
        sp.segType = o['segType'] as string || 'at';
        sp.qq = o['qq'] as string || '';
        sp.name = o['name'] as string || '';
        sp.faceId = o['faceId'] as string || '';
        this.placeholderMap.push(sp);
      }
      if (obj['replyText'] as string !== '') {
        this.replyMsgText = obj['replyText'] as string || '';
        this.replyMsgId = obj['replyId'] as number || 0;
      }
      RefreshLogger.getInstance().log('SMP-LOAD-OK', 'loaded text=' + (this.inputText).length +
        ' sqC=' + this.sqCounter + ' pmLen=' + this.placeholderMap.length);
    } catch (e) {
      RefreshLogger.getInstance().log('SMP-LOAD-ERR', 'parse failed: ' + (e as Error).message);
    }
  }

  async saveDraft(): Promise<void> {
    let chatIdValue = this.getChatId();
    RefreshLogger.getInstance().log('SMP-SAVE', 'start textLen=' + this.inputText.length +
      ' sqC=' + this.sqCounter + ' pmLen=' + this.placeholderMap.length + ' cid=' + chatIdValue);
    let pmArr: Record<string, Object>[] = [];
    for (let sp of this.placeholderMap) {
      let o: Record<string, Object> = { 'key': sp.key, 'segType': sp.segType,
        'qq': sp.qq, 'name': sp.name, 'faceId': sp.faceId };
      pmArr.push(o);
    }
    let obj: Record<string, Object> = {
      'text': this.inputText,
      'sqCounter': this.sqCounter,
      'pm': JSON.stringify(pmArr),
      'replyText': this.replyMsgText,
      'replyId': this.replyMsgId
    };
    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);
    let key = 'draft_' + chatIdValue;
    await this.configManager.setString(key, JSON.stringify(obj));
    let verify = await this.configManager.getString(key, '');
    RefreshLogger.getInstance().log('SMP-SAVE-OK', 'wrote k=' + key + ' verLen=' +
      (verify !== '' && verify !== null ? (verify || '').length : 0));
  }

  async clearDraft(): Promise<void> {
    let chatIdValue = this.getChatId();
    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);
    await this.configManager.setString('draft_' + chatIdValue, '');
    RefreshLogger.getInstance().log('SMP-CLEAR', 'draft cleared for cid=' + chatIdValue);
  }

  cancelReply(): void {
    this.replyMsgText = '';
    this.replyMsgId = 0;
    this.renderKey++;
  }

  buildMsgArr(): Record<string, Object>[] {
    let arr: Record<string, Object>[] = [];

    if (this.replyMsgId > 0) {
      let replyData: Record<string, Object> = { 'id': String(this.replyMsgId) };
      let replySeg: Record<string, Object> = { 'type': 'reply', 'data': replyData };
      arr.push(replySeg);
    }

    let text = this.inputText;
    if (text === '' && this.replyMsgId <= 0) {
      return arr;
    }

    if (this.placeholderMap.length > 0) {
      let remain = text;
      let fullMatch = remain.match(/\[SQ:\d+\]/);
      while (fullMatch !== null && fullMatch.index !== undefined) {
        let idx = fullMatch.index;
        if (idx > 0) {
          let before = remain.substring(0, idx);
          if (before.trim() !== '') {
            let textData: Record<string, Object> = { 'text': before };
            let textSeg: Record<string, Object> = { 'type': 'text', 'data': textData };
            arr.push(textSeg);
          }
        }

        let matchedKey = fullMatch[0];
        for (let sp of this.placeholderMap) {
          if (sp.key === matchedKey) {
            if (sp.segType === 'face') {
              let faceData: Record<string, Object> = { 'id': sp.faceId };
              let faceSeg: Record<string, Object> = { 'type': 'face', 'data': faceData };
              arr.push(faceSeg);
            } else {
              let atData: Record<string, Object> = { 'qq': sp.qq };
              let atSeg: Record<string, Object> = { 'type': 'at', 'data': atData };
              arr.push(atSeg);
            }
            break;
          }
        }

        remain = remain.substring(idx + matchedKey.length);
        fullMatch = remain.match(/\[SQ:\d+\]/);
      }
      if (remain.trim() !== '') {
        let textData: Record<string, Object> = { 'text': remain };
        let textSeg: Record<string, Object> = { 'type': 'text', 'data': textData };
        arr.push(textSeg);
      }
    } else {
      let textData: Record<string, Object> = { 'text': text };
      let textSeg: Record<string, Object> = { 'type': 'text', 'data': textData };
      arr.push(textSeg);
    }

    return arr;
  }

  async sendAndClose(): Promise<void> {
    if (this.sending) { return; }

    let arr = this.buildMsgArr();
    if (arr.length === 0) {
      return;
    }

    let params: Record<string, Object> = {
      'message_type': this.chatType,
      'message': arr
    };
    if (this.chatType === 'group') {
      params['group_id'] = this.peerId;
    } else {
      params['user_id'] = this.peerId;
    }

    let reqObj: Record<string, Object> = {
      'action': 'send_msg',
      'params': params,
      'echo': 'send_msg_' + Date.now()
    };

    this.sending = true;
    // 先保存占位，再等 WS 回执
    await this.savePlaceholder(arr);

    this.wsManager.sendRequestWithCallback(reqObj, (data: Record<string, Object>) => {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        this.sent = true;
        router.back();
      }
      // 失败不退，用户可重试
    });
  }

  async savePlaceholder(segments: Record<string, Object>[]): Promise<void> {
    let chatId = ChatStore.chatId(this.chatType, this.peerId);
    let rawText = '';
    let firstType = 'text';
    for (let seg of segments) {
      let s = seg as Record<string, Object>;
      let st = s['type'] as string || '';
      if (rawText === '' && st !== '') {
        firstType = st;
      }
      let sd = s['data'] as Record<string, Object> || {};
      if (st === 'text') {
        rawText += (sd['text'] as string || '');
      } else if (st === 'face') {
        rawText += '[表情]';
      } else if (st === 'at') {
        rawText += '@' + (sd['qq'] || '');
      } else if (st === 'reply') {
        rawText += '[回复]';
      } else if (st === 'record') {
        rawText += '[语音]';
      }
    }

    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);
    let selfId = parseInt(await this.configManager.getString('self_id', '0') || '0');

    let cm = new CachedMessage();
    cm.messageId = -Date.now(); // 唯一负 ID，后续 handleHistoryResponse 替换
    cm.chatId = chatId;
    cm.userId = selfId;
    cm.nickname = '我';
    cm.content = JSON.stringify(segments);
    cm.rawMessage = rawText;
    cm.msgType = firstType;
    cm.timestamp = Date.now();
    cm.isSelf = true;

    await ChatStore.getInstance().initDb(ctx);
    await ChatStore.getInstance().saveMessage(cm);
  }

  async toggleRecording(): Promise<void> {
    if (this.isRecording) {
      await this.stopRecording();
    } else {
      await this.startRecording();
    }
  }

  async startRecording(): Promise<void> {
    // 运行时申请麦克风权限
    try {
      let ctx = this.getUIContext().getHostContext() as Context;
      let atManager = abilityAccessCtrl.createAtManager();
      let grantStatus = await atManager.checkAccessToken(
        ctx.applicationInfo.accessTokenId, 'ohos.permission.MICROPHONE');
      if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        await atManager.requestPermissionsFromUser(ctx, ['ohos.permission.MICROPHONE']);
      }
    } catch (_e) {
    }
    try {
      let ctx = this.getUIContext().getHostContext() as Context;
      let filePath = ctx.cacheDir + '/voice_' + Date.now() + '.m4a';

      this.avRecorder = await media.createAVRecorder();
      let audioConfig: media.AVRecorderProfile = {
        audioBitrate: 48000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 16000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A,
      };
      await this.avRecorder.prepare({
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: audioConfig,
        url: 'file://' + filePath,
      });
      await this.avRecorder.start();
      this.isRecording = true;
      this.recordedFilePath = filePath;
    } catch (_e) {
      this.isRecording = false;
    }
  }

  async stopRecording(): Promise<void> {
    this.isRecording = false;
    if (this.avRecorder !== null) {
      try {
        await this.avRecorder.stop();
        await this.avRecorder.release();
      } catch (_e) {
      }
      this.avRecorder = null;
    }
    // 录制完成后自动发送
    if (this.recordedFilePath !== '') {
      this.sendVoice();
    }
  }

  async sendVoice(): Promise<void> {
    // 读取录音文件，base64 编码后通过 data.file 发送
    // OneBot v11 标准：data.file 支持 base64:// 前缀
    let sendFile = '';
    try {
      let stat = fileIo.statSync(this.recordedFilePath);
      if (stat.size > 0 && stat.size < 1024 * 1024) {
        let file = fileIo.openSync(this.recordedFilePath, fileIo.OpenMode.READ_ONLY);
        let buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        fileIo.closeSync(file);
        let base64Helper = new util.Base64Helper();
        sendFile = 'base64://' + base64Helper.encodeToStringSync(new Uint8Array(buf));
      }
    } catch (_e) {
    }
    if (sendFile === '') {
      RefreshLogger.getInstance().log('VOICE-SEND-ERR', 'failed to read/encode voice file');
      return;
    }
    if (this.sending) { return; }
    RefreshLogger.getInstance().log('VOICE-SEND', 'sending size=' + sendFile.length + ' file=' + this.recordedFilePath);
    let req = OneBotRequest.createSendVoice(
      this.peerId, this.chatType, sendFile);

    // 保存本地占位消息
    let voiceData: Record<string, Object> = { 'file': this.recordedFilePath };
    let voiceSeg: Record<string, Object> = { 'type': 'record', 'data': voiceData };
    await this.savePlaceholder([voiceSeg]);

    this.sending = true;
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        this.sent = true;
        router.back();
      }
    });
  }

  build() {
    Stack() {
      Column() {
        Text(this.peerName || '发送消息')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('76%')
          .textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 8 })

        // 回复提示条
        if (this.replyMsgText !== '') {
          Row() {
            Text('回复: ' + this.replyMsgText.substring(0, 30))
              .fontSize(11)
              .fontColor('#888888')
              .fontStyle(FontStyle.Italic)
              .maxLines(1)
              .layoutWeight(1)
            Button() {
              SymbolGlyph($r('sys.symbol.xmark_circle'))
                .fontColor(['#FF6666'])
                .fontSize(16)
            }
            .width(28)
            .height(28)
            .backgroundColor(Color.Transparent)
            .onClick(() => { this.cancelReply(); })
          }
          .width('76%')
          .height(32)
          .backgroundColor('#1a1a1a')
          .borderRadius(8)
          .padding({ left: 10, right: 6 })
          .margin({ bottom: 8 })
        }

        // @ 选择面板
        if (this.showAtPicker && this.memberList.length > 0) {
          Column() {
            Row() {
              Text('选择要@的人')
                .fontSize(12)
                .fontColor(Color.White)
                .layoutWeight(1)
              Button() {
                SymbolGlyph($r('sys.symbol.xmark_circle'))
                  .fontColor(['#888888'])
                  .fontSize(14)
              }
              .width(24)
              .height(24)
              .backgroundColor(Color.Transparent)
              .onClick(() => { this.showAtPicker = false; })
            }
            .width('100%')
            .padding({ bottom: 6 })

            List() {
              ForEach(this.memberList, (member: GroupMember) => {
                ListItem() {
                  Row() {
                    Text(member.getDisplayName())
                      .fontSize(13)
                      .fontColor(Color.White)
                      .layoutWeight(1)
                      .maxLines(1)
                    Text(member.userId.toString())
                      .fontSize(10)
                      .fontColor('#666666')
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                  .onClick(() => { this.pickAtMember(member); })
                }
              }, (member: GroupMember) => member.userId.toString())
            }
            .width('100%')
            .height(150)
            .scrollBar(BarState.Off)
          }
          .width('76%')
          .backgroundColor('#1a1a1a')
          .borderRadius(12)
          .padding(10)
          .margin({ bottom: 8 })
        }

        // 表情选择面板
        if (this.showFacePicker && this.allFaceIds.length > 0) {
          Column() {
            Row() {
              Text('选择表情')
                .fontSize(12)
                .fontColor(Color.White)
                .layoutWeight(1)
              Button() {
                SymbolGlyph($r('sys.symbol.xmark_circle'))
                  .fontColor(['#888888'])
                  .fontSize(14)
              }
              .width(24)
              .height(24)
              .backgroundColor(Color.Transparent)
              .onClick(() => { this.showFacePicker = false; })
            }
            .width('100%')
            .padding({ bottom: 6 })

            Grid() {
              ForEach(this.allFaceIds, (fid: number) => {
                GridItem() {
                  Image($rawfile('face/' + fid + '.png'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                }
                .width(28)
                .height(28)
                .onClick(() => { this.pickFace(fid); })
              }, (fid: number) => fid.toString())
            }
            .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
            .rowsGap(6)
            .columnsGap(4)
            .width('100%')
            .height(160)
            .scrollBar(BarState.Off)
          }
          .width('76%')
          .backgroundColor('#1a1a1a')
          .borderRadius(12)
          .padding(10)
          .margin({ bottom: 8 })
        }

        // 输入区
        if (!this.showAtPicker && !this.showFacePicker) {
          TextArea({ text: this.inputText, placeholder: '输入消息' })
            .width('76%')
            .height(80)
            .fontSize(14)
            .fontColor(Color.White)
            .placeholderColor('#555555')
            .backgroundColor('#1a1a1a')
            .borderRadius(12)
            .padding(12)
            .defaultFocus(true)
            .onChange((value: string) => {
              this.inputText = value;
            })
        }

        // 按钮行
        Row() {
          Button('表情')
            .fontSize(12)
            .fontColor('#FFB347')
            .backgroundColor('#1a1a1a')
            .height(30)
            .borderRadius(15)
            .padding({ left: 12, right: 12 })
            .onClick(() => { this.openFacePicker(); })

          if (this.chatType === 'group') {
            Button('@ 提及')
              .fontSize(12)
              .fontColor('#C0B8E0')
              .backgroundColor('#1a1a1a')
              .height(30)
              .borderRadius(15)
              .padding({ left: 12, right: 12 })
              .margin({ left: 6 })
              .onClick(() => { this.openAtPicker(); })
          }

          Button(this.isRecording ? '⏹ 停止' : '🎤 语音')
            .fontSize(12)
            .fontColor(this.isRecording ? '#FF0000' : '#00CC88')
            .backgroundColor(this.isRecording ? '#331111' : '#1a1a1a')
            .height(30)
            .borderRadius(15)
            .padding({ left: 12, right: 12 })
            .margin({ left: 6 })
            .onClick(() => { this.toggleRecording(); })
          Blank()
        }
        .width('76%')
        .margin({ top: 4 })

        Blank()

        // ArcButton 发送
        ArcButton({
          options: new ArcButtonOptions({
            label: this.sending ? '发送中...' : (this.isRecording ? '停止录音' : '发送'),
            position: ArcButtonPosition.BOTTOM_EDGE,
            styleMode: ArcButtonStyleMode.CUSTOM,
            backgroundColor: ColorMetrics.resourceColor(this.sending ? '#888888' : (this.isRecording ? '#FF4444' : '#C0B8E0')),
            fontSize: new LengthMetrics(15, LengthUnit.FP),
            onClick: () => {
              if (this.sending) { return; }
              if (this.isRecording) {
                this.stopRecording();
              } else {
                this.sendAndClose();
              }
            }
          })
        })
        // 录音/发送状态指示
        if (this.isRecording) {
          Text('🔴 正在录音...')
            .fontSize(12)
            .fontColor('#FF4444')
            .textAlign(TextAlign.Center)
            .width('76%')
            .padding({ bottom: 4 })
        }
        if (this.sending) {
          Text('⏳ 正在发送...')
            .fontSize(12)
            .fontColor('#C0B8E0')
            .textAlign(TextAlign.Center)
            .width('76%')
            .padding({ bottom: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
