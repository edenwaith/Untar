//
//  UTController.h
//  Untar Version 1.3.2
//
//  Created by admin on August 2002.
//  Copyright (c) 2002 - 2007 Edenwaith. All rights reserved.
//
// Untar is a freeware application which uncompresses files in .7z, .tar, .tar.gz, .dmg.gz, 
// .svgz, .gz, .tgz, .tar.z, .z, .Z, .tar.Z, .taz, .tar.bz, .tar.bz2, .tbz, .tbz2, .bz,
// .bz2, .rar, and .zip formats.
// (Chad Armstrong : chad@edenwaith.com).

// The following source code has been released under the GPL license.
// http://www.gnu.org/copyleft/gpl.html

#import <Cocoa/Cocoa.h>

@interface UTController : NSObject
{
    IBOutlet NSTextField	*fileField;		// text field containing compressed file name
    IBOutlet NSTextField 	*dirField;		// text field containing directory name 
    IBOutlet NSButton 		*UTButton;		// Untar button
    IBOutlet NSButton		*cancelButton;	// Cancel button on drop down sheet
    IBOutlet NSProgressIndicator *spinningIndicator;
    IBOutlet id				window;
    IBOutlet id				progressSheet;
    IBOutlet id				consoleLogPanel;
    IBOutlet NSTextField 	*progress_msg;	// Message displaying current file extracted
    IBOutlet NSTextView	 	*textView;		// NSTextView in Console Log
    IBOutlet NSMenuItem		*consoleLogMenu;
    
    NSTask *untar;				// new task to run tar 
    NSPipe *pipe;
	NSData *consoleText;
    
    BOOL quitWhenFinished;		// boolean value to indicate to close prog. when done
    BOOL beepWhenFinished;		// value to determine whether or not to beep when task is finished
    BOOL tempSuspendQuit;
    BOOL pauseTaskRelease;
    BOOL wasCanceled;
        
    NSFileManager			*fm;
    
    NSMutableDictionary		*dict;
	
	NSMutableString			*directory;
    
    int						os_version;	// Operating System version (i.e. 1000 = 10.0.0)

}


// drag, drop, & launch functions
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification;
- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (void) applicationWillTerminate:(NSNotification *)aNotification;

// other wonderful functions which uncompress and get files
- (IBAction)getFile: (id)sender;
- (IBAction)getDir: (id)sender;
- (IBAction)uncompress: (id)sender;
- (IBAction) cancelExtraction: (id)sender;
- (void) unTarIt;
- (void) outputData: (NSFileHandle *) handle;
- (NSString *) fileNameString: (NSString *) filename;
- (NSString *) fileNameWithoutExtension: (NSString *) filename;
- (void) setWorkingDirectory: (BOOL) isArchive;
- (BOOL) isArchive: (NSString *) filename;
- (void)doneTarring: (NSNotification *)aNotification;

// Console log functions
- (IBAction) toggleConsoleLog: (id) sender;
- (IBAction) clearConsole: (id) sender;
- (void) closeConsoleLogPanel: (NSNotification *) aNotification;

// Extras
- (void) checkOSVersion;
- (IBAction) checkForNewVersion: (id) sender;
- (IBAction) goToProductPage : (id) sender;
- (IBAction) goToFeedbackPage: (id) sender;
- (IBAction) openHelp: (id) sender;

@end
