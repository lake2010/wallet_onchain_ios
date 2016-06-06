//
//  NSString+Password.m
//  CBWallet
//
//  Created by Zin on 16/3/24.
//  Copyright © 2016年 Bitmain. All rights reserved.
//

#import "NSString+Password.h"

@implementation NSString (Password)

- (double)passwordStrength {
    float score = 1.0f;
    NSInteger length = self.length;
    // 长度
    if (length < 8) score -= 100.0f;// 小于八位不合法
    // 重复性，超过两个重复扣分
    for (int i = 0; i < length - 1; i++) {
        NSString *a = [self substringWithRange:NSMakeRange(i, 1)];
        NSString *b = [self substringWithRange:NSMakeRange(i+1, 1)];
        if ([a isEqualToString:b]) score -= .2f;
    }
    // 是否有小写字母
    NSString *lowercase = @"abcdefghijklmnopqrstuvwxyz";
    int checkL = 0;
    for (int i = 0; i < lowercase.length; i++) {
        NSString *l = [lowercase substringWithRange:NSMakeRange(i, 1)];
        if ([self rangeOfString:l].location == NSNotFound) {
            checkL ++;
        }
    }
    score += (checkL == lowercase.length) ? -.1f : .1f;
    // 是否有大写字母
    NSString *uppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    checkL = 0;
    for (int i = 0; i < uppercase.length; i++) {
        NSString *l = [uppercase substringWithRange:NSMakeRange(i, 1)];
        if ([self rangeOfString:l].location == NSNotFound) {
            checkL ++;
        }
    }
    score += (checkL == uppercase.length) ? -.1f : .2f;
    // 是否包含数字
    NSString *number = @"0123456789";
    checkL = 0;
    for (int i = 0; i < number.length; i++) {
        NSString *l = [number substringWithRange:NSMakeRange(i, 1)];
        if ([self rangeOfString:l].location == NSNotFound) {
            checkL ++;
        }
    }
    score += (checkL == number.length) ? -.1f : .1f;
    // 是否包含特殊符号
    NSString *cha = @"`,./;'[]\\-=~!@#$%^&*()_+{}|:\"<>?";
    checkL = 0;
    for (int i = 0; i < cha.length; i++) {
        NSString *l = [cha substringWithRange:NSMakeRange(i, 1)];
        if ([self rangeOfString:l].location == NSNotFound) {
            checkL ++;
        }
    }
    score += (checkL == cha.length) ? -.2f : .6f;//
    //TODO: 是否有顺序数字
    //TODO: 是否有顺序字母
    // 是否为bad case
    NSString *badCase = @"123456 porsche firebird prince rosebud password guitar butter beach jaguar 12345678 chelsea united amateur great 1234 black turtle 7777777 cool pussy diamond steelers muffin cooper 12345 nascar tiffany redsox 1313 dragon jackson zxcvbn star scorpio qwerty cameron tomcat testing mountain 696969 654321 golf shannon madison mustang computer bond007 murphy 987654 letmein amanda bear frank brazil baseball wizard tiger hannah lauren master xxxxxxxx doctor dave japan michael money gateway eagle1 naked football phoenix gators 11111 squirt shadow mickey angel mother stars monkey bailey junior nathan apple abc123 knight thx1138 raiders alexis pass iceman porno steve aaaa fuckme tigers badboy forever bonnie 6969 purple debbie angela peaches jordan andrea spider viper jasmine harley horny melissa ou812 kevin ranger dakota booger jake matt iwantu aaaaaa 1212 lovers qwertyui jennifer player flyers suckit danielle hunter sunshine fish gregory beaver fuck morgan porn buddy 4321 2000 starwars matrix whatever 4128 test boomer teens young runner batman cowboys scooby nicholas swimming trustno1 edward jason lucky dolphin thomas charles walter helpme gordon tigger girls cumshot jackie casper robert booboo boston monica stupid access coffee braves midnight shit love xxxxxx yankee college saturn buster bulldog lover baby gemini 1234567 ncc1701 barney cunt apples soccer rabbit victor brian august hockey peanut tucker mark 3333 killer john princess startrek canada george johnny mercedes sierra blazer sexy gandalf 5150 leather cumming andrew spanky doggie 232323 hunting charlie winter zzzzzz 4444 kitty superman brandy gunner beavis rainbow asshole compaq horney bigcock 112233 fuckyou carlos bubba happy arthur dallas tennis 2112 sophie cream jessica james fred ladies calvin panties mike johnson naughty shaved pepper brandon xxxxx giants surfer 1111 fender tits booty samson austin anthony member blonde kelly william blowme boobs fucked paul daniel ferrari donald golden mine golfer cookie bigdaddy king summer chicken bronco fire racing heather maverick penis sandra 5555 hammer chicago voyager pookie eagle yankees joseph rangers packers hentai joshua diablo birdie einstein newyork maggie sexsex trouble dolphins little biteme hardcore white redwings enter 666666 topgun chevy smith ashley willie bigtits winston sticky thunder welcome bitches warrior cocacola cowboy chris green sammy animal silver panther super slut broncos richard yamaha qazwsx 8675309 private fucker justin magic zxcvbnm skippy orange banana lakers nipples marvin merlin driver rachel power blondes michelle marine slayer victoria enjoy corvette angels scott asdfgh girl bigdog fishing 2222 vagina apollo cheese david asdf toyota parker matthew maddog video travis qwert 121212 hooters london hotdog time patrick wilson 7777 paris sydney martin butthead marlboro rock women freedom dennis srinivas xxxx voodoo ginger fucking internet extreme magnum blowjob captain action redskins juice nicole bigdick carter erotic abgrtyu sparky chester jasper dirty 777777 yellow smokey monster ford dreams camaro xavier teresa freddy maxwell secret steven jeremy arsenal music dick viking 11111111 access14 rush2112 falcon snoopy bill wolf russia taylor blue crystal nipple scorpion 111111 eagles peter iloveyou rebecca 131313 winner pussies alex tester 123123 samantha cock florida mistress bitch house beer eric phantom hello miller rocket legend billy scooter flower theman movie 6666 please jack oliver success albert";
    NSArray *badCasesArray = [badCase componentsSeparatedByString:@" "];
    for (NSString *bad in badCasesArray) {
        if ([self rangeOfString:bad options:NSCaseInsensitiveSearch].location != NSNotFound) {
            score -= .3f;
        }
    }
    return score * 100;
}

@end
