import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ConfigManager } from '../model/ConfigManager';
import { ChatStore } from '../model/ChatStore';
import { WebSocketManager } from '../model/WebSocketManager';
import { MessageCenter } from '../model/MessageCenter';
import { CacheManager } from '../model/CacheManager';

@Entry
@Component
struct SplashPage {
  private configManager: ConfigManager = ConfigManager.getInstance();
  private chatStore: ChatStore = ChatStore.getInstance();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private msgCenter: MessageCenter = MessageCenter.getInstance();
  @State routed: boolean = false;
  @State statusText: string = '正在初始化...';

  aboutToAppear(): void {
    this.initAndRoute();
  }

  async initAndRoute(): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      // 初始化数据库
      await this.configManager.initDb(context);
      await this.chatStore.initDb(context);
      await this.msgCenter.init();
      await CacheManager.getInstance().init();

      let serverUrl: string = await this.configManager.getString('server_url', '');

      if (serverUrl !== '') {
        // 有已保存的服务器 → 自动连接
        this.statusText = '正在连接服务器...';
        let token = await this.configManager.getString('access_token', '');
        let url = serverUrl;
        if (token !== '') {
          url = url + '?access_token=' + encodeURI(token);
        }

        let success = await this.wsManager.connect(url);
        if (!this.routed) {
          this.routed = true;
          if (success) {
            router.replaceUrl({ url: 'pages/HomePage' });
          } else {
            router.replaceUrl({ url: 'pages/HomePage' });
          }
        }
      } else {
        if (!this.routed) {
          this.routed = true;
          router.replaceUrl({ url: 'pages/HomePage' });
        }
      }
    } catch (_err) {
      if (!this.routed) {
        this.routed = true;
        router.replaceUrl({ url: 'pages/HomePage' });
      }
    }
  }

  build() {
    Column() {
      Text('NapcatWatch')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text(this.statusText)
        .fontSize(14)
        .fontColor('#888888')
        .margin({ top: 8 })

      LoadingProgress()
        .width(40)
        .height(40)
        .color('#C0B8E0')
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
