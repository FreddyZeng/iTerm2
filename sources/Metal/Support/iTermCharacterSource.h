//
//  iTermCharacterSource.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 11/26/17.
//

#import <Foundation/Foundation.h>

@class iTermCharacterBitmap;
@class iTermFontTable;
@class PTYFontInfo;

@interface iTermCharacterSourceDescriptor : NSObject
@property (nonatomic, readonly, strong) iTermFontTable *fontTable;
@property (nonatomic, readonly) CGSize asciiOffset;
@property (nonatomic, readonly) CGSize glyphSize;
@property (nonatomic, readonly) CGSize cellSize;
@property (nonatomic, readonly) CGSize cellSizeWithoutSpacing;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) BOOL useBoldFont;
@property (nonatomic, readonly) BOOL useItalicFont;
@property (nonatomic, readonly) BOOL useNonAsciiFont;
@property (nonatomic, readonly) NSDictionary *dictionaryValue;
@property (nonatomic, readonly) BOOL asciiAntiAliased;
@property (nonatomic, readonly) BOOL nonAsciiAntiAliased;

+ (instancetype)characterSourceDescriptorWithFontTable:(iTermFontTable *)fontTable
                                           asciiOffset:(CGSize)asciiOffset
                                             glyphSize:(CGSize)glyphSize
                                              cellSize:(CGSize)cellSize
                                cellSizeWithoutSpacing:(CGSize)cellSizeWithoutSpacing
                                                 scale:(CGFloat)scale
                                           useBoldFont:(BOOL)useBoldFont
                                         useItalicFont:(BOOL)useItalicFont
                                      usesNonAsciiFont:(BOOL)useNonAsciiFont
                                      asciiAntiAliased:(BOOL)asciiAntiAliased
                                   nonAsciiAntiAliased:(BOOL)nonAsciiAntiAliased;
@end

@interface iTermCharacterSourceAttributes : NSObject
@property (nonatomic, readonly) BOOL useThinStrokes;
@property (nonatomic, readonly) BOOL bold;
@property (nonatomic, readonly) BOOL italic;

+ (instancetype)characterSourceAttributesWithThinStrokes:(BOOL)useThinStrokes
                                                    bold:(BOOL)bold
                                                  italic:(BOOL)italic;
@end

@interface iTermCharacterSource : NSObject

@property (nonatomic, readonly) BOOL isEmoji;
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) NSArray<NSNumber *> *parts;
@property (nonatomic) BOOL debug;

// Using conservative settings (bold, italic, thick strokes, antialiased)
// returns the frame that contains all characters in the range. This is useful
// for finding the bounding box of all ASCII glyphs.
+ (NSRect)boundingRectForCharactersInRange:(NSRange)range
                                 fontTable:(iTermFontTable *)fontTable
                                     scale:(CGFloat)scale
                               useBoldFont:(BOOL)useBoldFont
                             useItalicFont:(BOOL)useItalicFont
                          usesNonAsciiFont:(BOOL)useNonAsciiFont
                                   context:(CGContextRef)context;

- (instancetype)initWithCharacter:(NSString *)string
                       descriptor:(iTermCharacterSourceDescriptor *)descriptor
                       attributes:(iTermCharacterSourceAttributes *)attributes
                       boxDrawing:(BOOL)boxDrawing
                           radius:(int)radius
         useNativePowerlineGlyphs:(BOOL)useNativePowerlineGlyphs
                          context:(CGContextRef)context;

- (instancetype)initWithFontID:(unsigned int)fontID
                      fakeBold:(BOOL)fakeBold
                    fakeItalic:(BOOL)fakeItalic
                   glyphNumber:(unsigned short)glyphNumber
                      position:(NSPoint)position
                    descriptor:(iTermCharacterSourceDescriptor *)descriptor
                    attributes:(iTermCharacterSourceAttributes *)attributes
                        radius:(int)radius
                       context:(CGContextRef)context;

- (iTermCharacterBitmap *)bitmapForPart:(int)part;

@end

