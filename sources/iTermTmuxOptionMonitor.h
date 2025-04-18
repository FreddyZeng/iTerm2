//
//  iTermTmuxOptionMonitor.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/2/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TmuxGateway;
@class iTermVariableScope;
@protocol iTermVariableVendor;

@interface iTermTmuxOptionMonitor : NSObject

@property (nonatomic, weak) TmuxGateway *gateway;
@property (nullable, nonatomic, strong) id<iTermVariableVendor> scope;
@property (nonatomic) NSTimeInterval interval;
@property (nullable, nonatomic, readonly) NSString *lastValue;
@property (nonatomic, readonly) NSString *variableName;
@property (nonatomic, readonly) NSString *format;

- (instancetype)init NS_UNAVAILABLE;

// If `fallbackVariableName` is nonnil, the value of the variable named
// `fallbackVariableName` will be used for tmux 2.8 and earlier.
- (instancetype)initWithGateway:(TmuxGateway *)gateway
                          scope:(id<iTermVariableVendor>)scope
           fallbackVariableName:(nullable NSString *)fallbackVariableName
                         format:(NSString *)format
                         target:(NSString *)tmuxTarget
                   variableName:(nullable NSString *)variableName
                          block:(void (^ _Nullable)(NSString *))block NS_DESIGNATED_INITIALIZER;

- (void)updateOnce;

// Begin regular updates
- (void)startTimer;

// Call this to stop the timer. The scope will no longer be updated.
- (void)invalidate;

- (void)startTimerIfSubscriptionsUnsupported;
@end

NS_ASSUME_NONNULL_END
