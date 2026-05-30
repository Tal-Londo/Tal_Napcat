import { OneBotMessage } from './OneBotModel';
import { CachedMessage, ChatItem } from './ChatStore';

export class MessageFormatter {
  private static selfId: number = 0;

  static setSelfId(id: number): void {
    MessageFormatter.selfId = id;
  }

  static getSelfId(): number {
    return MessageFormatter.selfId;
  }

  static getMsgType(msg: OneBotMessage): string {
    if (msg.post_type === 'notice') {
      return 'notice';
    }
    if (msg.message instanceof Array) {
      let arr = msg.message as Object[];
      if (arr.length > 0) {
        let first = arr[0] as Record<string, Object>;
        return (first['type'] as string) || 'text';
      }
    }
    return 'text';
  }

  static getTextSummary(msg: OneBotMessage): string {
    if (msg.post_type === 'notice') {
      return '[系统通知]';
    }
    let displayText = msg.getDisplayText();
    if (displayText.length > 30) {
      return displayText.substring(0, 30) + '...';
    }
    return displayText || '[消息]';
  }

  // OneBotMessage → CachedMessage
  static toCachedMessage(msg: OneBotMessage, selfId: number): CachedMessage {
    let cm = new CachedMessage();
    cm.messageId = msg.message_id;
    cm.chatId = msg.isGroupChat() ?
      `group_${msg.group_id}` : `private_${msg.user_id}`;
    cm.userId = msg.user_id;
    cm.nickname = msg.sender.nickname || '';
    cm.content = JSON.stringify(msg.message);
    cm.rawMessage = msg.getDisplayText();
    cm.msgType = MessageFormatter.getMsgType(msg);
    cm.timestamp = msg.time * 1000;
    cm.isSelf = msg.user_id === selfId;
    return cm;
  }

  static formatTime(timestamp: number): string {
    let d = new Date(timestamp);
    let now = new Date();
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    if (d.toDateString() === now.toDateString()) {
      return h + ':' + m;
    }
    let mon = (d.getMonth() + 1).toString();
    let day = d.getDate().toString();
    return mon + '/' + day + ' ' + h + ':' + m;
  }

  static buildChatItem(msg: OneBotMessage, selfId: number): ChatItem {
    let item = new ChatItem();
    item.chatType = msg.isGroupChat() ? 'group' : 'private';
    item.peerId = msg.getUserOrGroupId();
    item.chatId = item.chatType + '_' + item.peerId;
    item.peerName = msg.isGroupChat() ?
      ('群' + msg.group_id) : msg.getSenderName();
    item.lastMessage = MessageFormatter.getTextSummary(msg);
    item.lastMessageTime = msg.time * 1000;
    item.unreadCount = msg.user_id !== selfId ? 1 : 0;
    return item;
  }
}
