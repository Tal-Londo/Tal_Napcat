import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ChatStore';
const DOMAIN = 0x0005;

interface ChatRow {
  id: number;
  chat_id: string;
  chat_type: string;
  peer_id: number;
  peer_name: string;
  avatar_url: string;
  last_message: string;
  last_message_time: number;
  unread_count: number;
  is_top: number;
  updated_at: number;
}

interface MsgRow {
  id: number;
  message_id: number;
  chat_id: string;
  user_id: number;
  nickname: string;
  content: string;
  raw_message: string;
  msg_type: string;
  timestamp: number;
  is_self: number;
}

interface ContactRow {
  id: number;
  user_id: number;
  nickname: string;
  remark: string;
  avatar_url: string;
  updated_at: number;
}

interface GroupRow {
  id: number;
  group_id: number;
  group_name: string;
  member_count: number;
  updated_at: number;
}

export class ChatItem {
  chatId: string = '';
  chatType: string = '';
  peerId: number = 0;
  peerName: string = '';
  avatarUrl: string = '';
  lastMessage: string = '';
  lastMessageTime: number = 0;
  unreadCount: number = 0;
  isTop: boolean = false;

  static fromRow(row: ChatRow): ChatItem {
    let item = new ChatItem();
    item.chatId = row.chat_id;
    item.chatType = row.chat_type;
    item.peerId = row.peer_id;
    item.peerName = row.peer_name;
    item.avatarUrl = row.avatar_url;
    item.lastMessage = row.last_message;
    item.lastMessageTime = row.last_message_time;
    item.unreadCount = row.unread_count;
    item.isTop = row.is_top === 1;
    return item;
  }
}

export class CachedMessage {
  messageId: number = 0;
  chatId: string = '';
  userId: number = 0;
  nickname: string = '';
  content: string = '';
  rawMessage: string = '';
  msgType: string = '';
  timestamp: number = 0;
  isSelf: boolean = false;
  senderRole: string = '';

  isRevoked(): boolean {
    return this.msgType === 'revoked';
  }

  static fromRow(row: MsgRow): CachedMessage {
    let msg = new CachedMessage();
    msg.messageId = row.message_id;
    msg.chatId = row.chat_id;
    msg.userId = row.user_id;
    msg.nickname = row.nickname;
    msg.content = row.content;
    msg.rawMessage = row.raw_message;
    msg.msgType = row.msg_type;
    msg.timestamp = row.timestamp;
    msg.isSelf = row.is_self === 1;
    return msg;
  }

  static fromMsg(src: CachedMessage): CachedMessage {
    let msg = new CachedMessage();
    msg.messageId = src.messageId;
    msg.chatId = src.chatId;
    msg.userId = src.userId;
    msg.nickname = src.nickname;
    msg.content = src.content;
    msg.rawMessage = src.rawMessage;
    msg.msgType = src.msgType;
    msg.timestamp = src.timestamp;
    msg.isSelf = src.isSelf;
    msg.senderRole = src.senderRole;
    return msg;
  }
}

export class ContactItem {
  userId: number = 0;
  nickname: string = '';
  remark: string = '';
  avatarUrl: string = '';

  static fromRow(row: ContactRow): ContactItem {
    let c = new ContactItem();
    c.userId = row.user_id;
    c.nickname = row.nickname;
    c.remark = row.remark;
    c.avatarUrl = row.avatar_url;
    return c;
  }

  getDisplayName(): string {
    return this.remark !== '' ? this.remark : this.nickname;
  }
}

export class GroupItem {
  groupId: number = 0;
  groupName: string = '';
  memberCount: number = 0;
  groupAllShut: number = 0;

  static fromRow(row: GroupRow): GroupItem {
    let g = new GroupItem();
    g.groupId = row.group_id;
    g.groupName = row.group_name;
    g.memberCount = row.member_count;
    return g;
  }
}

export class GroupMember {
  userId: number = 0;
  nickname: string = '';
  card: string = '';
  role: string = '';
  title: string = '';

  getDisplayName(): string {
    if (this.card !== '') {
      return this.card;
    }
    return this.nickname;
  }
}

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'napcatwatch_msg.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CHATS =
  'CREATE TABLE IF NOT EXISTS chats (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'chat_id TEXT UNIQUE NOT NULL, ' +
  'chat_type TEXT NOT NULL, ' +
  'peer_id INTEGER NOT NULL, ' +
  'peer_name TEXT DEFAULT \'\', ' +
  'avatar_url TEXT DEFAULT \'\', ' +
  'last_message TEXT DEFAULT \'\', ' +
  'last_message_time INTEGER DEFAULT 0, ' +
  'unread_count INTEGER DEFAULT 0, ' +
  'is_top INTEGER DEFAULT 0, ' +
  'updated_at INTEGER DEFAULT 0)';

const SQL_MESSAGES =
  'CREATE TABLE IF NOT EXISTS messages (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'message_id INTEGER, ' +
  'chat_id TEXT NOT NULL, ' +
  'user_id INTEGER, ' +
  'nickname TEXT DEFAULT \'\', ' +
  'content TEXT NOT NULL, ' +
  'raw_message TEXT DEFAULT \'\', ' +
  'msg_type TEXT DEFAULT \'text\', ' +
  'timestamp INTEGER NOT NULL, ' +
  'is_self INTEGER DEFAULT 0)';

const SQL_CONTACTS =
  'CREATE TABLE IF NOT EXISTS contacts (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'user_id INTEGER UNIQUE NOT NULL, ' +
  'nickname TEXT DEFAULT \'\', ' +
  'remark TEXT DEFAULT \'\', ' +
  'avatar_url TEXT DEFAULT \'\', ' +
  'updated_at INTEGER DEFAULT 0)';

const SQL_GROUPS =
  'CREATE TABLE IF NOT EXISTS groups (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'group_id INTEGER UNIQUE NOT NULL, ' +
  'group_name TEXT DEFAULT \'\', ' +
  'member_count INTEGER DEFAULT 0, ' +
  'updated_at INTEGER DEFAULT 0)';

export class ChatStore {
  private static instance: ChatStore;
  private rdbStore: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;
  private memberCache: Record<number, Record<number, GroupMember>> = {};

  static getInstance(): ChatStore {
    if (ChatStore.instance === undefined) {
      ChatStore.instance = new ChatStore();
    }
    return ChatStore.instance;
  }

  // ========== Members Cache ==========

  setGroupMembers(groupId: number, members: GroupMember[]): void {
    let map: Record<number, GroupMember> = {};
    for (let m of members) {
      map[m.userId] = m;
    }
    this.memberCache[groupId] = map;
  }

  getGroupMember(groupId: number, userId: number): GroupMember | null {
    let map = this.memberCache[groupId];
    if (map !== undefined) {
      let m = map[userId];
      if (m !== undefined) {
        return m;
      }
    }
    return null;
  }

  getAllGroupMembers(groupId: number): GroupMember[] {
    let result: GroupMember[] = [];
    let map = this.memberCache[groupId];
    if (map !== undefined) {
      let keys = Object.keys(map);
      for (let k of keys) {
        result.push(map[parseInt(k)]);
      }
    }
    return result;
  }

  async initDb(context: Context): Promise<void> {
    if (this.initialized && this.rdbStore !== null) {
      return;
    }
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.rdbStore.executeSql(SQL_CHATS);
      await this.rdbStore.executeSql(SQL_MESSAGES);
      await this.rdbStore.executeSql(SQL_CONTACTS);
      await this.rdbStore.executeSql(SQL_GROUPS);
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'ChatStore initialized');
    } catch (err) {
      let e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, `initDb failed: ${e.message}`);
    }
  }

  // ========== Chats ==========

  async getChats(limit: number = 50): Promise<ChatItem[]> {
    if (this.rdbStore === null) {
      return [];
    }
    let result: ChatItem[] = [];
    try {
      let predicates = new relationalStore.RdbPredicates('chats');
      predicates.orderByDesc('is_top');
      predicates.orderByDesc('last_message_time');
      predicates.limitAs(limit);
      let rs = await this.rdbStore.query(predicates);
      while (rs.goToNextRow()) {
        let row: ChatRow = {
          id: rs.getLong(rs.getColumnIndex('id')),
          chat_id: rs.getString(rs.getColumnIndex('chat_id')),
          chat_type: rs.getString(rs.getColumnIndex('chat_type')),
          peer_id: rs.getLong(rs.getColumnIndex('peer_id')),
          peer_name: rs.getString(rs.getColumnIndex('peer_name')),
          avatar_url: rs.getString(rs.getColumnIndex('avatar_url')),
          last_message: rs.getString(rs.getColumnIndex('last_message')),
          last_message_time: rs.getLong(rs.getColumnIndex('last_message_time')),
          unread_count: rs.getLong(rs.getColumnIndex('unread_count')),
          is_top: rs.getLong(rs.getColumnIndex('is_top')),
          updated_at: rs.getLong(rs.getColumnIndex('updated_at'))
        };
        result.push(ChatItem.fromRow(row));
      }
      rs.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getChats failed`);
    }
    return result;
  }

  async upsertChat(item: ChatItem): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    let bucket: relationalStore.ValuesBucket = {
      'chat_id': item.chatId,
      'chat_type': item.chatType,
      'peer_id': item.peerId,
      'peer_name': item.peerName,
      'avatar_url': item.avatarUrl,
      'last_message': item.lastMessage,
      'last_message_time': item.lastMessageTime,
      'unread_count': item.unreadCount,
      'is_top': item.isTop ? 1 : 0,
      'updated_at': Date.now()
    };
    try {
      await this.rdbStore.insert('chats', bucket,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `upsertChat failed`);
    }
  }

  static chatId(chatType: string, peerId: number): string {
    return `${chatType}_${peerId}`;
  }

  // ========== Messages ==========

  async getMessages(chatId: string, limit: number = 100): Promise<CachedMessage[]> {
    if (this.rdbStore === null) {
      return [];
    }
    let result: CachedMessage[] = [];
    try {
      let predicates = new relationalStore.RdbPredicates('messages');
      predicates.equalTo('chat_id', chatId);
      predicates.orderByDesc('timestamp');
      predicates.limitAs(limit);
      let rs = await this.rdbStore.query(predicates);
      while (rs.goToNextRow()) {
        let row: MsgRow = {
          id: rs.getLong(rs.getColumnIndex('id')),
          message_id: rs.getLong(rs.getColumnIndex('message_id')),
          chat_id: rs.getString(rs.getColumnIndex('chat_id')),
          user_id: rs.getLong(rs.getColumnIndex('user_id')),
          nickname: rs.getString(rs.getColumnIndex('nickname')),
          content: rs.getString(rs.getColumnIndex('content')),
          raw_message: rs.getString(rs.getColumnIndex('raw_message')),
          msg_type: rs.getString(rs.getColumnIndex('msg_type')),
          timestamp: rs.getLong(rs.getColumnIndex('timestamp')),
          is_self: rs.getLong(rs.getColumnIndex('is_self'))
        };
        result.push(CachedMessage.fromRow(row));
      }
      rs.close();
      result.reverse();
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getMessages failed`);
    }
    return result;
  }

  async saveMessage(msg: CachedMessage): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    let bucket: relationalStore.ValuesBucket = {
      'message_id': msg.messageId,
      'chat_id': msg.chatId,
      'user_id': msg.userId,
      'nickname': msg.nickname,
      'content': msg.content,
      'raw_message': msg.rawMessage,
      'msg_type': msg.msgType,
      'timestamp': msg.timestamp,
      'is_self': msg.isSelf ? 1 : 0
    };
    try {
      // 有真实 ID 的消息：先删旧行再插入，避免重复
      if (msg.messageId > 0) {
        let delPred = new relationalStore.RdbPredicates('messages');
        delPred.equalTo('message_id', msg.messageId);
        await this.rdbStore.delete(delPred);
      }
      await this.rdbStore.insert('messages', bucket);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveMessage failed`);
    }
  }

  async saveMessages(msgs: CachedMessage[]): Promise<void> {
    for (let msg of msgs) {
      await this.saveMessage(msg);
    }
  }

  async deleteMessages(chatId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    try {
      let predicates = new relationalStore.RdbPredicates('messages');
      predicates.equalTo('chat_id', chatId);
      await this.rdbStore.delete(predicates);
    } catch (err) {
    }
  }

  async markRevoked(messageId: number): Promise<void> {
    if (this.rdbStore === null || messageId <= 0) {
      return;
    }
    try {
      let bucket: relationalStore.ValuesBucket = {
        'msg_type': 'revoked',
        'raw_message': '消息已被撤回',
        'content': '[]'
      };
      let predicates = new relationalStore.RdbPredicates('messages');
      predicates.equalTo('message_id', messageId);
      await this.rdbStore.update(bucket, predicates);
    } catch (err) {
    }
  }

  async deleteMessageByMsgId(messageId: number): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    try {
      let predicates = new relationalStore.RdbPredicates('messages');
      predicates.equalTo('message_id', messageId);
      await this.rdbStore.delete(predicates);
    } catch (err) {
    }
  }

  async clearAllData(): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    try {
      await this.rdbStore.executeSql('DELETE FROM messages');
      await this.rdbStore.executeSql('DELETE FROM chats');
      await this.rdbStore.executeSql('DELETE FROM contacts');
      await this.rdbStore.executeSql('DELETE FROM groups');
    } catch (err) {
    }
  }

  // ========== Contacts ==========

  async getContacts(): Promise<ContactItem[]> {
    if (this.rdbStore === null) {
      return [];
    }
    let result: ContactItem[] = [];
    try {
      let predicates = new relationalStore.RdbPredicates('contacts');
      let rs = await this.rdbStore.query(predicates);
      while (rs.goToNextRow()) {
        let row: ContactRow = {
          id: rs.getLong(rs.getColumnIndex('id')),
          user_id: rs.getLong(rs.getColumnIndex('user_id')),
          nickname: rs.getString(rs.getColumnIndex('nickname')),
          remark: rs.getString(rs.getColumnIndex('remark')),
          avatar_url: rs.getString(rs.getColumnIndex('avatar_url')),
          updated_at: rs.getLong(rs.getColumnIndex('updated_at'))
        };
        result.push(ContactItem.fromRow(row));
      }
      rs.close();
    } catch (err) {
    }
    return result;
  }

  async saveContacts(items: ContactItem[]): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    for (let c of items) {
      let bucket: relationalStore.ValuesBucket = {
        'user_id': c.userId,
        'nickname': c.nickname,
        'remark': c.remark,
        'avatar_url': c.avatarUrl,
        'updated_at': Date.now()
      };
      try {
        await this.rdbStore.insert('contacts', bucket,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      } catch (err) {
      }
    }
  }

  // ========== Groups ==========

  async getGroups(): Promise<GroupItem[]> {
    if (this.rdbStore === null) {
      return [];
    }
    let result: GroupItem[] = [];
    try {
      let predicates = new relationalStore.RdbPredicates('groups');
      let rs = await this.rdbStore.query(predicates);
      while (rs.goToNextRow()) {
        let row: GroupRow = {
          id: rs.getLong(rs.getColumnIndex('id')),
          group_id: rs.getLong(rs.getColumnIndex('group_id')),
          group_name: rs.getString(rs.getColumnIndex('group_name')),
          member_count: rs.getLong(rs.getColumnIndex('member_count')),
          updated_at: rs.getLong(rs.getColumnIndex('updated_at'))
        };
        result.push(GroupItem.fromRow(row));
      }
      rs.close();
    } catch (err) {
    }
    return result;
  }

  async saveGroups(items: GroupItem[]): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }
    for (let g of items) {
      let bucket: relationalStore.ValuesBucket = {
        'group_id': g.groupId,
        'group_name': g.groupName,
        'member_count': g.memberCount,
        'updated_at': Date.now()
      };
      try {
        await this.rdbStore.insert('groups', bucket,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      } catch (err) {
      }
    }
  }
}
