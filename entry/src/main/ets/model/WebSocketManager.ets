import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { WsState, OneBotMessage } from './OneBotModel';
import { RefreshLogger } from './RefreshLogger';

const TAG = 'WebSocketManager';
const DOMAIN = 0x0003;
const MAX_LOG_ENTRIES = 500;

export enum WsEventType {
  STATE = 'state',
  SEND = 'send',
  RECV = 'recv',
  ERROR = 'error',
  SYSTEM = 'system'
}

export class WsLogEntry {
  id: number = 0;
  type: WsEventType = WsEventType.SYSTEM;
  message: string = '';
  timestamp: number = 0;

  getTypeLabel(): string {
    switch (this.type) {
      case WsEventType.STATE:
        return '状态';
      case WsEventType.SEND:
        return '发送';
      case WsEventType.RECV:
        return '接收';
      case WsEventType.ERROR:
        return '错误';
      case WsEventType.SYSTEM:
        return '系统';
      default:
        return '未知';
    }
  }

  getTypeColor(): string {
    switch (this.type) {
      case WsEventType.STATE:
        return '#4DA6FF';
      case WsEventType.SEND:
        return '#FFB347';
      case WsEventType.RECV:
        return '#00FF88';
      case WsEventType.ERROR:
        return '#FF6666';
      case WsEventType.SYSTEM:
        return '#888888';
      default:
        return '#AAAAAA';
    }
  }
}

const CONNECT_TIMEOUT_MS = 10000;
const PING_INTERVAL_MS = 30000;
const PONG_TIMEOUT_MS = 10000;
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_BASE_DELAY_MS = 2000;
const RECONNECT_MAX_DELAY_MS = 30000;

export class WebSocketManager {
  private static instance: WebSocketManager;
  private ws: webSocket.WebSocket | null = null;
  private state: WsState = WsState.DISCONNECTED;
  private currentUrl: string = '';
  private connectTimer: number = -1;
  private reconnectAttempts: number = 0;
  private reconnectEnabled: boolean = true;
  private intentionalClose: boolean = false;
  private heartbeatTimer: number = -1;

  onStateChange?: (state: WsState) => void;
  onMessage?: (msg: OneBotMessage) => void;
  onError?: (error: string) => void;

  private logEntries: WsLogEntry[] = [];
  private logCounter: number = 0;
  onLogUpdate?: () => void;

  private stateListeners: Array<(state: WsState) => void> = [];
  private messageListeners: Array<(msg: OneBotMessage) => void> = [];
  private responseCallbacks: Map<string, (data: Record<string, Object>) => void> = new Map();
  private echoCounter: number = 0;

  static getInstance(): WebSocketManager {
    if (WebSocketManager.instance === undefined) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  getState(): WsState {
    return this.state;
  }

  setReconnectEnabled(enabled: boolean): void {
    this.reconnectEnabled = enabled;
  }

  isConnected(): boolean {
    return this.state === WsState.CONNECTED;
  }

  getLogEntries(): WsLogEntry[] {
    return this.logEntries;
  }

  clearLog(): void {
    this.logEntries = [];
    this.logCounter = 0;
    if (this.onLogUpdate) {
      this.onLogUpdate();
    }
  }

  addStateListener(callback: (state: WsState) => void): void {
    let found = false;
    for (let i = 0; i < this.stateListeners.length; i++) {
      if (this.stateListeners[i] === callback) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.stateListeners.push(callback);
    }
  }

  removeStateListener(callback: (state: WsState) => void): void {
    let newList: Array<(state: WsState) => void> = [];
    for (let i = 0; i < this.stateListeners.length; i++) {
      if (this.stateListeners[i] !== callback) {
        newList.push(this.stateListeners[i]);
      }
    }
    this.stateListeners = newList;
  }

  addMessageListener(callback: (msg: OneBotMessage) => void): void {
    let found = false;
    for (let i = 0; i < this.messageListeners.length; i++) {
      if (this.messageListeners[i] === callback) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.messageListeners.push(callback);
    }
  }

  removeMessageListener(callback: (msg: OneBotMessage) => void): void {
    let newList: Array<(msg: OneBotMessage) => void> = [];
    for (let i = 0; i < this.messageListeners.length; i++) {
      if (this.messageListeners[i] !== callback) {
        newList.push(this.messageListeners[i]);
      }
    }
    this.messageListeners = newList;
  }

  sendRequestWithCallback(request: Object, callback: (data: Record<string, Object>) => void): void {
    this.echoCounter++;
    let echo = 'req_' + this.echoCounter + '_' + Date.now();
    let reqObj = request as Record<string, Object>;
    reqObj['echo'] = echo;
    this.responseCallbacks.set(echo, callback);
    this.send(JSON.stringify(reqObj));

    // 超时清理（30秒）
    setTimeout(() => {
      if (this.responseCallbacks.has(echo)) {
        this.responseCallbacks.delete(echo);
      }
    }, 30000);
  }

  private addLog(type: WsEventType, message: string): void {
    this.logCounter++;
    let entry = new WsLogEntry();
    entry.id = this.logCounter;
    entry.type = type;
    entry.message = message;
    entry.timestamp = Date.now();
    this.logEntries.unshift(entry);
    if (this.logEntries.length > MAX_LOG_ENTRIES) {
      this.logEntries.pop();
    }
    if (this.onLogUpdate) {
      this.onLogUpdate();
    }
  }

  async connect(url: string): Promise<boolean> {
    if (this.state === WsState.CONNECTING) {
      hilog.warn(DOMAIN, TAG, 'Already connecting');
      return false;
    }
    if (this.state === WsState.CONNECTED) {
      this.disconnect();
    }

    this.currentUrl = url;
    this.intentionalClose = false;
    this.addLog(WsEventType.SYSTEM, `正在连接 ${url}`);
    this.setState(WsState.CONNECTING);

    hilog.info(DOMAIN, TAG, `Connecting to ${url}`);

    try {
      this.ws = webSocket.createWebSocket();

      let connectPromise = new Promise<boolean>((resolve) => {
        let resolved = false;

        this.ws!.on('open', (err: BusinessError, value: Object) => {
          if (resolved) {
            return;
          }
          resolved = true;
          clearTimeout(this.connectTimer);
          hilog.info(DOMAIN, TAG, 'WebSocket connected');
          this.addLog(WsEventType.STATE, 'WebSocket 连接成功');
          this.setState(WsState.CONNECTED);
          this.reconnectAttempts = 0;
          this.startHeartbeat();
          resolve(true);
        });

        this.ws!.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
          if (err) {
            hilog.error(DOMAIN, TAG, `Message error: ${JSON.stringify(err)}`);
            return;
          }
          let textDecoder = util.TextDecoder.create();
          let data: string = typeof value === 'string' ? value :
          textDecoder.decodeToString(new Uint8Array(value as ArrayBuffer));
          let preview: string = data.length > 300 ? data.substring(0, 300) + '...' : data;
          this.addLog(WsEventType.RECV, preview);
          // fire-and-forget the async handler
          this.handleMessage(data);
        });

        this.ws!.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
          if (!resolved) {
            resolved = true;
          }
          clearTimeout(this.connectTimer);
          hilog.info(DOMAIN, TAG,
            `WebSocket closed: code=${value.code}, reason=${value.reason}`);
          this.addLog(WsEventType.STATE, `连接关闭 (code=${value.code}, reason=${value.reason})`);
          this.setState(WsState.DISCONNECTED);
          this.stopHeartbeat();
          this.handleReconnect();
          resolve(false);
        });

        this.ws!.on('error', (err: BusinessError) => {
          if (resolved) {
            return;
          }
          resolved = true;
          clearTimeout(this.connectTimer);
          hilog.error(DOMAIN, TAG, `WebSocket error: ${JSON.stringify(err)}`);
          this.addLog(WsEventType.ERROR, `WebSocket 错误: ${err.message}`);
          this.setState(WsState.DISCONNECTED);
          this.fireError(`连接错误: ${err.message}`);
          this.handleReconnect();
          resolve(false);
        });

        this.connectTimer = setTimeout(() => {
          if (!resolved) {
            resolved = true;
            hilog.warn(DOMAIN, TAG, 'Connect timeout');
            this.addLog(WsEventType.ERROR, '连接超时');
            this.setState(WsState.DISCONNECTED);
            this.fireError('连接超时');
            try {
              this.ws?.close();
            } catch (e) {
            }
            this.handleReconnect();
            resolve(false);
          }
        }, CONNECT_TIMEOUT_MS);
      });

      let options: webSocket.WebSocketRequestOptions = {
        header: { 'User-Agent': 'NapcatWatch/1.0' }
      };
      this.ws.connect(url, options, (err: BusinessError, value: boolean) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `Connect call failed: ${JSON.stringify(err)}`);
        }
      });

      return await connectPromise;
    } catch (err) {
      let e = err as BusinessError;
      hilog.error(DOMAIN, TAG, `Connect exception: ${e.message}`);
      this.addLog(WsEventType.ERROR, `连接异常: ${e.message}`);
      this.setState(WsState.DISCONNECTED);
      this.fireError(`连接异常: ${e.message}`);
      this.handleReconnect();
      return false;
    }
  }

  disconnect(): void {
    this.intentionalClose = true;
    this.stopHeartbeat();
    clearTimeout(this.connectTimer);
    if (this.ws) {
      try {
        this.ws.close();
      } catch (e) {
      }
      this.ws = null;
    }
    this.responseCallbacks.clear();
    this.setState(WsState.DISCONNECTED);
    this.addLog(WsEventType.SYSTEM, '主动断开连接');
    hilog.info(DOMAIN, TAG, 'Disconnected');
  }

  send(data: string): void {
    if (this.ws === null || this.state !== WsState.CONNECTED) {
      hilog.warn(DOMAIN, TAG, 'Cannot send: not connected');
      return;
    }
    this.ws.send(data, (err: BusinessError, value: boolean) => {
      if (err) {
        hilog.error(DOMAIN, TAG, `Send failed: ${JSON.stringify(err)}`);
      } else {
        hilog.info(DOMAIN, TAG, `Sent: ${data.substring(0, 200)}`);
        let preview: string = data.length > 300 ? data.substring(0, 300) + '...' : data;
        this.addLog(WsEventType.SEND, preview);
      }
    });
  }

  sendRequest(request: Object): void {
    this.send(JSON.stringify(request));
  }

  private setState(newState: WsState): void {
    if (this.state !== newState) {
      this.state = newState;
      if (this.onStateChange) {
        this.onStateChange(newState);
      }
      for (let listener of this.stateListeners) {
        listener(newState);
      }
    }
  }

  private handleMessage(data: string): void {
    try {
      let raw = JSON.parse(data) as Object;
      let obj = raw as Record<string, Object>;

      // 处理 API 响应（有 echo/status 字段）
      if (obj['echo'] !== undefined || obj['status'] !== undefined) {
        let echo = obj['echo'] as string;
        if (echo && this.responseCallbacks.has(echo)) {
          let cb = this.responseCallbacks.get(echo)!;
          this.responseCallbacks.delete(echo);
          cb(obj);
        }
      }

      // Napcat 消息事件不一定有 post_type，但一定有 message_type + sender
      // 补齐 post_type = 'message' 以匹配 OneBotMessage 模型
      if (obj['message_type'] !== undefined && obj['sender'] !== undefined) {
        obj['post_type'] = 'message';
      }

      // 处理推送事件（有 post_type 字段）
      if (obj['post_type'] !== undefined) {
        let msg = raw as OneBotMessage;
        RefreshLogger.getInstance().log('WS-DISPATCH',
          'pt=' + msg.post_type + ' mt=' + msg.message_type +
          ' uid=' + msg.user_id + ' text=' + (msg.raw_message||'').substring(0,20));
        if (this.onMessage) {
          this.onMessage(msg);
        }
        for (let listener of this.messageListeners) {
          listener(msg);
        }
      }

      if (obj['post_type'] === undefined && obj['echo'] === undefined &&
        obj['meta_event_type'] === undefined) {
        hilog.info(DOMAIN, TAG, `Unknown message format`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Failed to parse message as JSON: ${data.substring(0, 100)}`);
    }
  }

  private handleReconnect(): void {
    if (this.intentionalClose || !this.reconnectEnabled) {
      return;
    }
    if (this.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      hilog.warn(DOMAIN, TAG, 'Max reconnect attempts reached');
      this.addLog(WsEventType.SYSTEM, '已达最大重连次数，停止重连');
      this.fireError('已达最大重连次数，已停止重连');
      return;
    }
    this.reconnectAttempts++;
    let delay = Math.min(
      RECONNECT_BASE_DELAY_MS * Math.pow(2, this.reconnectAttempts - 1),
      RECONNECT_MAX_DELAY_MS
    );
    hilog.info(DOMAIN, TAG,
      `Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
    this.addLog(WsEventType.SYSTEM,
      `重连 ${this.reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS}，${delay}ms 后重试`);
    setTimeout(() => {
      if (this.state === WsState.DISCONNECTED && !this.intentionalClose) {
        this.connect(this.currentUrl);
      }
    }, delay);
  }

  // Napcat 服务端主动推送 heartbeat meta_event，客户端无需发送 ping
  private startHeartbeat(): void {
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  private fireError(message: string): void {
    hilog.error(DOMAIN, TAG, message);
    if (this.onError) {
      this.onError(message);
    }
  }
}
