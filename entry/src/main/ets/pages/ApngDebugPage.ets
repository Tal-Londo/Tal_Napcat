import { router } from '@kit.ArkUI';
import { apngV2 } from '@ohos/apng';
import { RefreshLogger } from '../model/RefreshLogger';

@Entry
@Component
struct ApngDebugPage {

  // 本地 rawfile face（APNG 格式）
  private localFaces: string[] = ['0', '1', '2', '3', '4', '5', '10', '14', '18', '20', '21', '26', '35'];

  // 网络 APNG（Stapxs CDN）
  private networkApng: string = 'https://lib.stapxs.cn/download/stapxs-qq-lite/qq_emoji/0/apng/0.png';

  @State status: string = 'idle';

  aboutToAppear(): void {
    RefreshLogger.getInstance().log('APNGDBG-OPEN', 'page opened');
  }

  build() {
    Column() {
      Row() {
        Text('APNG 调试')
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
        .margin({ bottom: 8 })

      // 本地 APNG (rawfile) 测试
      Text('本地 rawfile/face/ (APNG 格式)')
        .fontSize(12)
        .fontColor('#C0B8E0')
        .width('90%')
        .margin({ top: 8, bottom: 6 })

      Grid() {
        ForEach(this.localFaces, (faceId: string) => {
          GridItem() {
            Column() {
              apngV2({
                src: $rawfile('face/' + faceId + '.png'),
                speedRate: 1,
                apngWidth: 28,
                apngHeight: 28,
                context: getContext()
              })
                .width(28)
                .height(28)
              Text(faceId)
                .fontSize(8)
                .fontColor('#666666')
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width(36)
          .height(44)
        }, (faceId: string) => faceId)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
      .rowsGap(6)
      .columnsGap(4)
      .width('90%')
      .height(150)
      .scrollBar(BarState.Auto)

      // 单个大尺寸 APNG 测试
      Text('放大测试 (faceId=0)')
        .fontSize(12)
        .fontColor('#FFB347')
        .width('90%')
        .margin({ top: 12, bottom: 6 })

      apngV2({
        src: $rawfile('face/0.png'),
        speedRate: 1,
        apngWidth: 80,
        apngHeight: 80,
        context: getContext()
      })
        .width(80)
        .height(80)

      // 网络 APNG 测试
      Text('网络 APNG (Stapxs CDN)')
        .fontSize(12)
        .fontColor('#4DA6FF')
        .width('90%')
        .margin({ top: 12, bottom: 6 })

      apngV2({
        src: this.networkApng,
        speedRate: 1,
        apngWidth: 80,
        apngHeight: 80,
        context: getContext()
      })
        .width(80)
        .height(80)

      Text('网络 URL: ' + this.networkApng)
        .fontSize(8)
        .fontColor('#444444')
        .width('90%')
        .maxLines(2)
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
