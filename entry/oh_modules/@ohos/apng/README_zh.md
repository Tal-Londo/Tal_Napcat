# APNG

## 简介

ohos_apng是以开源库[apng-js](https://github.com/davidmz/apng-js)为参考，基于1.1.2版本，通过重构解码算法，拆分出apng里各个帧图层的数据；使用arkts能力，将每一帧数据组合成imagebitmap，使用定时器调用每一帧数据 通过canvas渲染，从而达到帧动画效果.对外提供解码渲染能力。

#### 效果图如下：

![演示示例](./preview.gif)

## 下载安装

```
ohpm install @ohos/apng
```
OpenHarmony ohpm 环境配置等更多内容，请参考 [如何安装 OpenHarmony ohpm 包](https://gitcode.com/openharmony-tpc/docs/blob/master/OpenHarmony_har_usage.md)。

## 使用说明
```
  1、如果是在HSP模块中使用，可以使用两种方式传入Context上下文对象。
     1).在EntryAbility文件引入 import { GlobalContext } from '@ohos/apng',
        在onCreate函数中调用，传入上下文对象，用作后续读取本地的图片资源文件。
        示例：
        GlobalContext.getContext().setObject('MainContext',this.context);
      2).在使用组件的时候通过参数传入Context对象：
        示例：
         apngV2({
            src: $r('app.media.stack'),
            speedRate: this.speedRate,
            context: this.getUIContext().getHostContext()
          })
         apng({
            src: $r('app.media.stack'),
            speedRate: this.speedRate,
            context: this.getUIContext().getHostContext()
          })
```
```
  2、引入 import {apng, ApngController} from '@ohos/apng'。
  示例1：
    apngV2({
        src: $r('app.media.stack'), //图片资源
        speedRate: 1 //动画倍速
    })
    apng({
        src: $r('app.media.stack'), //图片资源
        speedRate: 1 //动画倍速
    })
  示例2：
    apngV2({
        src: 'https://gitcode.com/openharmony-sig/ohos_apng/blob/master/entry/src/main/resources/base/media/stack.png', // 网络资源连接
        speedRate: 1 //动画倍速
    })
    apng({
        src: 'https://gitcode.com/openharmony-sig/ohos_apng/blob/master/entry/src/main/resources/base/media/stack.pngg', // 网络资源连接
        speedRate: 1 //动画倍速
    })
    
 
  示例3：
    apngV2({
        src: this.srcUint8Array, // Uint8Array对象资源
        speedRate: 1 //动画倍速
    })
    apng({
        src: this.srcUint8Array, // Uint8Array对象资源
        speedRate: 1 //动画倍速
    })
    
  示例4：
    apngV2({
        src: this.getUIContext().getHostContext()?.filesDir + '/stack.png', // 沙箱路径
        speedRate: 1 //动画倍速
    })
    apng({
        src: this.getUIContext().getHostContext()?.filesDir + '/stack.png', // 沙箱路径
        speedRate: 1 //动画倍速
    })
  示例5：
    apngV2({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200  //设置动图的高度
    })
    apng({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200  //设置动图的高度
    })
  示例6：
    controller: ApngController = new ApngController();
    
    apngV2({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200  //设置动图的高度
        controller: this.controller
    })
    apng({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200  //设置动图的高度
        controller: this.controller
    })    

    this.controller.pause();
    this.controller.stop();
  示例7：
    aboutToAppear() {
        emitter.on("ohos-apng", (data) => {
          console.log('data', JSON.stringify(data));
        })
    }
   示例8：
    apngV2({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200,  //设置动图的高度
        loadingText: this.loadingText  //加载中提示文字
    })
    apng({
        src: $r('app.media.stack'),  //设置图片资源
        speedRate: this.speedRate, //设置动画倍速
        apngWidth: 200,  //设置动图的宽度
        apngHeight: 200,  //设置动图的高度
        loadingText: this.loadingText   //加载中提示文字
    })

```
```
  3、自定义内存缓存使用。
    支持自定义内存缓存策略，支持设置内存缓存的大小(默认LRU策略)：
    Apng.getInstance().initMemoryCache();
    内存缓存默认关闭，开启/关闭内存缓存: 
    Apng.getInstance().setEnableCache(enableCache: boolean);
    清空全部内存缓存：
    Apng.getInstance().removeAllMemoryCache();
    清空指定内存缓存：
    Apng.getInstance().removeMemoryCache(src); 
    自定义内存缓存大小：
    Apng.getInstance().initMemoryCache(new MemoryLruCache(200, 128 * 1024 * 1024));
```
## 接口说明

| **接口**                                                                                                                                                                                                                                                                            | 参数                                                                                                                                                                                                                                                                                                                | 功能                                                       |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| apng(src: Resource/Uint8Array/string, <br>speedRate: number, <br>apngWidth: string/number/Resource, <br>apngHeight: string/number/Resource,   <br>context: Context, <br>loadingText: string, <br>numPlays: number, <br>alignItems: HorizontalAlign, <br>justifyContent: FlexAlign);| src：图片资源，支持本地资源，网络图片以及Uint8Array三种格式<br/>speedRate：动画倍速，默认值为1,取值范围(0.1~2)。 <br/>apngWidth：图片宽度，默认原图宽度(支持vp及px单位，默认vp)。 <br/>apngHeight：图片高度，默认原图高度(支持vp及px单位，默认vp)。 <br/>context：上下文对象，默认为null。 <br/>numPlays：循环次数，必须设置controller，numPlays才会生效。 <br/>alignItems：子组件在水平方向的对齐格式。 <br/>justifyContent：子组件在垂直方向的对齐格式。 | apng图片展示(@Component实现)。 `loadingText` :加载提示文本，默认为"加载中"。  |
| apngV2(src: Resource/Uint8Array/string, <br>speedRate: number, <br>apngWidth: string/number/Resource, <br>apngHeight: string/number/Resource, <br>context: Context, <br>loadingText: string, <br>numPlays: number, <br>alignItems: HorizontalAlign, <br>justifyContent: FlexAlign);| src：图片资源，支持本地资源，网络图片以及Uint8Array三种格式<br/>speedRate：动画倍速，默认值为1,取值范围(0.1~2)。 <br/>apngWidth：图片宽度，默认原图宽度(支持vp及px单位，默认vp)。 <br/>apngHeight：图片高度，默认原图高度(支持vp及px单位，默认vp)。 <br/>context：上下文对象，默认为null。 <br/>numPlays：循环次数，必须设置controller，numPlays才会生效。 <br/>alignItems：子组件在水平方向的对齐格式。 <br/>justifyContent：子组件在垂直方向的对齐格式。 | apng图片展示(@ComponentV2实现)。`loadingText` :加载提示文本，默认为"加载中"。 |
| GlobalContext.getContext().setObject(key: string,objectClass: Object);                                                                                                                                                                                                            | key：上下文对象对应的key,固定值 "MainContext"<br/>objectClass:上下文对象(this.context)。                                                                                                                                                                                                                                            | 在EntryAbility文件设置上下文对象 。                                 |
| Apng.getInstance().setEnableCache(enableCache: boolean);                                                                                                                                                                                                                          | enableCache：是否开启内存缓存，默认false。                                                                                                                                                                                                                                                                                     | 开启或关闭内存缓存。                                               |
| Apng.getInstance().removeAllMemoryCache();                                                                                                                                                                                                                                        |                                                                                                                                                                                                                                                                                                                   | 清空全部内存缓存。                                                |
| Apng.getInstance().removeMemoryCache(src?: ResourceStr / Uint8Array);                                                                                                                                                                                                             | src：图片资源，支持本地资源，网络图片以及Uint8Array三种格式。                                                                                                                                                                                                                                                                             | 清除指定图片的内存缓存。                                             |
| Apng.getInstance().initMemoryCache(newMemoryCache: IMemoryCache);                                                                                                                                                                                                                 | 自定义内存缓存策略，支持设置内存缓存的大小。                                                                                                                                                                                                                                                                                            | 自定义内存缓存策略，设置内存缓存的大小。                                     |
| ApngController.play();                                                                                                                                                                                                                                                            | Apng播放控制，播放Apng图片，默认开启播放。                                                                                                                                                                                                                                                                                         |                                                          |
| ApngController.puase();                                                                                                                                                                                                                                                           | Apng播放控制，暂停播放Apng图片。                                                                                                                                                                                                                                                                                              |                                                          |
| ApngController.stop();                                                                                                                                                                                                                                                            | Apng播放控制，停止播放Apng图片。                                                                                                                                                                                                                                                                                              |                                                          |
|                                                                                                                                                                                                                                                                                   |                                                                                                                                                                                                                                                                                                                   |                                                          |


## 关于混淆
- 代码混淆，请查看[代码混淆简介](https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/arkts-utils/source-obfuscation.md)。
- 如果希望apng库在代码混淆过程中不会被混淆，需要在混淆规则配置文件obfuscation-rules.txt中添加相应的排除规则：
```
-keep
./oh_modules/@ohos/apng
```

## 约束与限制

在下述版本验证通过：

DevEco Studio NEXT Developer Beta3: 5.0 (5.0.3.530);
SDK: API12 (5.0.0.35(SP3))。

## 目录结构

```
|---- apng
|     |---- entry # 示例代码文件夹
|     |---- library # apng库文件夹
|           |---- src
|                 |---- main
|                       |---- ets
|                             |---- components
|                                   |---- apng.ets # 处理apng拆解后的每一帧，每一帧通过canvas绘制成apng,apng的@Component版本
|                                   |---- apngV2.ets # 处理apng拆解后的每一帧，每一帧通过canvas绘制成apng,apng的@ComponentV2版本
|                                   |---- crc32.ets # 用作数据传输和存储中的错误检测
|                                   |---- GlobalContext.ets # 创建了一个全局类，用来获取数据对象或者设置对象的值
|                                   |---- manager.ets # 读取本地apng文件，获取到文件buffer对象
|                                   |---- parser.ets # 对buffer对象进行拆解
|                                   |---- structs.ets # 创建了两个类，APNG类指的是整个APNG动画，包括宽度、高度、播放次数、播放时间和帧列表等属性，Frame类指的是APNG动画中的每一帧
|                             |---- utils # 工具类相关
|                             |---- Apng.ets  # Apng门面，app持久化类
|                             |---- ApngDispatcher.ets # Apng图片请求排队分发处理类
|                             |---- ApngRequest.ets # Apng图片请求参数封装
|     |---- README_zh.MD # 安装使用方法

```
## 贡献代码

使用过程中发现任何问题都可以提[Issue](https://gitcode.com/openharmony-sig/ohos_apng/issues)，当然，也非常欢迎提[PR](https://gitcode.com/openharmony-sig/ohos_apng/pulls)。

## 开源协议

本项目基于 [MIT](https://gitcode.com/openharmony-sig/ohos_apng/blob/master/LICENSE.txt) ，请自由地享受和参与开源。