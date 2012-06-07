/*
 * Copyright (C) 2011 Ba-Z Communication Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *	this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *	this list of conditions and the following disclaimer in the documentation
 *	and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <MobileCoreServices/MobileCoreServices.h>
#import <CarbonateJSON/CarbonateJSON.h>
#import "BZFoursquareRequest.h"

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(objc_arc)
#error This file does not support Objective-C Automatic Reference Counting (ARC)
#endif

#define kAPIv2BaseURL @"https://api.foursquare.com/v2"
#define kTimeoutInterval 180.0

NSString *const BZFoursquareErrorDomain = @"BZFoursquareErrorDomain";

static NSString *_BZGetMIMETypeFromFilename(NSString *filename)
{
	NSString *pathExtension = [filename pathExtension];
	CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)pathExtension, NULL);
	CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
	CFRelease(UTI);
	return [NSMakeCollectable(MIMEType) autorelease];
}

static NSString *_BZGetMIMEBoundary()
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyyMMddHHmmss"];
	NSDate *date = [NSDate date];
	NSTimeInterval ti = [date timeIntervalSinceReferenceDate];
	NSInteger microSec = floor((ti - floor(ti)) * 1000000.0);
	NSString *ret = [NSString stringWithFormat:@"Multipart_%@%06ld", [formatter stringFromDate:date], microSec];
	[formatter release];
	return ret;
}

@interface BZFoursquareRequest ()

- (NSURLRequest *)requestForGETMethod;
- (NSURLRequest *)requestForPOSTMethod;

@property(nonatomic,retain) NSURLConnection *connection;
@property(nonatomic,retain) NSMutableData *responseData;

@end

static NSURL *_baseURL = nil;

@implementation BZFoursquareRequest

@synthesize path = path_;
@synthesize HTTPMethod = HTTPMethod_;
@synthesize parameters = parameters_;
@synthesize delegate = delegate_;
@synthesize connection = connection_;
@synthesize responseData = responseData_;
@synthesize meta = meta_;
@synthesize notifications = notifications_;
@synthesize response = response_;

+ (NSURL *)baseURL
{
	if (_baseURL == nil)
		_baseURL = [[NSURL alloc] initWithString:kAPIv2BaseURL];

	return _baseURL;
}

- (id)init
{
	return [self initWithPath:nil HTTPMethod:nil parameters:nil delegate:nil];
}

- (id)initWithPath:(NSString *)path HTTPMethod:(NSString *)HTTPMethod parameters:(NSDictionary *)parameters delegate:(id <BZFoursquareRequestDelegate>)delegate
{
	if ((self = [super init]))
	{
		self.path = path;
		self.HTTPMethod = HTTPMethod ? HTTPMethod : @"GET";
		self.parameters = parameters;
		self.delegate = delegate;
	}
	return self;
}

- (void)dealloc
{
	self.path = nil;
	self.HTTPMethod = nil;
	self.parameters = nil;
	self.delegate = nil;
	self.connection = nil;
	self.responseData = nil;
	self.meta = nil;
	self.notifications = nil;
	self.response = nil;
	[super dealloc];
}

- (void)start
{
	[self cancel];
	self.meta = nil;
	self.notifications = nil;
	self.response = nil;
	NSURLRequest *request;
	if ([HTTPMethod_ isEqualToString:@"GET"]) {
		request = [self requestForGETMethod];
	} else if ([HTTPMethod_ isEqualToString:@"POST"]) {
		request = [self requestForPOSTMethod];
	} else {
		NSAssert2(NO, @"*** %s: HTTP %@ method not supported", __PRETTY_FUNCTION__, HTTPMethod_);
		request = nil;
	}

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	NSAssert1(connection_ != nil, @"*** %s: connection is nil", __PRETTY_FUNCTION__);
}

- (void)cancel
{
	if (self.connection)
	{
		[self.connection cancel];
		self.connection = nil;
		self.responseData = nil;
	}
}

// NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.responseData = [NSMutableData data];
	if ([self.delegate respondsToSelector:@selector(requestDidStartLoading:)])
	{
		[self.delegate requestDidStartLoading:self];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[responseData_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *responseString = [[NSString alloc] initWithData:responseData_ encoding:NSUTF8StringEncoding];
	NSDictionary *response = [responseString parseJson];
	NSError *error = nil;

	if (response != nil)
	{
		self.meta = [response objectForKey:@"meta"];
		self.notifications = [response objectForKey:@"notifications"];
		self.response = [response objectForKey:@"response"];
		int code = [(NSNumber *)[meta_ objectForKey:@"code"] intValue];
		if (code / 100 != 2)	// Ugly clever hack: 20x code means a successful request,
		{			// and 20x / 100 = 2, as integer division truncates
			error = [NSError errorWithDomain:BZFoursquareErrorDomain code:code userInfo:meta_];
		}
	}

	if (error)
	{
		if ([self.delegate respondsToSelector:@selector(request:didFailWithError:)])
		{
			[self.delegate request:self didFailWithError:error];
		}
	}
	else
	{
		if ([self.delegate respondsToSelector:@selector(requestDidFinishLoading:)])
		{
			[self.delegate requestDidFinishLoading:self];
		}
	}

	self.connection = nil;
	self.responseData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if ([delegate_ respondsToSelector:@selector(request:didFailWithError:)])
	{
		[delegate_ request:self didFailWithError:error];
	}

	self.connection = nil;
	self.responseData = nil;
}

- (NSURLRequest *)requestForGETMethod
{
	NSMutableArray *pairs = [NSMutableArray array];
	for (NSString *key in parameters_)
	{
		NSString *value = [parameters_ objectForKey:key];
		if ([value isKindOfClass:[NSString class]] == NO)
		{
			if ([value isKindOfClass:[NSNumber class]])
				value = [value description];
			else
				continue;
		}

		NSString *escapedValue = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)value, NULL, CFSTR("%:/?#[]@!$&'()*+,;="), kCFStringEncodingUTF8);
		NSMutableString *pair = [key mutableCopy];
		[pair appendString:@"="];
		[pair appendString:escapedValue];
		[pairs addObject:pair];
		[pair release];
		CFRelease(escapedValue);
	}

	NSString *URLString = [kAPIv2BaseURL stringByAppendingPathComponent:path_];
	NSMutableString *mURLString = [[URLString mutableCopy] autorelease];
	[mURLString appendString:@"?"];
	[mURLString appendString:[pairs componentsJoinedByString:@"&"]];
	NSURL *URL = [NSURL URLWithString:mURLString];
	return [NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:kTimeoutInterval];
}

- (NSURLRequest *)requestForPOSTMethod
{
	NSString *URLString = [kAPIv2BaseURL stringByAppendingPathComponent:path_];
	NSURL *URL = [NSURL URLWithString:URLString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:kTimeoutInterval];
	[request setHTTPMethod:@"POST"];
	NSString *boundary = _BZGetMIMEBoundary();

	NSString *value = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	NSString *field = @"Content-Type";
	[request setValue:value forHTTPHeaderField:field];

	NSMutableData *body = [NSMutableData data];
	NSMutableDictionary *datas = [NSMutableDictionary dictionary];
	NSString *dashBoundary = [NSString stringWithFormat:@"--%@", boundary];
	NSData *dashBoundaryData = [dashBoundary dataUsingEncoding:NSUTF8StringEncoding];
	NSData *crlfData = [NSData dataWithBytes:"\r\n" length:2];
	for (NSString *key in parameters_)
	{
		NSString *value = [parameters_ objectForKey:key];
		if ([value isKindOfClass:[NSString class]] == NO)
		{
			if ([value isKindOfClass:[NSNumber class]])
			{
				value = [value description];
			}
			else
			{
				if ([value isKindOfClass:[NSData class]])
				{
					[datas setObject:value forKey:key];
				}
				continue;
			}
		}

		// dash-boundary CRLF
		[body appendData:dashBoundaryData];
		[body appendData:crlfData];
		// Content-Disposition header CRLF
		NSString *header = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"", key];
		[body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:crlfData];
		// Content-Type header CRLF
		header = @"Content-Type: text/plain; charset=utf-8";
		[body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:crlfData];
		// empty line
		[body appendData:crlfData];
		// content
		NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
		[body appendData:valueData];
		// CRLF
		[body appendData:crlfData];
	}
	for (NSString *key in datas)
	{
		// dash-boundary CRLF
		[body appendData:dashBoundaryData];
		[body appendData:crlfData];
		// Content-Disposition header CRLF
		NSString *header = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"",[key stringByDeletingPathExtension], key];
		[body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:crlfData];
		// Content-Type header CRLF
		header = [NSString stringWithFormat:@"Content-Type: %@", _BZGetMIMETypeFromFilename(key)];
		[body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:crlfData];
		// Content-Transfer-Encoding header CRLF
		header = @"Content-Transfer-Encoding: binary";
		[body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:crlfData];
		// empty line
		[body appendData:crlfData];
		// content
		[body appendData:[datas objectForKey:key]];
		// CRLF
		[body appendData:crlfData];
	}
	// dash-boundary "--" CRLF
	[body appendData:dashBoundaryData];
	[body appendBytes:"--" length:2];
	[body appendData:crlfData];
	[request setHTTPBody:body];
	return request;
}

@end

