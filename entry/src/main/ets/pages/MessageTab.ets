import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { ChatStore, ChatItem } from '../model/ChatStore';
import { ConfigManager } from '../model/ConfigManager';

@Component
export struct MessageTab {
  private chatStore: ChatStore = ChatStore.getInstance();
  @Prop stateColor: string = '#FF6666';
  @Prop @Watch('onRefreshChange') refreshTrigger: number = 0;
  @State chats: ChatItem[] = [];
  @State renderKey: number = 0;
  listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadChats();
  }

  onRefreshChange(): void {
    this.loadChats();
  }

  async loadChats(): Promise<void> {
    let ctx = this.getUIContext().getHostContext() as Context;
    await this.chatStore.initDb(ctx);
    this.chats = await this.chatStore.getChats(50);
    // 加载免打扰状态
    let configMgr = ConfigManager.getInstance();
    await configMgr.initDb(ctx);
    let mutedJson = await configMgr.getString('muted_chats', '[]');
    for (let chat of this.chats) {
      chat.isMuted = mutedJson.indexOf('"' + chat.chatId + '"') >= 0;
    }
    this.renderKey = this.renderKey + 1;
  }

  formatTime(ts: number): string {
    if (ts === 0) {
      return '';
    }
    let d = new Date(ts);
    let now = new Date();
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    if (d.toDateString() === now.toDateString()) {
      return h + ':' + m;
    }
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

  openProfile(chat: ChatItem): void {
    router.pushUrl({
      url: 'pages/ProfilePage',
      params: {
        type: chat.chatType,
        peerId: chat.peerId,
        peerName: chat.peerName,
        userId: chat.peerId
      }
    });
  }

  getAvatarColor(name: string): string {
    let colors: string[] = ['#C0B8E0', '#FFB347', '#4DA6FF', '#00CC88', '#FF7777', '#77BBFF'];
    let sum = 0;
    for (let i = 0; i < name.length; i++) {
      sum += name.charCodeAt(i);
    }
    return colors[sum % colors.length];
  }

  getAvatarUrl(chat: ChatItem): string {
    if (chat.chatType === 'group') {
      return 'https://p.qlogo.cn/gh/' + chat.peerId + '/' + chat.peerId + '/100';
    }
    return 'https://q1.qlogo.cn/g?b=qq&nk=' + chat.peerId + '&s=100';
  }

  getInitial(name: string): string {
    if (name.length > 0) {
      return name.charAt(0);
    }
    return '#';
  }

  build() {
    ArcList({ scroller: this.listScroller }) {
      // 标题
      ArcListItem() {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.stateColor)
            .margin({ right: 6 })
          Text('消息')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          if (this.chats.length > 0) {
            Text(this.chats.length + ' 个会话')
              .fontSize(10)
              .fontColor('#666666')
          }
        }
        .width('100%')
        .padding({ top: 14, bottom: 10, left: 4, right: 4 })
      }
      .width('82%')

      if (this.chats.length === 0) {
        ArcListItem() {
          Column() {
            SymbolGlyph($r('sys.symbol.message'))
              .fontColor(['#333333'])
              .fontSize(32)
              .margin({ bottom: 10 })
            Text('暂无消息')
              .fontSize(13)
              .fontColor('#666666')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 40, bottom: 40 })
        }
        .width('82%')
      }

      ForEach(this.chats, (chat: ChatItem, index: number) => {
        ArcListItem() {
          Row() {
            // 圆形头像
            Stack({ alignContent: Alignment.Center }) {
              Text(this.getInitial(chat.peerName || chat.chatId))
                .fontSize(15)
                .fontColor(Color.White)
              Image(this.getAvatarUrl(chat))
                .width(38)
                .height(38)
                .borderRadius(19)
                .objectFit(ImageFit.Cover)
            }
            .width(38)
            .height(38)
            .borderRadius(19)
            .backgroundColor(this.getAvatarColor(chat.peerName || chat.chatId))
            .clip(true)
            .margin({ right: 10 })

            Column() {
              Text(chat.peerName || chat.chatId)
                .fontSize(14)
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
            .width('55%')
            .alignItems(HorizontalAlign.Start)

            Column() {
              if (chat.isMuted) {
                Text('静音')
                  .fontSize(9)
                  .fontColor('#555555')
                  .margin({ bottom: 2 })
              }
              Text(this.formatTime(chat.lastMessageTime))
                .fontSize(10)
                .fontColor('#666666')

              if (chat.unreadCount > 0) {
                Text(chat.unreadCount > 99 ? '99+' : String(chat.unreadCount))
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor(chat.isMuted ? '#555555' : '#C0B8E0')
                  .borderRadius(10)
                  .width(22)
                  .height(18)
                  .textAlign(TextAlign.Center)
                  .margin({ top: 5 })
              }
            }
            .alignItems(HorizontalAlign.Center)
            .width('18%')
          }
          .width('100%')
          .height(52)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 6, right: 6 })
          .borderRadius(10)
          .onClick(() => { this.openChat(chat); })
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction(() => { this.openProfile(chat); })
          )
        }
        .width('82%')
        .margin({ bottom: 4 })
      }, (chat: ChatItem, index: number) => this.renderKey + '_' + index.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .space(LengthMetrics.vp(0))
    .scrollBar(BarState.Off)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }
}
