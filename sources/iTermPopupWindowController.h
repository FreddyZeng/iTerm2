//
//  iTermPopupWindowController.h
//  iTerm
//
//  Created by George Nachman on 11/4/10.
//  Copyright 2010 George Nachman. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class iTermPopupWindowController;
@class PopupModel;
@class PopupEntry;
@class VT100Screen;

@protocol iTermPopupWindowPresenter<NSObject>
- (void)popupWindowWillPresent:(iTermPopupWindowController *)popupWindowController;
- (NSRect)popupWindowOriginRectInScreenCoords;
@end

@protocol PopupDelegate <NSObject>

- (NSRect)popupScreenVisibleFrame;
- (VT100Screen *)popupVT100Screen;
- (id<iTermPopupWindowPresenter>)popupPresenter;
- (void)popupPreview:(NSString *)text;
- (void)popupInsertText:(NSString *)text popup:(iTermPopupWindowController *)popupWindowController;
- (void)popupKeyDown:(NSEvent *)event;
// Return YES if the delegate handles it, NO if Popup should handle it.
- (BOOL)popupHandleSelector:(SEL)selector string:(NSString *)string currentValue:(NSString *)currentValue;
- (void)popupWillClose:(iTermPopupWindowController *)popup;
- (BOOL)popupWindowIsInFloatingHotkeyWindow;
- (void)popupIsSearching:(BOOL)searching;
- (BOOL)popupShouldTakePrefixFromScreen;
// If the cursor is preceded by whitespace the last word will be empty. Words go in reverse order.
- (NSArray<NSString *> *)popupWordsBeforeInsertionPoint:(int)count;
- (BOOL)popupWindowShouldAvoidChangingWindowOrderOnClose;
@end

@protocol iTermPopupWindowHosting
- (NSRect)popupWindowHostingInsertionPointFrameInScreenCoordinates;
- (NSArray<NSString *> *)wordsBeforeInsertionPoint:(NSInteger)count;
- (void)popupWindowHostingInsertText:(NSString *)string;
- (void)popupWindowHostSetPreview:(NSString *)string;
@end

@interface iTermPopupWindowController : NSWindowController

@property(nonatomic, assign) id<PopupDelegate> delegate;

- (instancetype)initWithWindowNibName:(NSString*)nibName
                             tablePtr:(NSTableView**)table
                                model:(PopupModel*)model;

// Programmatically close the window.
- (void)closePopupWindow;

// Call this after initWithWindowNibName:tablePtr:model: if table was nil.
- (void)setTableView:(NSTableView *)table;

// Turn off focus follows mouse while this window is key.
- (BOOL)disableFocusFollowsMouse;

// Called by clients to open window.
- (void)popWithDelegate:(id<PopupDelegate>)delegate
               inWindow:(NSWindow *)owningWindow;

// Safely shut down the popup when the parent is about to be dealloced. Clients must call this from
// dealloc. It removes possible pending timers.
- (void)shutdown;

// Subclasses may override these methods.
// Begin populating the unfiltered model.
- (void)refresh;

// Notify that a row was selected. Call this method when subclass has accepted
// the selection.
- (void)rowSelected:(id)sender;

// Window is closing. Call this method when subclass is done.
- (void)onClose;

// Window is opening. -[refresh] will be called immediately after this returns.
- (void)onOpen;

// Get a value for a table cell. Always returns a value from the model.
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (void)setOnTop:(BOOL)onTop;
- (PopupModel*)unfilteredModel;
- (PopupModel*)model;
- (void)setPosition:(BOOL)canChangeSide;
- (void)reloadData:(BOOL)canChangeSide;
- (void)_setClearFilterOnNextKeyDownFlag:(id)sender;
- (int)convertIndex:(int)i;
- (NSAttributedString*)attributedStringForEntry:(PopupEntry*)entry isSelected:(BOOL)isSelected;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (BOOL)_word:(NSString*)temp matchesFilter:(NSString*)filter;

- (NSString *)truncatedMainValueForEntry:(PopupEntry *)entry;
- (NSAttributedString *)shrunkToFitAttributedString:(NSAttributedString *)attributedString
                                            inEntry:(PopupEntry *)entry
                                     baseAttributes:(NSDictionary *)baseAttributes;
- (BOOL)passKeyEventToDelegateForSelector:(SEL)selector string:(NSString *)string;
- (void)previewCurrentRow;
- (BOOL)shouldEscapeShellCharacters;

@end
