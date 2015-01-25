#import "ViewController.h"

#define SERVICE_UUIDS           nil //@[[CBUUID UUIDWithString:@"UUID"]]
#define CHARACTERISTIC_UUID     nil //[CBUUID UUIDWithString:@"UUID"]

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _discoveredPeripherals = [NSMutableArray array];
}

# pragma mark - CBCentralManagerDelegate

/**
 *  iOS端末のBluetooth設定が変化した場合
 *
 *  @param central Bluetooth検出側
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    //iOS端末のBluetooth設定がONなら周辺機器のスキャンを始める。
    [self scan];
}

/**
 *  周辺機器を検出した場合
 *
 *  @param central           Bluetooth検出側
 *  @param peripheral        検出した周辺機器
 *  @param advertisementData 周辺機器が発見されるためにブロードキャストする情報。
 *                           検出側はこの情報を元に機器の信号を受信するかどうか決める。
 *  @param RSSI              信号強度。integerValueが-35〜-15くらいが妥当とのこと。
 */
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    //RSSIの値次第で接続に進むかどうかを決める。ここでは無視。
    NSLog(@"周辺機器を発見:%@ 信号強度:%d 情報:%@", peripheral.name, (int) RSSI.integerValue, advertisementData);
    
    for (CBPeripheral *p in _discoveredPeripherals) {
        if (p == peripheral) {
            return;
        }
    }
    
    //未発見機器の場合、接続を試みる。
    [_discoveredPeripherals addObject:peripheral];
    NSLog(@"機器へ接続開始 機器:%@", peripheral);
    [_centralManager connectPeripheral:peripheral options:nil];
}

/**
 *  周辺機器に接続完了時。
 *
 *  @param central    Bluetooth検出側
 *  @param peripheral 検出した周辺機器
 */
- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"接続完了 機器:%@", peripheral);
    [_centralManager stopScan];
    peripheral.delegate = self;
    //指定したUUIDのサービスを持つ周辺機器を検出する(nilの場合は全ての周辺機器)
    [peripheral discoverServices:SERVICE_UUIDS];
}

/**
 *  周辺機器への接続に失敗した場合。
 *
 *  @param central    Bluetooth検出側
 *  @param peripheral 検出した周辺機器
 *  @param error      エラー
 */
- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    NSLog(@"機器への接続失敗。 機器情報:%@. (%@)", peripheral, [error localizedDescription]);
    [self disconnectConnectedPeripheral];
}

/**
 *  サービスのキャラクタリスティックが発見された時。
 *
 *  @param peripheral Bluetooth検出側
 *  @param service    サービス
 *  @param error      エラー
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error) {
        NSLog(@"キャラクタリスティック検出中のエラー: %@", [error localizedDescription]);
        [self disconnectConnectedPeripheral];
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"キャラクタリスティックを発見 機器情報:%@ サービス:%@ キャラクタリスティック:%@", peripheral, service, characteristic);
        if (!CHARACTERISTIC_UUID || [characteristic.UUID isEqual:CHARACTERISTIC_UUID]) {
            //指定した通知のみを購読する。機器通知は接続時にperipheralに設定したdelegate=selfに通知される。
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

/**
 *  Bluetooth検出側と周辺機器の接続が切断された時。
 *
 *  @param central    localizedDescription
 *  @param peripheral 周辺機器
 *  @param error      エラー
 */
- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    NSLog(@"周辺機器から切断されました。 %@", peripheral);
    _discoveredPeripheral = nil;
    [self scan]; //機器の検出を再開
}

# pragma mark - 周辺機器からの通知

/**
 *  購読中のキャラクタリスティックの値が更新された時。
 *
 *  @param peripheral     Bluetooth検出側
 *  @param characteristic キャラクタリスティック
 *  @param error          エラー
 */
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (error) {
        NSLog(@"キャラクタリスティックの値検出中のエラー: %@", [error localizedDescription]);
        return;
    }
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"受信データ: %@", stringFromData);
}

/**
 *  周辺機器に紐付いたキャラクタリスティックからの更新通知について、ステータスが変化した時。
 *
 *  @param peripheral     周辺機器
 *  @param characteristic キャラクタリスティック
 *  @param error          エラー
 */
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (error) {
        NSLog(@"更新通知ステータスが変化した: %@", error.localizedDescription);
    }
    if (!characteristic.isNotifying) {
        NSLog(@"更新通知ステータスが変化した 機器:%@ キャラクタリスティック:%@  切断中...", peripheral, characteristic);
        //周辺機器からの切断
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

# pragma mark private

/**
 *  周辺機器を探し始めます。
 */
- (void)scan {
    [_centralManager scanForPeripheralsWithServices:SERVICE_UUIDS
                                            options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"探索開始");
}

/**
 * 接続済みの周辺機器から切断します。
 */
- (void) disconnectConnectedPeripheral {
    if (!_discoveredPeripheral.state == CBPeripheralStateConnected) {
        return;
    }
    
    if (self.discoveredPeripheral.services == nil) {
        return;
    }
    for (CBService *service in self.discoveredPeripheral.services) {
        if (service.characteristics == nil) {
            continue;
        }
        for (CBCharacteristic *characteristic in service.characteristics) {
            if (CHARACTERISTIC_UUID && [characteristic.UUID isEqual:CHARACTERISTIC_UUID]) {
                if (characteristic.isNotifying) {
                    //購読中のキャラクタリスティックがあれば購読を停止する
                    [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                }
            }
        }
    }
    //周辺機器の接続を切断する
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}

@end
