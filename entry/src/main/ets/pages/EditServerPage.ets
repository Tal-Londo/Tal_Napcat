import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ConfigManager } from '../model/ConfigManager';
import { OneBotServerInfo } from '../model/OneBotModel';

@Entry
@Component
struct EditServerPage {
  private configManager: ConfigManager = ConfigManager.getInstance();
  @State isEdit: boolean = false;
  @State pageTitle: string = '添加服务器';
  @State serverUrl: string = '';
  @State serverName: string = '';
  @State accessToken: string = '';
  private editUrl: string = '';

  async aboutToAppear(): Promise<void> {
    let context: Context = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(context);
    let params = router.getParams() as Record<string, string>;
    if (params !== undefined && params !== null) {
      let url = params['url'];
      if (url !== undefined && url !== '') {
        this.editUrl = url;
        this.isEdit = true;
        this.pageTitle = '编辑服务器';
        await this.loadServer(url);
      }
    }
  }

  async loadServer(url: string): Promise<void> {
    let json = await this.configManager.getString('history_servers', '[]');
    try {
      let arr = JSON.parse(json) as Object[];
      for (let item of arr) {
        let info = OneBotServerInfo.fromJson(JSON.stringify(item));
        if (info.url === url) {
          this.serverUrl = info.url;
          this.serverName = info.name;
          this.accessToken = info.accessToken;
          return;
        }
      }
    } catch (e) {
    }
  }

  build() {
    Scroll() {
    Column() {
      Text(this.pageTitle)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .margin({ top: 16, bottom: 14 })

      Text('服务器地址')
        .fontSize(11)
        .fontColor('#888888')
        .width('82%')
        .margin({ bottom: 4 })
      TextInput({ text: this.serverUrl, placeholder: 'wss://192.168.1.100:8099' })
        .fontSize(14)
        .fontColor(Color.White)
        .placeholderColor('#555555')
        .backgroundColor('#1a1a1a')
        .width('82%')
        .height(38)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => { this.serverUrl = v; })
        .margin({ bottom: 12 })

      Text('Access Token (连接密钥)')
        .fontSize(11)
        .fontColor('#888888')
        .width('82%')
        .margin({ bottom: 4 })
      TextInput({ text: this.accessToken, placeholder: 'Napcat 中配置的 token' })
        .fontSize(14)
        .fontColor(Color.White)
        .placeholderColor('#555555')
        .backgroundColor('#1a1a1a')
        .width('82%')
        .height(38)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .type(InputType.Password)
        .onChange((v: string) => { this.accessToken = v; })
        .margin({ bottom: 12 })

      Text('服务器名称（可选）')
        .fontSize(11)
        .fontColor('#888888')
        .width('82%')
        .margin({ bottom: 4 })
      TextInput({ text: this.serverName, placeholder: '我的 Napcat' })
        .fontSize(14)
        .fontColor(Color.White)
        .placeholderColor('#555555')
        .backgroundColor('#1a1a1a')
        .width('82%')
        .height(38)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => { this.serverName = v; })
        .margin({ bottom: 20 })

      Row() {
        Button('保存')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#C0B8E0')
          .width('76%')
          .height(38)
          .borderRadius(19)
          .onClick(() => { this.onSave(); })
      }
      .width('82%')
      .justifyContent(FlexAlign.Center)

      if (this.isEdit) {
        Button('删除此服务器')
          .fontSize(13)
          .fontColor('#FF6666')
          .backgroundColor('#2a1a1a')
          .width('65%')
          .height(36)
          .borderRadius(18)
          .margin({ top: 16 })
          .onClick(() => { this.onDelete(); })
      }
    }
    .width('100%')
    .backgroundColor(Color.Black)
    .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
  }

  validateUrl(url: string): string {
    let trimmed = url.trim();
    if (!trimmed.startsWith('ws://') && !trimmed.startsWith('wss://')) {
      trimmed = 'ws://' + trimmed;
    }
    return trimmed;
  }

  async onSave(): Promise<void> {
    let url = this.serverUrl.trim();
    if (url === '') {
      promptAction.showToast({ message: '请输入服务器地址' });
      return;
    }
    url = this.validateUrl(url);

    let info = new OneBotServerInfo();
    info.url = url;
    info.name = this.serverName.trim();
    info.accessToken = this.accessToken.trim();
    info.lastConnected = Date.now();

    // 保存到历史列表
    let json = await this.configManager.getString('history_servers', '[]');
    let arr: OneBotServerInfo[] = [];
    try {
      let raw = JSON.parse(json) as Object[];
      for (let item of raw) {
        let existing = OneBotServerInfo.fromJson(JSON.stringify(item));
        if (existing.url !== '' && existing.url !== this.editUrl) {
          arr.push(existing);
        }
      }
    } catch (e) {
    }
    arr.unshift(info);
    if (arr.length > 10) {
      arr = arr.slice(0, 10);
    }
    await this.configManager.setString('history_servers', JSON.stringify(arr));

    // 同时设为当前服务器
    await this.configManager.setString('server_url', info.url);
    await this.configManager.setString('access_token', info.accessToken);
    await this.configManager.setString('server_name', info.name);

    promptAction.showToast({ message: this.isEdit ? '已更新' : '已添加' });
    router.back();
  }

  async onDelete(): Promise<void> {
    let json = await this.configManager.getString('history_servers', '[]');
    let arr: OneBotServerInfo[] = [];
    try {
      let raw = JSON.parse(json) as Object[];
      for (let item of raw) {
        let existing = OneBotServerInfo.fromJson(JSON.stringify(item));
        if (existing.url !== '' && existing.url !== this.editUrl) {
          arr.push(existing);
        }
      }
    } catch (e) {
    }
    await this.configManager.setString('history_servers', JSON.stringify(arr));
    promptAction.showToast({ message: '已删除' });
    router.back();
  }
}
