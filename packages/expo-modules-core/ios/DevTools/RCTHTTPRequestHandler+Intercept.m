#import "RCTHTTPRequestHandler+Intercept.h"
#import <objc/runtime.h>

@implementation RCTHTTPRequestHandler (Intercept)

+(void)removeAllInterceptedMethods {
  [RCTHTTPRequestHandler removeInterceptedImplementationForSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)];
  [RCTHTTPRequestHandler removeInterceptedImplementationForSelector:@selector(URLSession:dataTask:didReceiveData:)];
  [RCTHTTPRequestHandler removeInterceptedImplementationForSelector:@selector(URLSession:task:didCompleteWithError:)];
  [RCTHTTPRequestHandler removeInterceptedImplementationForSelector:@selector(URLSession:task:didCompleteWithError:)];
  [RCTHTTPRequestHandler removeInterceptedImplementationForSelector:@selector(sendRequest:withDelegate:)];
}

+(Method)getMethodForSelector:(SEL)selector {
  Method originalMethod = class_getInstanceMethod([RCTHTTPRequestHandler class], selector);
  if ([RCTHTTPRequestHandler conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
//    [NSException raise:@"Target class RCTHTTPRequestHandler does not conform to NSURLSessionDelegate" format:@""];
  }
  if (!originalMethod) {
    [NSException raise:@"Target class RCTHTTPRequestHandler does not conform to NSURLSessionDelegate" format:@"%@", NSStringFromSelector(selector)];
  }
  return originalMethod;
}

+(void)storeOriginalImplementationForSelector:(SEL)selector {
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: selector];
  IMP originalImp = method_getImplementation(originalMethod);
  NSString *newStringSelector = [NSString stringWithFormat:@"original_%@", NSStringFromSelector(selector)];
  SEL newSelector = NSSelectorFromString(newStringSelector);
  if (class_addMethod([RCTHTTPRequestHandler class], newSelector, originalImp, method_getTypeEncoding(originalMethod))) {
    NSLog(@"Stored original implemenation in selector: %@ for class %@", newStringSelector, [RCTHTTPRequestHandler class]);
  }
}

+(void)removeInterceptedImplementationForSelector:(SEL)selector {
  NSString *originalSelectorString = [NSString stringWithFormat:@"original_%@", NSStringFromSelector(selector)];
  SEL originalSelector = NSSelectorFromString(originalSelectorString);
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  method_setImplementation([RCTHTTPRequestHandler getMethodForSelector: selector], originalImp);
}

+(void)interceptCreateTask:(void (^)(NSURLSessionTask *task))interceptor {
  // TODO: Remove implementation after usage because it is not declared on the original class
  SEL originalSelector = @selector(URLSession:didCreateTask:);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionTask *task) {
    interceptor(task);
  });
  class_addMethod([RCTHTTPRequestHandler class], originalSelector, interceptedImp, "v@:@@");
}

+(void)interceptSendRequest:(void (^)(NSURLRequest *request))interceptor {
  SEL originalSelector = @selector(sendRequest:withDelegate:);
  [RCTHTTPRequestHandler storeOriginalImplementationForSelector:originalSelector];
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLRequest *request, id<RCTURLRequestDelegate> delegate) {
    // Call the original implementation
    NSURLSessionDataTask *task = ((NSURLSessionDataTask* (*)(id, SEL, NSURLRequest *, id<RCTURLRequestDelegate>))originalImp)(self, originalSelector, request, delegate);
    // call the interceptor after calling the original implementation
    interceptor(request);
    return task;
  });
  method_setImplementation(originalMethod, interceptedImp);
}

+(void)interceptDidReceiveResponseWithInterceptor:(void (^)(NSURLSessionDataTask *task, NSURLResponse *response))interceptor {
  SEL originalSelector = @selector(URLSession:dataTask:didReceiveResponse:completionHandler:);
  [RCTHTTPRequestHandler storeOriginalImplementationForSelector:originalSelector];
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
  [RCTHTTPRequestHandler storeOriginalImplementationForSelector:originalSelector];
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
  [RCTHTTPRequestHandler storeOriginalImplementationForSelector:originalSelector];
  Method originalMethod = [RCTHTTPRequestHandler getMethodForSelector: originalSelector];
  IMP originalImp = method_getImplementation(originalMethod);
  IMP interceptedImp = imp_implementationWithBlock(^(id self, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
    // Call the original implementation
    ((void (*)(id, SEL, NSURLSession *, NSURLSessionTask *, NSError *))originalImp)(self, originalSelector, session, task, error);
    // call the interceptor after calling the original implementation
    interceptor(task, error);
  });
  method_setImplementation(originalMethod, interceptedImp);
}

+ (void)interceptWillPerformHTTPRedirection:(void (^)(NSURLSessionTask *task, NSHTTPURLResponse *response, NSURLRequest *request))interceptor {
  SEL originalSelector = @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:);
  [RCTHTTPRequestHandler storeOriginalImplementationForSelector:originalSelector];
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
