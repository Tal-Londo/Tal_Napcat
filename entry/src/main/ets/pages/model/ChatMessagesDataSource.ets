import { BasicDataSource } from '../common/LazyDataSource';
import { CachedMessage } from '../../model/ChatStore';

/**
 * 聊天消息列表的数据源（实现 IDataSource，供 List/LazyForEach 使用）。
 * 数据来自 ChatDetailPage 中的 messages 数组引用（浅拷贝），不单独维护数组。
 */
export class ChatMessagesDataSource extends BasicDataSource<CachedMessage> {
  private messages: CachedMessage[] = [];

  constructor(messages: CachedMessage[]) {
    super();
    this.messages = messages;
  }

  /** 更新数据源引用的数组（例如 loadHistory 整批替换后调用） */
  setMessages(messages: CachedMessage[]): void {
    this.messages = messages;
  }

  totalCount(): number {
    return this.messages.length;
  }

  getData(index: number): CachedMessage {
    return this.messages[index];
  }

  notifyDataReload(): void {
    super.notifyDataReload();
  }

  static messageItemKey(m: CachedMessage): string {
    return m.messageId + '-' + m.msgType + '-' + m.timestamp;
  }
}
