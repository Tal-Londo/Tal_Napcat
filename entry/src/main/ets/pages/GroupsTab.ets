import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { ChatStore, GroupItem } from '../model/ChatStore';

@Component
export struct GroupsTab {
  private chatStore: ChatStore = ChatStore.getInstance();
  @Prop stateColor: string = '#FF6666';
  @Prop @Watch('onRefreshChange') refreshTrigger: number = 0;
  @State groups: GroupItem[] = [];
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
    this.groups = await this.chatStore.getGroups();
    this.renderKey = this.renderKey + 1;
  }

  openChat(group: GroupItem): void {
    router.pushUrl({
      url: 'pages/ChatDetailPage',
      params: {
        peer_id: group.groupId,
        peer_name: group.groupName || ('群' + group.groupId),
        chat_type: 'group'
      }
    });
  }

  getAvatarColor(name: string): string {
    let colors: string[] = ['#C0B8E0', '#4DA6FF', '#00CC88', '#FFB347', '#FF7777', '#77BBFF'];
    let sum = 0;
    for (let i = 0; i < name.length; i++) {
      sum += name.charCodeAt(i);
    }
    return colors[sum % colors.length];
  }

  getInitial(name: string): string {
    return name.length > 0 ? name.charAt(0) : '群';
  }

  getAvatarUrl(groupId: number): string {
    return 'https://p.qlogo.cn/gh/' + groupId + '/' + groupId + '/100';
  }

  build() {
    ArcList({ scroller: this.listScroller }) {
      ArcListItem() {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.stateColor)
            .margin({ right: 6 })
          Text('群聊')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Blank()
          Text(this.groups.length + ' 个')
            .fontSize(10)
            .fontColor('#666666')
        }
        .width('100%')
        .padding({ top: 14, bottom: 10, left: 4, right: 4 })
      }
      .width('82%')

      if (this.groups.length === 0) {
        ArcListItem() {
          Column() {
            SymbolGlyph($r('sys.symbol.person_3'))
              .fontColor(['#333333'])
              .fontSize(32)
              .margin({ bottom: 10 })
            Text('暂无群聊')
              .fontSize(13)
              .fontColor('#666666')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 40, bottom: 40 })
        }
        .width('82%')
      }

      ForEach(this.groups, (group: GroupItem, index: number) => {
        ArcListItem() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Text(this.getInitial(group.groupName))
                .fontSize(15)
                .fontColor(Color.White)
              Image(this.getAvatarUrl(group.groupId))
                .width(38)
                .height(38)
                .borderRadius(19)
                .objectFit(ImageFit.Cover)
            }
            .width(38)
            .height(38)
            .borderRadius(19)
            .backgroundColor(this.getAvatarColor(group.groupName))
            .clip(true)
            .margin({ right: 10 })

            Column() {
              Text(group.groupName || ('群' + group.groupId))
                .fontSize(14)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              Text(group.memberCount + ' 名成员')
                .fontSize(10)
                .fontColor('#888888')
                .margin({ top: 3 })
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
          .onClick(() => { this.openChat(group); })
        }
        .width('82%')
        .margin({ bottom: 4 })
      }, (group: GroupItem, index: number) => this.renderKey + '_' + index.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .space(LengthMetrics.vp(0))
    .scrollBar(BarState.Off)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }
}
