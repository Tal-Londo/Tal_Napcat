# NapcatWatch 技术文档

> QQ for HarmonyOS Watch — 基于 NapCat/OneBot v11 协议的鸿蒙手表 QQ 客户端

## 项目概览

| 项目 | 值 |
|------|-----|
| 平台 | HarmonyOS NEXT (API 23 / 6.1.0), Stage Mode |
| 设备 | `wearable` (智能手表) |
| 构建 | Hvigor (`@ohos/hvigor-ohos-plugin`) |
| 协议 | WebSocket → NapCat → OneBot v11 |
| DB | SQLite (`napcatwatch_msg.db` + `napcatwatch.db`) |
| 语言 | ArkTS (TypeScript 方言) |
| 源码 | 29 个 `.ets` 文件, ~250 KB |

## 架构图

```
NapCat Server (WS: super.tkcloud.online:3005)
    │
    ▼
WebSocketManager (连接/重连/心跳/请求响应路由)
    │
    ▼
MessageCenter (消息分发/DB 写入/通知推送)
    │
    ├──→ ChatStore (SQLite 持久化)
    │     ├── chats 表 (会话列表)
    │     ├── messages 表 (消息记录)
    │     ├── contacts 表 (好友)
    │     └── groups 表 (群聊)
    │
    ├──→ per-chat handler → ChatDetailPage (聊天界面)
    └──→ global handler → HomePage (刷新消息列表)
```

## 页面导航

```
SplashPage (启动 → 自动连接)
  └── HomePage (ArcSwiper 4 页)
        ├── MessageTab (消息列表)
        │     └── ChatDetailPage (聊天详情)
        │           └── MsgBubble (消息气泡)
        ├── FriendsTab (好友列表)
        ├── GroupsTab (群聊列表)
        └── SettingsTab (设置 → 调试页入口)

SendMessagePage (发送消息, 从 ChatDetailPage 跳转)
MediaViewerPage (图片/视频查看器)
DebugPage / RefreshLogPage / CrownDebugPage / VideoDebugPage
```

## 关键设计模式

### 1. 全局单例

`WebSocketManager`, `MessageCenter`, `ChatStore`, `ConfigManager`, `CacheManager`, `RefreshLogger` 都是单例，通过 `Class.getInstance()` 访问。

### 2. 消息渲染流水线

```
CachedMessage[] (@State)
  → ChatMessagesDataSource (继承 BasicDataSource, 实现 IDataSource)
    → LazyForEach (ArkUI 虚拟列表)
      → MsgBubble (@Component, 按 OneBot segment type 渲染)
```

### 3. 自己发送消息的占位/替换机制

```
sendText():
  1. 发送 WS send_msg 请求
  2. 创建占位 CachedMessage (messageId = -timestamp)
  3. 保存到 DB + 追加到 messages 数组 + 显示
  4. WS 回调收到真实 message_id 后替换占位的 messageId
  5. handleHistoryResponse 拉取到同内容消息时删除占位
```

### 4. 语音播放流程

```
点击语音气泡
  → get_record(file_id, out_format=mp3) WS 请求
  → 响应返回 base64 字段 (MP3 数据)
  → buffer.from(b64, 'base64') → 写入本地文件
  → fileIo.open(r) → 取 fd
  → AVPlayer.url = 'fd://' + fd → prepare → play
```

**注意**: AVPlayer 必须用 `fd://<n>` 协议, 不能用 `file://`

### 5. 视频播放流程

```
打开视频
  → get_file(file_uuid) WS 请求 (刷新过期 rkey)
  → fixVideoUrl(): 追加 android 客户端 UA 参数
    (client_proto=ntv2&client_type=android...)
  → Video 组件 (autoPlay, controls=false, objectFit=Contain)
```

**注意**: 必须用 android UA 参数, 否则 QQ CDN 返回 5411006

### 6. WebSocket 消息分发

`handleMessage()` 解析 JSON:
- 有 `echo` → API 响应回调 (`responseCallbacks` map)
- 有 `message_type` + `sender` → 补充 `post_type='message'` (NapCat 兼容)
- 有 `post_type` → 推送给所有 messageListeners

### 7. ArkUI 手表组件

所有列表页使用 `ArcList` + `ArcListItem` (支持表冠旋转)。
`ChatDetailPage` 的 ArcList id 为 `'chatArcList'`, 每次 notifyDataReload 后调用 `requestArcListFocus()` 保持焦点。

### 8. 通知和后台

- `EntryAbility.onForeground()` → 停止后台任务
- `EntryAbility.onBackground()` → 启动 dataTransfer 后台长时任务
- `MessageCenter.processMessage()` → 用户不在聊天页时发布通知

## DB 表结构

### napcatwatch_msg.db

```sql
chats: id, chat_id(UNIQUE), chat_type, peer_id, peer_name, last_message, unread_count
messages: id, message_id, chat_id, user_id, nickname, content, raw_message, msg_type, timestamp
contacts: id, user_id(UNIQUE), nickname, remark
groups: id, group_id(UNIQUE), group_name, member_count
```

### napcatwatch.db

```sql
app_config: key(PK), value  -- 简单 KV
```

## ChatDetailPage 关键逻辑

| 场景 | 方法 | 行为 |
|------|------|------|
| 进入聊天 | `loadHistory()` | DB 读 100 条 + 双遍去重 (占位跳过同内容真实消息) |
| 拉取历史 | `handleHistoryResponse()` | 服务器消息合并, 占位匹配替换 |
| 实时推送 | `handleWsEvent()` | messageId 去重, 追加+fillSenderRole |
| 返回聊天 | `onPageShow()` → `loadHistorySilent()` | 拾取新占位, 重置未读 |
| 撤回 | `onRecall()` → `applyRecall()` | 内存中标记 revoked, 未找到 800ms 重试 |
| 左滑 | PanGesture(Left,30) | → replyMsg() → SendMessagePage |

## MsgBubble 消息段渲染

| type | 渲染 |
|------|------|
| text | Text(BREAK_ALL, self=#111 else #EEE) |
| image | Image(120×120) → onClick → MediaViewerPage |
| face | Image(22×22) rawfile |
| at | Text(Bold, #FFB347 self/#4DA6FF others) |
| reply | Text(Italic, bordered) 显示引用内容 |
| record | Row(play icon + 语音/播放中/加载中) → get_record + AVPlayer |
| video | ThumbStack 或 TextRow → MediaViewerPage |
| file | Text(文件名) |

## OneBot API 封装 (OneBotModel.ets)

| 方法 | action | 参数 |
|------|--------|------|
| `createSendMsg` | send_msg | message_type, message[text segment] |
| `createSendSegments` | send_msg | 任意 segment 数组 |
| `createSendVoice` | send_msg | record segment (base64) |
| `createGetRecord` | get_record | file, out_format |
| `createGetFile` | get_file | file |
| `createGetMsgHistory` | get_*_msg_history | peer_id, message_id=0, count |
| `createGetGroupMemberList` | get_group_member_list | group_id |

## 调试入口

| 页面 | 入口 | 功能 |
|------|------|------|
| DebugPage | 设置 > "Debug 调试面板" | WS 日志, 上传日志/DB, 通知测试 |
| RefreshLogPage | 设置 > "消息刷新日志" | RefreshLogger 日志, 上传 |
| CrownDebugPage | 设置 > "表冠旋转调试" | 聊天列表 + 表冠测试 |
| VideoDebugPage | 设置 > "视频播放调试" | 直链视频播放测试 |

## 常见问题和修复记录

| 问题 | 根因 | 修复 |
|------|------|------|
| 语音无法播放 | AVPlayer 不支持 `file://` 协议 | 改用 `fd://<n>` 协议 |
| 视频 5411006 | QQ CDN 拒绝手表直连 | 追加 android UA 参数 |
| 自己消息重复 | 占位与真实消息并存 | 两遍去重 + rawMessage 匹配 |
| 表冠旋转失效 | notifyDataReload 后焦点丢失 | 每次 reload 后调 requestArcListFocus |
| 未读数永远是 1 | buildChatItem 写死 1 | 改为从 DB 累加 |
| DB 只查最旧消息 | getMessages ORDER BY ASC | 改为 ORDER BY DESC + reverse |
| 连接 UI 不刷新 | SettingsTab 用单回调 | 改用 addStateListener 多监听 |
| 撤回失败 | loadHistorySilent 整体替换竞态 | 改为内存标记 + 800ms 重试 |
| 头衔不显示 | 新消息未补 senderRole | MessageFormatter + fillSenderRole |
| CQ 码丑陋 | raw_message 含 CQ 原码 | stripCQCode() 转文字描述 |
