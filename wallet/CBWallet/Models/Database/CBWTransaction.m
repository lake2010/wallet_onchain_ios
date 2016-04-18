//
//  Transaction.m
//  wallet
//
//  Created by Zin (noteon.com) on 16/2/24.
//  Copyright © 2016年 Bitmain. All rights reserved.
//

#import "CBWTransaction.h"
#import "CBWTransactionStore.h"

@implementation CBWTransaction
@synthesize relatedAddresses = _relatedAddresses;

- (NSArray *)relatedAddresses {
    if (!_relatedAddresses) {
        //TODO: 优化判断
        NSString *selfAddress = ((CBWTransactionStore *)self.store).addressString;
        __block NSMutableArray *addresses = [NSMutableArray array];
        if (self.type == TransactionTypeSend) {
            [self.outputs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                OutItem *o = obj;
                if (![o.addresses containsObject:selfAddress]) {
                    [o.addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        // 去重
                        if (![addresses containsObject:obj]) {
                            [addresses addObject:obj];
                        }
                    }];
                }
            }];
        } else {
            [self.inputs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                InputItem *i = obj;
                if (![i.prevAddresses containsObject:selfAddress]) {
                    [i.prevAddresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        // 去重
                        if (![addresses containsObject:obj]) {
                            [addresses addObject:obj];
                        }
                    }];
                }
            }];
        }
        _relatedAddresses = [addresses copy];
    }
    return _relatedAddresses;
}

//- (NSUInteger)confirmedCount {
//    if (self.blockHeight > -1) {
//        return MAX(((TransactionStore *)self.store).blockHeight - self.blockHeight + 1, 0);
//    }
//    return 0;
//}
#pragma mark - Initialization
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    self = [super init];
    if (self) {
        [self setValuesForKeysWithDictionary:dictionary];
    }
    return self;
}

- (instancetype)init {
    return nil;
}

+ (instancetype)newRecordInStore:(CBWRecordObjectStore *)store {
    return nil;
}

#pragma mark - Public Method

- (void)deleteFromStore:(CBWRecordObjectStore *)store {
    DLog(@"will never delete a transaction");
    return;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"transaction, related addresses %@..., %lld satoshi, %ld confirmations", [self.relatedAddresses firstObject], self.value, (unsigned long)self.confirmations];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[CBWTransaction class]]) {
        if ([self.hashId isEqualToString:((CBWTransaction *)object).hashId]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - KVC
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"inputs"]) {
        // inputs
        if ([value isKindOfClass:[NSArray class]]) {
            __block NSMutableArray *inputs = [NSMutableArray array];// capacity = vin_size
            [value enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                InputItem *i = [[InputItem alloc] initWithDictionary:obj];
                if (i) {
                    [inputs addObject:i];
                }
            }];
            _inputs = [inputs copy];
        }
    } else if ([key isEqualToString:@"outputs"]) {
        // outputs
        if ([value isKindOfClass:[NSArray class]]) {
            __block NSMutableArray *outs = [NSMutableArray array];
            [value enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                OutItem *o = [[OutItem alloc] initWithDictionary:obj];
                if (o) {
                    [outs addObject:o];
                }
            }];
            _outputs = [outs copy];
        }
    } else if ([key isEqualToString:@"fee"]) {
        _fee = [value longLongValue];
    } else if ([key isEqualToString:@"size"]) {
        _size = [value unsignedIntegerValue];
    } else if ([key isEqualToString:@"version"]) {
        _version = [value unsignedIntegerValue];
    } else if ([key isEqualToString:@"confirmations"]) {
        _confirmations = [value unsignedIntegerValue];
    } else {
        [super setValue:value forKey:key];
    }
}
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if ([key isEqualToString:@"hash"]) {
        _hashId = value;
    } else if ([key isEqualToString:@"balance_diff"]) {
        _value = [value longLongValue];
        _type = (_value > 0) ? TransactionTypeReceive : TransactionTypeSend;
    } else if ([key isEqualToString:@"block_time"]) {
        NSTimeInterval timestamp = [value doubleValue];
        if (timestamp > 0) {
            _blockTime = self.creationDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
        }
    } else if ([key isEqualToString:@"block_height"]) {
//        if (![value isKindOfClass:[NSNull class]]) {
            _blockHeight = MAX([value integerValue], 0);
//        }
    } else if ([key isEqualToString:@"created_at"]) {
        if (!self.creationDate) {
            NSTimeInterval timestamp = [value doubleValue];
            self.creationDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
        }
    } else if ([key isEqualToString:@"inputs_count"]) {
        _inputsCount = [value unsignedIntegerValue];
    } else if ([key isEqualToString:@"inputs_value"]) {
        _inputsValue = [value longLongValue];
    } else if ([key isEqualToString:@"outputs_count"]) {
        _outputsCount = [value unsignedIntegerValue];
    } else if ([key isEqualToString:@"outputs_value"]) {
        _outputsValue = [value longLongValue];
    } else if ([key isEqualToString:@"is_coinbase"]) {
        _isCoinbase = [value boolValue];
    }
}

@end

@implementation OutItem

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if (self = [super init]) {
        [self setValuesForKeysWithDictionary:dictionary];
    }
    return self;
}

- (instancetype)init {
    return nil;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // ignore
}
- (id)valueForUndefinedKey:(NSString *)key {
    return nil;
}

@end

@implementation InputItem

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if (self = [super init]) {
        [self setValuesForKeysWithDictionary:dictionary];
    }
    return self;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if ([key isEqualToString:@"prev_addresses"]) {
        _prevAddresses = value;
    } else if ([key isEqualToString:@"prev_value"]) {
        _prevValue = value;
    }
}

@end