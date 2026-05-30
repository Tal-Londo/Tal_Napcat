import { CachedMessage } from '../model/ChatStore';

class BasicDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private maxCount: number = 500;

  totalCount(): number {
    return 0;
  }

  getData(index: number): CachedMessage {
    return new CachedMessage();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    let pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  setMaxCount(max: number): void {
    this.maxCount = max;
  }

  notifyDataReload(): void {
    for (let listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  notifyDataAdd(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataAdd(index);
    }
  }

  notifyDataChange(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataChange(index);
    }
  }

  notifyDataDelete(index: number): void {
    for (let listener of this.listeners) {
      listener.onDataDelete(index);
    }
  }
}

export class MessagesDataSource extends BasicDataSource {
  private messages: CachedMessage[] = [];

  setMessages(msgs: CachedMessage[]): void {
    this.messages = msgs;
    this.notifyDataReload();
  }

  addMessage(msg: CachedMessage): void {
    this.messages.push(msg);
    if (this.messages.length > 500) {
      this.messages.splice(0, this.messages.length - 500);
      this.notifyDataReload();
      return;
    }
    this.notifyDataAdd(this.messages.length - 1);
  }

  updateMessage(index: number, msg: CachedMessage): void {
    if (index >= 0 && index < this.messages.length) {
      this.messages[index] = msg;
      this.notifyDataChange(index);
    }
  }

  getMessage(index: number): CachedMessage {
    return this.messages[index];
  }

  totalCount(): number {
    return this.messages.length;
  }

  getData(index: number): CachedMessage {
    return this.messages[index];
  }
}
