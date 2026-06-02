import { OneBotMessage } from './OneBotModel';
import { CachedMessage, ChatItem } from './ChatStore';

function isGroupChat(msg: OneBotMessage): boolean {
  return (msg.message_type || '') === 'group';
}

function getDisplayText(msg: OneBotMessage): string {
  let raw = '';
  if (msg.raw_message !== undefined && msg.raw_message !== '') {
    raw = msg.raw_message as string;
  } else if (typeof msg.message === 'string') {
    raw = msg.message as string;
  } else if (msg.message instanceof Array) {
    let arr = msg.message as Object[];
    let parts: string[] = [];
    for (let seg of arr) {
      let s = seg as Record<string, Object>;
      let stype = s['type'] as string || '';
      let sdata = s['data'] as Record<string, Object> || {};
      if (stype === 'text' && sdata['text']) { parts.push(sdata['text'] as string); }
      else if (stype === 'image') { parts.push('[图片]'); }
      else if (stype === 'face') { parts.push('[表情]'); }
      else if (stype === 'at') { parts.push('@' + (sdata['qq'] || '')); }
      else if (stype === 'record') { parts.push('[语音]'); }
      else if (stype === 'video') { parts.push('[视频]'); }
      else if (stype === 'file') { parts.push('[文件]'); }
      else if (stype === 'reply') { parts.push('[回复]'); }
    }
    return parts.join('');
  }
  return stripCQCode(raw);
}

/** CQ码 → 文字描述，用于消息预览/回复引用等场景 */
export function stripCQCode(raw: string): string {
  if (raw === '') {
    return '';
  }
  // 按序替换常见 CQ 码
  let result = raw;
  result = result.replace(/\[CQ:image,[^\]]*\]/gi, '[图片]');
  result = result.replace(/\[CQ:record,[^\]]*\]/gi, '[语音]');
  result = result.replace(/\[CQ:video,[^\]]*\]/gi, '[视频]');
  result = result.replace(/\[CQ:face,[^\]]*\]/gi, '[表情]');
  result = result.replace(/\[CQ:at,[^\]]*\]/gi, (_match: string) => {
    let qqMatch = _match.match(/qq=(\d+)/i);
    return qqMatch ? '@' + qqMatch[1] : '@提及';
  });
  result = result.replace(/\[CQ:file,[^\]]*\]/gi, '[文件]');
  result = result.replace(/\[CQ:reply,[^\]]*\]/gi, '[回复]');
  result = result.replace(/\[CQ:share,[^\]]*\]/gi, '[分享]');
  result = result.replace(/\[CQ:music,[^\]]*\]/gi, '[音乐]');
  result = result.replace(/\[CQ:\w+,[^\]]*\]/gi, '[消息]');
  return result;
}

function getSenderName(msg: OneBotMessage): string {
  if (msg.sender.card !== '' && msg.sender.card !== undefined) {
    return msg.sender.card as string;
  }
  if (msg.sender.nickname !== '' && msg.sender.nickname !== undefined) {
    return msg.sender.nickname as string;
  }
  return String(msg.user_id);
}

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
    let displayText = getDisplayText(msg);
    if (displayText.length > 30) {
      return displayText.substring(0, 30) + '...';
    }
    return displayText || '[消息]';
  }

  static toCachedMessage(msg: OneBotMessage, selfId: number): CachedMessage {
    let cm = new CachedMessage();
    cm.messageId = msg.message_id;
    cm.chatId = isGroupChat(msg) ?
      'group_' + msg.group_id : 'private_' + msg.user_id;
    cm.userId = msg.user_id;
    cm.nickname = msg.sender.nickname || '';
    cm.content = JSON.stringify(msg.message);
    cm.rawMessage = getDisplayText(msg);
    cm.msgType = MessageFormatter.getMsgType(msg);
    cm.timestamp = msg.time * 1000;
    cm.isSelf = msg.user_id === selfId;
    cm.senderRole = msg.sender.role || '';
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
    item.chatType = isGroupChat(msg) ? 'group' : 'private';
    let isGroup = isGroupChat(msg);
    item.peerId = isGroup ? msg.group_id : msg.user_id;
    item.chatId = item.chatType + '_' + item.peerId;
    // 群聊保留已有 peerName（由 handleRecentContact 设置），私聊用发送者名
    if (!isGroup) {
      item.peerName = getSenderName(msg);
    }
    // 群聊预览显示「发送者: 内容」，私聊显示「内容」
    let summary = MessageFormatter.getTextSummary(msg);
    if (isGroup && msg.user_id !== selfId) {
      let sName = msg.sender.card || msg.sender.nickname || String(msg.user_id);
      item.lastMessage = sName + ': ' + summary;
    } else {
      item.lastMessage = summary;
    }
    item.lastMessageTime = msg.time * 1000;
    item.unreadCount = msg.user_id !== selfId ? 1 : 0;
    return item;
  }
}
