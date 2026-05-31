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
struct HomePage {
  private swiperController: ArcSwiperController = new ArcSwiperController();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private msgCenter: MessageCenter = MessageCenter.getInstance();
  @State currentIndex: number = 0;
  @State wsState: WsState = WsState.DISCONNECTED;
  @State refreshTrigger: number = 0;

  aboutToAppear(): void {
    this.wsState = this.wsManager.getState();

    this.wsManager.addStateListener((state: WsState) => {
      this.wsState = state;
    });

    // 全局消息 → 刷新消息列表
    this.msgCenter.addGlobalHandler((_msg: OneBotMessage) => {
      this.refreshTrigger++;
    });

    // 联系人加载完成 → 刷新好友/群聊列表
    this.msgCenter.onContactsLoaded = () => {
      this.refreshTrigger++;
    };
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

  build() {
    ArcSwiper(this.swiperController) {
      MessageTab({ stateColor: this.getStateColor(), refreshTrigger: this.refreshTrigger })
      FriendsTab({ stateColor: this.getStateColor(), refreshTrigger: this.refreshTrigger })
      GroupsTab({ stateColor: this.getStateColor(), refreshTrigger: this.refreshTrigger })
      SettingsTab({ stateColor: this.getStateColor(), refreshTrigger: this.refreshTrigger })
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
  }
}
