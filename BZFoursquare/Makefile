TARGET = BZFoursquare
OBJECTS = BZFoursquare.o BZFoursquareRequest.o

CC = arm-apple-darwin9-gcc
LD = $(CC)
SYSROOT = /Developer/Platforms/iPhoneOS.platform/SDKs/iPhoneOS4.2.sdk

CFLAGS = -isysroot $(SYSROOT) -c -dynamiclib -ObjC -Wall
LDFLAGS = -isysroot $(SYSROOT) -w -dynamiclib -ObjC -lobjc -framework Foundation -framework CoreFoundation -framework MobileCoreServices -framework UIKit -framework CarbonateJSON

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.m
	$(CC) $(CFLAGS) -o $@ $<
