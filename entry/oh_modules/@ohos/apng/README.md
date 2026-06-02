# APNG

## Introduction

Based on the open source software [apng-js](https://github.com/davidmz/apng-js) of the version 1.1.2, this project provides functions for decoding and rendering animated PNG (APNG) images for external systems. It utilizes a reconstructed decoding algorithm to parse the data at each frame layer in an APNG image, uses the ArkTS capability to merge each frame of data into an image bitmap, and employs a timer to sequentially render each frame onto a canvas.

#### The display effect is as follows.

![Demo](./preview.gif)

## How to Install

```
ohpm install @ohos/apng
```
For details about the OpenHarmony ohpm environment configuration, see [OpenHarmony HAR](https://gitcode.com/openharmony-tpc/docs/blob/master/OpenHarmony_har_usage.en.md).

## How to Use
```
  1. If the project is used in an HSP module, you can use either of the following methods to pass in a context object.
     (1) Add the following statement in the EntryAbility file: import { GlobalContext } from '@ohos/apng',
        Use the onCreate function to pass in the context object for reading local image files.
        Example:
        GlobalContext.getContext().setObject('MainContext',this.context);
      (2) Pass in the context object through parameters when using the component.
        Example:
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
  2. Use import {apng, ApngController} from '@ohos/apng'.
  Example 1:
    apngV2({
        src: $r('app.media.stack'), // Local image resource.
        speedRate: 1 // Animation speed.
    })
    apng({
        src: $r('app.media.stack'), // Local image resource.
        speedRate: 1 // Animation speed.
    })
  Example 2:
    apngV2({
        src: 'https://gitcode.com/openharmony-sig/ohos_apng/blob/master/entry/src/main/resources/base/media/stack.png', // Network image resource.
        speedRate: 1 // Animation speed.
    })
    apng({
        src: 'https://gitcode.com/openharmony-sig/ohos_apng/blob/master/entry/src/main/resources/base/media/stack.png', // Network image resource.
        speedRate: 1 // Animation speed.
    })
 
  Example 3:
    apngV2({
        src: this.srcUint8Array, // Uint8Array object resource.
        speedRate: 1 // Animation speed.
    })
    apng({
        src: this.srcUint8Array, // Uint8Array object resource.
        speedRate: 1 // Animation speed.
    })
    
  Example 4:
    apngV2({
        src: this.getUIContext().getHostContext().filesDir + '/stack.png', // Sandbox path.
        speedRate: 1 // Animation speed.
    })
    apng({
        src: this.getUIContext().getHostContext().filesDir + '/stack.png', // Sandbox path.
        speedRate: 1 // Animation speed.
    })
  Example 5:
    apngV2({
        src: $r('app.media.stack'), // Set the image resource.
        speedRate: this.speedRate, // Set the animation speed.
        apngWidth: 200, // Set the width of the animation.
        apngHeight: 200 // Set the height of the animation.
    })
    apng({
        src: $r('app.media.stack'), // Set the image resource.
        speedRate: this.speedRate, // Set the animation speed.
        apngWidth: 200, // Set the width of the animation.
        apngHeight: 200 // Set the height of the animation.
    })
  Example 6:
    controller: ApngController = new ApngController();
    
    apngV2({
        src: $r('app.media.stack'), // Set the image resource.
        speedRate: this.speedRate, // Set the animation speed.
        apngWidth: 200, // Set the width of the animation.
        apngHeight: 200 // Set the height of the animation.
        controller: this.controller
    })
    apng({
        src: $r('app.media.stack'), // Set the image resource.
        speedRate: this.speedRate, // Set the animation speed.
        apngWidth: 200, // Set the width of the animation.
        apngHeight: 200 // Set the height of the animation.
        controller: this.controller
    })   

    this.controller.pause();
    this.controller.stop();
  Example 7:
    aboutToAppear() {
        emitter.on("ohos-apng", (data) => {
          console.log('data', JSON.stringify(data));
        })
    }
    
  Example 8:
    apngV2({
        src: $r('app.media.stack'),  // Set the image resource.
        speedRate: this.speedRate,  // Set the animation speed.
        apngWidth: 200,   // Set the width of the animation.
        apngHeight: 200,  // Set the height of the animation.
        loadingText: this.loadingText  // Set loading prompt text.
    })
    apng({
        src: $r('app.media.stack'),  // Set the image resource.
        speedRate: this.speedRate, // Set the animation speed.
        apngWidth: 200,   // Set the width of the animation.
        apngHeight: 200,  // Set the height of the animation.
        loadingText: this.loadingText   // Set loading prompt text.
    })

```
```
  3. Customize the memory cache usage.
    You can customize the memory cache policy and set the memory cache size (LRU policy by default).
    Apng.getInstance().initMemoryCache().
    Enable or disable the memory cache. The memory cache is disabled by default.
    Apng.getInstance().setEnableCache(enableCache: boolean)
    Clear all memory caches.
    Apng.getInstance().removeAllMemoryCache();
    Clear the specified memory cache.
    Apng.getInstance().removeMemoryCache(src); 
    Customize the memory cache size.
    Apng.getInstance().initMemoryCache(new MemoryLruCache(200, 128 * 1024 * 1024));
```
## Available APIs

| Name                                                                                                                                                                     | Parameter                                                        | Description                                                                                                     |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ------------------------------------------------------------ |-----------------------------------------------------------------------------------------------------------------|
| apng(src: Resource/Uint8Array/string, <br>speedRate: number, <br>apngWidth: string/number/Resource, <br>apngHeight: string/number/Resource,   <br>context: Context, <br>loadingText: string, <br>numPlays: number, <br>alignItems: HorizontalAlign, <br>justifyContent: FlexAlign);| `src`: image resource, which can be a local image, network image, or Uint8Array object.<br>`speedRate`: animation speed. The default value is 1. The value ranges from 0.1 to 2.<br>`apngWidth`: image width. The default value is the width of the original image. The unit can be vp or px, and the default unit is vp.<br>`apngHeight`: image height. The default value is the height of the original image. The unit can be vp or px, and the default unit is vp.<br>`context`: context object. The default value is null.<br/>`numPlays`：Number of loops. The controller must be set for numPlays to take effect. <br/>`alignItems`：Alignment format of child components in the horizontal direction. <br/>`justifyContent`：Alignment format of child components in the vertical direction.| APNG image(@Component implementation).  `loadingText` .loading prompt text, The default value is "Loading...".  |
| apng(src: Resource/Uint8Array/string, <br>speedRate: number, <br>apngWidth: string/number/Resource, <br>apngHeight: string/number/Resource,   <br>context: Context, <br>loadingText: string, <br>numPlays: number, <br>alignItems: HorizontalAlign, <br>justifyContent: FlexAlign);| `src`: image resource, which can be a local image, network image, or Uint8Array object.<br>`speedRate`: animation speed. The default value is 1. The value ranges from 0.1 to 2.<br>`apngWidth`: image width. The default value is the width of the original image. The unit can be vp or px, and the default unit is vp.<br>`apngHeight`: image height. The default value is the height of the original image. The unit can be vp or px, and the default unit is vp.<br>`context`: context object. The default value is null.<br/>`numPlays`：Number of loops. The controller must be set for numPlays to take effect. <br/>`alignItems`：Alignment format of child components in the horizontal direction. <br/>`justifyContent`：Alignment format of child components in the vertical direction.| APNG image(@ComponentV2 implementation). `loadingText` .loading prompt text, The default value is "Loading...". |
| GlobalContext.getContext().setObject(key: string,objectClass: Object);                                                                                                    | `key`: key corresponding to the context object. The value is fixed at `MainContext`.<br>`objectClass`: context object (`this.context`).| Sets a context object in the EntryAbility file.                                                                 |
| Apng.getInstance().setEnableCache(enableCache: boolean);                                                                                                                  | `enableCache`: whether to enable the memory cache. The default value is `false`.                    | Enables or disables the memory cache.                                                                           |
| Apng.getInstance().removeAllMemoryCache();                                                                                                                               |                                                              | Clears all memory caches.                                                                                       |
| Apng.getInstance().removeMemoryCache(src?: ResourceStr / Uint8Array);                                                                                                    | `src`: image resource, which can be a local image, network image, or Uint8Array object. | Clears the specified memory cache.                                                                              |
| Apng.getInstance().initMemoryCache(newMemoryCache: IMemoryCache);                                                                                                         | `IMemoryCache`: memory cache.                  | Customizes the memory cache policy and sets the memory cache size.                                              |
| ApngController.play();                                                                                                                                                    | Plays an APNG image. The playback is enabled by default.                    |                                                                                                                 |
| ApngController.puase();                                                                                                                                                   | Pauses the playback of an APNG image.                              |                                                                                                                 |
| ApngController.stop();                                                                                                                                                    | Stops the playback of an APNG image.                              |                                                                                                                 |
|                                                                                                                                                                          |                                                              |                                                                                                                 |

## About obfuscation
- Code obfuscation, please see[Code Obfuscation](https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/arkts-utils/source-obfuscation.md).
- If you want the apng library not to be obfuscated during code obfuscation, you need to add corresponding exclusion rules in the obfuscation rule configuration file obfuscation-rules.txt：
```
-keep
./oh_modules/@ohos/apng
```

## Constraints

This project has been verified in the following version:

DevEco Studio NEXT Developer Beta3: 5.0 (5.0.3.530);
SDK: API 12 (5.0.0.35 (SP3)).

## Directory Structure

```
|---- apng
|     |---- entry  # Sample code
|     |---- library  # apng library
|           |---- src
|                 |---- main
|                       |---- ets
|                             |---- components
|                                   |---- apng.ets # Processes each frame disassembled from the APNG image file. Each frame is drawn as an APNG file on the canvas.The @Component version of apng.
|                                   |---- apngV2.ets # Processes each frame disassembled from the APNG image file. Each frame is drawn as an APNG file on the canvas.The @ComponentV2 version of apng.
|                                   |---- crc32.ets # Detects errors in data transmission and storage.
|                                   |---- GlobalContext.ets # Creates a global class to obtain data objects or set object values.
|                                   |---- manager.ets # Reads the local APNG file and obtains the buffer object of the file.
@Component 组件|                                   |---- parser.ets # Splits the buffer object.
|                                   |---- structs.ets # Creates two classes. The APNG class refers to the entire APNG animation, including the width, height, number of playback times, playback time, and frame list. The Frame class refers to each frame in the APNG animation.
|                             |---- utils # Utility class.
|                             |---- Apng.ets  # APNG entry, app persistence class.
|                             |---- ApngDispatcher.ets # Classes for distributing APNG image requests.
|                             |---- ApngRequest.ets # Encapsulation of APNG image request parameters.
|     |---- README.MD  # Readme

```
## How to Contribute

If you find any problem during the use, submit an [issue](https://gitcode.com/openharmony-sig/ohos_apng/issues) or a [PR](https://gitcode.com/openharmony-sig/ohos_apng/pulls).

## License

This project is licensed under [MIT License](https://gitcode.com/openharmony-sig/ohos_apng/blob/master/LICENSE.txt).
