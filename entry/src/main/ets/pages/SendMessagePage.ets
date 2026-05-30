import { router } from '@kit.ArkUI';
import { WebSocketManager } from '../model/WebSocketManager';
import { OneBotRequest } from '../model/OneBotModel';

@Entry
@Component
struct SendMessagePage {
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  @State inputText: string = '';
  private peerId: number = 0;
  private chatType: string = 'private';
  private peerName: string = '';

  aboutToAppear(): void {
    let params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params) {
      this.peerId = params['peer_id'] as number || 0;
      this.peerName = params['peer_name'] as string || '';
      this.chatType = params['chat_type'] as string || 'private';
    }
  }

  sendAndClose(): void {
    if (this.inputText.trim() === '') {
      return;
    }
    let req: OneBotRequest = OneBotRequest.createSendMsg(
      this.peerId, this.chatType, this.inputText);
    this.wsManager.sendRequest(req);
    router.back();
  }

  close(): void {
    router.back();
  }

  build() {
    Stack() {
      Column() {
        // 标题
        Text(this.peerName || '发送消息')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('86%')
          .textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 12 })

        // 输入框
        TextInput({ text: this.inputText, placeholder: '输入消息' })
          .width('86%')
          .height(80)
          .fontSize(14)
          .fontColor(Color.White)
          .placeholderColor('#555555')
          .backgroundColor('#1a1a1a')
          .borderRadius(12)
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .maxLength(5000)
          .defaultFocus(true)
          .onChange((value: string) => {
            this.inputText = value;
          })

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .padding({ top: 4 })

      // 底部发送按钮
      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor('#AAAAAA')
          .backgroundColor('#1a1a1a')
          .width('35%')
          .height(40)
          .borderRadius(20)
          .onClick(() => { this.close(); })

        Blank().width(16)

        Button('发送')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
          .backgroundColor('#C0B8E0')
          .width('45%')
          .height(40)
          .borderRadius(20)
          .onClick(() => { this.sendAndClose(); })
      }
      .width('86%')
      .height(56)
      .justifyContent(FlexAlign.Center)
      .position({ x: '7%', y: '88%' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
