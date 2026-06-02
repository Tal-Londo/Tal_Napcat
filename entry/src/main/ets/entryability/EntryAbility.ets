import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, common } from '@kit.AbilityKit';
import { RefreshLogger } from '../model/RefreshLogger';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  static context: common.UIAbilityContext | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    EntryAbility.context = this.context;
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    RefreshLogger.getInstance().log('ENTRY-CREATE', 'Ability onCreate');
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    RefreshLogger.getInstance().log('ENTRY-DESTROY', 'Ability onDestroy');
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    RefreshLogger.getInstance().log('ENTRY-WINSTART', 'onWindowStageCreate');
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        RefreshLogger.getInstance().log('ENTRY-WINFAIL', 'loadContent failed: ' + JSON.stringify(err));
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      RefreshLogger.getInstance().log('ENTRY-WINOK', 'loadContent succeeded');
    });
  }

  onWindowStageDestroy(): void {
    RefreshLogger.getInstance().log('ENTRY-WINSTOP', 'onWindowStageDestroy');
  }

  onForeground(): void {
    RefreshLogger.getInstance().log('ENTRY-FG', 'onForeground');
    this.stopBackgroundTask();
    // 每次回前台检查通知权限
    this.checkNotificationPermission();
  }

  onBackground(): void {
    RefreshLogger.getInstance().log('ENTRY-BG', 'onBackground');
    this.startBackgroundTask();
  }

  // ========== Notification Channel ==========

  async setupNotificationChannel(): Promise<void> {
    try {
      let isEnabled = await notificationManager.isNotificationEnabled();
      RefreshLogger.getInstance().log('NOTIFY-ENABLED', 'isNotificationEnabled=' + isEnabled);
      if (!isEnabled) {
        return;
      }
      // 创建通知渠道
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      RefreshLogger.getInstance().log('NOTIFY-SLOT', 'slot SOCIAL_COMMUNICATION added');
    } catch (e) {
      let err = e as BusinessError;
      RefreshLogger.getInstance().log('NOTIFY-SLOT-ERR', 'code=' + err.code + ' msg=' + err.message);
    }
  }

  async checkNotificationPermission(): Promise<void> {
    try {
      let isEnabled = await notificationManager.isNotificationEnabled();
      RefreshLogger.getInstance().log('NOTIFY-CHECK', 'enabled=' + isEnabled);
      if (isEnabled) {
        await this.setupNotificationChannel();
      }
    } catch (_e) {
    }
  }

  async requestNotificationPermission(): Promise<boolean> {
    try {
      let isEnabled = await notificationManager.isNotificationEnabled();
      RefreshLogger.getInstance().log('NOTIFY-REQ-0', 'current enabled=' + isEnabled);
      if (!isEnabled) {
        await notificationManager.requestEnableNotification();
        RefreshLogger.getInstance().log('NOTIFY-REQ-1', 'requestEnableNotification done');
        isEnabled = await notificationManager.isNotificationEnabled();
        RefreshLogger.getInstance().log('NOTIFY-REQ-2', 'after request enabled=' + isEnabled);
      }
      if (isEnabled) {
        await this.setupNotificationChannel();
      }
      return isEnabled;
    } catch (e) {
      let err = e as BusinessError;
      RefreshLogger.getInstance().log('NOTIFY-REQ-ERR', 'code=' + err.code + ' msg=' + err.message);
      return false;
    }
  }

  // ========== Background Task ==========

  async startBackgroundTask(): Promise<void> {
    try {
      let ctx = this.context;
      RefreshLogger.getInstance().log('BG-START', 'attempting');
      let wAgent = await wantAgent.getWantAgent({
        wants: [{
          bundleName: ctx.abilityInfo.bundleName,
          abilityName: ctx.abilityInfo.name
        }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      let bgModes: string[] = ['taskKeeping'];
      await backgroundTaskManager.startBackgroundRunning(ctx, bgModes, wAgent);
      RefreshLogger.getInstance().log('BG-START-OK', 'started');
    } catch (e) {
      let err = e as BusinessError;
      RefreshLogger.getInstance().log('BG-START-ERR', 'code=' + err.code + ' msg=' + err.message);
    }
  }

  async stopBackgroundTask(): Promise<void> {
    try {
      let ctx = this.context;
      backgroundTaskManager.stopBackgroundRunning(ctx);
      RefreshLogger.getInstance().log('BG-STOP', 'stopped');
    } catch (e) {
      let err = e as BusinessError;
      RefreshLogger.getInstance().log('BG-STOP-ERR', 'code=' + err.code + ' msg=' + err.message);
    }
  }
}
