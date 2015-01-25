#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController : UIViewController<CBCentralManagerDelegate, CBPeripheralDelegate>

//BL機器連携先として振る舞うマネージャ
@property (strong, nonatomic) CBCentralManager      *centralManager;
//発見した周辺機器への参照（deallocateされるのを防止するため）
@property (strong, nonatomic) CBPeripheral          *discoveredPeripheral;
//発見した周辺機器への参照（deallocateされるのを防止するため）
@property (strong, nonatomic) NSMutableArray        *discoveredPeripherals;

@end

