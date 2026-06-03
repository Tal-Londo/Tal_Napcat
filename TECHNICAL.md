# NapcatWatch 技术文档

> QQ for HarmonyOS Watch — NapCat/OneBot v11 手表客户端
> **最后更新: 2026-06-03**

## 项目概览

| 项目 | 值 |
|------|-----|
| 平台 | HarmonyOS NEXT API 23 (6.1.0), Stage Mode |
| 设备 | `wearable` (手表) |
| 构建 | Hvigor + ohpm (`/d/command-line-tools/bin/hvigorw.bat`) |
| 依赖 | `@ohos/apng` v1.1.4 |
| 协议 | WebSocket → NapCat → OneBot v11 |
| WS URL | `ws://super.tkcloud.online:3005/ws?access_token=Nahida2147483647` |
| 日志 | 上传到 `super.tkcloud.online:8899/upload` |
| 源码 | 30 个 `.ets` 文件 |
| 测试 WS | `node -e "const WebSocket=require('ws');..."` in /tmp (npm i ws) |

## 架构

```
NapCat Server (WS)
  → WebSocketManager (连接/重连/响应路由)
    → MessageCenter (分发/DB/通知)
      ├→ ChatStore (SQLite: chats/messages/contacts/groups)
      ├→ per-chat handler → ChatDetailPage
      └→ global handler → HomePage (刷新)
```

## 所有页面

| 页面 | 功能 |
|------|------|
| SplashPage | 启动 → 自动连接 |
| HomePage | ArcSwiper 4 页: MessageTab/FriendsTab/GroupsTab/SettingsTab |
| ChatDetailPage | 聊天详情 (`ArcList + LazyForEach + ChatMessagesDataSource`) |
| SendMessagePage | 发送消息 (文本/表情/@/语音) |
| ProfilePage | 资料卡 (私聊/群聊/成员) + 免打扰 |
| MediaViewerPage | 图片/视频查看 (`Video` 组件) |
| ForwardDetailPage | 合并转发查看 |
| DebugPage | WS 日志 + 通知测试 + 上传日志/DB |
| RefreshLogPage | RefreshLogger 日志查看 |
| CrownDebugPage | 表冠调试 |
| VideoDebugPage | 视频测试页面 |
| ApngDebugPage | APNG 动图测试页面 |
| EditServerPage | 服务器配置 |

## 关键设计

### 消息管道
```
CachedMessage[] (@State)
  → ChatMessagesDataSource (IDataSource)
    → LazyForEach → ArcListItem → MsgBubble
```

### 自我消息流程
1. `sendText()` 创建占位 (`messageId = -Date.now()`)
2. WS `sendRequestWithCallback` 收到 `message_id` 后替换占位
3. `loadHistory()` 用 `msgType|rawMessage` 复合键去重

### 语音播放
1. `get_record(file_amr_id, out_format=mp3)` → base64
2. `buffer.from(b64,'base64')` → 写本地文件 → `fileIo.open(r)` → fd
3. `AVPlayer.url = 'fd://' + fd` (不能用 `file://`)

### 视频播放
- `Video` 组件 + `fixVideoUrl()`: QQ CDN 需 android UA 参数
- NapCat 不支持视频转码 (`get_record` 对视频 retcode=1200)

### 历史消息
- NapCat `get_group_msg_history` **不支持游标分页**
- `loadMoreHistory`: Phase1=本地DB(`getMessagesBefore`), Phase2=远程全量重拉(count+50)
- 首次 `loadHistory`: count=100

## 数据库

### napcatwatch_msg.db (ChatStore)
```sql
chats(id, chat_id UNIQUE, chat_type, peer_id, peer_name, last_message, unread_count, is_top)
messages(id, message_id, chat_id, user_id, nickname, content, raw_message, msg_type, timestamp)
contacts(id, user_id UNIQUE, nickname, remark)
groups(id, group_id UNIQUE, group_name, member_count)
```
- `getMessagesBefore(chatId, beforeTs, limit)`: WHERE timestamp < `beforeTs` ORDER BY DESC
- `memberCache`: in-memory `Map<groupId, Map<userId, GroupMember>>`

### napcatwatch.db (ConfigManager)
```sql
app_config(key TEXT PK, value TEXT)  -- KV存储
```
键: `server_url`, `access_token`, `self_id`, `auto_reconnect`, `history_servers`, `muted_chats`, `draft_<chatId>`

## OneBot 请求工厂

| 方法 | action |
|------|--------|
| `createSendMsg/SendSegments/SendVoice` | send_msg |
| `createGetRecord(file, out_format)` | get_record (语音转码) |
| `createGetFile(file)` | get_file (刷新视频URL) |
| `createGetMsgHistory(peerId, type, echo, count)` | get_*_msg_history |
| `createGetForwardMsg(id)` | get_forward_msg |
| `createGetStrangerInfo(userId)` | get_stranger_info |
| `createGetGroupDetailInfo(groupId)` | get_group_detail_info |
| `createGetGroupMemberInfo/List` | get_group_member_info/list |

## HarmonyOS 魔鬼细节

1. **AVPlayer**: 本地文件用 `fd://<n>` 不能 `file://`
2. **AVRecorder**: 同样用 `fd://` 打开文件
3. **Video 组件**: QQ CDN 拒绝手表直连, 需仿 android UA
4. **ArcList 焦点**: 每次 `notifyDataReload` 后要 `requestArcListFocus()`
5. **后台保活**: `dataTransfer` 仅~6min, `taskKeeping` 需 ACL, 无真正长连接后台
6. **@arkts 严格限制**: `any/unknown` 不可用, 对象字面量需显式类型, import 默认导出用 `import X from` 非 `import { X } from`
7. **apngV2**: rawfile 需 `context: getContext()` 参数, 网络 URL 同样
8. **SymbolGlyph**: `sys.symbol.*` 在手表上不全, 调试入口用纯文字
9. **scrollBar**: ArcList 的 `BarState.Auto` 在手表上导致偏移, 聊天页用 `Off`

## 已知限制

1. NapCat `get_group_msg_history` 不支持游标分页 (message_seq 被忽略)
2. NapCat 视频转码不支持 (retcode=1200)
3. 后台 WebSocket 最长 ~6 分钟存活
4. 手表无视频画面渲染 (仅音频流)
5. `@ohos/apng` 需 `context` 参数内联传入

## Build & Test

```bash
cd "D:/super projec lite/Tal_Napcat/NapcatWatch"
/d/command-line-tools/bin/hvigorw.bat assembleApp
/d/command-line-tools/bin/ohpm.bat install
```

WS 测试 (在 /tmp):
```bash
npm i ws
node -e "const WebSocket=require('ws'); const ws=new WebSocket('ws://super.tkcloud.online:3005/ws?access_token=Nahida2147483647'); ..."
```
