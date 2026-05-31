import { WebSocketManager } from './WebSocketManager';
import { ChatStore, ChatItem, CachedMessage, ContactItem, GroupItem } from './ChatStore';
import { MessageFormatter } from './MessageFormatter';
import { OneBotMessage, OneBotRequest, WsState } from './OneBotModel';
import { ConfigManager } from './ConfigManager';
import { RefreshLogger } from './RefreshLogger';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MessageCenter';
const DOMAIN = 0x0007;

type MessageHandler = (msg: OneBotMessage) => void;

export class MessageCenter {
  private static instance: MessageCenter;
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private chatStore: ChatStore = ChatStore.getInstance();
  private configManager: ConfigManager = ConfigManager.getInstance();
  private selfId: number = 0;
  private initialized: boolean = false;

  private chatHandlers: Map<string, MessageHandler> = new Map();
  private globalHandlers: MessageHandler[] = [];

  onContactsLoaded?: () => void;
  onSelfInfoLoaded?: (userId: number, nickname: string) => void;

  static getInstance(): MessageCenter {
    if (MessageCenter.instance === undefined) {
      MessageCenter.instance = new MessageCenter();
    }
    return MessageCenter.instance;
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    this.wsManager.addMessageListener((msg: OneBotMessage) => {
      this.onWsMessage(msg);
    });

    this.wsManager.addStateListener((state: WsState) => {
      if (state === WsState.CONNECTED) {
        this.onConnected();
      }
    });

    let selfIdStr = await this.configManager.getString('self_id', '0');
    this.selfId = parseInt(selfIdStr) || 0;
    MessageFormatter.setSelfId(this.selfId);

    hilog.info(DOMAIN, TAG, 'MessageCenter initialized');
  }

  getSelfId(): number {
    return this.selfId;
  }

  registerChatHandler(chatId: string, handler: MessageHandler): void {
    this.chatHandlers.set(chatId, handler);
    RefreshLogger.getInstance().log('MC-REG', 'chatId=' + chatId + ' totalH=' + this.chatHandlers.size);
  }

  unregisterChatHandler(chatId: string): void {
    this.chatHandlers.delete(chatId);
    RefreshLogger.getInstance().log('MC-UNREG', 'chatId=' + chatId + ' totalH=' + this.chatHandlers.size);
  }

  addGlobalHandler(handler: MessageHandler): void {
    let found = false;
    for (let h of this.globalHandlers) {
      if (h === handler) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.globalHandlers.push(handler);
    }
  }

  removeGlobalHandler(handler: MessageHandler): void {
    let newList: MessageHandler[] = [];
    for (let h of this.globalHandlers) {
      if (h !== handler) {
        newList.push(h);
      }
    }
    this.globalHandlers = newList;
  }

  private async onConnected(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Connected, fetching login info and contacts...');

    // 流程与 Stapxs QQ Lite 一致: login_info → recent_contact → friend/group list
    let loginReq = OneBotRequest.createGetLoginInfo();
    this.wsManager.sendRequestWithCallback(loginReq, (data: Record<string, Object>) => {
      this.handleSelfInfo(data);
    });

    let recentReq = OneBotRequest.createGetRecentContact();
    this.wsManager.sendRequestWithCallback(recentReq, (data: Record<string, Object>) => {
      this.handleRecentContact(data);
    });

    let friendReq = OneBotRequest.createGetFriendList();
    this.wsManager.sendRequestWithCallback(friendReq, (data: Record<string, Object>) => {
      this.handleFriendList(data);
    });

    let groupReq = OneBotRequest.createGetGroupList();
    this.wsManager.sendRequestWithCallback(groupReq, (data: Record<string, Object>) => {
      this.handleGroupList(data);
    });
  }

  private async handleRecentContact(data: Record<string, Object>): Promise<void> {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode !== 0) {
        return;
      }
      let list = data['data'] as Object[];
      if (list === undefined || list.length === 0) {
        return;
      }
      // get_recent_contact 返回: [{peerUin, msgTime, chatType, peerName, ...}]
      // chatType: 1=private, 2=group
      for (let item of list) {
        let obj = item as Record<string, Object>;
        let chatType = parseInt(String(obj['chatType'] || '0'));
        if (chatType !== 1 && chatType !== 2) {
          continue;
        }
        let peerId = parseInt(String(obj['peerUin'] || '0'));
        if (peerId === 0) {
          continue;
        }
        let chatItem = new ChatItem();
        chatItem.chatType = chatType === 2 ? 'group' : 'private';
        chatItem.peerId = peerId;
        chatItem.chatId = ChatStore.chatId(chatItem.chatType, peerId);
        chatItem.peerName = String(obj['peerName'] || '');
        chatItem.lastMessage = String(obj['abstract'] || '');
        chatItem.lastMessageTime = parseInt(String(obj['msgTime'] || '0')) * 1000;
        chatItem.unreadCount = parseInt(String(obj['unreadCnt'] || '0'));
        await this.chatStore.upsertChat(chatItem);
      }
      hilog.info(DOMAIN, TAG, `Recent contacts loaded: ${list.length} items`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `handleRecentContact error: ${e}`);
    }
  }

  private async handleSelfInfo(data: Record<string, Object>): Promise<void> {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        let info = data['data'] as Record<string, Object>;
        this.selfId = parseInt(String(info['user_id'] || '0'));
        let nickname = String(info['nickname'] || '');
        MessageFormatter.setSelfId(this.selfId);
        await this.configManager.setString('self_id', String(this.selfId));
        hilog.info(DOMAIN, TAG, `Self info loaded: ${this.selfId} (${nickname})`);
        if (this.onSelfInfoLoaded) {
          this.onSelfInfoLoaded(this.selfId, nickname);
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `handleSelfInfo error: ${e}`);
    }
  }

  private async handleFriendList(data: Record<string, Object>): Promise<void> {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        let payload = data['data'] as Object[];
        let contacts: ContactItem[] = [];
        for (let item of payload) {
          let obj = item as Record<string, Object>;
          // get_friends_with_category 返回: {categoryId, categoryName, buddyList: [{user_id, nickname, remark}]}
          let buddyList = obj['buddyList'] as Object[];
          if (buddyList) {
            for (let buddy of buddyList) {
              let b = buddy as Record<string, Object>;
              let c = new ContactItem();
              c.userId = parseInt(String(b['user_id'] || '0'));
              c.nickname = String(b['nickname'] || '');
              c.remark = String(b['remark'] || '');
              contacts.push(c);
            }
          }
        }
        if (contacts.length > 0) {
          await this.chatStore.saveContacts(contacts);
        }
        hilog.info(DOMAIN, TAG, `Friend list loaded: ${contacts.length} contacts`);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `handleFriendList error: ${e}`);
    }
    if (this.onContactsLoaded) {
      this.onContactsLoaded();
    }
  }

  private async handleGroupList(data: Record<string, Object>): Promise<void> {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        let list = data['data'] as Object[];
        let groups: GroupItem[] = [];
        for (let item of list) {
          let obj = item as Record<string, Object>;
          let g = new GroupItem();
          g.groupId = parseInt(String(obj['group_id'] || '0'));
          g.groupName = String(obj['group_name'] || '');
          g.memberCount = parseInt(String(obj['member_count'] || '0'));
          groups.push(g);
        }
        if (groups.length > 0) {
          await this.chatStore.saveGroups(groups);
        }
        hilog.info(DOMAIN, TAG, `Group list loaded: ${groups.length} groups`);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `handleGroupList error: ${e}`);
    }
    if (this.onContactsLoaded) {
      this.onContactsLoaded();
    }
  }

  private async onWsMessage(msg: OneBotMessage): Promise<void> {
    let rl = RefreshLogger.getInstance();
    rl.log('MC', 'pt=' + msg.post_type + ' nt=' + (msg.notice_type||'') + ' mt=' + msg.message_type);

    try {
      await this.processMessage(msg);
    } catch (e) {
      rl.log('MC-ERR', 'processMessage threw: ' + (e as Error).message);
    }
  }

  private async processMessage(msg: OneBotMessage): Promise<void> {
    let rl = RefreshLogger.getInstance();

    if (msg.post_type === 'notice') {
      this.handleNotice(msg);
      return;
    }

    if (msg.post_type !== 'message') {
      rl.log('MC-SKIP', 'not message event');
      return;
    }

    let chatId = ((msg.message_type || '') === 'group') ?
      'group_' + msg.group_id : 'private_' + msg.user_id;
    let selfId = this.selfId;

    let cm = MessageFormatter.toCachedMessage(msg, selfId);
    await this.chatStore.saveMessage(cm);
    let chatItem = MessageFormatter.buildChatItem(msg, selfId);
    this.chatStore.upsertChat(chatItem);

    let handler = this.chatHandlers.get(chatId);
    rl.log('MC-DISP', 'chatId=' + chatId + ' hasH=' + (handler !== undefined));
    if (handler !== undefined) {
      handler(msg);
    }

    for (let h of this.globalHandlers) {
      h(msg);
    }
  }

  private async handleNotice(msg: OneBotMessage): Promise<void> {
    let nt = msg.notice_type || '';

    // 消息撤回
    if (nt === 'friend_recall' || nt === 'group_recall') {
      let msgId = msg.message_id;
      await this.chatStore.markRevoked(msgId);

      // 通知聊天页面刷新
      let chatId = nt.includes('group') ?
        'group_' + msg.group_id : 'private_' + msg.user_id;
      let handler = this.chatHandlers.get(chatId);
      if (handler) {
        handler(msg);
      }
      for (let h of this.globalHandlers) {
        h(msg);
      }
    }
  }
}
