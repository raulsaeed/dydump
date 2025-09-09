#import "IOSLogger.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface iOSLogger()
@property (nonatomic) int socketfd;
@property (nonatomic) BOOL isConnected;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, strong) dispatch_source_t reconnectTimer;

- (void)handleConnectionFailure;
- (void)scheduleReconnect;
static void dispatch_source_cancel_safe(dispatch_source_t timer);
@end

@implementation iOSLogger

+ (instancetype)sharedInstance {
    static iOSLogger *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[iOSLogger alloc] init];
        shared.socketQueue = dispatch_queue_create("com.logger.socket", DISPATCH_QUEUE_SERIAL);
    });
    return shared;
}

- (void)startLoggingWithHost:(NSString *)host port:(int)port {
    if (!host || port <= 0) {
        NSLog(@"Invalid host or port");
        return;
    }
    
    // Cancel any existing reconnect timer
    dispatch_source_cancel_safe(self.reconnectTimer);
    
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:@"logger_host"];
    [[NSUserDefaults standardUserDefaults] setInteger:port forKey:@"logger_port"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    dispatch_async(self.socketQueue, ^{
        self.socketfd = socket(AF_INET, SOCK_STREAM, 0);
        if (self.socketfd < 0) {
            NSLog(@"Failed to create socket: %s", strerror(errno));
            return;
        }
        
        struct sockaddr_in serverAddr;
        memset(&serverAddr, 0, sizeof(serverAddr));
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_port = htons(port);
        
        if (inet_pton(AF_INET, [host UTF8String], &serverAddr.sin_addr) <= 0) {
            NSLog(@"Invalid address: %s", strerror(errno));
            close(self.socketfd);
            return;
        }
        
        if (connect(self.socketfd, (struct sockaddr *)&serverAddr, sizeof(serverAddr)) == 0) {
            self.isConnected = YES;
            NSLog(@"Connected to logger server");
            
            // Set socket options for keep-alive
            int keepAlive = 1;
            if (setsockopt(self.socketfd, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive)) < 0) {
                NSLog(@"Failed to set SO_KEEPALIVE: %s", strerror(errno));
            }
        } else {
            NSLog(@"Failed to connect: %s", strerror(errno));
            close(self.socketfd);
            self.isConnected = NO;
        }
    });
}

- (void)sendLog:(NSString *)message {
    dispatch_async(self.socketQueue, ^{
        if (!self.isConnected) {
            NSLog(@"Not connected, attempting to reconnect...");
            [self scheduleReconnect];
            return;
        }
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *timeString = [formatter stringFromDate:[NSDate date]];
        NSString *logMessage = [NSString stringWithFormat:@"[%@] %@\n", 
                       timeString, message];
        const char *utf8Message = [logMessage UTF8String];
        size_t messageLength = strlen(utf8Message);
        
        ssize_t bytesSent = send(self.socketfd, utf8Message, messageLength, 0);
        if (bytesSent < 0) {
            NSLog(@"Failed to send log message: %s", strerror(errno));
            [self handleConnectionFailure];
        } else if (bytesSent < messageLength) {
            NSLog(@"Incomplete message sent: %zd of %zu bytes", bytesSent, messageLength);
            // For partial sends, we could implement a retry mechanism here
        }
    });
}

- (void)stopLogging {
    dispatch_async(self.socketQueue, ^{
        dispatch_source_cancel_safe(self.reconnectTimer);
        if (self.isConnected) {
            close(self.socketfd);
            self.isConnected = NO;
        }
    });
}

- (void)handleConnectionFailure {
    self.isConnected = NO;
    close(self.socketfd);
    [self scheduleReconnect];
}

- (void)scheduleReconnect {
    dispatch_source_cancel_safe(self.reconnectTimer);
    
    self.reconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.socketQueue);
    dispatch_source_set_timer(self.reconnectTimer,
                            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                            5 * NSEC_PER_SEC,
                            1 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(self.reconnectTimer, ^{
        [self startLoggingWithHost:[[NSUserDefaults standardUserDefaults] stringForKey:@"logger_host"]
                             port:[[NSUserDefaults standardUserDefaults] integerForKey:@"logger_port"]];
    });
    
    dispatch_resume(self.reconnectTimer);
}

static void dispatch_source_cancel_safe(dispatch_source_t timer) {
    if (timer) {
        dispatch_source_cancel(timer);
        dispatch_source_set_event_handler(timer, NULL);
    }
}

@end