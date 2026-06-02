import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ConfigManager } from '../model/ConfigManager';
import { ChatStore } from '../model/ChatStore';
import { CacheManager } from '../model/CacheManager';
import { WebSocketManager } from '../model/WebSocketManager';
import { OneBotServerInfo, WsState } from '../model/OneBotModel';

const TAG = 'SettingsTab';
const DOMAIN = 0x0004;

@Component
export struct SettingsTab {
  private configManager: ConfigManager = ConfigManager.getInstance();
  private chatStore: ChatStore = ChatStore.getInstance();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  @Prop stateColor: string = '#FF6666';
  @Prop refreshTrigger: number = 0;
  @State wsState: WsState = WsState.DISCONNECTED;
  @State statusText: string = '未连接';
  @State autoReconnect: boolean = true;
  @State servers: OneBotServerInfo[] = [];
  @State currentUrl: string = '';
  @State currentName: string = '';
  listScroller: Scroller = new Scroller();
  private stateListenerId?: (state: WsState) => void;

  aboutToAppear(): void {
    this.initPage();
  }

  async initPage(): Promise<void> {
    let context: Context = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(context);

    this.currentUrl = await this.configManager.getString('server_url', '');
    this.currentName = await this.configManager.getString('server_name', '');
    this.autoReconnect = await this.configManager.getBoolean('auto_reconnect', true);
    await this.loadServers();

    this.refreshDisplay();

    this.stateListenerId = (state: WsState) => {
      this.refreshDisplay();
    };
    this.wsManager.addStateListener(this.stateListenerId);

    this.wsManager.onError = (error: string) => {
      this.statusText = error;
    };
  }

  refreshDisplay(): void {
    this.wsState = this.wsManager.getState();
    switch (this.wsState) {
      case WsState.CONNECTED:
        this.statusText = '已连接';
        break;
      case WsState.CONNECTING:
        this.statusText = '连接中...';
        break;
      default:
        this.statusText = '未连接';
        break;
    }
  }

  async loadServers(): Promise<void> {
    try {
      let json = await this.configManager.getString('history_servers', '[]');
      let arr: OneBotServerInfo[] = [];
      if (json !== '[]') {
        let raw = JSON.parse(json) as Object[];
        for (let item of raw) {
          let info = OneBotServerInfo.fromJson(JSON.stringify(item));
          if (info.url !== '') { arr.push(info); }
        }
      }
      this.servers = arr;
    } catch (e) {}
  }

  selectServer(server: OneBotServerInfo): void {
    this.currentUrl = server.url;
    this.currentName = server.name;
    this.configManager.setString('server_url', server.url);
    this.configManager.setString('server_name', server.name);
    this.configManager.setString('access_token', server.accessToken);
  }

  async deleteServer(server: OneBotServerInfo): Promise<void> {
    let newArr: OneBotServerInfo[] = [];
    for (let s of this.servers) {
      if (s.url !== server.url) { newArr.push(s); }
    }
    this.servers = newArr;
    await this.configManager.setString('history_servers', JSON.stringify(newArr));
    if (this.currentUrl === server.url) {
      this.currentUrl = '';
      this.currentName = '';
      await this.configManager.setString('server_url', '');
    }
  }

  async connect(): Promise<void> {
    if (this.currentUrl === '') {
      this.statusText = '请先选择或添加服务器';
      return;
    }
    let url = this.currentUrl;
    let token = await this.configManager.getString('access_token', '');
    if (token !== '') { url = url + '?access_token=' + encodeURI(token); }

    this.wsManager.setReconnectEnabled(this.autoReconnect);
    let success = await this.wsManager.connect(url);
    if (success) {
      await this.configManager.setBoolean('auto_reconnect', this.autoReconnect);
      // update lastConnected
      let json = await this.configManager.getString('history_servers', '[]');
      try {
        let raw = JSON.parse(json) as Object[];
        let arr: OneBotServerInfo[] = [];
        for (let item of raw) {
          let info = OneBotServerInfo.fromJson(JSON.stringify(item));
          if (info.url === this.currentUrl) { info.lastConnected = Date.now(); }
          if (info.url !== '') { arr.push(info); }
        }
        await this.configManager.setString('history_servers', JSON.stringify(arr));
      } catch (e) {}
    } else {
      hilog.error(DOMAIN, TAG, 'Connection failed');
    }
  }

  disconnect(): void {
    this.wsManager.disconnect();
  }

  async clearCache(): Promise<void> {
    let context: Context = this.getUIContext().getHostContext() as Context;
    await this.chatStore.initDb(context);
    await this.chatStore.clearAllData();
    await CacheManager.getInstance().clearAll();
    promptAction.showToast({ message: '缓存已清除' });
  }

  @Builder
  endSwipe(server: OneBotServerInfo) {
    Column() {
      Button('编辑')
        .fontSize(12)
        .fontColor('#C0B8E0')
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(36)
        .borderRadius(8)
        .onClick(() => { router.pushUrl({ url: 'pages/EditServerPage', params: { 'url': server.url } }); })
    }
    .padding(6)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    ArcList({ scroller: this.listScroller }) {
      // 标题
      ArcListItem() {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.stateColor)
            .margin({ right: 5 })
          Text('设置')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 6 })
      }
      .width('82%')

      // 当前连接状态
      ArcListItem() {
          Column() {
            if (this.currentUrl !== '') {
              Text(this.currentName !== '' ? this.currentName : this.currentUrl)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#C0B8E0')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.currentUrl)
                .fontSize(11)
                .fontColor('#666666')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            } else {
              Text('未选择服务器')
                .fontSize(14)
                .fontColor('#888888')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 4 })
        }
        .width('82%')

        // 连接/断开按钮
        ArcListItem() {
          Column() {
            Button(this.wsState === WsState.CONNECTED ? '断开' : '连接')
              .fontSize(16)
              .fontColor(this.wsState === WsState.CONNECTED ? '#FF6666' : Color.White)
              .backgroundColor(this.wsState === WsState.CONNECTED ? '#3a1a1a' : '#C0B8E0')
              .width(100)
              .height(38)
              .borderRadius(19)
              .onClick(() => {
                if (this.wsState === WsState.CONNECTED) { this.disconnect(); }
                else { this.connect(); }
              })

            Row() {
              Circle({ width: 8, height: 8 })
                .fill(this.wsState === WsState.CONNECTED ? '#00FF88' :
                  this.wsState === WsState.CONNECTING ? '#FFB347' : '#FF6666')
                .margin({ right: 4 })
              Text(this.statusText)
                .fontSize(12)
                .fontColor('#AAAAAA')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 6 })
          }
          .width('100%')
          .padding({ top: 6, bottom: 8 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('82%')

        // 添加服务器
        ArcListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.plus_circle'))
              .fontColor(['#C0B8E0'])
              .fontSize(18)
              .margin({ right: 6 })
            Text('添加服务器')
              .fontSize(14)
              .fontColor('#C0B8E0')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => { router.pushUrl({ url: 'pages/EditServerPage' }); })
        }
        .width('82%')

        // 服务器列表
        if (this.servers.length === 0) {
          ArcListItem() {
            Text('暂无历史连接')
              .fontSize(12)
              .fontColor('#666666')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 20, bottom: 20 })
          }
          .width('82%')
        }

        ForEach(this.servers, (server: OneBotServerInfo, index: number) => {
          ArcListItem() {
            Column() {
              Text(server.name !== '' ? server.name : server.url)
                .fontSize(14)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Center)
              if (server.accessToken !== '') {
                Text('已设置密钥')
                  .fontSize(10)
                  .fontColor('#888888')
                  .margin({ top: 2 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 10, bottom: 10 })
            .onClick(() => { this.selectServer(server); })
          }
          .width('82%')
          .backgroundColor(server.url === this.currentUrl ? '#1a2a3a' : 'transparent')
          .borderRadius(8)
          .swipeAction({
            end: {
              builder: () => { this.endSwipe(server); },
              actionAreaDistance: 64
            }
          })
        }, (server: OneBotServerInfo, index: number) => index.toString())

        // 自动重连
        ArcListItem() {
          Row() {
            Text('自动重连')
              .fontSize(13)
              .fontColor(Color.White)
              .margin({ right: 10 })
            Toggle({ type: ToggleType.Switch, isOn: this.autoReconnect })
              .onChange((value: boolean) => {
                this.autoReconnect = value;
                this.wsManager.setReconnectEnabled(value);
                this.configManager.setBoolean('auto_reconnect', value);
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 10 })
        }
        .width('82%')

        // 清除缓存
        ArcListItem() {
          Row() {
            Text('清除缓存')
              .fontSize(13)
              .fontColor('#FF6666')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .onClick(() => {
            this.clearCache();
          })
        }
        .width('82%')

        // Debug 入口
        ArcListItem() {
          Text('Debug 调试面板')
            .fontSize(14)
            .fontColor('#C0B8E0')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => { router.pushUrl({ url: 'pages/DebugPage' }); })
        }
        .width('82%')

        // 刷新日志入口
        ArcListItem() {
          Text('消息刷新日志')
            .fontSize(14)
            .fontColor('#00FF88')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => { router.pushUrl({ url: 'pages/RefreshLogPage' }); })
        }
        .width('82%')

        // Crown 调试入口
        ArcListItem() {
          Text('表冠旋转调试')
            .fontSize(14)
            .fontColor('#FFB347')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => { router.pushUrl({ url: 'pages/CrownDebugPage' }); })
        }
        .width('82%')

        // 视频调试入口
        ArcListItem() {
          Text('视频播放调试')
            .fontSize(14)
            .fontColor('#4DA6FF')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => { router.pushUrl({ url: 'pages/VideoDebugPage' }); })
        }
        .width('82%')
      }
      .width('100%')
      .height('100%')
      .space(LengthMetrics.vp(4))
      .focusable(true)
      .focusOnTouch(true)
      .defaultFocus(true)
      .groupDefaultFocus(true)
      .id('settingsArcList')
      .scrollBar(BarState.Off)
      .padding({ left: 12, right: 12 })
  }
}
