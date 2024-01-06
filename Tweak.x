@import Foundation;
#include <roothide.h>

BOOL enabled;
NSString *host;
NSNumber *port;
BOOL usePort;
BOOL useHTTPS;

static void createPrefs(NSURL *prefsPath) {
	NSDictionary *newPrefs = @{
		@"enabled": @NO,
		@"host": @"127.0.0.1",
		@"port": @443,
		@"usePort": @YES,
		@"useHTTPS": @YES
	};

	NSLog(@"[HoYoPS] Created prefs file");

	NSError *error;
	[newPrefs writeToURL:prefsPath error:&error];
	if (error) NSLog(@"[HoYoPS] %@",error.localizedDescription);
}

// Normal tweak preferences didn't work, might be something to do with RootHide.
static void reloadPrefs() {
	// Get app's local library directory
	NSArray<NSURL *> *paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
	NSURL *libraryDir = paths[0];

	NSURL *prefsPath = [libraryDir URLByAppendingPathComponent:@"server_config.plist"];

	NSError *error;
    NSDictionary* prefs = [NSDictionary dictionaryWithContentsOfURL:prefsPath error:&error];
	if (error) NSLog(@"[HoYoPS] %@",error.localizedDescription);

	// Check if prefs already exist
	if (!prefs) {
		createPrefs(prefsPath);
		prefs = [NSDictionary new];
	}

    enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : false;
	host = prefs[@"host"] ? prefs[@"host"] : nil;
	port = prefs[@"port"] ? [NSNumber numberWithInt:[prefs[@"port"] intValue]] : nil;
	usePort = prefs[@"usePort"] ? [prefs[@"usePort"] boolValue] : true;
	useHTTPS = prefs[@"useHTTPS"] ? [prefs[@"useHTTPS"] boolValue] : true;
}

NSString *injectServer(NSString *string) {
	// Check against all hoyo api hosts
	BOOL inject = [string containsString:@"hoyoverse.com"] ||
				  [string containsString:@"mihoyo.com"] ||
				  [string containsString:@"starrails.com"] ||
				  [string containsString:@"bhsr.com"];

	if (inject) {
		NSURLComponents *components = [NSURLComponents componentsWithString:string];

		if (!useHTTPS) components.scheme = @"http";
		components.host = host;
		if (usePort) components.port = port;

		#if DEBUG
		NSLog(@"[HoYoPS] Found: %@\nRewrote: %@", string, components.URL.absoluteString);
		#endif

		string = components.URL.absoluteString;
	}

	return string;
}

// There's probably a better place to hook this, NSURLRequest and NSURLSession didn't fully work
%hook NSURL

+ (instancetype)URLWithString:(NSString *)string {

	if (!enabled) return %orig(string);
	return %orig(injectServer(string));
}

- (instancetype)initWithString:(NSString *)string {

	if (!enabled) return %orig(string);
	return %orig(injectServer(string));
}

%end

%ctor {
	// Only do this on app launch
	reloadPrefs();
}