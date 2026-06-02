import { ArcList, ArcListItem, LengthMetrics, router } from '@kit.ArkUI';
import { ChatStore, GroupMember, ChatItem, ContactItem } from '../model/ChatStore';
import { OneBotRequest } from '../model/OneBotModel';
import { WebSocketManager } from '../model/WebSocketManager';
import { ConfigManager } from '../model/ConfigManager';
import { RefreshLogger } from '../model/RefreshLogger';

class ProfileParams {
  type: string = 'private';   // private / group / member
  peerId: number = 0;         // QQ号或群号
  peerName: string = '';      // 名称
  groupId: number = 0;        // member类型时的群号
  userId: number = 0;         // member类型时的QQ号
}

@Entry
@Component
struct ProfilePage {
  private chatStore: ChatStore = ChatStore.getInstance();
  private configManager: ConfigManager = ConfigManager.getInstance();
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  @State avatarInitial: string = '?';
  @State avatarColor: string = '#C0B8E0';
  @State avatarUrl: string = '';
  @State title: string = '';
  @State subtitle: string = '';
  @State fields: ProfileField[] = [];
  @State isMuted: boolean = false;
  @State loading: boolean = true;
  @State chatId: string = '';
  params: ProfileParams = new ProfileParams();

  aboutToAppear(): void {
    let raw = this.getUIContext().getRouter().getParams() as ProfileParams;
    if (raw !== undefined) {
      this.params = raw;
    }
    this.load();
  }

  async load(): Promise<void> {
    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);

    let p = this.params;
    this.chatId = (p.type === 'member' || p.type === 'private') ? ChatStore.chatId(p.type === 'member' ? 'group' : 'private', p.peerId) : ChatStore.chatId('group', p.peerId);
    // setup avatar
    this.avatarUrl = this.getAvatarUrl();
    this.avatarInitial = this.getInitial(p.peerName || '');
    this.avatarColor = this.getAvatarColor(p.peerName || '');

    if (p.type === 'private' || p.type === 'member') {
      this.title = p.peerName || String(p.userId || p.peerId);
      this.subtitle = String(p.userId || p.peerId);
      this.fields = this.buildUserFields();
    } else {
      this.title = p.peerName || String(p.peerId);
      this.subtitle = '群号: ' + p.peerId;
      this.fields = [];
    }

    // 加载免打扰状态
    let mutedJson = await this.configManager.getString('muted_chats', '[]');
    this.isMuted = mutedJson.indexOf('"' + this.chatId + '"') >= 0;

    // 异步拉取详细信息
    if (p.type === 'private' && p.peerId > 0) {
      await this.loadUserInfo(p.peerId);
    } else if (p.type === 'member' && p.userId > 0 && p.groupId > 0) {
      await this.loadMemberInfo(p.groupId, p.userId);
    } else if (p.type === 'group' && p.peerId > 0) {
      await this.loadGroupInfo(p.peerId);
    }
    this.loading = false;
  }

  async loadUserInfo(userId: number): Promise<void> {
    // 先查本地联系人备注
    let contacts = await this.chatStore.getContacts();
    for (let c of contacts) {
      if (c.userId === userId) {
        if (c.remark !== '') { this.title = c.remark; }
        if (c.nickname !== '') { this.subtitle = '昵称: ' + c.nickname; }
        break;
      }
    }
    // 查陌生人信息
    let req = OneBotRequest.createGetStrangerInfo(userId);
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let info = data['data'] as Record<string, Object> || {};
      let sex = String(info['sex'] || '');
      let age = parseInt(String(info['age'] || '0'));
      if (sex !== '' || age > 0) {
        this.fields = this.buildUserFieldsFrom(sex, age, info);
      }
    });
  }

  async loadMemberInfo(groupId: number, userId: number): Promise<void> {
    // 先查缓存
    let m = this.chatStore.getGroupMember(groupId, userId);
    if (m !== null) {
      this.fields = this.buildMemberFields(m);
    }
    // 实时拉取
    let req = OneBotRequest.createGetGroupMemberInfo(groupId, userId);
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let info = data['data'] as Record<string, Object> || {};
      let member = new GroupMember();
      member.userId = userId;
      member.nickname = String(info['nickname'] || '');
      member.card = String(info['card'] || '');
      member.role = String(info['role'] || '');
      member.title = String(info['title'] || '');
      member.sex = String(info['sex'] || '');
      member.age = parseInt(String(info['age'] || '0'));
      member.area = String(info['area'] || '');
      member.level = String(info['level'] || '');
      member.qqLevel = parseInt(String(info['qq_level'] || '0'));
      member.joinTime = parseInt(String(info['join_time'] || '0'));
      member.lastSentTime = parseInt(String(info['last_sent_time'] || '0'));
      this.fields = this.buildMemberFields(member);
    });
  }

  async loadGroupInfo(groupId: number): Promise<void> {
    let groups = await this.chatStore.getGroups();
    for (let g of groups) {
      if (g.groupId === groupId) {
        this.subtitle = '群号: ' + groupId + '  成员: ' + g.memberCount;
        this.fields = this.buildGroupFields(groupId, g.memberCount);
        return;
      }
    }
    // 实时拉取
    let req = OneBotRequest.createGetGroupDetailInfo(groupId);
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      let info = data['data'] as Record<string, Object> || {};
      let name = String(info['group_name'] || '');
      let count = parseInt(String(info['member_count'] || '0'));
      if (name !== '') { this.title = name; }
      this.subtitle = '群号: ' + groupId + '  成员: ' + count;
    });
  }

  buildGroupFields(groupId: number, count: number): ProfileField[] {
    let result: ProfileField[] = [];
    result.push(new ProfileField('群号', String(groupId)));
    if (count > 0) { result.push(new ProfileField('成员数', String(count))); }
    return result;
  }

  buildUserFields(): ProfileField[] {
    let result: ProfileField[] = [];
    if (this.params.type !== 'member') {
      result.push(new ProfileField('QQ', String(this.params.peerId)));
    }
    return result;
  }

  buildUserFieldsFrom(sex: string, age: number, info: Record<string, Object>): ProfileField[] {
    let result: ProfileField[] = [];
    result.push(new ProfileField('QQ', String(this.params.peerId)));
    if (sex !== '' && sex !== 'unknown') { result.push(new ProfileField('性别', sex === 'male' ? '男' : (sex === 'female' ? '女' : sex))); }
    if (age > 0) { result.push(new ProfileField('年龄', String(age))); }
    return result;
  }

  buildMemberFields(m: GroupMember): ProfileField[] {
    let result: ProfileField[] = [];
    if (m.card !== '') { result.push(new ProfileField('群名片', m.card)); }
    if (m.nickname !== '') { result.push(new ProfileField('昵称', m.nickname)); }
    result.push(new ProfileField('QQ', String(m.userId)));
    let roleLabel = '成员';
    if (m.role === 'owner') { roleLabel = '群主'; }
    else if (m.role === 'admin') { roleLabel = '管理员'; }
    result.push(new ProfileField('角色', roleLabel));
    if (m.title !== '') { result.push(new ProfileField('头衔', m.title)); }
    if (m.sex !== '' && m.sex !== 'unknown') { result.push(new ProfileField('性别', m.sex === 'male' ? '男' : (m.sex === 'female' ? '女' : m.sex))); }
    if (m.age > 0) { result.push(new ProfileField('年龄', String(m.age))); }
    if (m.area !== '') { result.push(new ProfileField('地区', m.area)); }
    if (m.level !== '') { result.push(new ProfileField('等级', m.level)); }
    if (m.qqLevel > 0) { result.push(new ProfileField('QQ等级', String(m.qqLevel))); }
    if (m.joinTime > 0) {
      let d = new Date(m.joinTime * 1000);
      result.push(new ProfileField('入群时间', d.getFullYear() + '-' + (d.getMonth()+1).toString().padStart(2,'0') + '-' + d.getDate().toString().padStart(2,'0')));
    }
    return result;
  }

  getAvatarUrl(): string {
    let id = this.params.userId || this.params.peerId;
    if (this.params.type === 'group') {
      return 'https://p.qlogo.cn/gh/' + id + '/' + id + '/100';
    }
    return 'https://q1.qlogo.cn/g?b=qq&nk=' + id + '&s=100';
  }

  getInitial(name: string): string {
    return name.length > 0 ? name.charAt(0) : '?';
  }

  getAvatarColor(name: string): string {
    let colors: string[] = ['#C0B8E0', '#FFB347', '#4DA6FF', '#00CC88', '#FF7777', '#77BBFF'];
    let sum = 0;
    for (let i = 0; i < name.length; i++) { sum += name.charCodeAt(i); }
    return colors[sum % colors.length];
  }

  async toggleMute(): Promise<void> {
    this.isMuted = !this.isMuted;
    let mutedJson = await this.configManager.getString('muted_chats', '[]');
    let list: string[] = [];
    try { list = JSON.parse(mutedJson) as string[]; } catch (_e) {}
    if (this.isMuted) {
      if (list.indexOf(this.chatId) < 0) { list.push(this.chatId); }
    } else {
      let newList: string[] = [];
      for (let id of list) { if (id !== this.chatId) { newList.push(id); } }
      list = newList;
    }
    await this.configManager.setString('muted_chats', JSON.stringify(list));
    RefreshLogger.getInstance().log('PROF-MUTE', 'chatId=' + this.chatId + ' muted=' + this.isMuted);
  }

  build() {
    ArcList() {
      // 头像区域
      ArcListItem() {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(60)
            .height(60)
            .fill(this.avatarColor)
          Text(this.avatarInitial)
            .fontSize(24)
            .fontColor(Color.White)
          Image(this.avatarUrl)
            .width(60)
            .height(60)
            .borderRadius(30)
            .objectFit(ImageFit.Cover)
        }
        .width(60)
        .height(60)
        .margin({ top: 10, bottom: 6 })
      }
      .width('82%')

      // 标题
      ArcListItem() {
        Column() {
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textAlign(TextAlign.Center)
          Text(this.subtitle)
            .fontSize(12)
            .fontColor('#888888')
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 10 })
      }
      .width('82%')

      // 加载
      if (this.loading) {
        ArcListItem() {
          Column() {
            LoadingProgress()
              .width(30)
              .height(30)
              .color('#C0B8E0')
            Text('加载中...')
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 12, bottom: 12 })
        }
        .width('82%')
      }

      // 字段
      if (this.fields.length > 0) {
        ArcListItem() {
          Column() {
            ForEach(this.fields, (f: ProfileField) => {
              Row() {
                Text(f.label)
                  .fontSize(13)
                  .fontColor('#888888')
                  .width('35%')
                Text(f.value)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ top: 7, bottom: 7 })
            }, (f: ProfileField) => f.label)
          }
          .width('100%')
          .padding({ top: 6, bottom: 6, left: 12, right: 12 })
          .borderRadius(10)
          .backgroundColor('#1a1a1a')
        }
        .width('82%')
        .margin({ bottom: 8 })
      }

      // 免打扰
      if (this.params.type === 'private' || this.params.type === 'group') {
        ArcListItem() {
          Row() {
            Text('免打扰')
              .fontSize(13)
              .fontColor(Color.White)
              .margin({ right: 8 })
            Toggle({ type: ToggleType.Switch, isOn: this.isMuted })
              .onChange((value: boolean) => {
                // 先切状态再保存（toggle 会翻转，但 value 已经是最终值）
                if (this.isMuted !== value) {
                  this.isMuted = value;
                  this.toggleMute();
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 10 })
        }
        .width('82%')
      }

      // 关闭
      ArcListItem() {
        Text('关闭')
          .fontSize(13)
          .fontColor('#AAAAAA')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .onClick(() => { router.back(); })
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
    .id('profileArcList')
    .scrollBar(BarState.Auto)
    .backgroundColor(Color.Black)
    .padding({ left: 12, right: 12 })
  }
}

class ProfileField {
  label: string;
  value: string;
  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}
