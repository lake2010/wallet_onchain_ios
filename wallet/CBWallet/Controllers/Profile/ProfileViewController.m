//
//  ProfileViewController.m
//  wallet
//
//  Created by Zin (noteon.com) on 16/2/24.
//  Copyright © 2016年 Bitmain. All rights reserved.
//

#import "ProfileViewController.h"
#import "TransactionListViewController.h"
#import "AccountsManagerViewController.h"
#import "SettingsViewController.h"
#import "PasswordViewController.h"

#import "CBWAccountStore.h"
#import "CBWBackup.h"
#import "Guard.h"

#import "SSKeychain.h"

#import "NSDate+Helper.h"

@import LocalAuthentication;

typedef NS_ENUM(NSUInteger, kProfileSection) {
    kProfileSectionAccounts = 0,
//    kProfileSectionAllTransactions,
//    kProfileSectionSettings,
    kProfileSectionSecurity,
    kProfileSectionBackup
};

@interface ProfileViewController ()

@property (nonatomic, strong) NSArray *tableStrings;
@property (nonatomic, strong) UISwitch *iCloudSwitch;
@property (nonatomic, strong) UISwitch *touchIDSwitch;

@end

@implementation ProfileViewController

#pragma mark - Initialization

- (instancetype)initWithAccountStore:(CBWAccountStore *)store {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _accountStore = store;
    }
    return self;
}

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
    
    self.title = NSLocalizedStringFromTable(@"Navigation profile", @"CBW", @"Profile");
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navigation_close"] style:UIBarButtonItemStylePlain target:self action:@selector(dismiss:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Navigation manage_accounts", @"CBW", nil) style:UIBarButtonItemStylePlain target:self action:@selector(p_handleManageAccounts:)];
    
    NSMutableArray *securityCells = [NSMutableArray arrayWithObject:NSLocalizedStringFromTable(@"Profile Cell change_password", @"CBW", @"Settings")];
    NSError *error = nil;
    LAContext *laContext = [[LAContext alloc] init];
    if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [securityCells addObject:NSLocalizedStringFromTable(@"Profile Cell touchid", @"CBW", nil)];
    }
    
    _tableStrings = @[@{NSLocalizedStringFromTable(@"Profile Section accounts", @"CBW", @"Accounts"): @[]},
//                      @[NSLocalizedStringFromTable(@"Profile Cell all_transactions", @"CBW", @"All Transactions")],
//                      @[NSLocalizedStringFromTable(@"Profile Cell settings", @"CBW", @"Settings")],
                      @{NSLocalizedStringFromTable(@"Profile Section security", @"CBW", nil): securityCells},
                      @{NSLocalizedStringFromTable(@"Profile Section backup", @"CBW", nil):
                            @[
                                NSLocalizedStringFromTable(@"Profile Cell export", @"CBW", @"Export"),
                                NSLocalizedStringFromTable(@"Profile Cell iCloud", @"CBW", @"iCloud")
                                ]
                        }
                      ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // account store could be updated
    [self.tableView reloadData];
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
- (void)p_handleManageAccounts:(id)sender {
    AccountsManagerViewController *managerViewController = [[AccountsManagerViewController alloc] initWithAccountStore:self.accountStore];
    [self.navigationController pushViewController:managerViewController animated:YES];
}
- (void)p_handleToggleiCloudEnabled:(id)sender {
    DLog(@"toggle icloud");
    [CBWBackup toggleiCloudBySwith:self.iCloudSwitch inViewController:self];
}
- (void)p_handleToggleTouchIdEnabled:(id)sender {
    DLog(@"toggle touch id");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsTouchIdEnabledKey]) {
        // turn off
        if ([SSKeychain deletePasswordForService:CBWKeychainMasterPasswordService account:CBWKeychainAccountDefault]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:CBWUserDefaultsTouchIdEnabledKey];
            if ([[NSUserDefaults standardUserDefaults] synchronize]) {
                [self.touchIDSwitch setOn:NO animated:YES];
            }
        }
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
                        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:CBWUserDefaultsTouchIdEnabledKey];
                        if ([[NSUserDefaults standardUserDefaults] synchronize]) {
                            [self.touchIDSwitch setOn:YES animated:YES];
                        } else {
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

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.tableStrings.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kProfileSectionAccounts) {
        return self.accountStore.count;
    }
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
    
    if (indexPath.section == kProfileSectionAccounts) {
    
        CBWAccount *account = [self.accountStore recordAtIndex:indexPath.row];
        cell.textLabel.text = account.label;

    } else {

        // set text label
        id sectionStrings = self.tableStrings[indexPath.section];
        if ([sectionStrings isKindOfClass:[NSDictionary class]]) {
            id object = [[[sectionStrings allObjects] firstObject] objectAtIndex:indexPath.row];
            cell.textLabel.text = object;
        } else {
            cell.textLabel.text = [sectionStrings objectAtIndex:indexPath.row];
        }
        
        // set touch id cell stuff
        if (indexPath.section == kProfileSectionSecurity) {
            if (indexPath.row == 1) {
                // touch id
                if (!self.touchIDSwitch) {
                    UISwitch *aSwitch = [[UISwitch alloc] init];
                    [aSwitch addTarget:self action:@selector(p_handleToggleTouchIdEnabled:) forControlEvents:UIControlEventValueChanged];
                    self.touchIDSwitch = aSwitch;
                }
                cell.accessoryView = self.touchIDSwitch;
                self.touchIDSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:CBWUserDefaultsTouchIdEnabledKey];
            }
        }
        
        // set icloud cell stuff
        if (indexPath.section == kProfileSectionBackup) {
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
    }
    
    return cell;
}
#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case kProfileSectionAccounts: {
            if ([self.delegate respondsToSelector:@selector(profileViewController:didSelectAccount:)]) {
                [self.delegate profileViewController:self didSelectAccount:[self.accountStore recordAtIndex:indexPath.row]];
            }
            break;
        }
//        case kProfileSectionAllTransactions: {
//            TransactionListViewController *transactionListViewController = [[TransactionListViewController alloc] init];
//            [self.navigationController pushViewController:transactionListViewController animated:YES];
//            break;
//        }
//        case kProfileSectionSettings: {
//            SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
//            [self.navigationController pushViewController:settingsViewController animated:YES];
//            break;
//        }
        case kProfileSectionSecurity: {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            switch (indexPath.row) {
                case 0: {
                    PasswordViewController *settingsViewController = [[PasswordViewController alloc] init];
                    [self.navigationController pushViewController:settingsViewController animated:YES];
                    break;
                }
                    
                case 1: {
                    [self p_handleToggleTouchIdEnabled:nil];
                    break;
                }
            }
            break;
        }
            
        case kProfileSectionBackup: {
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
    }
}

@end
