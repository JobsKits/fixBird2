import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Cash, ClientError, Evidence, Loan, Order, Part, Purchase, Snapshot, STATES, STATE_TITLES, money, stateTitle } from '../core/Models';
import type { ActionRequest } from '../core/Models';
import { Choice, Field, actionTitle, collectPayload, fieldsFor } from '../core/ActionCatalog';
import { WorkbenchStore } from '../core/WorkbenchStore';
import { HttpTransport } from '../platform/HttpTransport';
import { checkedSignature, chooseEvidence } from '../platform/FileEvidence';

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

  aboutToAppear(): void {
    this.restoreEnvironment();
  }

  private async restoreEnvironment(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saved = await preferences.getPreferences(context, { name: 'repair_environment' });
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
    const options: SelectOption[] = [{ value: '全部阶段' }];
    STATE_TITLES.forEach((title: string) => options.push({ value: title }));
    return options;
  }

  @Builder
  private heading(title: string, text: string) {
    Column({ space: 8 }) {
      Text(title).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#17243A').width('100%')
      Text(text).fontSize(14).fontColor('#617084').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 8 })
  }

  @Builder
  private empty(title: string, description: string) {
    Column({ space: 12 }) {
      Image($r('app.media.repair_logo')).width(72).height(72).objectFit(ImageFit.Contain)
      Text(title).fontSize(19).fontWeight(FontWeight.Medium)
      Text(description).fontSize(14).fontColor('#617084').textAlign(TextAlign.Center)
      Button('重新加载').onClick(() => this.run(async () => {
        await this.store.refresh();
        if (this.page === 'orders') {
          await this.loadOrders();
        }
      })).enabled(!this.busy)
    }.width('100%').padding(28).backgroundColor('#FFFFFF').borderRadius(16)
  }

  @Builder
  private loginPage() {
    this.heading('每一单，都有交代', '客户报修、工程师履约、报价验收与票款记录。')
    Text('连接服务').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
    TextInput({ text: this.username, placeholder: '账号，如 customer / engineer' }).onChange((value: string) => this.username = value)
    TextInput({ text: this.password, placeholder: '密码' }).type(InputType.Password).onChange((value: string) => this.password = value)
    Button('登录服务器').width('100%').enabled(!this.busy).onClick(() => this.run(async () => {
      await this.store.login(this.username.trim(), this.password);
      this.password = '';
      await this.loadOrders();
    }))
    Text('还没有服务器？选择下方演示即可熟悉界面。演示资料不上传，不含真实客户数据。').fontColor('#617084').fontSize(14)
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(['customer', 'engineer', 'admin'], (role: string) => {
        Button(role === 'customer' ? '客户演示' : role === 'engineer' ? '工程师演示' : '公司演示')
          .margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => {
            await this.store.enterDemo(role);
            await this.loadOrders();
          }))
      })
    }
    Button('连接设置').type(ButtonType.Normal).onClick(() => this.page = 'settings')
  }

  @Builder
  private orderList() {
    this.heading('维修工单', '共 ' + this.total + ' 单 · 第 ' + this.listPage + ' / ' + Math.max(1, this.totalPages) + ' 页')
    TextInput({ text: this.q, placeholder: '搜索工单号、设备或客户' }).onChange((value: string) => this.q = value)
      .onSubmit(() => this.run(async () => this.loadOrders()))
    Select(this.statusOptions())
      .value(this.status ? stateTitle(this.status) : '全部阶段').onSelect((index: number) => {
        this.status = index === 0 ? '' : STATES[index - 1];
        this.run(async () => this.loadOrders());
      })
    Flex({ wrap: FlexWrap.Wrap }) {
      Button('搜索／重新加载').margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => this.loadOrders()))
      if (['customer', 'admin', 'dispatcher'].indexOf(this.store.actor.role) >= 0) {
        Button('新增工单').margin({ bottom: 8 }).onClick(() => this.openForm('create')).enabled(!this.busy)
      }
    }
    if (this.orders.length === 0) {
      this.empty('当前没有工单', '可调整筛选条件，或在确认客户和设备后新增工单。')
    } else {
      ForEach(this.orders, (order: Order) => {
        Column({ space: 8 }) {
          Row() {
            Text(order.number).fontSize(14).fontColor('#617084').layoutWeight(1)
            Text(stateTitle(order.status)).fontSize(13).fontColor('#147D70')
          }.width('100%')
          Text(order.device).fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          Text(order.customer + ' · ' + order.project).fontSize(14).width('100%')
          Text(order.summary.nextTask || '打开详情核对下一步').fontSize(14).fontColor('#617084').width('100%')
          Text('待收 ' + money(order.summary.remainingCents)).fontSize(15).width('100%')
          Button('查看与办理').width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.openOrder(order.id)))
        }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(16)
      }, (order: Order) => order.id)
    }
    Row({ space: 12 }) {
      Button('上一页').enabled(this.listPage > 1 && !this.busy).onClick(() => this.run(async () => this.loadOrders(this.listPage - 1)))
      Button('下一页').enabled(this.listPage < this.totalPages && !this.busy).onClick(() => this.run(async () => this.loadOrders(this.listPage + 1)))
    }
  }

  @Builder
  private detailPage() {
    this.heading(this.selected.device, this.selected.number + ' · ' + stateTitle(this.selected.status) + ' · 版本 ' + this.selected.version)
    Text(this.selected.customer + ' · ' + this.selected.project).width('100%')
    Text(this.selected.description).width('100%')
    Text('对客说明：' + (this.selected.customerNote || '暂无')).width('100%').fontColor('#617084')
    Text('下一步：' + this.selected.summary.nextTask).width('100%')
    if (this.selected.summary.missing.length > 0) {
      Text('未办妥事项：\n' + this.selected.summary.missing.join('\n')).width('100%').fontColor('#A95524')
    }
    Column({ space: 8 }) {
      Text('报价与票款').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      Text('报价 ' + money(this.selected.quote.amountCents) + ' · 已核实净收 ' + money(this.selected.summary.collectedCents) + ' · 待收 ' + money(this.selected.summary.remainingCents)).width('100%')
      Text(this.selected.quote.description || '尚未制定报价').width('100%')
      Text('质保 ' + this.selected.quote.warrantyMonths + ' 月；' + (this.selected.quote.startRequiresPrepayment ? '明确约定先款开修，预付款 ' + money(this.selected.quote.prepayCents) : '未约定先款开修')).width('100%')
      Text(this.selected.summary.warrantyLabel || '').width('100%').fontColor('#617084')
    }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(16)
    if (this.selected.cash.length > 0) {
      Text('现金记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      ForEach(this.selected.cash, (cash: Cash) => {
        Text((cash.kind === 'refund' ? '退款 ' : '收款 ') + money(cash.amountCents) + ' · ' + cash.purpose + ' · ' + (cash.verified ? '财务已核实' : '待财务核实') + ' · ' + (cash.handedOver ? '已内部交接' : '未内部交接')).width('100%')
      }, (cash: Cash) => cash.id)
    }
    Text('可办理事项').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.selected.allowedActions, (action: string) => {
        Button(actionTitle(action)).margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.openForm(action))
      })
      if (this.selected.allowedActions.indexOf('evidence') >= 0) {
        Button('选择文件归档').margin({ right: 8, bottom: 8 }).enabled(!this.busy).onClick(() => this.run(async () => {
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
      Text('已归档资料').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
      ForEach(this.selected.evidence.filter((item: Evidence) => !item.deleted), (item: Evidence) => {
        Column({ space: 5 }) {
          Text(item.name + ' · ' + item.id).width('100%').fontWeight(FontWeight.Medium)
          Text(item.kind === 'text' ? item.text : '已归档 ' + item.kind + ' 原件；下载请使用网页工作台。').width('100%').fontColor('#617084')
        }.padding(12).width('100%').backgroundColor('#FFFFFF').borderRadius(12)
      }, (item: Evidence) => item.id)
    }
    Row({ space: 12 }) {
      Button('重新加载详情').enabled(!this.busy).onClick(() => this.run(async () => this.openOrder(this.selected.id)))
      Button('返回工单').enabled(!this.busy).onClick(() => this.run(async () => this.loadOrders()))
    }
  }

  @Builder
  private inputField(field: Field) {
    Column({ space: 6 }) {
      Text(field.label + (field.required ? ' *' : '')).width('100%').fontSize(14).fontWeight(FontWeight.Medium)
      if (field.kind === 'files') {
        if (field.choices.length === 0) {
          Text('暂无可选原件，请先返回工单选择文件归档。').fontColor('#617084').fontSize(13).width('100%')
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
              Text(choice.label).layoutWeight(1).fontSize(14)
            }.width('100%')
          }, (choice: Choice) => choice.value)
        }
      } else if (field.choices.length > 0 || field.kind === 'choice') {
        Select(field.choices.map((choice: Choice): SelectOption => ({ value: choice.label })))
          .value((field.choices.find((choice: Choice) => choice.value === field.value) || new Choice('', '请选择')).label)
          .onSelect((index: number) => {
            if (field.choices[index]) {
              field.value = field.choices[index].value;
              this.fields = this.fields.slice();
            }
          })
      } else if (field.kind === 'multiline') {
        TextArea({ text: field.value, placeholder: '请输入' }).height(100).onChange((value: string) => field.value = value)
      } else {
        TextInput({ text: field.value, placeholder: field.kind === 'money' ? '例如 120.50' : '请输入' })
          .type(field.kind === 'integer' ? InputType.Number : InputType.Normal)
          .onChange((value: string) => field.value = value)
      }
    }.width('100%')
  }

  @Builder
  private formPage() {
    this.heading(actionTitle(this.action), this.action === 'create' ? '确认客户、设备和需求后录入。' : this.selected.number + ' · 仅记录真实发生且已核实的事实。')
    ForEach(this.fields, (field: Field) => {
      this.inputField(field)
    }, (field: Field) => field.key)
    if (this.action === 'sign_quote' || this.action === 'accept') {
      Text('请核对：' + this.selected.quote.description + '\n含税总价 ' + money(this.selected.quote.amountCents) + '，质保 ' + this.selected.quote.warrantyMonths + ' 月；' + (this.selected.quote.startRequiresPrepayment ? '约定先款 ' + money(this.selected.quote.prepayCents) + ' 后开修。' : '未约定先款开修。') + (this.selected.quote.autoAccept ? '已约定完整交付后七日无异议自动验收。' : '未约定自动验收。')).width('100%')
      Text('在下方实际手写签名；提交后会保存签署原件。').fontSize(14).fontColor('#617084')
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
      Button('清除重写').onClick(() => this.clearSignature())
    }
    Button('确认提交').width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.submit()))
    Button('取消并返回').width('100%').type(ButtonType.Normal).enabled(!this.busy).onClick(() => {
      this.page = this.returnPage;
      this.fields = [];
      this.message = '';
    })
  }

  @Builder
  private inventoryPage() {
    this.heading('配件与借还', '良品、隔离数量和每次借还分别记录；库存变更以服务端确认为准。')
    Button('重新加载库存').enabled(!this.busy).onClick(() => this.run(async () => this.store.refresh()))
    if (['admin', 'warehouse'].indexOf(this.store.actor.role) >= 0) {
      Row({ space: 12 }) {
        Button('借出配件').onClick(() => this.openInventory('loan'))
        Button('新增采购').onClick(() => this.openInventory('purchase'))
      }
    }
    if (this.snapshot.parts.length === 0) {
      this.empty('当前没有配件', '暂无可见库存，可重新加载或联系仓库管理员。')
    } else {
      ForEach(this.snapshot.parts, (part: Part) => {
        Column({ space: 6 }) {
          Text(part.name).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          Text('可用 ' + part.available + ' · 隔离 ' + part.quarantine + ' · ' + part.sku).width('100%')
          Text('配件 ID：' + part.id).fontSize(12).fontColor('#617084').width('100%')
        }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(14)
      }, (part: Part) => part.id)
    }
    Text('借还记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    if (this.snapshot.loans.length === 0) {
      this.empty('没有待查看的借还', '借出后可在这里逐次归还、隔离或经批准转出。')
    } else {
      ForEach(this.snapshot.loans, (loan: Loan) => {
        Column({ space: 8 }) {
          Text(loan.partName + ' · 尚欠 ' + loan.outstanding + ' / ' + loan.quantity).width('100%')
          Text('借用人 ' + loan.borrowerId + ' · 期限 ' + loan.dueAt).fontColor('#617084').width('100%')
          if (loan.outstanding > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.store.actor.role === 'admin' ? ['return', 'consume', 'dispose', 'transfer'] : ['return'], (action: string) => {
                Button(actionTitle(action)).margin({ right: 8, bottom: 8 }).onClick(() => this.openInventory(action, loan.id, loan.version))
              })
            }
          }
        }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(14)
      }, (loan: Loan) => loan.id)
    }
    Text('采购记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
    if (this.snapshot.purchases.length === 0) {
      this.empty('没有采购记录', '实际采购后登记供应商、配件和数量，再分批办理收货。')
    } else {
      ForEach(this.snapshot.purchases, (purchase: Purchase) => {
        Column({ space: 8 }) {
          Text(purchase.supplier + ' · 已收 ' + purchase.received + ' / ' + purchase.quantity).width('100%')
          Text('单价 ' + money(purchase.unitCents) + ' · 配件 ' + purchase.partId).width('100%')
          if (purchase.received < purchase.quantity && ['admin', 'warehouse'].indexOf(this.store.actor.role) >= 0) {
            Button('分批收货').onClick(() => this.openInventory('receive_purchase', purchase.id, purchase.version))
          }
        }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(14)
      }, (purchase: Purchase) => purchase.id)
    }
  }

  @Builder
  private settingsPage() {
    this.heading('连接设置', '测试时填电脑的局域网地址；手机上的 127.0.0.1 指向手机自身。')
    Text('服务地址').width('100%')
    TextInput({ text: this.base, placeholder: 'http://电脑局域网IP:8098' }).onChange((value: string) => this.base = value)
    Text('请求超时（毫秒，500～10000）').width('100%')
    TextInput({ text: this.timeoutText }).type(InputType.Number).onChange((value: string) => this.timeoutText = value)
    Button('保存并重新登录').width('100%').enabled(!this.busy).onClick(() => this.run(async () => this.saveEnvironment()))
    Text('只保存连接地址与超时；密码、会话和客户资料不落到偏好设置。正式服务应使用 HTTPS。').fontColor('#617084').fontSize(14)
    Button('返回').width('100%').onClick(() => this.page = this.logged ? 'orders' : 'login')
    if (this.logged) {
      Button('退出当前账号').width('100%').onClick(() => this.run(async () => this.store.logout()))
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Image($r('app.media.repair_logo')).width(40).height(40).objectFit(ImageFit.Contain)
        Column({ space: 4 }) {
          Text('啄木鸟维修').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
          Text(this.actorName || '原生鸿蒙工作台').fontSize(12).fontColor('#617084').width('100%')
        }.layoutWeight(1)
      }.padding(16).width('100%').backgroundColor('#FFFFFF')
      Text(this.source).width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 }).fontSize(12).fontColor('#147D70').backgroundColor('#EAF5F2')
      if (this.logged && this.page !== 'form') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Button('工单').margin(4).onClick(() => this.run(async () => this.loadOrders())).enabled(!this.busy)
          Button('库存借还').margin(4).onClick(() => this.run(async () => {
            await this.store.refresh();
            this.page = 'inventory';
          })).enabled(!this.busy)
          Button('设置').margin(4).onClick(() => this.page = 'settings').enabled(!this.busy)
        }.padding({ left: 12, right: 12 })
      }
      if (this.busy) {
        Text('正在请求，请稍候…').fontSize(13).fontColor('#617084').padding(6)
      }
      Scroll() {
        Column({ space: 14 }) {
          if (this.message) {
            Text(this.message).width('100%').fontSize(14).fontColor('#9A4F21').padding(12).backgroundColor('#FFF0DE').borderRadius(10)
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
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(16).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top)
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }
}
