#if DEBUG
@import React;

NS_ASSUME_NONNULL_BEGIN

typedef void (NS_SWIFT_SENDABLE ^RCTHTTPRequestHandlerURLRequestBlock)(NSURLRequest * _Nullable);

@interface RCTHTTPRequestHandler (Intercept)
+ (void)interceptDidReceiveResponseWithInterceptor:(void (^)(NSURLSessionDataTask *task, NSURLResponse *response))interceptor;
+ (void)interceptDidReceiveData:(void (^)(NSURLSessionDataTask *task, NSData *data))interceptor;
+ (void)interceptDidCompleteWithError:(void (^)(NSURLSessionTask *task, NSError *error))interceptor;
+ (void)interceptWillPerformHTTPRedirection:(void (^)(NSURLSessionTask *task, NSHTTPURLResponse *response, NSURLRequest *request))interceptor;
@end

NS_ASSUME_NONNULL_END
#endif
