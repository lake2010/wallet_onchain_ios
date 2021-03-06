//
//  SettingsViewController.m
//  wallet
//
//  Created by Zin (noteon.com) on 16/2/24.
//  Copyright © 2016年 Bitmain. All rights reserved.
//

#import "SettingsViewController.h"
#import "PasswordViewController.h"

#import "Database.h"
#import "CBWBackup.h"
#import "Guard.h"
#import "CBWFee.h"

#import "SSKeychain.h"

#import "NSDate+Helper.h"
#import "NSString+CBWAddress.h"

@import LocalAuthentication;

typedef NS_ENUM(NSUInteger, kSettingsSection) {
    kSettingsSectionCustomFee,
    kSettingsSectionSecurity,
    kSettingsSectionBackup,
//    kSettingsSectionNetwork,
    kSettingsSectionSignOut
};

@interface SettingsViewController ()

@property (nonatomic, strong) NSArray *tableStrings;
@property (nonatomic, strong) UISwitch *iCloudSwitch;
@property (nonatomic, strong) UISwitch *touchIDSwitch;
@property (nonatomic, strong) UISwitch *testnetSwitch;

@end

@implementation SettingsViewController

#pragma mark - Initialization
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

#pragma mark - View Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedStringFromTable(@"Navigation settings", @"CBW", @"Settings");
    
    [self enableRevealInteraction];
    
    // data
    NSMutableArray *securityCells = [NSMutableArray arrayWithObjects:
                                     NSLocalizedStringFromTable(@"Settings Cell change_password", @"CBW", @"Settings"),
                                     NSLocalizedStringFromTable(@"Settings Cell change_hint", @"CBW", @"Chnage Hint"),
                                     nil];
    NSError *error = nil;
    LAContext *laContext = [[LAContext alloc] init];
    if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [securityCells addObject:NSLocalizedStringFromTable(@"Settings Cell touchid", @"CBW", nil)];
    }
    
    _tableStrings = @[@[NSLocalizedStringFromTable(@"Settings Cell custom_fee", @"CBW", nil)],
                      @{NSLocalizedStringFromTable(@"Settings Section security", @"CBW", nil): securityCells},
                      @{NSLocalizedStringFromTable(@"Settings Section backup", @"CBW", nil): @[
                            NSLocalizedStringFromTable(@"Settings Cell export", @"CBW", @"Export"),
                            NSLocalizedStringFromTable(@"Settings Cell iCloud", @"CBW", @"iCloud")]},
//                      @{NSLocalizedStringFromTable(@"Settings Section network", @"CBW", nil): @[
//                                NSLocalizedStringFromTable(@"Settings Cell testnet", @"CBW", @"Testnet")]},
                      @[NSLocalizedStringFromTable(@"Settings Cell sign_out", @"CBW", nil)]
                      ];
}

#pragma mark - Private Method
- (void)p_exportBackupImageToPhotoLibraryWithCell:(UITableViewCell *)cell {
    [CBWBackup saveToLocalPhotoLibraryWithCompleiton:^(NSURL *assetURL, NSError *error) {
        id indicator = cell.accessoryView;
        if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
            [indicator stopAnimating];
        }
        if (error) {
            NSLog(@"export to photo library error: \n%@", error);
            [self alertMessage:error.localizedDescription withTitle:NSLocalizedStringFromTable(@"Error", @"CBW", nil)];
        } else {
            [self alertMessage:NSLocalizedStringFromTable(@"Alert Message saved_to_photo_library", @"CBW", nil) withTitle:NSLocalizedStringFromTable(@"Success", @"CBW", nil)];
        }
    }];
}
#pragma mark Handlers
- (void)p_handleToggleiCloudEnabled:(id)sender {
    [self reportActivity:@"toggle iCloud"];
    DLog(@"toggle icloud");
    [CBWBackup toggleiCloudBySwith:self.iCloudSwitch inViewController:self];
}
- (void)p_handleUpdateCustomFee {
    [self reportActivity:@"updateCustomFee"];
    
    DLog(@"to select fee");
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"Settings Cell custom_fee", @"CBW", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSUInteger count = CBWFee.values.count;
    for (NSUInteger i = 0; i < count; i ++) {
        CBWFee *fee = [CBWFee feeWithLevel:i];
        UIAlertAction *feeAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", [fee.value satoshiBTCString], fee.description] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
            [[NSUserDefaults standardUserDefaults] setObject:@(i) forKey:CBWUserDefaultsFeeLevel];
            if ([[NSUserDefaults standardUserDefaults] synchronize]) {
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kSettingsSectionCustomFee] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                [self alertMessage:NSLocalizedStringFromTable(@"Alert Message custom_fee_update_error", @"CBW", nil) withTitle:@""];
            }
        }];
        [actionSheet addAction:feeAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"CBW", nil) style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}
- (void)p_handleUpdateHint {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"Settings Cell change_hint", @"CBW", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedStringFromTable(@"Placeholder enter_new_hint", @"CBW", nil);
        textField.text = [SSKeychain passwordForService:CBWKeychainHintService account:CBWKeychainAccountDefault];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"CBW", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    
    
    __weak typeof(alert) weakAlert = alert;
    UIAlertAction *save = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Save", @"CBW", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *hintField = [[weakAlert textFields] firstObject];
        NSString *hint = hintField.text;
        if (hint.length > 0) {
            if ([SSKeychain setPassword:hint forService:CBWKeychainHintService account:CBWKeychainAccountDefault]) {
                [self alertMessage:NSLocalizedStringFromTable(@"Success", @"CBW", nil) withTitle:@""];
                // 重新备份到 iCloud
                [CBWBackup saveToCloudKitWithCompletion:^(NSError *error) {
                    // TODO: handle error
                    if (error) {
                        DLog(@"changed hint, update iCloud backup failed. \n%@", error);
                    }
                }];
            } else {
                [self alertMessage:NSLocalizedStringFromTable(@"Alert Message update_hint_error", @"CBW", nil) withTitle:@""];
            }
        } else {
            [self alertErrorMessage:NSLocalizedStringFromTable(@"Alert Message empty_hint", @"CBW", nil)];
        }
    }];
    [alert addAction:save];
    
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)p_handleToggleTouchIdEnabled:(id)sender {
    [self reportActivity:@"toggle Touch ID"];
    DLog(@"toggle touch id");
    if ([[SSKeychain passwordForService:CBWKeychainTouchIDService account:CBWKeychainAccountDefault] isEqualToString:CBWKeychainTouchIDON]) {
        // turn off
        [SSKeychain deletePasswordForService:CBWKeychainMasterPasswordService account:CBWKeychainAccountDefault];
        [SSKeychain deletePasswordForService:CBWKeychainTouchIDService account:CBWKeychainAccountDefault];
        [self.touchIDSwitch setOn:NO animated:YES];
        return;
    }
    
    // TODO: validate domain status
    // turn on
    LAContext *context = [LAContext new];
    NSError *error = nil;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:NSLocalizedString(@"Alert Message enable_touchid", nil) reply:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    // authorized
                    if ([SSKeychain setPassword:[Guard globalGuard].code forService:CBWKeychainMasterPasswordService account:CBWKeychainAccountDefault]) {
                        if ([SSKeychain setPassword:CBWKeychainTouchIDON forService:CBWKeychainTouchIDService account:CBWKeychainAccountDefault]) {
                            [self.touchIDSwitch setOn:YES animated:YES];
                        } else {
                            [SSKeychain deletePasswordForService:CBWKeychainMasterPasswordService account:CBWKeychainAccountDefault];
                            [self.touchIDSwitch setOn:NO animated:YES];
                        }
                    }
                } else if (error) {
                    [self.touchIDSwitch setOn:NO animated:YES];
                    NSString *message = nil;
                    switch (error.code) {
                        case LAErrorAuthenticationFailed: {
                            message = NSLocalizedString(@"There was a problem verifying your identity.", nil);
                            break;
                        }
                            
                        case LAErrorUserCancel: {
//                            message = NSLocalizedString(@"You canceled.", nil);
                            break;
                        }
                            
                        case LAErrorUserFallback: {
//                            message = NSLocalizedString(@"You pressed password.", nil);
                            break;
                        }
                            
                        default:
                            message = NSLocalizedString(@"Touch ID may not be configured.", nil);
                            break;
                    }
                    if (message) {
                        [self alertMessage:message withTitle:NSLocalizedString(@"Error", nil)];
                    }
                }
            });
        }];
    }
}

- (void)p_handleToggleTestnetEnabled:(id)sender {
    DLog(@"toggle testnet");
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsTestnetEnabled];
    [[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:CBWUserDefaultsTestnetEnabled];
    if ([[NSUserDefaults standardUserDefaults] synchronize]) {
        if (self.testnetSwitch.on == enabled) {
            [self.testnetSwitch setOn:!enabled animated:YES];
        }
    } else {
        if (self.testnetSwitch.on != enabled) {
            [self.testnetSwitch setOn:enabled animated:YES];
        }
    }
}

- (void)p_confirmToSignOut {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"Alert Title confirm_to_sign_out", @"CBW", nil) message:NSLocalizedStringFromTable(@"Alert Message confirm_to_sign_out", @"CBW", nil) preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"CBW", nil) style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Yes", @"CBW", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[Guard globalGuard] signOut];
    }];
    [alert addAction:confirm];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.tableStrings.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id sectionStrings = self.tableStrings[section];
    if ([sectionStrings isKindOfClass:[NSDictionary class]]) {
        return [[[sectionStrings allObjects] firstObject] count];
    }
    return [sectionStrings count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id sectionStrings = self.tableStrings[section];
    if ([sectionStrings isKindOfClass:[NSDictionary class]]) {
        return [[sectionStrings allKeys] firstObject];
    }
    return nil;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    DefaultSectionHeaderView *view = [tableView dequeueReusableHeaderFooterViewWithIdentifier:BaseTableViewSectionHeaderIdentifier];
    view.topHairlineHidden = YES;
    return view;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BaseTableViewCellDefaultIdentifier forIndexPath:indexPath];
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.textLabel.textColor = [UIColor CBWTextColor];

    // set text label
    id sectionStrings = self.tableStrings[indexPath.section];
    if ([sectionStrings isKindOfClass:[NSDictionary class]]) {
        id object = [[[sectionStrings allObjects] firstObject] objectAtIndex:indexPath.row];
        cell.textLabel.text = object;
    } else {
        cell.textLabel.text = [sectionStrings objectAtIndex:indexPath.row];
    }
    
    // set custom fee cell stuff
    if (kSettingsSectionCustomFee == indexPath.section) {
        NSNumber *userDefaultFee = [[NSUserDefaults standardUserDefaults] objectForKey:CBWUserDefaultsFeeLevel];
        if (!userDefaultFee) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Settings Cell custom_fee_undefined", @"CBW", nil);
        } else {
            cell.detailTextLabel.text = [[[CBWFee feeWithLevel:[userDefaultFee unsignedIntegerValue]] value] satoshiBTCString];
        }
    }
    
    // set touch id cell stuff
    if (kSettingsSectionSecurity == indexPath.section) {
        if (indexPath.row == 2) {
            // touch id
            if (!self.touchIDSwitch) {
                UISwitch *aSwitch = [[UISwitch alloc] init];
                [aSwitch addTarget:self action:@selector(p_handleToggleTouchIdEnabled:) forControlEvents:UIControlEventValueChanged];
                self.touchIDSwitch = aSwitch;
            }
            cell.accessoryView = self.touchIDSwitch;
            DLog(@"touch id %@", [SSKeychain passwordForService:CBWKeychainTouchIDService account:CBWKeychainAccountDefault]);
            self.touchIDSwitch.on = [[SSKeychain passwordForService:CBWKeychainTouchIDService account:CBWKeychainAccountDefault] isEqualToString:CBWKeychainTouchIDON];//[[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsTouchIdEnabledKey];
        }
    }
    
    // set icloud cell stuff
    if (kSettingsSectionBackup == indexPath.section) {
        if (indexPath.row == 1) {
            // iCloud
            cell.detailTextLabel.text = [[[NSUserDefaults standardUserDefaults] objectForKey:CBWUserDefaultsiCloudSyncDateKey] stringWithFormat:@"yyyy-MM-dd HH:mm:ss"];
            if (!self.iCloudSwitch) {
                UISwitch *aSwitch = [[UISwitch alloc] init];
                [aSwitch addTarget:self action:@selector(p_handleToggleiCloudEnabled:) forControlEvents:UIControlEventValueChanged];
                self.iCloudSwitch = aSwitch;
            }
            cell.accessoryView = self.iCloudSwitch;
            self.iCloudSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsiCloudEnabledKey];
        }
    }
    
    // set testnet cell stuff
//        if (indexPath.section == kSettingsSectionNetwork) {
//            // testnet
//            if (!self.testnetSwitch) {
//                UISwitch *aSwitch = [[UISwitch alloc] init];
//                [aSwitch addTarget:self action:@selector(p_handleToggleTestnetEnabled:) forControlEvents:UIControlEventValueChanged];
//                self.testnetSwitch = aSwitch;
//            }
//            cell.accessoryView = self.testnetSwitch;
//            self.testnetSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsTestnetEnabled];
//        }
    
    // set sign out with danger color
    if (kSettingsSectionSignOut == indexPath.section) {
        cell.textLabel.textColor = [UIColor CBWDangerColor];
    }
    
    
    return cell;
}
#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self reportActivity:@"selectCell"];
    
    switch (indexPath.section) {
        case kSettingsSectionSecurity: {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            switch (indexPath.row) {
                case 0: {
                    PasswordViewController *settingsViewController = [[PasswordViewController alloc] init];
                    [self.navigationController pushViewController:settingsViewController animated:YES];
                    break;
                }
                    
                case 1: {
                    [self p_handleUpdateHint];
                    
                    break;
                }
                    
                case 2: {
                    [self p_handleToggleTouchIdEnabled:nil];
                    break;
                }
            }
            break;
        }
            
        case kSettingsSectionCustomFee: {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self p_handleUpdateCustomFee];
            break;
        }
            
        case kSettingsSectionBackup: {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            if (indexPath.row == 0) {
                // export
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                cell.accessoryView = indicator;
                [indicator startAnimating];
                [self p_exportBackupImageToPhotoLibraryWithCell:cell];
            } else if (indexPath.row == 1) {
                // icloud
                [self p_handleToggleiCloudEnabled:nil];
            }
            break;
        }
            
//        case kSettingsSectionNetwork: {
//            [tableView deselectRowAtIndexPath:indexPath animated:YES];
//            [self p_handleToggleTestnetEnabled:nil];
//            break;
//        }
            
        case kSettingsSectionSignOut: {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"Alert Title sign_out", @"CBW", nil) message:NSLocalizedStringFromTable(@"Alert Message sign_out", @"CBW", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.secureTextEntry = YES;
                textField.placeholder = NSLocalizedStringFromTable(@"Placeholder master_password", @"CBW", nil);
            }];
            UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"CBW", nil) style:UIAlertActionStyleCancel handler:nil];
            [alert addAction:cancel];
            
            __weak typeof(alert) weakAlert = alert;
            UIAlertAction *backupAndDelete = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Alert Action backup_delete", @"CBW", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *code = [weakAlert.textFields firstObject].text;
                if (code.length == 0) {
                    [self alertErrorMessage:NSLocalizedStringFromTable(@"Alert Message need_current_password", @"CBW", nil)];
                } else {
                    if (![[Guard globalGuard] checkCode:code]) {
                        [self alertErrorMessage:NSLocalizedStringFromTable(@"Alert Message invalid_master_password", @"CBW", nil)];
                    } else {
                        [CBWBackup saveToLocalPhotoLibraryWithCompleiton:^(NSURL *assetURL, NSError *error) {
                            if (error) {
                                NSLog(@"export to photo library error: \n%@", error);
                                [self alertMessage:error.localizedDescription withTitle:NSLocalizedStringFromTable(@"Error", @"CBW", nil)];
                            } else {
                                [self p_confirmToSignOut];
                            }
                        }];
                    }
                    
                }
            }];
            [alert addAction:backupAndDelete];
            
            UIAlertAction *delete = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Delete", @"CBW", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *code = [weakAlert.textFields firstObject].text;
                if (code.length == 0) {
                    [self alertErrorMessage:NSLocalizedStringFromTable(@"Alert Message need_current_password", @"CBW", nil)];
                } else {
                    if (![[Guard globalGuard] checkCode:code]) {
                        [self alertErrorMessage:NSLocalizedStringFromTable(@"Alert Message invalid_master_password", @"CBW", nil)];
                    } else {
                        [self p_confirmToSignOut];
                    }
                }
            }];
            [alert addAction:delete];
            [self presentViewController:alert animated:YES completion:^{
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            }];
            break;
        }
    }
}

@end
