import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { ChatStore, ChatItem } from '../model/ChatStore';
import { MessageCenter } from '../model/MessageCenter';
import { WebSocketManager } from '../model/WebSocketManager';
import { OneBotMessage, WsState } from '../model/OneBotModel';

@Entry
@Component
struct CrownDebugPage {
  private chatStore: ChatStore = ChatStore.getInstance();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private msgCenter: MessageCenter = MessageCenter.getInstance();
  @State chats: ChatItem[] = [];
  @State wsState: WsState = WsState.DISCONNECTED;
  listScroller: Scroller = new Scroller();
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    this.wsState = this.wsManager.getState();
    this.loadChats();

    this.wsManager.onStateChange = (state: WsState) => {
      this.wsState = state;
    };

    this.msgCenter.addGlobalHandler((_msg: OneBotMessage) => {
      this.loadChats();
    });

    this.refreshTimer = setInterval(() => {
      this.loadChats();
    }, 3000);
  }

  aboutToDisappear(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  onPageShow(): void {
    this.wsState = this.wsManager.getState();
    this.loadChats();
  }

  async loadChats(): Promise<void> {
    this.chats = await this.chatStore.getChats(50);
  }

  getStateColor(): string {
    switch (this.wsState) {
      case WsState.CONNECTED: return '#00FF88';
      case WsState.CONNECTING: return '#FFB347';
      default: return '#FF6666';
    }
  }

  getStateText(): string {
    switch (this.wsState) {
      case WsState.CONNECTED: return '在线';
      case WsState.CONNECTING: return '连接中';
      default: return '离线';
    }
  }

  formatTime(ts: number): string {
    if (ts === 0) return '';
    let d = new Date(ts);
    let now = new Date();
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    if (d.toDateString() === now.toDateString()) return h + ':' + m;
    let mon = d.getMonth() + 1;
    let day = d.getDate();
    return mon + '/' + day;
  }

  openChat(chat: ChatItem): void {
    router.pushUrl({
      url: 'pages/ChatDetailPage',
      params: {
        peer_id: chat.peerId,
        peer_name: chat.peerName,
        chat_type: chat.chatType
      }
    });
  }

  build() {
    Column() {
      // 顶部状态栏
      Row() {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.getStateColor())
            .margin({ right: 4 })
          Text(this.getStateText())
            .fontSize(11)
            .fontColor(this.getStateColor())
        }
        .margin({ left: 4 })

        Blank()

        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.person_2'))
              .fontColor(['#C0B8E0'])
              .fontSize(18)
          }
          .width(36)
          .height(36)
          .type(ButtonType.Circle)
          .backgroundColor('#1a1a1a')
          .onClick(() => {
            router.pushUrl({ url: 'pages/ContactsPage' });
          })

          Button() {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .fontColor(['#888888'])
              .fontSize(16)
          }
          .width(36)
          .height(36)
          .type(ButtonType.Circle)
          .backgroundColor('#1a1a1a')
          .margin({ left: 6 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/ConnectionPage' });
          })
        }
      }
      .width('86%')
      .height(44)
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 4, right: 4 })

      Text('消息')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width('86%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      // 空状态
      if (this.chats.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.message'))
            .fontColor(['#444444'])
            .fontSize(36)
            .margin({ bottom: 12 })
          Text('暂无消息')
            .fontSize(14)
            .fontColor('#666666')
          Text('收到新消息后将显示在这里')
            .fontSize(11)
            .fontColor('#444444')
            .margin({ top: 4 })
        }
        .width('86%')
        .height('60%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      if (this.chats.length > 0) {
        ArcList({ scroller: this.listScroller }) {
          ForEach(this.chats, (chat: ChatItem, index: number) => {
            ArcListItem() {
              Row() {
                Column() {
                  Text(chat.peerName || chat.chatId)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(chat.lastMessage || '')
                    .fontSize(11)
                    .fontColor('#888888')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 3 })
                }
                .width('70%')
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 8 })

                Column() {
                  Text(this.formatTime(chat.lastMessageTime))
                    .fontSize(10)
                    .fontColor('#555555')

                  if (chat.unreadCount > 0) {
                    Text(chat.unreadCount > 99 ? '99+' : String(chat.unreadCount))
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                      .backgroundColor('#C0B8E0')
                      .borderRadius(9)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .margin({ top: 4 })
                  }
                }
                .alignItems(HorizontalAlign.Center)
                .margin({ right: 8 })
              }
              .width('100%')
              .height(52)
              .justifyContent(FlexAlign.SpaceBetween)
              .alignItems(VerticalAlign.Center)
              .border({ width: { bottom: 0.5 }, color: '#1a1a1a' })
              .onClick(() => { this.openChat(chat); })
            }
            .width('86%')
          }, (chat: ChatItem, index: number) => index.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .space(LengthMetrics.vp(0))
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .groupDefaultFocus(true)
        .id('homeArcList')
        .scrollBar(BarState.Auto)
        .padding({ left: 8, right: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .padding({ top: 8 })
  }
}
