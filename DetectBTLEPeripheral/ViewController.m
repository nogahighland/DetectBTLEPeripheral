#import "ViewController.h"

#define SERVICE_UUIDS           nil // @[[CBUUID UUIDWithString:@"UUID"]]
#define CHARACTERISTIC_UUIDS    nil // @[[CBUUID UUIDWithString:@"UUID"]]

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
    peripheral.delegate = self;
    //指定したUUIDのサービスを検出する(nilの場合は全てのサービス)
    [peripheral discoverServices:SERVICE_UUIDS];
}

/**
 *  サービス発見時。
 *
 *  @param peripheral 周辺機器
 *  @param error      エラー
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"サービス発見時のエラー 周辺機器:%@", peripheral);
        [self disconnectPeripheral:peripheral];
        return;
    }
    for (CBService *service in peripheral.services) {
        NSLog(@"キャラクタリスティックの探索開始 周辺機器:%@, サービス:%@", peripheral, service);
        [peripheral discoverCharacteristics:CHARACTERISTIC_UUIDS forService:service];
    }
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
    [self disconnectPeripheral:peripheral];
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
}

# pragma mark - 周辺機器からの通知

/**
 *  サービスのキャラクタリスティックが発見された時。
 *
 *  @param peripheral Bluetooth検出側
 *  @param service    サービス
 *  @param error      エラー
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
    if (error) {
        NSLog(@"キャラクタリスティック検出中のエラー: %@", [error localizedDescription]);
        [self disconnectPeripheral:peripheral];
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"キャラクタリスティックを発見 機器情報:%@ サービス:%@ キャラクタリスティック:%@", peripheral, service, characteristic);
        if (!CHARACTERISTIC_UUIDS) {
            NSLog(@"購読を開始 機器情報:%@ サービス:%@ キャラクタリスティック:%@", peripheral, service, characteristic);
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        [(NSArray*) CHARACTERISTIC_UUIDS enumerateObjectsUsingBlock:^(id characteristicUUID, NSUInteger idx, BOOL *stop) {
            if ([characteristic.UUID isEqual:characteristicUUID]) {
                //指定した通知のみを購読する。機器通知は接続時にperipheralに設定したdelegate=selfに通知される。
                NSLog(@"購読を開始 機器情報:%@ サービス:%@ キャラクタリスティック:%@", peripheral, service, characteristic);
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }];
    }
}

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
    NSLog(@"受信データ: %@, キャラクタリスティック:%@", stringFromData, characteristic);
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
 *  発見済の全ての周辺機器から切断します。
 */
- (void) disconnectFromAllPeripherals {
    for (CBPeripheral* p in _discoveredPeripherals) {
        [self disconnectPeripheral:p];
    }
}
/**
 * 接続済みの周辺機器から切断します。
 *
 *  @param peripheral 周辺機器
 */
- (void) disconnectPeripheral:(CBPeripheral*) peripheral {
    [_discoveredPeripherals removeObject:peripheral];
    if (!peripheral.state == CBPeripheralStateConnected) {
        return;
    }
    
    if (peripheral.services == nil) {
        return;
    }
    for (CBService *service in peripheral.services) {
        if (service.characteristics == nil) {
            continue;
        }
        for (CBCharacteristic *characteristic in service.characteristics) {
            if (characteristic.isNotifying) {
                //購読中のキャラクタリスティックがあれば購読を停止する
                [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            }
        }
    }
    //周辺機器の接続を切断する
    [_centralManager cancelPeripheralConnection:peripheral];
}


@end
