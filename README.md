# Foursquare API v2 for iOS

A simple Objective-C wrapper for Version 2 of the Foursquare API. It allows you to integrate Foursquare into your iOS application.

## Features

* Simple, small and easy to use
* Authentication using Safari
* Asynchronous requests support
* Open source BSD license

## Requirements

This library requires your app to link against the following frameworks:

* Foundation.framework
* MobileCoreServices.framework
* UIKit.framework

Uses H2CO3's CarbonateJSON for JSON parsing.

## Getting Started

1. ### [Register](https://foursquare.com/oauth/) for an API consumer key

	In order to obtain an oAuth access token, this library uses Safari and a custom URL scheme that brings the user back to your app. The client ID and callback URL are required when creating the BZFoursquare object.

		BZFoursquare *foursquare = [[BZFoursquare alloc] initWithClientID:@"YOUR_CLIENT_ID" callbackURL:@"YOUR_CALLBACK_URL"];

2. ### Installation

	Copy all the files from the BZFoursquare folder to your project.

	#### Automatic Reference Counting (ARC)

	If you are including this library in your project that uses Objective-C Automatic Reference Counting (ARC) enabled, you will need to set the `-fno-objc-arc` compiler flag on all of the BZFoursquare source files. Simply add this switch to CFLAGS and LDFLAGS in the Makefile.

3. ### Set up your custom URL scheme

	Add your custom URL scheme to your project. The following is the setting of the FSQDemo project.

	![URL Types](https://github.com/baztokyo/foursquare-ios-api/raw/master/images/url_types.png "URL Types")

## License

Foursquare API v2 for iOS is available under the 2-clause BSD license. See the LICENSE file for more info.

