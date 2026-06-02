import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { ChatStore, ContactItem } from '../model/ChatStore';

@Component
export struct FriendsTab {
  private chatStore: ChatStore = ChatStore.getInstance();
  @Prop stateColor: string = '#FF6666';
  @Prop @Watch('onRefreshChange') refreshTrigger: number = 0;
  @State friends: ContactItem[] = [];
  @State renderKey: number = 0;
  listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadData();
  }

  onRefreshChange(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    await this.chatStore.initDb(this.getUIContext().getHostContext() as Context);
    this.friends = await this.chatStore.getContacts();
    this.renderKey = this.renderKey + 1;
  }

  openChat(contact: ContactItem): void {
    router.pushUrl({
      url: 'pages/ChatDetailPage',
      params: {
        peer_id: contact.userId,
        peer_name: contact.getDisplayName(),
        chat_type: 'private'
      }
    });
  }

  openProfile(contact: ContactItem): void {
    router.pushUrl({
      url: 'pages/ProfilePage',
      params: {
        type: 'private',
        peerId: contact.userId,
        peerName: contact.getDisplayName(),
        userId: contact.userId
      }
    });
  }

  // 用昵称首字生成头像颜色
  getAvatarColor(name: string): string {
    let colors: string[] = ['#C0B8E0', '#FFB347', '#4DA6FF', '#00CC88', '#FF7777', '#77BBFF'];
    let sum = 0;
    for (let i = 0; i < name.length; i++) {
      sum += name.charCodeAt(i);
    }
    return colors[sum % colors.length];
  }

  getInitial(name: string): string {
    return name.length > 0 ? name.charAt(0) : '?';
  }

  getAvatarUrl(userId: number): string {
    return 'https://q1.qlogo.cn/g?b=qq&nk=' + userId + '&s=100';
  }

  build() {
    ArcList({ scroller: this.listScroller }) {
      // 标题行
      ArcListItem() {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.stateColor)
            .margin({ right: 6 })
          Text('好友')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          Text(this.friends.length + ' 人')
            .fontSize(10)
            .fontColor('#666666')
        }
        .width('100%')
        .padding({ top: 14, bottom: 10, left: 4, right: 4 })
      }
      .width('82%')

      if (this.friends.length === 0) {
        ArcListItem() {
          Column() {
            SymbolGlyph($r('sys.symbol.person'))
              .fontColor(['#333333'])
              .fontSize(32)
              .margin({ bottom: 10 })
            Text('暂无好友')
              .fontSize(13)
              .fontColor('#666666')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 40, bottom: 40 })
        }
        .width('82%')
      }

      ForEach(this.friends, (friend: ContactItem, index: number) => {
        ArcListItem() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Text(this.getInitial(friend.getDisplayName()))
                .fontSize(15)
                .fontColor(Color.White)
              Image(this.getAvatarUrl(friend.userId))
                .width(38)
                .height(38)
                .borderRadius(19)
                .objectFit(ImageFit.Cover)
            }
            .width(38)
            .height(38)
            .borderRadius(19)
            .backgroundColor(this.getAvatarColor(friend.getDisplayName()))
            .clip(true)
            .margin({ right: 10 })

            // 名称 + 备注
            Column() {
              Text(friend.getDisplayName())
                .fontSize(14)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text('QQ: ' + friend.userId)
                .fontSize(10)
                .fontColor('#888888')
                .margin({ top: 3 })
                .maxLines(1)
            }
            .width('60%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .height(52)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 6, right: 6 })
          .borderRadius(10)
          .onClick(() => { this.openChat(friend); })
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction(() => { this.openProfile(friend); })
          )
        }
        .width('82%')
        .margin({ bottom: 4 })
      }, (friend: ContactItem, index: number) => this.renderKey + '_' + index.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .space(LengthMetrics.vp(0))
    .scrollBar(BarState.Off)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }
}
