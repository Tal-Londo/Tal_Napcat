## 1.1.4
1. Release official version.

## 1.1.4-rc.0
1. Fix the lagging issue of some APNG animations.

## 1.1.3
1. Fix compilation warning issues.

## 1.1.2
1. Released version 1.1.2.

## 1.1.2-rc.8
1. Support the function of centering animation display.

## 1.1.2-rc.7
1. Optimize the code by replacing deprecated interfaces with the latest and standardized ones.
2. Support static image loading and display.

## 1.1.2-rc.6
1. Fixed the issue where animations did not automatically stop playing in certain invisible scenes.

## 1.1.2-rc.5
1. Modified the compilation and build warning prompt.
2. Add confusion instructions to the document.

## 1.1.2-rc.4
1. fix: Fixed the issue where the parent component node was hidden while the child component canvas node was visible, causing the animation to still play.
2. fix: Fixed the issue where animations are automatically destroyed when their state is not visible in a specific scene.
3. Support custom loading prompt text.
4. fix: Fixed the issue that the loop playback time is taken from the first frame, which causes the delay time of the first frame to be inconsistent with other frames and the playback is too slow.
5. fix: Fixed the issue that animations could not be played according to the specified playNum when the animations were played indefinitely

## 1.1.2-rc.3
1. Code refactoring when APNG animation is not visible
2. Fixed the issue of abnormal display of some dynamic images during the initialization loading phase when APNG lazily loads multiple dynamic images from small to large
3. Log modification

## 1.1.2-rc.2
1. Provides the @Component version of apng

## 1.1.2-rc.1
1. canvas listening event trigger location replacement.

## 1.1.2-rc.0
1. When the APNG animation is not visible, the APNG automatically stops playing the animation to reduce power consumption.
2. Fixed a bug where a single APNG component created multiple setInterval timers in the initialization scenario.


## 1.1.1
1. Added functions such as control play, including start play, pause play, and stop play
2. Add listening events, including play,pause, and stop events
3. Modify the problem that apng listening events cannot distinguish images and add a frame listening event
4. Modify LogUtils to record logs

## 1.1.0
1.V2 decorator adaptation

## 1.0.0-rc.9
1. Add the ApngController to add the playback control function of the Apng

## 1.0.0-rc.8
1. Add a custom memory caching mechanism to optimize network image download performance

## 1.0.0-rc.7
1. Modify the problem that the memory keeps growing when a single image is loaded

## 1.0.0-rc.6
1. Optimize the page stalling problem when multiple apng images are loaded

## 1.0.0-rc.5
1. Modify the problem that UI does not refresh automatically when src resources change

## 1.0.0-rc.4
1. Added the width-height function for apng images
2. context Context incoming mode optimization

## 1.0.0-rc.3
1. Rectify the problem that the HSP module cannot obtain the resource file

## 1.0.0-rc.2
1. Added support for pictures in the sandbox path

## 1.0.0-rc.1
1. When apng is implemented with canvas, some residual shadows and graphics are missing
2. The double speed does not take effect
3. Added the apng support for network images
4. Modify the component memory usage problem

## 1.0.0-rc.0
1. The third library implements APNG format image loading and display, and supports format image encoding and decoding