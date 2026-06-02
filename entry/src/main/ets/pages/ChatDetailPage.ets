import { router, ArcButton, ArcButtonOptions, ArcButtonStyleMode, ArcButtonPosition, LengthUnit, ColorMetrics, LengthMetrics, ArcList, ArcListItem } from '@kit.ArkUI';
import { WebSocketManager } from '../model/WebSocketManager';
import { ChatStore, CachedMessage, ChatItem, GroupMember } from '../model/ChatStore';
import { MessageFormatter } from '../model/MessageFormatter';
import { MessageCenter } from '../model/MessageCenter';
import { OneBotMessage, OneBotRequest } from '../model/OneBotModel';
import { ConfigManager } from '../model/ConfigManager';
import { MsgBubble } from '../components/MsgBubble';
import { FaceStore } from '../model/FaceStore';
import { RefreshLogger } from '../model/RefreshLogger';
import { ChatMessagesDataSource } from './model/ChatMessagesDataSource';


class RouteParams {
  peer_id: number = 0;
  peer_name: string = '';
  chat_type: string = '';
}

@Entry
@Component
struct ChatDetailPage {
  private wsManager: WebSocketManager = WebSocketManager.getInstance();
  private chatStore: ChatStore = ChatStore.getInstance();
  private configManager: ConfigManager = ConfigManager.getInstance();
  private msgCenter: MessageCenter = MessageCenter.getInstance();
  private selfId: number = 0;
  @State messages: CachedMessage[] = [];
  messagesDataSource: ChatMessagesDataSource = new ChatMessagesDataSource([]);
  scrollScroller: Scroller = new Scroller();

  @State peerName: string = '';
  @State peerId: number = 0;
  @State chatType: string = 'private';
  @State chatId: string = '';
  @State inputText: string = '';
  @State title: string = '';
  @State loading: boolean = true;
  @State menuMsg: CachedMessage | null = null;
  private myRole: string = '';
  private myTitle: string = '';
  private shutUpUntil: number = 0;
  private groupAllShut: boolean = false;
  @State canSend: boolean = true;

  aboutToAppear(): void {
    let raw = this.getUIContext().getRouter().getParams() as RouteParams;
    if (raw && raw.peer_id) {
      this.peerId = raw.peer_id || 0;
      this.peerName = raw.peer_name || '';
      this.chatType = raw.chat_type || 'private';
      this.chatId = ChatStore.chatId(this.chatType, this.peerId);
      this.title = this.peerName || this.chatId;
    } else {
      this.chatId = 'default';
      this.title = '聊天';
    }
    this.initPage();
  }

  aboutToDisappear(): void {
    this.msgCenter.unregisterChatHandler(this.chatId);
  }

  onPageShow(): void {
    // 从 SendMessagePage 返回时重新加载 DB，拾取刚发的新占位消息
    this.loadHistorySilent();
    // 重置未读计数
    this.chatStore.resetUnread(this.chatId);
  }

  async initPage(): Promise<void> {
    let context: Context = this.getUIContext().getHostContext() as Context;
    await this.chatStore.initDb(context);
    await this.configManager.initDb(context);

    this.selfId = this.msgCenter.getSelfId();
    if (this.selfId === 0) {
      let selfIdStr = await this.configManager.getString('self_id', '0');
      this.selfId = parseInt(selfIdStr) || 0;
      MessageFormatter.setSelfId(this.selfId);
    }

    RefreshLogger.getInstance().log('CDP-INIT', 'registering handler for chatId=' + this.chatId);
    this.msgCenter.registerChatHandler(this.chatId, (msg: OneBotMessage) => {
      RefreshLogger.getInstance().log('CDP-CALLBACK', 'arrow fn entered pt=' + msg.post_type);
      try {
        this.handleWsEvent(msg);
      } catch (e) {
        RefreshLogger.getInstance().log('CDP-ERR', 'handleWsEvent threw: ' + (e as Error).message);
      }
    });

    await this.loadHistory();
    // 进入聊天时重置未读计数
    this.chatStore.resetUnread(this.chatId);
  }

  async loadHistory(): Promise<void> {
    let cached: CachedMessage[] = await this.chatStore.getMessages(this.chatId, 100);
    // 清理：Napcat 不推送自己发的消息，占位消息在服务端回执后被替换
    // 所有负 messageId 的占位消息如果没有对应的服务端消息就保留
    let deduped: CachedMessage[] = [];
    let seenIds: Set<number> = new Set();
    let selfTexts: Record<string, number> = {}; // rawMessage -> index of real self-sent msg
    let placeholderIndexes: number[] = [];

    // 第一遍：收集服务端下发的自己发送的消息
    for (let cm of cached) {
      cm.isSelf = cm.userId === this.selfId;
      if (cm.messageId > 0) {
        if (seenIds.has(cm.messageId)) {
          for (let i = 0; i < deduped.length; i++) {
            if (deduped[i].messageId === cm.messageId) {
              if (!deduped[i].isRevoked() && cm.isRevoked()) {
                deduped[i] = cm;
              }
              break;
            }
          }
        } else {
          seenIds.add(cm.messageId);
          deduped.push(cm);
          if (cm.isSelf && cm.msgType === 'text' && cm.rawMessage !== '') {
            selfTexts[cm.rawMessage] = deduped.length - 1;
          }
        }
      }
    }

    // 第二遍：处理占位消息
    for (let cm of cached) {
      if (cm.messageId > 0) { continue; }
      cm.isSelf = cm.userId === this.selfId;
      // 补齐旧版占位的 userId/nickname
      if (cm.isSelf && cm.userId === 0) {
        cm.userId = this.selfId;
        cm.nickname = '我';
      }
      // 如果服务端已经有相同内容的真实消息，删除占位
      let realIdx = selfTexts[cm.rawMessage];
      if (realIdx !== undefined) {
        // 服务端消息已存在 → 跳过占位
        continue;
      }
      deduped.push(cm);
    }
    deduped.sort((a, b) => a.timestamp - b.timestamp);
    this.messages = deduped;
    this.messagesDataSource.setMessages(deduped);
    this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
    this.loading = false;
    this.scrollToBottom();
    this.requestArcListFocus();

    // 从缓存中推断自己的角色，补全 senderRole
    this.inferMyRole();
    if (this.chatType === 'group') {
      for (let m of deduped) {
        this.fillSenderRole(m);
      }
    }

    let req: OneBotRequest = OneBotRequest.createGetMsgHistory(
      this.peerId, this.chatType, undefined, 20);
    this.wsManager.sendRequestWithCallback(req, (data: Record<string, Object>) => {
      this.handleHistoryResponse(data);
    });

    // 群聊：主动获取自己在群中的角色 + 成员列表
    if (this.chatType === 'group' && this.selfId > 0) {
      let roleReq = OneBotRequest.createGetGroupMemberInfo(this.peerId, this.selfId);
      this.wsManager.sendRequestWithCallback(roleReq, (data: Record<string, Object>) => {
        this.handleRoleResponse(data);
      });

      let memberListReq = OneBotRequest.createGetGroupMemberList(this.peerId);
      this.wsManager.sendRequestWithCallback(memberListReq, (data: Record<string, Object>) => {
        this.handleMemberListResponse(data);
      });

      // 获取群信息以检查全员禁言
      let groupInfoReq = OneBotRequest.createGetGroupList();
      this.wsManager.sendRequestWithCallback(groupInfoReq, (data: Record<string, Object>) => {
        this.handleGroupAllShut(data);
      });
    }
  }

  fillSenderRole(cm: CachedMessage): void {
    if (cm.senderRole !== '' || this.chatType !== 'group' || this.peerId <= 0) {
      return;
    }
    let member = this.chatStore.getGroupMember(this.peerId, cm.userId);
    if (member !== null && member.role !== '') {
      cm.senderRole = member.role;
    }
  }

  inferMyRole(): void {
    for (let m of this.messages) {
      if (m.isSelf && m.senderRole !== '') {
        this.myRole = m.senderRole;
        return;
      }
    }
  }

  handleRoleResponse(data: Record<string, Object>): void {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode === 0) {
        let info = data['data'] as Record<string, Object>;
        let role = String(info['role'] || '');
        if (role !== '') {
          this.myRole = role;
        }
        let title = String(info['title'] || '');
        if (title !== '') {
          this.myTitle = title;
        }
        this.shutUpUntil = parseInt(String(info['shut_up_timestamp'] || '0'));
        this.updateCanSend();
      }
    } catch (_e) {
    }
  }

  handleGroupAllShut(data: Record<string, Object>): void {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode !== 0) {
        return;
      }
      let list = data['data'] as Object[];
      if (list === undefined) {
        return;
      }
      for (let item of list) {
        let obj = item as Record<string, Object>;
        let gid = parseInt(String(obj['group_id'] || '0'));
        if (gid === this.peerId) {
          let allShut = parseInt(String(obj['group_all_shut'] || '0'));
          this.groupAllShut = allShut === 1;
          this.updateCanSend();
          break;
        }
      }
    } catch (_e) {
    }
  }

  updateCanSend(): void {
    if (this.chatType !== 'group') {
      this.canSend = true;
      return;
    }
    // 群主和管理员始终能发送
    if (this.myRole === 'owner' || this.myRole === 'admin') {
      this.canSend = true;
      return;
    }
    // 全员禁言
    if (this.groupAllShut) {
      this.canSend = false;
      return;
    }
    // 个人禁言
    let nowSec = Math.floor(Date.now() / 1000);
    if (this.shutUpUntil > 0 && this.shutUpUntil > nowSec) {
      this.canSend = false;
      return;
    }
    this.canSend = true;
  }

  handleMemberListResponse(data: Record<string, Object>): void {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode !== 0) {
        return;
      }
      let list = data['data'] as Object[];
      if (list === undefined || list.length === 0) {
        return;
      }
      let members: GroupMember[] = [];
      for (let item of list) {
        let obj = item as Record<string, Object>;
        let m = new GroupMember();
        m.userId = parseInt(String(obj['user_id'] || '0'));
        m.nickname = String(obj['nickname'] || '');
        m.card = String(obj['card'] || '');
        m.role = String(obj['role'] || '');
        m.title = String(obj['title'] || '');
        m.sex = String(obj['sex'] || '');
        m.age = parseInt(String(obj['age'] || '0'));
        m.area = String(obj['area'] || '');
        m.level = String(obj['level'] || '');
        m.qqLevel = parseInt(String(obj['qq_level'] || '0'));
        m.joinTime = parseInt(String(obj['join_time'] || '0'));
        m.lastSentTime = parseInt(String(obj['last_sent_time'] || '0'));
        members.push(m);
      }
      this.chatStore.setGroupMembers(this.peerId, members);

      // 补充已有消息的 senderRole
      let msgs = [...this.messages];
      let updated = false;
      for (let i = 0; i < msgs.length; i++) {
        if (msgs[i].senderRole === '') {
          let member = this.chatStore.getGroupMember(this.peerId, msgs[i].userId);
          if (member !== null && member.role !== '') {
            let copy = CachedMessage.fromMsg(msgs[i]);
            copy.senderRole = member.role;
            msgs[i] = copy;
            updated = true;
          }
        }
      }
      if (updated) {
        this.messages = msgs;
        this.messagesDataSource.setMessages(msgs);
        this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
      }
    } catch (_e) {
    }
  }

  async handleHistoryResponse(data: Record<string, Object>): Promise<void> {
    try {
      let retcode = data['retcode'] as number ?? 1;
      if (retcode !== 0) {
        return;
      }
      let payload = data['data'] as Record<string, Object>;
      if (payload === undefined) {
        return;
      }
      let msgArr = payload['messages'] as Object[];
      if (msgArr === undefined || msgArr.length === 0) {
        return;
      }

      let existingIds: Set<number> = new Set();
      for (let m of this.messages) {
        if (m.messageId > 0) {
          existingIds.add(m.messageId);
        }
      }

      let newCount = 0;
      let newMessages: CachedMessage[] = [...this.messages];
      for (let item of msgArr) {
        let obj = item as Record<string, Object>;
        let msgId = parseInt(String(obj['message_id'] || '0'));
        if (msgId > 0 && existingIds.has(msgId)) {
          continue;
        }

        let rawMsg = String(obj['raw_message'] || '');
        let sender = obj['sender'] as Record<string, Object> || {};
        let senderId = parseInt(String(sender['user_id'] || '0'));
        let msgTime = parseInt(String(obj['time'] || '0')) * 1000;

        // 自己发送的消息：删除内容相同的占位消息，用服务端数据替换
        if (senderId === this.selfId) {
          let filtered: CachedMessage[] = [];
          let replaced = false;
          for (let m of newMessages) {
            if (m.messageId < 0 && m.isSelf &&
                m.msgType === 'text' && m.rawMessage === rawMsg) {
              await this.chatStore.deleteMessageByMsgId(m.messageId);
              replaced = true;
            } else {
              filtered.push(m);
            }
          }
          if (replaced) {
            // 用服务端真实消息替换
            let cm = this.buildCachedMsg(msgId, sender, obj, rawMsg, msgTime);
            filtered.push(cm);
            await this.chatStore.saveMessage(cm);
            if (msgId > 0) {
              existingIds.add(msgId);
            }
            newMessages = filtered;
            newCount++;
          } else if (msgId > 0 && !existingIds.has(msgId)) {
            // 没有匹配的占位（可能是旧数据或重复拉取），直接追加
            existingIds.add(msgId);
            let cm = this.buildCachedMsg(msgId, sender, obj, rawMsg, msgTime);
            await this.chatStore.saveMessage(cm);
            newMessages.push(cm);
            newCount++;
          }
          continue;
        }

        if (msgId > 0) {
          existingIds.add(msgId);
        }
        let cm = this.buildCachedMsg(msgId, sender, obj, rawMsg, msgTime);
        this.fillSenderRole(cm);
        await this.chatStore.saveMessage(cm);
        newMessages.push(cm);
        newCount++;
      }

      if (newCount > 0) {
        newMessages.sort((a: CachedMessage, b: CachedMessage) => a.timestamp - b.timestamp);
        this.messages = newMessages;
        this.messagesDataSource.setMessages(newMessages);
        this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
        this.scrollToBottom();
      }
      this.inferMyRole();
    } catch (e) {
    }
  }

  buildCachedMsg(msgId: number, sender: Record<string, Object>,
    obj: Record<string, Object>, rawMsg: string, msgTime: number): CachedMessage {
    let cm = new CachedMessage();
    cm.messageId = msgId;
    cm.chatId = this.chatId;
    cm.userId = parseInt(String(sender['user_id'] || '0'));
    cm.nickname = String(sender['nickname'] || '');
    cm.senderRole = String(sender['role'] || '');
    cm.content = JSON.stringify(obj['message'] || []);
    cm.rawMessage = rawMsg;

    // Napcat 撤回的消息特征：message 为空数组且 raw_message 为空
    let msgSegs = obj['message'] as Object[];
    if ((msgSegs === undefined || msgSegs.length === 0) && rawMsg === '') {
      cm.msgType = 'revoked';
      cm.rawMessage = '消息已被撤回';
      cm.timestamp = msgTime;
      cm.isSelf = cm.userId === this.selfId;
      return cm;
    }

    if (msgSegs && msgSegs.length > 0) {
      let parts: string[] = [];
      for (let seg of msgSegs) {
        let s = seg as Record<string, Object>;
        let segType = s['type'] as string || '';
        let segData = s['data'] as Record<string, Object> || {};
        if (segType === 'text' && segData['text']) {
          parts.push(segData['text'] as string);
        } else if (segType === 'image') {
          parts.push('[图片]');
        } else if (segType === 'face') {
          parts.push('[表情]');
        } else if (segType === 'at') {
          parts.push('@' + (segData['qq'] || ''));
        } else if (segType === 'reply') {
          parts.push('[回复]');
        } else if (segType === 'record') {
          parts.push('[语音]');
        } else if (segType === 'video') {
          parts.push('[视频]');
        } else if (segType === 'file') {
          parts.push('[文件]');
        } else if (segType === 'forward') {
          parts.push('[聊天记录]');
        }
      }
      if (parts.length > 0) {
        cm.rawMessage = parts.join('');
      } else if (msgSegs && msgSegs.length === 1 &&
        ((msgSegs[0] as Record<string, Object>)['type'] as string) === 'forward') {
        cm.rawMessage = '[聊天记录]';
      }
    }
    cm.msgType = 'text';
    if (msgSegs && msgSegs.length > 0) {
      let first = msgSegs[0] as Record<string, Object>;
      let firstType = first['type'] as string || '';
      if (firstType !== '') {
        cm.msgType = firstType;
      }
    }
    cm.timestamp = msgTime;
    cm.isSelf = cm.userId === this.selfId;
    return cm;
  }

  handleWsEvent(msg: OneBotMessage): void {
    let msgChatId = ((msg.message_type || '') === 'group') ?
      'group_' + msg.group_id : 'private_' + msg.user_id;
    RefreshLogger.getInstance().log('CDP-HANDLER',
      'recv c=' + msgChatId + ' cur=' + this.chatId + ' pt=' + msg.post_type);

    if (msg.post_type === 'notice') {
      let nt = msg.notice_type || '';
      if (nt === 'friend_recall' || nt === 'group_recall') {
        let noticeChatId = nt.includes('group') ?
          'group_' + msg.group_id : 'private_' + msg.user_id;
        if (noticeChatId === this.chatId) {
          this.onRecall(msg.message_id);
        }
      }
      return;
    }

    if (msg.post_type !== 'message' || msgChatId !== this.chatId) {
      return;
    }

    let cm = MessageFormatter.toCachedMessage(msg, this.selfId);
    for (let m of this.messages) {
      if (cm.messageId > 0 && m.messageId === cm.messageId) {
        return;
      }
    }
    this.fillSenderRole(cm);
    let updated = [...this.messages, cm];
    this.messages = updated;
    this.messagesDataSource.setMessages(updated);
    this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
    RefreshLogger.getInstance().log('CDP-OK', 'msgId=' + cm.messageId + ' n=' + updated.length);
    this.scrollToBottom();
  }

  onRecall(messageId: number): void {
    // MessageCenter 已调过 markRevoked，此处只处理内存中的消息
    this.applyRecall(messageId);
  }

  applyRecall(messageId: number): void {
    for (let i = 0; i < this.messages.length; i++) {
      if (this.messages[i].messageId === messageId) {
        let updated = [...this.messages];
        updated[i].msgType = 'revoked';
        updated[i].rawMessage = '消息已被撤回';
        updated[i].content = '[]';
        this.messages = updated;
        this.messagesDataSource.setMessages(updated);
        this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
        return;
      }
    }
    // 未在内存中找到：可能 handleHistoryResponse 还在合并中，延迟重试
    setTimeout(() => {
      for (let i = 0; i < this.messages.length; i++) {
        if (this.messages[i].messageId === messageId) {
          let updated = [...this.messages];
          updated[i].msgType = 'revoked';
          updated[i].rawMessage = '消息已被撤回';
          updated[i].content = '[]';
          this.messages = updated;
          this.messagesDataSource.setMessages(updated);
          this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
          return;
        }
      }
    }, 800);
  }

  async loadHistorySilent(): Promise<void> {
    let cached: CachedMessage[] = await this.chatStore.getMessages(this.chatId, 100);
    let deduped: CachedMessage[] = [];
    let seenIds: Set<number> = new Set();
    let selfTexts: Record<string, number> = {};

    for (let cm of cached) {
      cm.isSelf = cm.userId === this.selfId;
      if (cm.messageId > 0) {
        if (seenIds.has(cm.messageId)) {
          for (let i = 0; i < deduped.length; i++) {
            if (deduped[i].messageId === cm.messageId) {
              if (!deduped[i].isRevoked() && cm.isRevoked()) {
                deduped[i] = cm;
              }
              break;
            }
          }
        } else {
          seenIds.add(cm.messageId);
          deduped.push(cm);
          if (cm.isSelf && cm.msgType === 'text' && cm.rawMessage !== '') {
            selfTexts[cm.rawMessage] = deduped.length - 1;
          }
        }
      }
    }

    for (let cm of cached) {
      if (cm.messageId > 0) { continue; }
      cm.isSelf = cm.userId === this.selfId;
      if (cm.isSelf && cm.userId === 0) {
        cm.userId = this.selfId;
        cm.nickname = '我';
      }
      if (selfTexts[cm.rawMessage] !== undefined) { continue; }
      deduped.push(cm);
    }
    deduped.sort((a, b) => a.timestamp - b.timestamp);
    this.messages = deduped;
    this.messagesDataSource.setMessages(deduped);
    this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
  }

  requestArcListFocus(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus('chatArcList');
      } catch (_e) {
      }
    }, 300);
  }

  scrollToBottom(): void {
    setTimeout(() => {
      this.scrollScroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  async sendText(text: string): Promise<void> {
    if (text.trim() === '') {
      return;
    }
    let req: OneBotRequest = OneBotRequest.createSendMsg(
      this.peerId, this.chatType, text);
    let sentEcho = req.echo;

    // 创建占位消息
    let localMsg: CachedMessage = new CachedMessage();
    localMsg.messageId = -Date.now();
    localMsg.chatId = this.chatId;
    localMsg.userId = this.selfId;
    localMsg.nickname = '我';
    let textData: Record<string, Object> = { 'text': text };
    let textSeg: Record<string, Object> = { 'type': 'text', 'data': textData };
    let contentArr: Record<string, Object>[] = [textSeg];
    localMsg.content = JSON.stringify(contentArr);
    localMsg.rawMessage = text;
    localMsg.msgType = 'text';
    localMsg.timestamp = Date.now();
    localMsg.isSelf = true;
    await this.chatStore.saveMessage(localMsg);
    let placeholderId = localMsg.messageId;

    let updated = [...this.messages, localMsg];
    this.messages = updated;
    this.messagesDataSource.setMessages(updated);
    this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
    this.scrollToBottom();

    let chatItem: ChatItem = new ChatItem();
    chatItem.chatType = this.chatType;
    chatItem.peerId = this.peerId;
    chatItem.chatId = this.chatId;
    chatItem.peerName = this.peerName;
    chatItem.lastMessage = text.length > 30 ? text.substring(0, 30) : text;
    chatItem.lastMessageTime = Date.now();
    this.chatStore.upsertChat(chatItem);

    // 发送并等待服务端确认 message_id
    this.wsManager.sendRequestWithCallback(req, async (data: Record<string, Object>) => {
      let serverMsgId = parseInt(String((data['data'] as Record<string, Object> || {})['message_id'] || '0'));
      if (serverMsgId > 0) {
        // 用服务端 message_id 更新占位消息
        for (let i = 0; i < this.messages.length; i++) {
          if (this.messages[i].messageId === placeholderId) {
            let updated = [...this.messages];
            updated[i].messageId = serverMsgId;
            this.messages = updated;
            this.messagesDataSource.setMessages(updated);
            this.messagesDataSource.notifyDataReload();
    this.requestArcListFocus();
            // 更新 DB
            await this.chatStore.deleteMessageByMsgId(placeholderId);
            let saved = CachedMessage.fromMsg(updated[i]);
            saved.messageId = serverMsgId;
            await this.chatStore.saveMessage(saved);
            break;
          }
        }
      }
    });
  }

  shouldShowTime(currentIndex: number): boolean {
    if (currentIndex === 0) {
      return true;
    }
    let prev = this.messages[currentIndex - 1];
    let cur = this.messages[currentIndex];
    if (!prev || !cur) {
      return false;
    }
    return (cur.timestamp - prev.timestamp) > 120000;
  }

  showMenu(msg: CachedMessage): void {
    this.menuMsg = msg;
  }

  dismissMenu(): void {
    this.menuMsg = null;
  }

  hasImageSeg(msg: CachedMessage): boolean {
    try {
      let arr = JSON.parse(msg.content || '[]') as Object[];
      for (let item of arr) {
        let obj = item as Record<string, Object>;
        if ((obj['type'] as string) === 'image') {
          return true;
        }
      }
    } catch (_e) {
    }
    return false;
  }

  getMsgPlainText(msg: CachedMessage): string {
    try {
      let arr = JSON.parse(msg.content || '[]') as Object[];
      let parts: string[] = [];
      for (let item of arr) {
        let obj = item as Record<string, Object>;
        let segType = obj['type'] as string || '';
        let data = obj['data'] as Record<string, Object> || {};
        if (segType === 'text') {
          parts.push(data['text'] as string || '');
        } else if (segType === 'face') {
          let emoji = FaceStore.getFace(parseInt(data['id'] as string || '0'));
          parts.push(emoji !== '' ? emoji : '[表情]');
        } else if (segType === 'image') {
          parts.push('[图片]');
        }
      }
      return parts.join('');
    } catch (_e) {
      return msg.rawMessage || '';
    }
  }

  async copyMsgText(msg: CachedMessage): Promise<void> {
    let text = this.getMsgPlainText(msg);
    let draftKey = 'draft_' + this.chatId;
    RefreshLogger.getInstance().log('DRAFT-0', 'start text=' + text.substring(0, 20) + ' key=' + draftKey);

    let ctx = this.getUIContext().getHostContext() as Context;
    await this.configManager.initDb(ctx);
    RefreshLogger.getInstance().log('DRAFT-1', 'db inited');

    let existing = await this.configManager.getString(draftKey, '');
    RefreshLogger.getInstance().log('DRAFT-2', 'read existing=' + (existing !== '' && existing !== null) +
      ' len=' + (existing !== '' && existing !== null ? (existing || '').length : 0));

    let existingText = '';
    let sqCounter = 0;
    let pm = '[]';
    let replyText = '';
    let replyId = 0;
    if (existing !== '' && existing !== null) {
      try {
        let o = JSON.parse(existing) as Record<string, Object>;
        existingText = o['text'] as string || '';
        sqCounter = o['sqCounter'] as number || 0;
        pm = o['pm'] as string || o['atMap'] as string || '[]';
        replyText = o['replyText'] as string || '';
        replyId = o['replyId'] as number || 0;
        RefreshLogger.getInstance().log('DRAFT-3', 'parsed existingText=' + existingText.length +
          ' sqC=' + sqCounter);
      } catch (e) {
        RefreshLogger.getInstance().log('DRAFT-3-ERR', 'parse failed: ' + (e as Error).message);
      }
    }
    let merged = existingText !== '' ? existingText + '\n' + text : text;
    RefreshLogger.getInstance().log('DRAFT-4', 'merged=' + merged.substring(0, 30) + '...');

    let obj: Record<string, Object> = {
      'text': merged, 'sqCounter': sqCounter, 'pm': pm,
      'replyText': replyText, 'replyId': replyId
    };
    await this.configManager.setString(draftKey, JSON.stringify(obj));

    // 验证写入
    let verify = await this.configManager.getString(draftKey, '');
    RefreshLogger.getInstance().log('DRAFT-5', 'verify wrote=' + (verify !== '' && verify !== null) +
      ' verifyLen=' + (verify !== '' && verify !== null ? (verify || '').length : 0));
    this.dismissMenu();
  }

  canRecall(msg: CachedMessage): boolean {
    // 私人聊天：只能撤回自己发的，且 2 分钟内
    if (this.chatType === 'private') {
      return msg.isSelf && (Date.now() - msg.timestamp) < 120000;
    }
    // 群聊
    let myRole = this.myRole;
    let senderRole = msg.senderRole || 'member';

    // owner 可以撤回所有人
    if (myRole === 'owner') {
      return true;
    }

    // admin 不能撤回 owner 和同级 admin，可以撤回普通人和自己
    if (myRole === 'admin') {
      if (senderRole === 'owner' || senderRole === 'admin') {
        return false;
      }
      return true;
    }

    // 普通成员：只能撤回自己 2 分钟内的
    if (msg.isSelf) {
      return (Date.now() - msg.timestamp) < 120000;
    }
    return false;
  }

  revokeMsg(msg: CachedMessage): void {
    this.dismissMenu();
    // 构造撤回请求
    let req = new OneBotRequest();
    req.action = 'delete_msg';
    req.params = { 'message_id': msg.messageId };
    this.wsManager.sendRequest(req);
  }

  replyMsg(msg: CachedMessage): void {
    this.dismissMenu();
    router.pushUrl({
      url: 'pages/SendMessagePage',
      params: {
        peer_id: this.peerId,
        peer_name: this.peerName,
        chat_type: this.chatType,
        reply_text: (msg.rawMessage || '').substring(0, 50),
        reply_id: msg.messageId
      }
    });
  }

  atMember(msg: CachedMessage): void {
    let member = this.chatStore.getGroupMember(this.peerId, msg.userId);
    let name: string;
    if (member !== null) {
      name = member.getDisplayName();
    } else {
      name = msg.nickname || String(msg.userId);
    }
    this.dismissMenu();
    router.pushUrl({
      url: 'pages/SendMessagePage',
      params: {
        peer_id: this.peerId,
        peer_name: this.peerName,
        chat_type: this.chatType,
        at_qq: String(msg.userId),
        at_name: name
      }
    });
  }

  getAllMediaItems(): string[] {
    let result: string[] = [];
    for (let msg of this.messages) {
      try {
        let arr = JSON.parse(msg.content || '[]') as Object[];
        for (let item of arr) {
          let obj = item as Record<string, Object>;
          let segType = obj['type'] as string || '';
          let data = obj['data'] as Record<string, Object> || {};
          if (segType === 'image') {
            let url = data['url'] as string || data['file'] as string || '';
            if (url !== '') {
              result.push(segType + '|' + url);
            }
          } else if (segType === 'video') {
            let vUrl = data['url'] as string || data['file'] as string || '';
            let vFile = data['file'] as string || '';
            if (vUrl !== '') {
              result.push(segType + '|' + vUrl + '|' + vFile);
            }
          }
        }
      } catch (_e) {
      }
    }
    return result;
  }

  getAllMediaUrls(): string[] {
    let result: string[] = [];
    for (let msg of this.messages) {
      try {
        let arr = JSON.parse(msg.content || '[]') as Object[];
        for (let item of arr) {
          let obj = item as Record<string, Object>;
          let segType = obj['type'] as string || '';
          if (segType === 'image' || segType === 'video') {
            let data = obj['data'] as Record<string, Object> || {};
            let url = data['url'] as string || data['file'] as string || '';
            if (url !== '') {
              result.push(url);
            }
          }
        }
      } catch (_e) {
      }
    }
    return result;
  }

  build() {
    Stack() {
      Column() {
        // 消息 ArcList
        ArcList({ scroller: this.scrollScroller }) {
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
              .padding({ top: 40, bottom: 40 })
            }
            .width('82%')
          }

          if (!this.loading && this.messages.length === 0) {
            ArcListItem() {
              Column() {
                Text('暂无消息')
                  .fontSize(14)
                  .fontColor('#666666')
                Text('发送消息开始对话')
                  .fontSize(11)
                  .fontColor('#444444')
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 40, bottom: 40 })
            }
            .width('82%')
          }

          LazyForEach(this.messagesDataSource, (msg: CachedMessage, index: number) => {
            ArcListItem() {
              MsgBubble({
                msg: msg,
                selfId: this.selfId,
                showTime: this.shouldShowTime(index),
                allMediaUrls: this.getAllMediaItems(),
                allMessages: this.messages,
                groupPeerId: (this.chatType === 'group' ? this.peerId : 0),
                onLongPress: (m: CachedMessage) => { this.showMenu(m); },
                onSwipeReply: (m: CachedMessage) => { this.replyMsg(m); }
              })
            }
            .width('89%')
            .autoScale(false)
          }, (m: CachedMessage) => ChatMessagesDataSource.messageItemKey(m))
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Black)
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .groupDefaultFocus(true)
        .id('chatArcList')
        .scrollBar(BarState.Off)
        .space(LengthMetrics.vp(0))
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          let oldHeight = oldValue.height, newHeight = newValue.height;
          oldHeight = (oldHeight === undefined ? 0 : oldHeight);
          newHeight = (newHeight === undefined ? 0 : newHeight);
          let toBeSmall = (newHeight > 0 && newHeight < oldHeight);
          if (toBeSmall) {
            this.scrollToBottom();
          }
        })
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })

        // 底部 ArcButton（被禁言时隐藏）
        if (this.canSend) {
          ArcButton({
            options: new ArcButtonOptions({
              label: '发送',
              position: ArcButtonPosition.BOTTOM_EDGE,
              styleMode: ArcButtonStyleMode.CUSTOM,
              backgroundColor: ColorMetrics.resourceColor('#C0B8E0'),
              fontSize: new LengthMetrics(15, LengthUnit.FP),
              onClick: () => {
                router.pushUrl({
                  url: 'pages/SendMessagePage',
                  params: {
                    peer_id: this.peerId,
                    peer_name: this.peerName,
                    chat_type: this.chatType
                  }
                });
              }
            })
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      // 长按菜单遮罩
      if (this.menuMsg !== null) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.dismissMenu(); })

        Column() {
          Text('消息操作')
            .fontSize(14)
            .fontColor(Color.White)
            .margin({ bottom: 12 })

          Button('引用')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#2a2a2a')
            .width('80%')
            .height(40)
            .borderRadius(8)
            .margin({ top: 6 })
            .onClick(() => { this.copyMsgText(this.menuMsg!); })

          Button('回复')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#2a2a2a')
            .width('80%')
            .height(40)
            .borderRadius(8)
            .margin({ top: 6 })
            .onClick(() => { this.replyMsg(this.menuMsg!); })

          if (this.chatType === 'group') {
            Button('@ ' + (this.menuMsg!.nickname || '提及'))
              .fontSize(14)
              .fontColor('#4DA6FF')
              .backgroundColor('#2a2a2a')
              .width('80%')
              .height(40)
              .borderRadius(8)
              .margin({ top: 6 })
              .onClick(() => { this.atMember(this.menuMsg!); })
          }

          

          if (this.canRecall(this.menuMsg!)) {
            Button('撤回')
              .fontSize(14)
              .fontColor('#FF6666')
              .backgroundColor('#2a2a2a')
              .width('80%')
              .height(40)
              .borderRadius(8)
              .margin({ top: 6 })
              .onClick(() => { this.revokeMsg(this.menuMsg!); })
          }

          Button('取消')
            .fontSize(13)
            .fontColor('#AAAAAA')
            .backgroundColor(Color.Transparent)
            .margin({ top: 8 })
            .onClick(() => { this.dismissMenu(); })
        }
        .width('78%')
        .backgroundColor('#1a1a1a')
        .borderRadius(16)
        .padding(16)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
