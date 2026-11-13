import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { Cash, ClientError, Evidence, Loan, Order, Part, Purchase, Snapshot, STATES, STATE_TITLES, money, stateTitle } from '../core/Models';
import type { ActionRequest } from '../core/Models';
import { Choice, Field, actionTitle, collectPayload, fieldsFor } from '../core/ActionCatalog';
import { WorkbenchStore } from '../core/WorkbenchStore';
import { HttpTransport } from '../platform/HttpTransport';
import { checkedSignature, chooseEvidence } from '../platform/FileEvidence';

interface UILanguage {
  code: string;
  name: string;
}

interface UICatalog {
  messages: Record<string, Record<string, string>>;
}

@Entry
@Component
struct Index {
  private store: WorkbenchStore = new WorkbenchStore(new HttpTransport());
  private signature: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private penPoints: number = 0;
  private inventoryPath: string = '';
  private inventoryVersion: number = 0;
  private inventoryLoan: boolean = false;
  private formIdentity: string = '';
  private selectedDemo: boolean = true;
  private ordersDemo: boolean = true;
  private catalog: UICatalog = { messages: {} };
  private languages: UILanguage[] = [
    { code: 'zh-Hans', name: '简体中文' }, { code: 'zh-Hant', name: '繁體中文' },
    { code: 'bo', name: 'བོད་ཡིག' }, { code: 'en', name: 'English' },
    { code: 'ja', name: '日本語' }, { code: 'fr', name: 'Français' },
    { code: 'es', name: 'Español' }, { code: 'de', name: 'Deutsch' },
    { code: 'ru', name: 'Русский' }, { code: 'ko', name: '한국어' }
  ];
  @State private language: string = 'zh-Hans';
  @State private appearance: string = 'system';
  @State private systemDark: boolean = false;
  private get dark(): boolean {
    return this.appearance === 'dark' || (this.appearance === 'system' && this.systemDark);
  }
  private get canvasColor(): string { return this.dark ? '#101C18' : '#F3F6F4'; }
  private get surfaceColor(): string { return this.dark ? '#192A22' : '#FFFFFF'; }
  private get inkColor(): string { return this.dark ? '#EFF6F1' : '#152820'; }
  private get mutedColor(): string { return this.dark ? '#B5C7BB' : '#53675D'; }
  private get brandColor(): string { return this.dark ? '#8CCBA8' : '#0F5144'; }
  private get tintColor(): string { return this.dark ? '#233E2F' : '#E9F2ED'; }
  @State private page: string = 'login';
  @State private returnPage: string = 'orders';
  @State private source: string = '请登录或选择演示账号';
  @State private actorName: string = '';
  @State private logged: boolean = false;
  @State private busy: boolean = false;
  @State private message: string = '';
  @State private username: string = 'customer';
  @State private password: string = '';
  @State private base: string = 'http://127.0.0.1:8098';
  @State private timeoutText: string = '2500';
  @State private q: string = '';
  @State private status: string = '';
  @State private listPage: number = 1;
  @State private totalPages: number = 1;
  @State private total: number = 0;
  @State private orders: Order[] = [];
  @State private snapshot: Snapshot = new Snapshot();
  @State private selected: Order = new Order();
  @State private action: string = '';
  @State private fields: Field[] = [];

  onPageShow(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.systemDark = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private t(value: string): string {
    const messages = this.catalog.messages[this.language];
    return messages && messages[value] ? messages[value] : value;
  }

  private literal(value: string): string {
    const direct = this.t(value);
    const messages = this.catalog.messages[this.language];
    if (direct !== value) {
      return value.trim() !== value ? value.replace(value.trim(), direct.trim()) : direct;
    }
    if (!messages || !value.trim()) {
      return direct;
    }
    const key = Object.keys(messages).find((candidate: string) => candidate.trim() === value.trim());
    return key ? value.replace(value.trim(), messages[key].trim()) : value;
  }

  private staticText(value: string): string {
    const direct = this.literal(value);
    if (direct !== value) {
      return direct;
    }
    return value.split(/([\s\p{P}]+)/u).map((part: string) => this.literal(part)).join('');
  }

  private async setLanguage(index: number): Promise<void> {
    const selected = this.languages[index];
    if (!selected) {
      return;
    }
    this.language = selected.code;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const saved = await preferences.getPreferences(context, { name: 'repair_environment' });
    await saved.put('language', this.language);
    await saved.flush();
  }

  private async setAppearance(value: string): Promise<void> {
    this.appearance = value;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const saved = await preferences.getPreferences(context, { name: 'repair_environment' });
    await saved.put('appearance', value);
    await saved.flush();
  }

  aboutToAppear(): void {
    this.onPageShow();
    this.restoreEnvironment();
  }

  private async restoreEnvironment(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const bytes = await context.resourceManager.getRawFileContent('ui-l10n.json');
      this.catalog = JSON.parse(util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes)) as UICatalog;
      const saved = await preferences.getPreferences(context, { name: 'repair_environment' });
      this.language = await saved.get('language', 'zh-Hans') as string;
      this.appearance = await saved.get('appearance', 'system') as string;
      this.base = await saved.get('base', this.base) as string;
      this.timeoutText = String(await saved.get('timeout', 2500));
      this.store.configure(this.base, Number(this.timeoutText));
    } catch (_) {
      this.message = '使用默认测试地址；可在连接设置中修改。';
    }
  }

  private sync(): void {
    this.source = this.store.source;
    this.actorName = this.store.actor.name;
    this.logged = this.store.authenticated;
    this.snapshot = this.store.snapshot;
    if (this.logged && this.ordersDemo !== this.store.demo) {
      this.orders = this.snapshot.orders;
      this.ordersDemo = this.store.demo;
      this.total = this.orders.length;
      this.listPage = 1;
      this.totalPages = 1;
    }
    if (this.logged && this.selected.id && this.selectedDemo !== this.store.demo) {
      this.selected = new Order();
      this.fields = [];
      if (this.page === 'detail' || this.page === 'form') {
        this.page = 'orders';
      }
    }
    if (!this.logged && this.page !== 'settings') {
      this.page = 'login';
      this.orders = [];
      this.selected = new Order();
      this.fields = [];
    }
  }

  private async run(job: () => Promise<void>): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.message = '';
    try {
      await job();
    } catch (reason) {
      const error = reason as Error;
      this.message = error.message || '连接暂不可用，请重新加载。';
    } finally {
      this.sync();
      this.busy = false;
    }
  }

  private async loadOrders(page: number = 1): Promise<void> {
    const result = await this.store.list(this.q, this.status, page);
    this.orders = result.items;
    this.ordersDemo = this.store.demo;
    this.total = result.total;
    this.listPage = result.page;
    this.totalPages = result.totalPages;
    this.page = 'orders';
  }

  private async openOrder(id: string): Promise<void> {
    this.selected = await this.store.detail(id);
    this.selectedDemo = this.store.demo;
    this.page = 'detail';
  }

  private openForm(action: string): void {
    this.action = action;
    this.returnPage = this.page;
    this.formIdentity = this.store.actor.id + ':' + this.store.actor.authVersion + ':' + this.store.demo;
    this.fields = fieldsFor(action, this.selected);
    this.fields.forEach((field: Field) => {
      if (field.kind === 'files') {
        field.choices = this.selected.evidence.filter((item: Evidence) => !item.deleted &&
          (action !== 'invoice' || item.kind === 'image' || item.mime === 'application/pdf'))
          .map((item: Evidence) => new Choice(item.id, item.name));
      }
    });
    if (action === 'remark' && ['admin', 'dispatcher', 'finance', 'engineer'].indexOf(this.store.actor.role) < 0) {
      this.fields = this.fields.filter((field: Field) => field.key !== 'remark');
    }
    this.penPoints = 0;
    this.message = '';
    this.inventoryPath = '';
    this.page = 'form';
  }

  private openInventory(action: string, id: string = '', version: number = 0): void {
    this.openForm(action);
    this.inventoryVersion = version;
    this.inventoryLoan = ['loan', 'return', 'consume', 'dispose', 'transfer'].indexOf(action) >= 0;
    if (action === 'loan') {
      this.inventoryPath = '/loans';
    } else if (action === 'purchase') {
      this.inventoryPath = '/purchases';
    } else if (action === 'receive_purchase') {
      this.inventoryPath = '/purchases/' + encodeURIComponent(id) + '/receive';
    } else {
      this.inventoryPath = '/loans/' + encodeURIComponent(id) + '/actions';
    }
  }

  private async submit(): Promise<void> {
    if (this.formIdentity !== this.store.actor.id + ':' + this.store.actor.authVersion + ':' + this.store.demo) {
      throw new ClientError('身份或数据来源已变化，请重新打开表单。');
    }
    const payload = collectPayload(this.fields, this.action);
    if (this.action === 'sign_quote' || this.action === 'accept') {
      if (this.penPoints < 8) {
        throw new ClientError('请在签署区域实际手写，不能提交空白签名。');
      }
      payload['signature'] = checkedSignature(this.signature.toDataURL('image/png'));
      if (this.action === 'sign_quote') {
        payload['quoteVersion'] = this.selected.quote.version;
      }
    }
    if (this.inventoryPath) {
      let body = JSON.stringify(payload);
      if (this.inventoryVersion > 0 && this.action !== 'receive_purchase') {
        const input: ActionRequest = { type: this.action, version: this.inventoryVersion, payload: payload };
        body = JSON.stringify(input);
      } else if (this.action === 'receive_purchase') {
        payload['version'] = this.inventoryVersion;
        body = JSON.stringify(payload);
      }
      await this.store.inventoryWrite(this.inventoryPath, body, this.inventoryLoan);
      this.page = 'inventory';
    } else {
      this.selected = this.action === 'create' ? await this.store.create(payload) : await this.store.perform(this.selected, this.action, payload);
      this.selectedDemo = this.store.demo;
      this.page = 'detail';
    }
    this.message = this.store.demo ? '已保存到独立本地演示。' : '服务端已确认，请核对最新单据。';
  }

  private async saveEnvironment(): Promise<void> {
    this.store.configure(this.base, Number(this.timeoutText));
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const saved = await preferences.getPreferences(context, { name: 'repair_environment' });
    await saved.put('base', this.store.base);
    await saved.put('timeout', this.store.timeout);
    await saved.flush();
    this.page = 'login';
    this.message = '连接设置已保存，请重新登录。';
  }

  private clearSignature(): void {
    this.signature.fillStyle = '#FFFFFF';
    this.signature.fillRect(0, 0, 300, 150);
    this.signature.strokeStyle = '#18283E';
    this.signature.lineWidth = 3;
    this.signature.lineCap = 'round';
    this.penPoints = 0;
  }

  private statusOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: this.staticText('全部阶段') }];
    STATE_TITLES.forEach((title: string) => options.push({ value: this.t(title) }));
    return options;
  }

  @Builder
  private heading(title: string, text: string) {
    Column({ space: 8 }) {
      Text(this.t(title)).fontColor(this.inkColor).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.inkColor).width('100%')
      Text(this.t(text)).fontColor(this.inkColor).fontSize(15).fontColor(this.mutedColor).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 16 })
  }

  @Builder
  private empty(title: string, description: string) {
    Column({ space: 12 }) {
      Image($r('app.media.repair_logo')).width(72).height(72).objectFit(ImageFit.Contain)
      Text(this.t(title)).fontColor(this.inkColor).fontSize(19).fontWeight(FontWeight.Medium)
      Text(this.t(description)).fontColor(this.inkColor).fontSize(15).fontColor(this.mutedColor).textAlign(TextAlign.Center)
      Button(this.staticText('重新加载')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).onClick(() => this.run(async () => {
        await this.store.refresh();
        if (this.page === 'orders') {
          await this.loadOrders();
        }
      })).enabled(!this.busy)
    }.width('100%').padding(28).backgroundColor(this.surfaceColor).borderRadius(16)
  }

  @Builder
  private loginPage() {
    this.heading(this.staticText('每一单，都有交代'), this.staticText('客户报修、工程师履约、报价验收与票款记录。'))
    Text(this.staticText('连接服务')).fontColor(this.inkColor).fontSize(17).fontWeight(FontWeight.Bold).width('100%')
    TextInput({ text: this.username, placeholder: this.staticText('账号，如 customer / engineer') }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10).onChange((value: string) => this.username = value)
    TextInput({ text: this.password, placeholder: this.staticText('密码') }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10).type(InputType.Password).onChange((value: string) => this.password = value)
    Button(this.staticText('登录服务器')).fontColor('#FFFFFF').backgroundColor('#0F5144').constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').enabled(!this.busy).onClick(() => this.run(async () => {
      await this.store.login(this.username.trim(), this.password);
      this.password = '';
      await this.loadOrders();
    }))
    Text(this.staticText('还没有服务器？选择下方演示即可熟悉界面。演示资料不上传，不含真实客户数据。')).fontColor(this.inkColor).fontColor(this.mutedColor).fontSize(14)
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(['customer', 'engineer', 'admin'], (role: string) => {
        Button(this.t(role === 'customer' ? this.staticText('客户演示') : role === 'engineer' ? this.staticText('工程师演示') : this.staticText('公司演示'))).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10)
          .margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => {
            await this.store.enterDemo(role);
            await this.loadOrders();
          }))
      })
    }
    this.settingsButton()
  }

  @Builder
  private settingsButton() {
    Button(this.t('⚙')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).type(ButtonType.Normal).width(48).height(48).fontSize(24)
      .accessibilityText(this.staticText('连接设置')).enabled(!this.busy)
      .onClick(() => this.page = 'settings')
  }

  @Builder
  private orderList() {
    this.heading(this.staticText('维修工单'), this.staticText('共 ') + this.total + this.staticText(' 单 · 第 ') + this.listPage + ' / ' + Math.max(1, this.totalPages) + this.staticText(' 页'))
    TextInput({ text: this.q, placeholder: this.staticText('搜索工单号、设备或客户') }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10).onChange((value: string) => this.q = value)
      .onSubmit(() => this.run(async () => this.loadOrders()))
    Select(this.statusOptions())
      .value(this.status ? this.t(stateTitle(this.status)) : this.staticText('全部阶段')).onSelect((index: number) => {
        this.status = index === 0 ? '' : STATES[index - 1];
        this.run(async () => this.loadOrders());
      })
    Flex({ wrap: FlexWrap.Wrap }) {
      Button(this.staticText('搜索／重新加载')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => this.loadOrders()))
      if (['customer', 'admin', 'dispatcher'].indexOf(this.store.actor.role) >= 0) {
        Button(this.staticText('新增工单')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin({ bottom: 8 }).onClick(() => this.openForm('create')).enabled(!this.busy)
      }
    }
    if (this.orders.length === 0) {
      this.empty('当前没有工单', '可调整筛选条件，或在确认客户和设备后新增工单。')
    } else {
      ForEach(this.orders, (order: Order) => {
        Column({ space: 8 }) {
          Row() {
            Text(order.number).fontColor(this.inkColor).fontSize(15).fontColor(this.mutedColor).layoutWeight(1)
            Text(this.t(stateTitle(order.status))).fontColor(this.inkColor).fontSize(13).fontColor(this.brandColor)
          }.width('100%')
          Text(order.device).fontColor(this.inkColor).fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          Text(order.customer + ' · ' + order.project).fontColor(this.inkColor).fontSize(14).width('100%')
          Text(order.summary.nextTask || this.staticText('打开详情核对下一步')).fontColor(this.inkColor).fontSize(15).fontColor(this.mutedColor).width('100%')
          Text(this.staticText('待收 ') + money(order.summary.remainingCents)).fontColor(this.inkColor).fontSize(15).width('100%')
          Button(this.staticText('查看与办理')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.openOrder(order.id)))
        }.padding(20).width('100%').backgroundColor(this.surfaceColor).borderRadius(16)
      }, (order: Order) => order.id)
    }
    Row({ space: 12 }) {
      Button(this.staticText('上一页')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).enabled(this.listPage > 1 && !this.busy).onClick(() => this.run(async () => this.loadOrders(this.listPage - 1)))
      Button(this.staticText('下一页')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).enabled(this.listPage < this.totalPages && !this.busy).onClick(() => this.run(async () => this.loadOrders(this.listPage + 1)))
    }
  }

  @Builder
  private detailPage() {
    this.heading(this.selected.device, this.selected.number + ' · ' + stateTitle(this.selected.status) + this.staticText(' · 版本 ') + this.selected.version)
    Text(this.selected.customer + ' · ' + this.selected.project).fontColor(this.inkColor).width('100%')
    Text(this.selected.description).fontColor(this.inkColor).width('100%')
    Text(this.staticText('对客说明：') + (this.selected.customerNote || this.staticText('暂无'))).fontColor(this.inkColor).width('100%').fontColor(this.mutedColor)
    Text(this.staticText('下一步：') + this.selected.summary.nextTask).fontColor(this.inkColor).width('100%')
    if (this.selected.summary.missing.length > 0) {
      Text(this.staticText('未办妥事项：\n') + this.selected.summary.missing.join('\n')).fontColor(this.inkColor).width('100%').fontColor('#A95524')
    }
    Column({ space: 8 }) {
      Text(this.staticText('报价与票款')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      Text(this.staticText('报价 ') + money(this.selected.quote.amountCents) + this.staticText(' · 已核实净收 ') + money(this.selected.summary.collectedCents) + this.staticText(' · 待收 ') + money(this.selected.summary.remainingCents)).fontColor(this.inkColor).width('100%')
      Text(this.selected.quote.description || this.staticText('尚未制定报价')).fontColor(this.inkColor).width('100%')
      Text(this.staticText('质保 ') + this.selected.quote.warrantyMonths + this.staticText(' 月；') + (this.selected.quote.startRequiresPrepayment ? this.staticText('明确约定先款开修，预付款 ') + money(this.selected.quote.prepayCents) : this.staticText('未约定先款开修'))).fontColor(this.inkColor).width('100%')
      Text(this.selected.summary.warrantyLabel || '').fontColor(this.inkColor).width('100%').fontColor(this.mutedColor)
    }.padding(18).width('100%').backgroundColor(this.surfaceColor).borderRadius(16)
    if (this.selected.cash.length > 0) {
      Text(this.staticText('现金记录')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      ForEach(this.selected.cash, (cash: Cash) => {
        Text((cash.kind === 'refund' ? this.staticText('退款 ') : this.staticText('收款 ')) + money(cash.amountCents) + ' · ' + cash.purpose + ' · ' + (cash.verified ? this.staticText('财务已核实') : this.staticText('待财务核实')) + ' · ' + (cash.handedOver ? this.staticText('已内部交接') : this.staticText('未内部交接'))).fontColor(this.inkColor).width('100%')
      }, (cash: Cash) => cash.id)
    }
    Text(this.staticText('可办理事项')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.selected.allowedActions, (action: string) => {
        Button(this.t(actionTitle(action))).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.openForm(action))
      })
      if (this.selected.allowedActions.indexOf('evidence') >= 0) {
        Button(this.staticText('选择文件归档')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => {
          if (this.store.demo) {
            throw new ClientError('文件原件归档须先连接服务端。');
          }
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          const payload = await chooseEvidence(context);
          this.selected = await this.store.perform(this.selected, 'evidence', payload);
          this.message = '文件原件已由服务端确认归档。';
        }))
      }
    }
    if (this.selected.evidence.length > 0) {
      Text(this.staticText('已归档资料')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      ForEach(this.selected.evidence.filter((item: Evidence) => !item.deleted), (item: Evidence) => {
        Column({ space: 5 }) {
          Text(item.name + ' · ' + item.id).fontColor(this.inkColor).width('100%').fontWeight(FontWeight.Medium)
          Text(item.kind === 'text' ? item.text : this.staticText('已归档 ') + item.kind + this.staticText(' 原件；下载请使用网页工作台。')).fontColor(this.inkColor).width('100%').fontColor(this.mutedColor)
        }.padding(12).width('100%').backgroundColor(this.surfaceColor).borderRadius(12)
      }, (item: Evidence) => item.id)
    }
    Row({ space: 12 }) {
      Button(this.staticText('重新加载详情')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).enabled(!this.busy).onClick(() => this.run(async () => this.openOrder(this.selected.id)))
      Button(this.staticText('返回工单')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).enabled(!this.busy).onClick(() => this.run(async () => this.loadOrders()))
    }
  }

  @Builder
  private inputField(field: Field) {
    Column({ space: 6 }) {
      Text(this.t(field.label) + (field.required ? ' *' : '')).fontColor(this.inkColor).width('100%').fontSize(14).fontWeight(FontWeight.Medium)
      if (field.kind === 'files') {
        if (field.choices.length === 0) {
          Text(this.staticText('暂无可选原件，请先返回工单选择文件归档。')).fontColor(this.inkColor).fontColor(this.mutedColor).fontSize(13).width('100%')
        } else {
          ForEach(field.choices, (choice: Choice) => {
            Row({ space: 8 }) {
              Checkbox().select(field.value.split(',').indexOf(choice.value) >= 0).onChange((checked: boolean) => {
                const values = field.value.split(',').filter((value: string) => value.length > 0 && value !== choice.value);
                if (checked) {
                  values.push(choice.value);
                }
                field.value = values.join(',');
                this.fields = this.fields.slice();
              })
              Text(choice.label).fontColor(this.inkColor).layoutWeight(1).fontSize(14)
            }.width('100%')
          }, (choice: Choice) => choice.value)
        }
      } else if (field.choices.length > 0 || field.kind === 'choice') {
        Select(field.choices.map((choice: Choice): SelectOption => ({ value: this.t(choice.label) })))
          .value(this.t((field.choices.find((choice: Choice) => choice.value === field.value) || new Choice('', '请选择')).label))
          .onSelect((index: number) => {
            if (field.choices[index]) {
              field.value = field.choices[index].value;
              this.fields = this.fields.slice();
            }
          })
      } else if (field.kind === 'multiline') {
        TextArea({ text: field.value, placeholder: this.staticText('请输入') }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).borderRadius(10).height(100).onChange((value: string) => field.value = value)
      } else {
        TextInput({ text: field.value, placeholder: field.kind === 'money' ? this.staticText('例如 120.50') : this.staticText('请输入') }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10)
          .type(field.kind === 'integer' ? InputType.Number : InputType.Normal)
          .onChange((value: string) => field.value = value)
      }
    }.width('100%')
  }

  @Builder
  private formPage() {
    this.heading(actionTitle(this.action), this.action === 'create' ? this.staticText('确认客户、设备和需求后录入。') : this.selected.number + this.staticText(' · 仅记录真实发生且已核实的事实。'))
    ForEach(this.fields, (field: Field) => {
      this.inputField(field)
    }, (field: Field) => field.key)
    if (this.action === 'sign_quote' || this.action === 'accept') {
      Text(this.staticText('请核对：') + this.selected.quote.description + this.staticText('\n含税总价 ') + money(this.selected.quote.amountCents) + this.staticText('，质保 ') + this.selected.quote.warrantyMonths + this.staticText(' 月；') + (this.selected.quote.startRequiresPrepayment ? this.staticText('约定先款 ') + money(this.selected.quote.prepayCents) + this.staticText(' 后开修。') : this.staticText('未约定先款开修。')) + (this.selected.quote.autoAccept ? this.staticText('已约定完整交付后七日无异议自动验收。') : this.staticText('未约定自动验收。'))).fontColor(this.inkColor).width('100%')
      Text(this.staticText('在下方实际手写签名；提交后会保存签署原件。')).fontColor(this.inkColor).fontSize(15).fontColor(this.mutedColor)
      Canvas(this.signature).width(300).height(150).backgroundColor('#FFFFFF').border({ width: 1, color: '#CAD4DF' })
        .onReady(() => this.clearSignature())
        .onTouch((event: TouchEvent) => {
          event.stopPropagation();
          if (event.touches.length < 1) {
            return;
          }
          const point = event.touches[0];
          if (event.type === TouchType.Down) {
            this.signature.beginPath();
            this.signature.moveTo(point.x, point.y);
          } else if (event.type === TouchType.Move) {
            this.signature.lineTo(point.x, point.y);
            this.signature.stroke();
            this.penPoints += 1;
          }
        })
      Button(this.staticText('清除重写')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).onClick(() => this.clearSignature())
    }
    Button(this.staticText('确认提交')).fontColor('#FFFFFF').backgroundColor('#0F5144').constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.submit()))
    Button(this.staticText('取消并返回')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').type(ButtonType.Normal).enabled(!this.busy).onClick(() => {
      this.page = this.returnPage;
      this.fields = [];
      this.message = '';
    })
  }

  @Builder
  private inventoryPage() {
    this.heading(this.staticText('配件与借还'), this.staticText('良品、隔离数量和每次借还分别记录；库存变更以服务端确认为准。'))
    Button(this.staticText('重新加载库存')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).enabled(!this.busy).onClick(() => this.run(async () => this.store.refresh()))
    if (['admin', 'warehouse'].indexOf(this.store.actor.role) >= 0) {
      Row({ space: 12 }) {
        Button(this.staticText('借出配件')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).onClick(() => this.openInventory('loan'))
        Button(this.staticText('新增采购')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).onClick(() => this.openInventory('purchase'))
      }
    }
    if (this.snapshot.parts.length === 0) {
      this.empty('当前没有配件', '暂无可见库存，可重新加载或联系仓库管理员。')
    } else {
      ForEach(this.snapshot.parts, (part: Part) => {
        Column({ space: 6 }) {
          Text(part.name).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          Text(this.staticText('可用 ') + part.available + this.staticText(' · 隔离 ') + part.quarantine + ' · ' + part.sku).fontColor(this.inkColor).width('100%')
          Text(this.staticText('配件 ID：') + part.id).fontColor(this.inkColor).fontSize(12).fontColor(this.mutedColor).width('100%')
        }.padding({ left: 20, right: 20, top: 16, bottom: 16 }).width('100%').backgroundColor(this.surfaceColor).borderRadius(14)
      }, (part: Part) => part.id)
    }
    Text(this.staticText('借还记录')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    if (this.snapshot.loans.length === 0) {
      this.empty('没有待查看的借还', '借出后可在这里逐次归还、隔离或经批准转出。')
    } else {
      ForEach(this.snapshot.loans, (loan: Loan) => {
        Column({ space: 8 }) {
          Text(loan.partName + this.staticText(' · 尚欠 ') + loan.outstanding + ' / ' + loan.quantity).fontColor(this.inkColor).width('100%')
          Text(this.staticText('借用人 ') + loan.borrowerId + this.staticText(' · 期限 ') + loan.dueAt).fontColor(this.inkColor).fontColor(this.mutedColor).width('100%')
          if (loan.outstanding > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.store.actor.role === 'admin' ? ['return', 'consume', 'dispose', 'transfer'] : ['return'], (action: string) => {
                Button(this.t(actionTitle(action))).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin({ right: 8, bottom: 8 }).onClick(() => this.openInventory(action, loan.id, loan.version))
              })
            }
          }
        }.padding(16).width('100%').backgroundColor(this.surfaceColor).borderRadius(14)
      }, (loan: Loan) => loan.id)
    }
    Text(this.staticText('采购记录')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    if (this.snapshot.purchases.length === 0) {
      this.empty('没有采购记录', '实际采购后登记供应商、配件和数量，再分批办理收货。')
    } else {
      ForEach(this.snapshot.purchases, (purchase: Purchase) => {
        Column({ space: 8 }) {
          Text(purchase.supplier + this.staticText(' · 已收 ') + purchase.received + ' / ' + purchase.quantity).fontColor(this.inkColor).width('100%')
          Text(this.staticText('单价 ') + money(purchase.unitCents) + this.staticText(' · 配件 ') + purchase.partId).fontColor(this.inkColor).width('100%')
          if (purchase.received < purchase.quantity && ['admin', 'warehouse'].indexOf(this.store.actor.role) >= 0) {
            Button(this.staticText('分批收货')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).onClick(() => this.openInventory('receive_purchase', purchase.id, purchase.version))
          }
        }.padding(16).width('100%').backgroundColor(this.surfaceColor).borderRadius(14)
      }, (purchase: Purchase) => purchase.id)
    }
  }

  @Builder
  private settingsPage() {
    this.heading(this.staticText('连接设置'), this.staticText('测试时填电脑的局域网地址；手机上的 127.0.0.1 指向手机自身。'))
    Text(this.staticText('语言')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Medium).width('100%')
    Select(this.languages.map((item: UILanguage): SelectOption => ({ value: item.name })))
      .value((this.languages.find((item: UILanguage) => item.code === this.language) || this.languages[0]).name)
      .onSelect((index: number) => this.setLanguage(index))
    Text(this.staticText('外观')).fontColor(this.inkColor).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.inkColor).width('100%')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(['system', 'light', 'dark'], (mode: string) => {
        Button(this.t(mode === 'system' ? this.staticText('跟随系统') : mode === 'light' ? this.staticText('白天') : this.staticText('黑夜'))).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10)
          .fontColor(this.appearance === mode ? '#FFFFFF' : this.brandColor)
          .backgroundColor(this.appearance === mode ? '#0F5144' : this.tintColor)
          .height(48).margin({ right: 8, bottom: 8 }).onClick(() => this.setAppearance(mode))
      })
    }
    Text(this.staticText('服务地址')).fontColor(this.inkColor).width('100%')
    TextInput({ text: this.base, placeholder: 'http://192.168.1.10:8098' }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10).onChange((value: string) => this.base = value)
    Text(this.staticText('请求超时（毫秒，500～10000）')).fontColor(this.inkColor).width('100%')
    TextInput({ text: this.timeoutText }).fontColor(this.inkColor).backgroundColor(this.surfaceColor).constraintSize({ minHeight: 52 }).borderRadius(10).type(InputType.Number).onChange((value: string) => this.timeoutText = value)
    Button(this.staticText('保存并重新登录')).fontColor('#FFFFFF').backgroundColor('#0F5144').constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.saveEnvironment()))
    Text(this.staticText('只保存连接地址与超时；密码、会话和客户资料不落到偏好设置。正式服务应使用 HTTPS。')).fontColor(this.inkColor).fontColor(this.mutedColor).fontSize(14)
    Button(this.staticText('返回')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').onClick(() => this.page = this.logged ? 'orders' : 'login')
    if (this.logged) {
      Button(this.staticText('退出当前账号')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).width('100%').onClick(() => this.run(async () => this.store.logout()))
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Image($r('app.media.repair_logo')).width(40).height(40).objectFit(ImageFit.Contain)
        Column({ space: 4 }) {
          Text(this.staticText('啄木鸟维修')).fontColor(this.inkColor).fontSize(21).fontWeight(FontWeight.Bold).width('100%')
          Text(this.actorName || this.staticText('维修进度与工单协作')).fontColor(this.inkColor).fontSize(12).fontColor(this.mutedColor).width('100%')
        }.layoutWeight(1)
      }.padding(16).width('100%').backgroundColor(this.surfaceColor)
      Text(this.t(this.source)).fontColor(this.inkColor).width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).fontSize(12).fontColor(this.brandColor).backgroundColor(this.tintColor)
      if (this.logged && this.page !== 'form') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Button(this.staticText('工单')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin(4).onClick(() => this.run(async () => this.loadOrders())).enabled(!this.busy)
          Button(this.staticText('库存借还')).fontColor(this.brandColor).backgroundColor(this.tintColor).constraintSize({ minHeight: 48 }).borderRadius(10).margin(4).onClick(() => this.run(async () => {
            await this.store.refresh();
            this.page = 'inventory';
          })).enabled(!this.busy)
          this.settingsButton()
        }.padding({ left: 12, right: 12 })
      }
      if (this.busy) {
        Text(this.staticText('正在请求，请稍候…')).fontColor(this.inkColor).fontSize(13).fontColor(this.mutedColor).padding(6)
      }
      Scroll() {
        Column({ space: 14 }) {
          if (this.message) {
            Text(this.t(this.message)).fontColor(this.inkColor).width('100%').fontSize(14).fontColor('#9A4F21').padding(12).backgroundColor('#FFF0DE').borderRadius(10)
          }
          if (this.page === 'login') {
            this.loginPage()
          } else if (this.page === 'orders') {
            this.orderList()
          } else if (this.page === 'detail') {
            this.detailPage()
          } else if (this.page === 'form') {
            this.formPage()
          } else if (this.page === 'inventory') {
            this.inventoryPage()
          } else {
            this.settingsPage()
          }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(20).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top)
    }.width('100%').height('100%').backgroundColor(this.canvasColor)
  }
}
