#if DEBUG
#import "RCTHTTPRequestHandler+Intercept.h"

@implementation RCTHTTPRequestHandler (Intercept)

+(Method) getMethodForSelector:(SEL)selector {
  Method originalMethod = class_getInstanceMethod([RCTHTTPRequestHandler class], selector);
  if ([RCTHTTPRequestHandler conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
    [NSException raise:@"Target class RCTHTTPRequestHandler does not conform to NSURLSessionDelegate" format:@""];
  }
  if (!originalMethod) {
    [NSException raise:@"Target class RCTHTTPRequestHandler does not conform to NSURLSessionDelegate" format:@"%@", NSStringFromSelector(selector)];
  }
  return originalMethod;
}

+ (void)interceptDidReceiveResponseWithInterceptor:(void (^)(NSURLSessionDataTask *task, NSURLResponse *response))interceptor {
  SEL originalSelector = @selector(URLSession:dataTask:didReceiveResponse:completionHandler:);
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionDataTask *task, NSURLResponse *response, void (^completionHandler)(NSURLSessionResponseDisposition)) {
    // Call the original implementation
    ((void (*)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSURLResponse *, void (^)(NSURLSessionResponseDisposition)))originalImp)(self, originalSelector, session, task, response, completionHandler);
    // call the interceptor after calling the original implementation
    interceptor(task, response);
  });
  method_setImplementation(originalMethod, interceptedImp);
}

+ (void)interceptDidReceiveData:(void (^)(NSURLSessionDataTask *task, NSData *data))interceptor {
  SEL originalSelector = @selector(URLSession:dataTask:didReceiveData:);
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionDataTask *task, NSData *data) {
    // Call the original implementation
    ((void (*)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *))originalImp)(self, originalSelector, session, task, data);
    // call the interceptor after calling the original implementation
    interceptor(task, data);
  });
  method_setImplementation(originalMethod, interceptedImp);
}

+ (void)interceptDidCompleteWithError:(void (^)(NSURLSessionTask *task, NSError *error))interceptor {
  SEL originalSelector = @selector(URLSession:task:didCompleteWithError:);
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
    // Call the original implementation
    ((void (*)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *))originalImp)(self, originalSelector, session, task, error);
    // call the interceptor after calling the original implementation
    interceptor(task, error);
  });
  method_setImplementation(originalMethod, interceptedImp);
}

+ (void)interceptWillPerformHTTPRedirection:(void (^)(NSURLSessionTask *task, NSHTTPURLResponse *response, NSURLRequest *request))interceptor {
  SEL originalSelector = @selector(URLSession:task:didCompleteWithError:);
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionTask *task, NSHTTPURLResponse *response, NSURLRequest *request, RCTHTTPRequestHandlerURLRequestBlock completionHandler) {
    // Call the original implementation
    ((void (*)(id, SEL, NSURLSession *, NSURLSessionTask *, NSHTTPURLResponse *, NSURLRequest *, RCTHTTPRequestHandlerURLRequestBlock))originalImp)(self, originalSelector, session, task, response, request, completionHandler);
    // call the interceptor after calling the original implementation
    interceptor(task, response, request);
  });
  method_setImplementation(originalMethod, interceptedImp);
}

@end
#endif
