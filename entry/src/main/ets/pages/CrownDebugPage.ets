import { ArcSwiper, ArcSwiperController, ArcDotIndicator, ArcDirection } from '@kit.ArkUI';
import { MessageCenter } from '../model/MessageCenter';
import { WebSocketManager } from '../model/WebSocketManager';
import { OneBotMessage, WsState } from '../model/OneBotModel';
import { MessageTab } from './MessageTab';
import { FriendsTab } from './FriendsTab';
import { GroupsTab } from './GroupsTab';
import { SettingsTab } from './SettingsTab';

@Entry
@Component
struct CrownDebugPage {
  private swiperController: ArcSwiperController = new ArcSwiperController();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private msgCenter: MessageCenter = MessageCenter.getInstance();
  @State currentIndex: number = 0;
  @State wsState: WsState = WsState.DISCONNECTED;

  aboutToAppear(): void {
    this.wsState = this.wsManager.getState();

    this.wsManager.addStateListener((state: WsState) => {
      this.wsState = state;
    });

    this.msgCenter.addGlobalHandler((_msg: OneBotMessage) => {
      // tabs 自行刷新
    });
  }

  getStateColor(): string {
    switch (this.wsState) {
      case WsState.CONNECTED:
        return '#00FF88';
      case WsState.CONNECTING:
        return '#FFB347';
      default:
        return '#FF6666';
    }
  }

  getStateText(): string {
    switch (this.wsState) {
      case WsState.CONNECTED:
        return '在线';
      case WsState.CONNECTING:
        return '连接中';
      default:
        return '离线';
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      ArcSwiper(this.swiperController) {
        MessageTab()
        FriendsTab()
        GroupsTab()
        SettingsTab()
      }
      .indicator(
        new ArcDotIndicator()
          .arcDirection(ArcDirection.SIX_CLOCK_DIRECTION)
          .itemColor('#444444')
          .selectedItemColor('#C0B8E0')
      )
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)

      Row() {
        Circle({ width: 6, height: 6 })
          .fill(this.getStateColor())
        Text(this.getStateText())
          .fontSize(10)
          .fontColor(this.getStateColor())
          .margin({ left: 4 })
      }
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(10)
      .backgroundColor('rgba(0,0,0,0.7)')
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
