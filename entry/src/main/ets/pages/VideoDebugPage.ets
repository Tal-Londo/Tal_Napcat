import { router } from '@kit.ArkUI';
import { RefreshLogger } from '../model/RefreshLogger';

@Entry
@Component
struct VideoDebugPage {
  private videoController: VideoController = new VideoController();
  @State status: string = 'ready';

  private testUrl: string = 'https://multimedia.nt.qq.com.cn/download?appid=1415&format=origin&orgfmt=t265&spec=0&client_proto=ntv2&client_appid=537324442&client_type=android&client_ver=9.2.30&client_down_type=manual&client_aio_type=bigs&rkey=CAQSqAGZmA0fLi93qKJbqpVrw4gtxpWEk1-TjdjHT91b92t5DGBTpNDJoNCIjBeQXqPNVB49UYrzSVwYacj6vmxxNndnyOnB7N24nvmrM4CHwNWgVG2WdJGhkItyhsolQrdKVhVxfKsEQawOsNI0GwTZl0XRNE1J13YNbXpSIl4PcCtC1qpJdEAFTVWrKRvINPt_q87GuHabs_fmrR01vngXOh2rkFVAAOVzjLU';

  aboutToAppear(): void {
    RefreshLogger.getInstance().log('VIDEO-DEBUG', 'page opened, url=' + this.testUrl);
  }

  build() {
    Column() {
      Row() {
        Text('视频调试')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
        Text('返回')
          .fontSize(12)
          .fontColor('#C0B8E0')
          .onClick(() => { router.back(); })
      }
      .width('90%')
      .padding({ top: 8, bottom: 8 })

      Text('状态: ' + this.status)
        .fontSize(12)
        .fontColor('#888888')
        .width('90%')

      Video({
        src: this.testUrl,
        controller: this.videoController
      })
        .autoPlay(true)
        .controls(false)
        .loop(false)
        .objectFit(ImageFit.Contain)
        .height('60%')
        .width('90%')
        .onStart(() => {
          this.status = 'playing';
          RefreshLogger.getInstance().log('VIDEO-DEBUG-ONSTART', 'playback started');
        })
        .onPause(() => {
          this.status = 'paused';
          RefreshLogger.getInstance().log('VIDEO-DEBUG-ONPAUSE', 'playback paused');
        })
        .onFinish(() => {
          this.status = 'finished';
          RefreshLogger.getInstance().log('VIDEO-DEBUG-ONFINISH', 'playback finished');
        })
        .onError((event) => {
          this.status = 'error: ' + (event?.code ?? '?') + ' ' + (event?.message ?? '?');
          RefreshLogger.getInstance().log('VIDEO-DEBUG-ONERR', 'code=' + (event?.code ?? '?') + ' msg=' + (event?.message ?? '?'));
        })
        .onPrepared((event) => {
          this.status = 'prepared, duration=' + event?.duration;
          RefreshLogger.getInstance().log('VIDEO-DEBUG-ONPREPARED', 'duration=' + event?.duration);
        })
        .onUpdate((event) => {
          if (event?.time !== undefined) {
            this.status = 'time=' + event.time;
          }
        })

      Text(this.testUrl)
        .fontSize(9)
        .fontColor('#444444')
        .width('90%')
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
