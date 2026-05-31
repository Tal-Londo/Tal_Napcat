export enum WsState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2
}

export class OneBotRequest {
  action: string = '';
  params: Record<string, Object> = {};
  echo: string = '';

  static createGetFriendList(echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_friends_with_category';
    req.echo = echo || 'get_friend_list';
    return req;
  }

  static createGetGroupList(echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_group_list';
    req.echo = echo || 'get_group_list';
    return req;
  }

  // group 历史用 get_group_msg_history，private 用 get_friend_msg_history
  static createGetMsgHistory(peerId: number, messageType: string,
    echo?: string, count?: number): OneBotRequest {
    let req = new OneBotRequest();
    req.echo = echo || 'get_msg_history';
    if (messageType === 'group') {
      req.action = 'get_group_msg_history';
      req.params = { 'group_id': peerId, 'message_id': 0, 'count': count || 20 };
    } else {
      req.action = 'get_friend_msg_history';
      req.params = { 'user_id': peerId, 'message_id': 0, 'count': count || 20 };
    }
    return req;
  }

  static createSendMsg(peerId: number, messageType: string, text: string,
    echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'send_msg';
    req.echo = echo || 'send_msg';
    let textData: Record<string, Object> = { 'text': text };
    let textSeg: Record<string, Object> = { 'type': 'text', 'data': textData };
    let msgArr: Record<string, Object>[] = [textSeg];
    let params: Record<string, Object> = {
      'message_type': messageType,
      'message': msgArr
    };
    if (messageType === 'group') {
      params['group_id'] = peerId;
    } else {
      params['user_id'] = peerId;
    }
    req.params = params;
    return req;
  }

  static createGetLoginInfo(echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_login_info';
    req.echo = echo || 'get_login_info';
    return req;
  }

  // 获取最近消息列表
  static createGetRecentContact(echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_recent_contact';
    req.echo = echo || 'get_recent_contact';
    return req;
  }

  static createGetGroupMemberInfo(groupId: number, userId: number, echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_group_member_info';
    req.params = { 'group_id': groupId, 'user_id': userId, 'no_cache': true };
    req.echo = echo || 'get_group_member_info';
    return req;
  }

  static createGetGroupMemberList(groupId: number, echo?: string): OneBotRequest {
    let req = new OneBotRequest();
    req.action = 'get_group_member_list';
    req.params = { 'group_id': groupId, 'no_cache': true };
    req.echo = echo || 'get_group_member_list';
    return req;
  }

  toJson(): string {
    return JSON.stringify(this);
  }
}

export class OneBotSender {
  user_id: number = 0;
  nickname: string = '';
  card: string = '';
  role: string = '';
  sex: string = '';
  age: number = 0;
  avatar: string = '';
}

// message 段: OneBot v11 格式 {type, data: {text/img/...}}
export class OneBotMsgSegment {
  type: string = '';
  data: Record<string, Object> = {};
}

export class OneBotMessage {
  post_type: string = '';
  message_type: string = '';
  sub_type: string = '';
  notice_type: string = '';
  message_id: number = 0;
  user_id: number = 0;
  group_id: number = 0;
  target_id: number = 0;
  time: number = 0;
  message: Object = '';       // string | OneBotMsgSegment[]
  raw_message: string = '';
  sender: OneBotSender = new OneBotSender();
  self_id: number = 0;
  font: number = 0;

  getSenderName(): string {
    if (this.sender.card !== '' && this.sender.card !== undefined) {
      return this.sender.card;
    }
    if (this.sender.nickname !== '' && this.sender.nickname !== undefined) {
      return this.sender.nickname;
    }
    return this.user_id.toString();
  }

  getUserOrGroupId(): number {
    if (this.message_type === 'group') {
      return this.group_id;
    }
    return this.user_id;
  }

  isPrivateChat(): boolean {
    return this.message_type === 'private';
  }

  isGroupChat(): boolean {
    return this.message_type === 'group';
  }

  // 提取消息文本：优先使用 raw_message，否则从 message 数组解析
  getDisplayText(): string {
    if (this.raw_message !== undefined && this.raw_message !== '') {
      return this.raw_message;
    }
    if (typeof this.message === 'string') {
      return this.message as string;
    }
    if (this.message instanceof Array) {
      let arr = this.message as Object[];
      let parts: string[] = [];
      for (let seg of arr) {
        let s = seg as Record<string, Object>;
        let type = s['type'] as string || '';
        let data = s['data'] as Record<string, Object> || {};
        if (type === 'text' && data['text']) {
          parts.push(data['text'] as string);
        } else if (type === 'image') {
          parts.push('[图片]');
        } else if (type === 'face') {
          parts.push('[表情]');
        } else if (type === 'at') {
          parts.push('@' + (data['qq'] || ''));
        } else if (type === 'record') {
          parts.push('[语音]');
        } else if (type === 'video') {
          parts.push('[视频]');
        } else if (type === 'file') {
          parts.push('[文件]');
        } else if (type === 'reply') {
          parts.push('[回复]');
        }
      }
      return parts.join('');
    }
    return '';
  }
}

export class OneBotServerInfo {
  url: string = '';
  name: string = '';
  accessToken: string = '';
  lastConnected: number = 0;

  static fromJson(json: string): OneBotServerInfo {
    let info = new OneBotServerInfo();
    try {
      let obj = JSON.parse(json) as Record<string, Object>;
      info.url = (obj.url as string) || '';
      info.name = (obj.name as string) || '';
      info.accessToken = (obj.accessToken as string) || '';
      info.lastConnected = (obj.lastConnected as number) || 0;
    } catch (e) {
    }
    return info;
  }

  toJson(): string {
    return JSON.stringify({
      url: this.url,
      name: this.name,
      accessToken: this.accessToken,
      lastConnected: this.lastConnected
    });
  }
}
