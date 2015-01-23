# DetectBTLEPeripheral

- Bluetooth LE機器の信号スキャンサンプルです。
- [Appleのサンプル](https://developer.apple.com/library/ios/samplecode/BTLE_Transfer/Introduction/Intro.html)を極力シンプルにして、コメントを日本語化しました。
- コンソールを見て周囲のBT端末との接続状況や受信した信号を楽しんでください。

## 受信する信号を限定したい場合

- ViewController.mの下記を変更してください。
```objc
#define SERVICE_UUIDS           nil //@[[CBUUID UUIDWithString:@"UUID"]]
#define CHARACTERISTIC_UUID     nil //[CBUUID UUIDWithString:@"UUID"]
```
### 変更方法

- SERVICE_UUIDS
	- 下記箇所で ```advertisementData``` に含まれるサービスを指定することで、そのサービスを備えた周辺機器のみを受け付けるようになります。
	```objc
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
	    //未発見機器の場合、接続を試みる。
	    if (_discoveredPeripheral != peripheral) {
	        _discoveredPeripheral = peripheral;
	        NSLog(@"機器へ接続開始 機器:%@", peripheral);
	        [_centralManager connectPeripheral:peripheral options:nil];
	    }
	}
	```

- CHARACTERISTIC_UUID
	- 下記箇所や、信号受信のタイミングでキャラクタリスティック情報を出力しているので、名前や検出タイミングなどから自分の欲しい情報を取得してください。
	- この情報を設定することで、指定した情報のみを受信するようになります。
	```objc
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
	        if (!CHARACTERISTIC_UUID || [characteristic.UUID isEqual:CHARACTERISTIC_UUID]) {
		        NSLog(@"キャラクタリスティックを発見 機器情報:%@ サービス:%@ キャラクタリスティック:%@", peripheral, service, characteristic);
	            //指定した通知のみを購読する。機器通知は接続時にperipheralに設定したdelegate=selfに通知される。
	            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
	        }
	    }
	}
	```

