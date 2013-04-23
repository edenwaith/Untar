//
//  UTController.m
//  Untar Version 1.3.2
//
//  Created by admin on August 2002.
//  Copyright (c) 2002 - 2007 Edenwaith. All rights reserved.

//	Untar Version 1.3.2 - Released February 2007
//  Untar Version 1.3.1 - Released 25. February 2006
//  Untar Version 1.3.0 - Released 10. March 2005
//  Untar Version 1.2.1 - Released 11. November 2003
//  Untar Version 1.2.0 - Released 19. October 2003
//  Untar Version 1.1.0 - Released 5. January 2003
//  Untar 1.0.x written by Chad Armstrong (chad@edenwaith.com) August - September 2002
//  http://www.edenwaith.com/downloads/untar.php

// Untar is a freeware application which uncompresses files in .7z, .tar, .tar.gz, .dmg.gz, 
// .svgz, .gz, .tgz, .tar.z, .z, .Z, .tar.Z, .taz, .tar.bz, .tar.bz2, .tbz, .tbz2, .bz,
// .bz2, .rar, and .zip formats.

// The following source code has been released under the GPL license.
// http://www.gnu.org/copyleft/gpl.html

// Saving & opening log info: http://www.macdevcenter.com/pub/a/mac/2001/06/01/cocoa.html?page=2
// Log: ~/Library/Logs/Untar.log

// GNU Tar: http://www.gnu.org/directory/tar.html
// GNU Tar (OS X): http://www.opensource.apple.com/darwinsource/10.4.8.ppc/gnutar-433.1/
// Bzip2 (OS X): http://www.opensource.apple.com/darwinsource/10.4.8.ppc/bzip2-9/
// Gnuzip (OS X): http://www.opensource.apple.com/darwinsource/10.4.8.ppc/gnuzip-22/

#import "UTController.h"

@implementation UTController


// =========================================================================
// (id)init
// -------------------------------------------------------------------------
// Allocate memory for program and initialize variables
// -------------------------------------------------------------------------
// Version: February 2006
// =========================================================================
- (id)init 
{
    self = [super init];
    
    [self checkOSVersion];
            
    fm					= [NSFileManager defaultManager];
    untar				= nil; 	// initialize the NSTask
    quitWhenFinished 	= NO;	// Initially, don't quit the program automatically
    beepWhenFinished 	= YES;	// Beep when the task is complete
    tempSuspendQuit  	= NO;	// Needed for multi-tasks (i.e. dmg.gz)
    pauseTaskRelease 	= NO;	// This needs to be NO, or resources won't be freed
    wasCanceled      	= NO;	// Variable set if a task was canceled
	directory			= [[NSMutableString alloc] init];

	// Perhaps keep this here for now, otherwise doneTarring gets called
    // too many times on repeat uses of Untar.
    [[NSNotificationCenter defaultCenter] addObserver:self 
            selector:@selector(doneTarring:) 
            name:NSTaskDidTerminateNotification 
            object:untar];
    
    return self;
}


// =========================================================================
// (void) delloc
// -------------------------------------------------------------------------
// Deallocate/free up memory used by Untar
// -------------------------------------------------------------------------
// Version: 8 February 2007
// =========================================================================
- (void)dealloc 
{
    untar = nil;
    
    [pipe release];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSTaskDidTerminateNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowWillCloseNotification object: consoleLogPanel];
    
	[directory dealloc];
    [untar dealloc];
    [super dealloc];
}


// =========================================================================
// (void) awakeFromNib
// -------------------------------------------------------------------------
// Need to make the controller the delegate of Window and File Owner in the
// IB for this to work.
// -------------------------------------------------------------------------
// Version: 28 January 2006 23:44
// =========================================================================
- (void)awakeFromNib 
{
    [[fileField window] makeKeyAndOrderFront:self];
    [[dirField window] makeKeyAndOrderFront:self];
    
    [spinningIndicator stopAnimation:self];
	
	// check preferences whether or not to open the Console Log at start up
	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"ConsoleLogOpen"] != nil)
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ConsoleLogOpen"] == YES)
		{
			[consoleLogMenu setState:NSOnState];
			[consoleLogPanel orderFront:self];
		}
	}

	// Load in console log data
	if ([fm fileExistsAtPath: [@"~/Library/Logs/Untar.log" stringByExpandingTildeInPath]] == YES)
	{
		NSString *consoleTextString = [[NSString alloc] initWithContentsOfFile:[@"~/Library/Logs/Untar.log" stringByExpandingTildeInPath]];
		
		[textView setEditable:YES];
		[textView insertText: consoleTextString];
		[textView setEditable:NO];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(closeConsoleLogPanel:)
		name:NSWindowWillCloseNotification
		object:consoleLogPanel];
}


// =========================================================================
// (BOOL) applicationShould....:(NSApplication *)theApplication
// -------------------------------------------------------------------------
// Terminate the program when the last window closes
// Need to connect File Owner to UTController as a delegate for this to
// work correctly
// =========================================================================
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication 
{
    return YES;
}


// =========================================================================
// (void) applicationDidFinishLaunching:(NSNotification *)
// -------------------------------------------------------------------------
// Stub method in case something useful should be put here.
// =========================================================================
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
  
}


// =========================================================================
// (void) applicationWillTerminate:(NSNotification *)aNotification
// -------------------------------------------------------------------------
// Called when the application is terminating.  Put any clean up code here.
// -------------------------------------------------------------------------
// Created: 21 January 2006 23:23
// Version: 21 January 2006 23:23
// =========================================================================
- (void) applicationWillTerminate:(NSNotification *)aNotification 
{
	// Save Console Log data to ~/Library/Logs/Untar.log
	[[textView string] writeToFile:[@"~/Library/Logs/Untar.log" stringByExpandingTildeInPath]	atomically:YES];
}

// =========================================================================
// (void) application:(NSApplication*) openFile:
// -------------------------------------------------------------------------
// This method is only called when a file is dragged-n-dropped onto the
// Untar icon.  This is useful since the actions are performed slightly
// different.
// -------------------------------------------------------------------------
// Version: 22 September 2003
// =========================================================================
- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    quitWhenFinished = YES;
    beepWhenFinished = NO;
    tempSuspendQuit  = YES;
    
    [fileField setStringValue: filename];    
    
    [self unTarIt];

    return NO;
}


// =========================================================================
// (IBAction) getFile: (id)sender
// -------------------------------------------------------------------------
// Get the name of the file to extract files from
// Check out http://lists.gnu.org/archive/html/gnustep-dev/2003-04/msg00103.html
// for case in/sensitive extensions.
// -------------------------------------------------------------------------
// Version: 25 January 2006 21:57
// =========================================================================
- (IBAction)getFile: (id)sender
{
    NSArray *fileTypes = [NSArray arrayWithObjects:@"tar", @"svgz", @"gz", @"tgz", @"z", @"Z", @"taz", @"tbz", @"tbz2", @"bz", @"bz2", @"zip", @"rar", @"7z", nil];
    NSOpenPanel *open_panel = [NSOpenPanel openPanel];
    int result = 0;
    
    [open_panel setCanChooseDirectories:NO];
    
    // NSHomeDirectory() can be used instead of the first nil (for the directory
    // path) to set the default directory to be the home directory.  Having
    // the path set to nil opens to the last opened directory.
    result = [open_panel runModalForDirectory:nil file:nil types:fileTypes];
    
    if (result == NSOKButton) 
    {
        [fileField setStringValue: [open_panel filename]];
    }    
}


// =========================================================================
// (IBAction) getDir: (id)sender
// -------------------------------------------------------------------------
// Use the NSOpenPanel to retrieve the name of the directory to download
// the extracted files to.  If no directory is specified, the directory
// in which the compressed file is in, is where the files will be saved
// about 'filename':
// -------------------------------------------------------------------------
// Version: 3 January 2005 21:30
// =========================================================================
- (IBAction)getDir: (id)sender 
{
    NSOpenPanel *dir_panel = [NSOpenPanel openPanel];
    int result = 0;
    
    // choose only directories, not files
    [dir_panel setCanChooseDirectories:YES];
    [dir_panel setCanChooseFiles:NO];

    // NSHomeDirectory()
    result = [dir_panel runModalForDirectory:nil file:nil types:nil];

    if (result == NSOKButton) 
    {
        [dirField setStringValue: [dir_panel filename]];
    }
}


// =========================================================================
// (IBAction) uncompress: (id)sender
// -------------------------------------------------------------------------
// Check to see if the user has selected an appropriate file to uncompress,
// and if so, then call the unTarIt method to uncompress the file and
// extract the files
// -------------------------------------------------------------------------
// Version: 2 December 2007 14:13
// =========================================================================
- (IBAction)uncompress: (id)sender 
{
    if ( [[UTButton title] isEqual: NSLocalizedString(@"Untar", nil)] )
    {

        if ([[fileField stringValue] isEqual: @""] == YES) // no file was selected
        {
            NSBeep();
			NSRunAlertPanel(NSLocalizedString(@"EmptyField", nil),
			NSLocalizedString(@"SelectFile", nil), NSLocalizedString(@"OK", nil), 
			nil, nil);
        }   
        else
        {
            [self unTarIt];
        }
    
    }
    else if ( [[UTButton title] isEqual: NSLocalizedString(@"Cancel", nil)] )
    {
        [untar terminate];
        
        wasCanceled = YES;
    }
}


// =========================================================================
// (IBAction) cancelExtraction : (id)sender
// -------------------------------------------------------------------------
// This is called when the Cancel button is pressed on the drop down
// extraction sheet.
// -------------------------------------------------------------------------
// Created: 14. January 2004
// Version: 14. January 2004
// =========================================================================
- (IBAction) cancelExtraction: (id)sender
{
    [untar terminate];
    wasCanceled = YES;
}


// =========================================================================
// (void) unTarIt
// -------------------------------------------------------------------------
// Set up the proper arguments to be made when uncompressing the file
// // Outputting messages to the log console http://cocoadevcentral.com/articles/000031.php
// Aaaaaarg!  No wonder I couldn't figure out why the output wasn't getting
// sent to the console log.  It sends to standard error, not standard output.
// http://www.redhat.com/docs/manuals/linux/RHL-7.3-Manual/getting-started-guide/s1-managing-compressing-archiving.html
// Experiment with gnutar instead of tar.  gnutar has the -j option which
// works with bzip2, so:
// tar -xjvf filename.tbz
// http://www.speculation.org/garrick/fcompress.txt
// Q: How do I uncompress foo.tar.bz2?
// A: bunzip2 foo.tar.bz2; tar x -f foo.tar
// A: bunzip2 < foo.tar.bz2 | tar x -f -
// A: tar x -jf foo.tar.bz2  (j tells tar to use bunzip2 ("b" was already taken))
// A: tar xjf foo.tar.bz2 
// A: tar xjvf foo.tar.bz2 
// ** different versions of tar may use j, I, or y
// -------------------------------------------------------------------------
// Version: 2 December 2007 14:00
// =========================================================================
- (void) unTarIt
{
    int status = 0;
    NSString *util_path;
    NSFileHandle *handle;
     
    pipe = [[NSPipe alloc] init];
    
    [progress_msg setStringValue: [self fileNameString: [[fileField stringValue] lastPathComponent]]];
	
	// Write file name out to console log
	[textView setEditable:YES];
	[textView insertText: @"==== "];
	[textView insertText: [[fileField stringValue] lastPathComponent]];
	[textView insertText: @" ====\n"];
	[textView setEditable:NO];
	
	// set the directory variable
	[self setWorkingDirectory: [self isArchive: [fileField stringValue]]];
    
	// 7Z -----------------------------------------------------------
	if ([[[fileField stringValue] pathExtension] isEqual: @"7z"])
	{
            util_path  = [ [NSBundle mainBundle] pathForResource:@"7za" ofType:@""];
            
			if (os_version <= 1020)
			{
				NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"MacOSRequiredToDecompress", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"10.3", @"7z");
				
				// Might need to reinitialize some variables here...
				[fileField setStringValue: @""];
				[dirField setStringValue: @""];
		
			}
            else if ([fm isExecutableFileAtPath: util_path] == YES)
            {
                untar = [[NSTask alloc] init];
                [untar setLaunchPath: util_path ];
            
				// ./7za e -o{/Users/admin/temp} -y ~/temp/Archive\ copy.7z
				[untar setArguments:[NSArray arrayWithObjects: @"x", [@"-o" stringByAppendingString: directory], @"-y",  [fileField stringValue], nil]];
        
				[untar setStandardError:pipe];
                handle = [pipe fileHandleForReading];

                [untar launch];
        
                [NSApp beginSheet: progressSheet modalForWindow: window
                modalDelegate:self didEndSelector:NULL contextInfo:nil];
                [spinningIndicator startAnimation: self];
        
                [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
            
            }
            else
            {   
                NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"UtilityNotFound", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"7za");
				            
                [fileField setStringValue: @""];
                [dirField setStringValue: @""];
                [progress_msg setStringValue: @""];
            }	
	}
    // TAR ----------------------------------------------------------
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"tar"])
    {

        untar = [[NSTask alloc] init];
        [untar setLaunchPath:@"/usr/bin/tar"];
            
        // Note: there is arrayWithObjects and arrayWithObject.  The first one
        // seems to need a 'nil' at the end to mark the end of the list
        
        // You DON'T need spaces after the -C or -xvf.  This is implied.  If spaces
        // are added, then this won't work, perhaps because it is looking for a file
        // named a space (' '), which doesn't make much sense.
            
        // if no directory was specified, then uncompress the files into the same directory
        // as the file
            
		[untar setArguments:[NSArray arrayWithObjects:@"-C", directory, @"-xvf", [fileField stringValue], nil]];
        
        // Tar (or gnutar) outputs to standard output for Mac OS 10.3, but to standard error
        // on Mac OS 10.1 and 10.2.
        [untar setStandardOutput:pipe];
        [untar setStandardError:pipe];
        handle = [pipe fileHandleForReading];
        
        [untar launch];
        
        [NSApp beginSheet: progressSheet modalForWindow: window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
        [spinningIndicator startAnimation: self];
        
        [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
      
    }
    // TGZ, SVGZ, GZ, Z ----------------------------------------------
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"gz"] || 
             [ [[fileField stringValue] pathExtension] isEqual: @"svgz"] || 
             [ [[fileField stringValue] pathExtension] isEqual: @"z"] || 
             [ [[fileField stringValue] pathExtension] isEqual: @"tgz"]) // check for .gz, tar.z, tar.gz, or .tgz files
    { 
        if([ [[fileField stringValue] pathExtension] isEqual: @"tgz"] || [ [[[fileField stringValue] stringByDeletingPathExtension] pathExtension] isEqual: @"tar"]) // file is tar.gz, tar.z, or .tgz
        {
            untar = [[NSTask alloc] init];
            [untar setLaunchPath:@"/usr/bin/tar"];
            
			[untar setArguments:[NSArray arrayWithObjects:@"-C", directory, @"-xvzf", [fileField stringValue], nil]];
            
            [untar setStandardOutput:pipe];
            [untar setStandardError:pipe];
            handle = [pipe fileHandleForReading];
            
            [untar launch];
            
            [NSApp beginSheet: progressSheet modalForWindow: window
            modalDelegate:self didEndSelector:NULL contextInfo:nil];
            [spinningIndicator startAnimation: self];
            
            [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
            
        }
        // SVGZ ------------------------------------------------------
        else if ( [[[fileField stringValue] pathExtension] isEqual: @"svgz"] )
        {
            NSString *renamedFile = [[NSString alloc] initWithString: [[[fileField stringValue]stringByDeletingPathExtension] stringByAppendingString: @".svg.gz"]];
            
            // rename .svgz to .svg.gz
            [fm movePath: [fileField stringValue] toPath: renamedFile handler: nil];
            
            // If the gunzipped already exists, then do not perform gunzip
            if ([fm fileExistsAtPath: [renamedFile stringByDeletingPathExtension]] == YES)
            {
                NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"FileAlreadyExists", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, [renamedFile stringByDeletingPathExtension]);
            }
            else
            {
                untar = [[NSTask alloc] init];
                [untar setLaunchPath:@"/usr/bin/gunzip"];
                
                [untar setArguments:[NSArray arrayWithObjects: @"-v", renamedFile, nil]];
                
                [untar setStandardError:pipe];
                handle = [pipe fileHandleForReading];
                
                [untar launch];
                
                [NSApp beginSheet: progressSheet modalForWindow: window
                modalDelegate:self didEndSelector:NULL contextInfo:nil];
                [spinningIndicator startAnimation: self];
                
                [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
            }
        }
        
        // GZ, Z, DMG.GZ ---------------------------------------------------
        else // otherwise, the file is something like dmg.gz, so just use gunzip
        {           
            NSString *currentDMGFile = [[NSString alloc] initWithString: [[fileField stringValue] stringByDeletingPathExtension]];
            
            // If the gunzipped already exists, then do not perform gunzip
            if ([fm fileExistsAtPath: currentDMGFile] == YES)
            {
                NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"FileAlreadyExists", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, currentDMGFile);
            }
             // uncompress and open dmg.gz files
            else if ( [[currentDMGFile pathExtension] isEqual: @"dmg"] )
            {
                if (tempSuspendQuit == YES)
                {
                    quitWhenFinished = NO;
					
					// Write an extra line break in the console log.
					[textView setEditable:YES];
					[textView insertText: @"\n"];
					[textView setEditable:NO];
                }
                
                pauseTaskRelease = YES;                
                beepWhenFinished = NO;
				[cancelButton setEnabled: NO];
				
                untar = [[NSTask alloc] init];
                [untar setLaunchPath:@"/usr/bin/gunzip"];
                
                [untar setArguments:[NSArray arrayWithObjects: @"-v", [fileField stringValue], nil]];
                
                [untar setStandardError:pipe];
                handle = [pipe fileHandleForReading];
				
                [untar launch];
                
                [NSApp beginSheet: progressSheet modalForWindow: window
                modalDelegate:self didEndSelector:NULL contextInfo:nil];
                [spinningIndicator startAnimation: self];
                
				if (tempSuspendQuit == NO)
                {
					// This seems to be preventing the application from closing when it needs to at times, so
					// only use this if Untar is not activated drag-n-drop.
					[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
				}
                        
				[untar waitUntilExit];
			
				status = [untar terminationStatus];
				
				[untar release];		// free up memeory from the task
				untar = nil;                         
			
				if ( 0 == status )
				{
					// For versions 10.2 and above
					if (os_version >= 1020)
					{
						[[NSWorkspace sharedWorkspace] openFile: currentDMGFile];
					}
					else // For version 10.1 and earlier
					{
						[[NSWorkspace sharedWorkspace] openFile: currentDMGFile withApplication:@"Disk Copy"];
					}
				}
					
                
                if (tempSuspendQuit == YES)
                {
                    [NSApp terminate: self];
                }
				else
				{
	                // reinitialize variables
					beepWhenFinished = YES;
					pauseTaskRelease = NO;
					wasCanceled      = NO;
					[cancelButton setEnabled: YES]; // this may need to be moved to the doneTarring method
				}
            
			} // end of DMG section
            else // otherwise, just .gz, or .z
            {
                [spinningIndicator startAnimation:self];
                untar = [[NSTask alloc] init];
                [untar setLaunchPath:@"/usr/bin/gunzip"];
            
                [untar setArguments:[NSArray arrayWithObjects: @"-v", [fileField stringValue], nil]];
				[untar setStandardError:pipe];
                handle = [pipe fileHandleForReading];
				
                [untar launch];
            
                [NSApp beginSheet:progressSheet modalForWindow: window
                modalDelegate:self didEndSelector:NULL contextInfo:nil];
                [spinningIndicator startAnimation: self];
				
				[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
            
            }
        }
    }
    // .taz code added 22. August 2003
    // Z, TAZ, TAR.Z ------------------------------------------------
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"Z"] || [[[fileField stringValue] pathExtension] isEqual: @"taz"])
    { 
        if ([ [[[fileField stringValue] stringByDeletingPathExtension] pathExtension] isEqual: @"tar"] || [[[fileField stringValue] pathExtension] isEqual: @"taz"]) // tar.Z or .taz
        {
            untar = [[NSTask alloc] init];
            [untar setLaunchPath:@"/usr/bin/tar"];
            
			[untar setArguments:[NSArray arrayWithObjects:@"-C", directory, @"-xvZf", [fileField stringValue], nil]];
            
            [untar setStandardError:pipe];
            handle = [pipe fileHandleForReading];

            [untar launch];
            
            [NSApp beginSheet: progressSheet modalForWindow: window
            modalDelegate:self didEndSelector:NULL contextInfo:nil];
            [spinningIndicator startAnimation: self];
            
            [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];            
        }
        else // this is for just a .Z file, not a .tar.Z or .taz or whatever...
        {
            untar = [[NSTask alloc] init];
            [untar setLaunchPath:@"/usr/bin/uncompress"];
            
            [untar setArguments:[NSArray arrayWithObjects: [fileField stringValue], nil]];
            
            [untar setStandardError:pipe];
            handle = [pipe fileHandleForReading];
            
            [untar launch];
            
            [NSApp beginSheet: progressSheet modalForWindow: window
            modalDelegate:self didEndSelector:NULL contextInfo:nil];
            [spinningIndicator startAnimation: self];
            
            [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
        }
    }
    // BZ, BZ2, TBZ  ------------------------------------------------
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"bz2"] || 
             [ [[fileField stringValue] pathExtension] isEqual: @"bz"]  ||
             [ [[fileField stringValue] pathExtension] isEqual: @"tbz"] ||
             [ [[fileField stringValue] pathExtension] isEqual: @"tbz2"] )
    {
		// Since pre-Jaguar (10.2) systems don't come with bzip2 included, this gnutar attempt at
		// uncompressing a tbz archive cannot be completed in one step.  Instead, just uncompress
		// a tbz file using bzip on Mac OS 10.1 systems.  Otherwise, go ahead as planned.
        if ( os_version >= 1020 &&
			 [ [[fileField stringValue] pathExtension] isEqual: @"tbz"] || 
             [ [[fileField stringValue] pathExtension] isEqual: @"tbz2"] ||
             [ [[[fileField stringValue] stringByDeletingPathExtension] pathExtension] isEqual: @"tar"] )
        {
			// gnutar in Mac OS 10.3 and later can properly uncompress tbz archives
			// The gnutar man page in 10.2 SAYS it has the option to uncompress tbz files, but it can't
			if ([fm isExecutableFileAtPath: @"/usr/bin/gnutar"] == YES && os_version >= 1030)
			{
				util_path = @"/usr/bin/gnutar";
			}
			else
			{
				util_path  = [ [NSBundle mainBundle] pathForResource:@"gnutar" ofType:@""];
			}
            
            if ([fm isExecutableFileAtPath: util_path] == YES)
            {
                untar = [[NSTask alloc] init];
                [untar setLaunchPath: util_path ];
            
				[untar setArguments:[NSArray arrayWithObjects:@"-C", directory, @"-xjvf", [fileField stringValue], nil]];
        
                [untar setStandardOutput:pipe];
                handle = [pipe fileHandleForReading];

                [untar launch];
        
                [NSApp beginSheet: progressSheet modalForWindow: window
                modalDelegate:self didEndSelector:NULL contextInfo:nil];
                [spinningIndicator startAnimation: self];
        
                [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
            
            }
            else
            {   
                NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"UtilityNotFound", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"gnutar");
            
                [fileField setStringValue: @""];
                [dirField setStringValue: @""];
                [progress_msg setStringValue: @""];
            }
        }
        else // otherwise, just a bz or bz2 compressed file
        {
			if ([fm isExecutableFileAtPath: @"/usr/bin/bzip2"] == YES)
			{
				util_path = @"/usr/bin/bzip2";
			}
			else
			{
				util_path  = [ [NSBundle mainBundle] pathForResource:@"bzip2" ofType:@""];
			}
			         
            if ([fm isExecutableFileAtPath: util_path] == YES)
            {
                // If the bunzipped file already exists, then do not perform bunzip (bzip2 -d)
                if ([fm fileExistsAtPath: [[fileField stringValue] stringByDeletingPathExtension]] == YES)
                {
                    NSBeep();
                    //NSRunAlertPanel(@"Cannot decompress", @"The file %@ already exists.", @"OK", nil, nil, [[fileField stringValue] stringByDeletingPathExtension]);
					NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
					NSLocalizedString(@"FileAlreadyExists", nil), NSLocalizedString(@"OK", nil), 
					nil, nil, [[fileField stringValue] stringByDeletingPathExtension]);	
                }
                else
                {
                    untar = [[NSTask alloc] init];
                    [untar setLaunchPath: util_path];
                
                    [untar setArguments:[NSArray arrayWithObjects: @"-dv", [fileField stringValue], nil]];
                    [untar setStandardOutput:pipe];
                    [untar setStandardError:pipe];
                    handle = [pipe fileHandleForReading];
                
                    [untar launch];
                
                    [NSApp beginSheet: progressSheet modalForWindow: window
                    modalDelegate:self didEndSelector:NULL contextInfo:nil];
                    [spinningIndicator startAnimation: self];
                
                    [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
                }
            }
            else
            {        
                NSBeep();
				NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"UtilityNotFound", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"bzip2");
            
                [fileField setStringValue: @""];
                [dirField setStringValue: @""];
                [progress_msg setStringValue: @""];
            }
        }
    }
    // RAR ---------------------------------------------------------
    // Go to http://www.rarlabs.com/ for more info on Rar
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"rar"])
    {
        util_path  = [ [NSBundle mainBundle] pathForResource:@"unrar" ofType:@""];
        
        if ([fm isExecutableFileAtPath: util_path] == YES)
        {

            untar = [[NSTask alloc] init];
            [untar setLaunchPath:util_path];
            
            // The directory at the end of the array is where the rar files are extracted
			[untar setArguments:[NSArray arrayWithObjects: @"e", [fileField stringValue], directory, nil]];
            
            [untar setStandardOutput:pipe];
            handle = [pipe fileHandleForReading];
            
            [untar launch];
            
            [NSApp beginSheet:progressSheet modalForWindow: window
			modalDelegate:self didEndSelector:NULL contextInfo:nil];
            [spinningIndicator startAnimation: self];
            
            [NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
        }
        else
        {
            NSBeep();
			NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"UtilityNotFound", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"unrar");
            
            [fileField setStringValue: @""];
            [dirField setStringValue: @""];
            [progress_msg setStringValue: @""];
        }
    }
    // ZIP ---------------------------------------------------------
    else if ([ [[fileField stringValue] pathExtension] isEqual: @"zip"])
    {
		if ([fm isExecutableFileAtPath: @"/usr/bin/unzip"] == YES)
		{
			util_path = @"/usr/bin/unzip";
		}
		else
		{
			util_path  = [ [NSBundle mainBundle] pathForResource:@"unzip" ofType:@""];
		}
        
        if ([fm isExecutableFileAtPath: util_path] == YES)
        {
            untar = [[NSTask alloc] init];
            [untar setLaunchPath:util_path];
			
			[untar setArguments:[NSArray arrayWithObjects: @"-d", directory, [fileField stringValue], @"-x", @"__MACOSX*", nil]];
        
            // zip's verbose output is to stdout
            [untar setStandardOutput:pipe];
            handle = [pipe fileHandleForReading];
        
            [untar launch];
            
            [NSApp beginSheet: progressSheet modalForWindow: window
            modalDelegate:self didEndSelector:NULL contextInfo:nil];
            [spinningIndicator startAnimation: self];
            
            [NSThread detachNewThreadSelector:@selector(outputData:) toTarget: self withObject: handle];
        
        }
        else
        {
            NSBeep();
			NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
				NSLocalizedString(@"UtilityNotFound", nil), NSLocalizedString(@"OK", nil), 
				nil, nil, @"unzip");
            
            [fileField setStringValue: @""];
            [dirField setStringValue: @""];
            [progress_msg setStringValue: @""];
        }
    }
    else	// File is not of a (recognized) supported type
    {
        // Do a check here to try and determine the file type if possible....someday.
        [spinningIndicator stopAnimation:self];

        NSBeep();
		NSRunAlertPanel(NSLocalizedString(@"CannotDecompress", nil),
		NSLocalizedString(@"FileAlreadyExists", nil), NSLocalizedString(@"OK", nil), 
		nil, nil, [fileField stringValue]);		
       
        [fileField setStringValue: @""];
        [dirField setStringValue: @""];
        [progress_msg setStringValue: @""];
    }

}


// =========================================================================
// (void) outputData: (NSFileHandle *) handle
// -------------------------------------------------------------------------
// Direct the output data sent from the task to the console log
// -------------------------------------------------------------------------
// Version: 15. January 2006
// =========================================================================
- (void) outputData: (NSFileHandle *) handle
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // ?
    NSData *data;
    
    while ([data=[handle availableData] length])
    {

        NSString *string = [[NSString alloc] initWithData:data encoding: NSASCIIStringEncoding];
        NSRange theEnd = NSMakeRange([[textView string] length], 0);
        
        [textView replaceCharactersInRange: theEnd withString: string];
        theEnd.location += [string length];
        [textView scrollRangeToVisible: theEnd];
        
        [string release];
    }
	
	[textView setEditable:YES];
	[textView insertText:[[NSString alloc]initWithString:@"\n"]];
	[textView setEditable:NO];
	
	// Save log data to file
	[ [textView string] writeToFile:[@"~/Library/Logs/Untar.log" stringByExpandingTildeInPath]	atomically:YES];
      
    [pool release];
}


// =========================================================================
// (NSString *) fileNameString
// -------------------------------------------------------------------------
// If a file name is too long,  the entire string will not print properly
// in the text field in the interface.  This checks if the file name exceeds
// the width of the progress_msg field, and if so, then it puts an ellipse
// (ellipsis) in the middle of the file name to abridge it.
// -------------------------------------------------------------------------
// Created: 2. April 2004 1:05
// Version: 9. February 2007 21:15
// =========================================================================
- (NSString *) fileNameString: (NSString *) filename
{
    NSMutableString *current_file_name = [[NSMutableString alloc] initWithString: [filename lastPathComponent]];
    int cfl_length = [current_file_name length];
    float cfl_len = 0.0;
    float field_width = [progress_msg bounds].size.width; // originally 167.0

    dict  = [ [NSMutableDictionary alloc] init];
    [dict setObject:[NSFont fontWithName:@"Lucida Grande" size:13.0] forKey:NSFontAttributeName];
    cfl_len = [current_file_name sizeWithAttributes:dict].width;
    
    if (cfl_len > field_width)
    {
		
        [current_file_name replaceCharactersInRange: NSMakeRange(cfl_length-10, 3) withString:@"..."];
        
        while (cfl_len > field_width)
        {
            [current_file_name deleteCharactersInRange: NSMakeRange(cfl_length-11, 1)];
            cfl_length = [current_file_name length];
            cfl_len = [current_file_name sizeWithAttributes:dict].width;
        }
		
		// Occasionally the last letter of the archive name would be clipped off, so
		// this is called to trim off one more character to make sure it fits OK.
		[current_file_name deleteCharactersInRange: NSMakeRange(cfl_length-11, 1)];
        
        [dict release];
        
        return (NSString *)current_file_name;
    }
    else
    {
        return (NSString *)current_file_name;
        
        [dict release];
    }
}


// =========================================================================
// (NSString *) fileNameWithoutExtension: (NSString *) filename
// -------------------------------------------------------------------------
// Return the name of the file without the file extension
// Archive.tar.gz would return "Archive"
// -------------------------------------------------------------------------
// Created: 6 February 2007 20:38
// Version: 6 February 2007 20:38
// =========================================================================
- (NSString *) fileNameWithoutExtension: (NSString *) filename
{
	NSArray *fileTypes = [NSArray arrayWithObjects:@"tar", @"svgz", @"gz", @"tgz", @"z", @"Z", @"taz", @"tbz", @"tbz2", @"bz", @"bz2", @"zip", @"rar", @"7z", nil];

	if ([fileTypes containsObject: [filename pathExtension]] == NO)
	{
		return (filename);
	}
	else
	{
		return ([self fileNameWithoutExtension: [filename stringByDeletingPathExtension]]);
	}
}


// =========================================================================
// - (void) setWorkingDirectory: (BOOL) isArchive
// -------------------------------------------------------------------------
// Set the working directory where files will be extracted to when an
// archive is opened.
// -------------------------------------------------------------------------
// Created: 8 February 2007 22:14
// Version: 10 February 2007 21:28
// =========================================================================
- (void) setWorkingDirectory: (BOOL) isArchive
{
	BOOL isDir = YES;
	
	if (isArchive == YES)
	{
		if ([[dirField stringValue] isEqual: @""] == YES)
		{
			[directory setString: [[ [[fileField stringValue] stringByDeletingLastPathComponent] stringByAppendingString:@"/"] stringByAppendingString:[self fileNameWithoutExtension: [[fileField stringValue] lastPathComponent]]] ];
		}
		else
		{
			[directory setString: [[ [dirField stringValue] stringByAppendingString:@"/"] stringByAppendingString:[self fileNameWithoutExtension: [[fileField stringValue] lastPathComponent]]] ];
		}
		
		// Create the working directory if it does not already exist.
		if ( ![fm fileExistsAtPath: directory isDirectory:&isDir] && isDir )
		{
			[fm createDirectoryAtPath:directory attributes:nil];
		}
	}
	else // just compressed files (i.e. .gz, .svgz, .bz)
	{	// This is an arbitrary value since compressed files normally wouldn't make use of "directory"
		[directory setString: [[fileField stringValue] stringByDeletingLastPathComponent]];
	}
	
}


// =========================================================================
// - (BOOL) isArchive
// -------------------------------------------------------------------------
// Check if a file is an archive (tar, tar.gz, rar, zip, 7z, tbz, etc.) or
// if it is just a compressed file.
// -------------------------------------------------------------------------
// Created: 10 February 2007 21:29
// Version: 10 February 2007 21:29
// =========================================================================
- (BOOL) isArchive: (NSString *) filename
{
	NSArray *compressedFileExtensions = [NSArray arrayWithObjects: @"svgz", @"gz", @"z", @"Z", @"bz", @"bz2", nil];
	
	if ([compressedFileExtensions containsObject: [filename pathExtension]] &&
		[[[filename stringByDeletingPathExtension] pathExtension] isEqual: @"tar"] == NO)
	{
		return (NO);
	}
	else
	{
		return (YES);
	}
}


// =========================================================================
// (void)doneTarring: (NSNotification *)aNotification
// -------------------------------------------------------------------------
// This file is called once the tar NSTask is complete
// -------------------------------------------------------------------------
// Version: 16 February 2007
// =========================================================================
- (void)doneTarring:(NSNotification *)aNotification 
{
    NSMutableString *open_dir = [[NSMutableString alloc] init];

    if ([[dirField stringValue] isEqualToString: @""])
    {
        [open_dir setString: [[fileField stringValue] stringByDeletingLastPathComponent]];
    }
    else
    {
        [open_dir setString: [dirField stringValue]];
    }

    [fileField setStringValue: @""];
    [dirField setStringValue: @""];
    [progress_msg setStringValue: @""];
    
    [UTButton setTitle: @"Untar"];
    [UTButton setEnabled: YES]; 	// re-enable the Untar button
    
    [spinningIndicator stopAnimation: self];
    [progressSheet orderOut:nil];
    [NSApp endSheet: progressSheet];

    // The NSTask untar's resources are released here for most cases
    // except when there is more than one process to be run, such as
    // with a dmg.gz file.  Otherwise, Disk Copy will not always run
    // if Untar's resources are released here.    
    if (pauseTaskRelease == NO)
    {
        [untar release];		// free up memeory from the task
        untar = nil; 
    }
   
    // Need to reinitialize variables after a task has been completed.
    // Otherwise, odd messages will appear (such as Untar has been canceled),
    // or it won't bing when necessary.   
    if (wasCanceled == YES)
    {
        NSBeep();
		NSRunAlertPanel(NSLocalizedString(@"UntarCanceled", nil),
		NSLocalizedString(@"UntarCanceledMsg", nil), NSLocalizedString(@"OK", nil), nil, nil);
		
        beepWhenFinished = YES;
        tempSuspendQuit  = NO;
        pauseTaskRelease = NO;
        wasCanceled      = NO;
    }
    else if (beepWhenFinished == YES)
    {
        NSBeep();
		NSRunAlertPanel(NSLocalizedString(@"UntarComplete", nil),
		NSLocalizedString(@"UntarCompleteMsg", nil), NSLocalizedString(@"OK", nil), nil, nil);
        
        beepWhenFinished = YES;
        tempSuspendQuit  = NO;
        pauseTaskRelease = NO;
        wasCanceled      = NO;
        
        [[NSWorkspace sharedWorkspace] selectFile: nil inFileViewerRootedAtPath: directory];
    }

    if (quitWhenFinished == YES)
    {
        NSBeep();
        [NSApp terminate:self];
    }

}


// =========================================================================
// (IBAction) toggleConsoleLog: (id) sender
// -------------------------------------------------------------------------
// Set the state to be either checked or unchecked and make the console
// log appear or disappear.
// -------------------------------------------------------------------------
// Created: 26. December 2004 23:00
// Version: 28. December 2004 19:09
// =========================================================================
- (IBAction) toggleConsoleLog: (id) sender
{
    if ([consoleLogMenu state] == NSOffState)
    {
        [consoleLogMenu setState:NSOnState];
        [consoleLogPanel orderFront:self];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey: @"ConsoleLogOpen"];
    }
    else
    {
        [consoleLogMenu setState:NSOffState];
        [consoleLogPanel orderOut:self];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey: @"ConsoleLogOpen"];
    }
}


// =========================================================================
// (void) clearConsole: (id) sender
// -------------------------------------------------------------------------
// Clear the information from the Console Log
// -------------------------------------------------------------------------
// Created: 10. October 2004 21:42
// Version: 10. October 2004 21:42
// =========================================================================
- (IBAction) clearConsole: (id) sender
{
    NSRange theEnd = NSMakeRange(0, [[textView string] length]);

    [textView replaceCharactersInRange: theEnd withString: @""];
    theEnd.location = 0;
    [textView scrollRangeToVisible: theEnd];
}


// =========================================================================
// (void) closeConsoleLogPanel: (NSNotification *) aNotification
// -------------------------------------------------------------------------
// When the console log panel has closed, this notification sets the
// consoleLogMenu to be in an off state (no check mark next to it)
// -------------------------------------------------------------------------
// Created: 28. December 2004 21:45
// Version: 28. December 2004 21:45
// =========================================================================
- (void) closeConsoleLogPanel: (NSNotification *) aNotification
{
    [consoleLogMenu setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey: @"ConsoleLogOpen"];
}


// =========================================================================
// (void) checkOSVersion
// -------------------------------------------------------------------------
// Check for the Mac OS version for Mac OS 10.0 through 10.4
// Unused system info code:
// NSString *aString = [[NSProcessInfo processInfo] operatingSystemVersionString];
// NSLog(@"Version: %@", aString);
// Other ways to check for the version of Mac OS X can be found at
// http://www.cocoadev.com/index.pl?DeterminingOSVersion
// http://developer.apple.com/releasenotes/Cocoa/AppKit.html
// -------------------------------------------------------------------------
// Created: 22. September 2004 19:12
// Version: 25. February 2006 15:53
// =========================================================================
- (void) checkOSVersion
{
    if ( floor(NSAppKitVersionNumber) <= 577 )
    {
        os_version = 1000;
    }
    else if ( floor(NSAppKitVersionNumber) <= 620 )
    {
        os_version = 1010;
    }
    else if ( floor(NSAppKitVersionNumber) <= 663)
    {
        os_version = 1020;
    }
    else if ( floor(NSAppKitVersionNumber) <= 743) 
    {
        os_version = 1030;
    }
	else
	{
        os_version = 1040;
    }
}


// =========================================================================
// (IBAction) checkForNewVersion: (id) sender
// -------------------------------------------------------------------------
// Added some new code to check if there is no network connection present.
// This resulted when the network went down at my house.  I learned
// something, but I still want my internet!  Screw MTV!  I want the Internet!
// CFBundleShortVersionString is the Short Version number (set in Target)
// CFBundleVersion can also be used to get an application's other version
// number (i.e v563).
// -------------------------------------------------------------------------
// Created: 5. March 2004 17:59
// Version: 16 February 2007
// =========================================================================
- (IBAction) checkForNewVersion: (id) sender
{
    NSString *currentVersionNumber = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSDictionary *productVersionDict = [NSDictionary dictionaryWithContentsOfURL: [NSURL URLWithString:@"http://www.edenwaith.com/version.xml"]];
    NSString *latestVersionNumber = [productVersionDict valueForKey:@"Untar"];
    int button = 0;

    if ( latestVersionNumber == nil )
    {
        NSBeep();
		NSRunAlertPanel(NSLocalizedString(@"UpdateFailure", nil),
		NSLocalizedString(@"UpdateFailureMsg", nil), NSLocalizedString(@"OK", nil), nil, nil);
    }
    else if ( [latestVersionNumber isEqualTo: currentVersionNumber] )
    {
		NSRunAlertPanel(NSLocalizedString(@"SoftwareUpToDate", nil),
		NSLocalizedString(@"RecentVersionMsg", nil), NSLocalizedString(@"OK", nil), nil, nil);
    }
    else
    {
		button = NSRunAlertPanel(NSLocalizedString(@"NewVersionAvailable", nil),
		NSLocalizedString(@"NewVersionAvailableMsg", nil), NSLocalizedString(@"Download", nil), NSLocalizedString(@"Cancel", nil), NSLocalizedString(@"MoreInfo", nil), latestVersionNumber);
        
        if (NSOKButton == button) // Download
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/downloads/untar.php"]];
        }
        else if (NSAlertOtherReturn == button) // More Info
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/products/untar/index.php"]];
        }
        
    }
}


// =========================================================================
// (IBAction) goToProductPage: (id) sender
// -------------------------------------------------------------------------
// Open a web browser to go to the product web page
// -------------------------------------------------------------------------
// Created: 5. March 2004 17:59
// Version: 5. March 2004 17:59
// =========================================================================
- (IBAction) goToProductPage: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/products/untar/"]];
}


// =========================================================================
// (IBAction) goToFeedbackPage: (id) sender
// -------------------------------------------------------------------------
// Open a web browser to go to the product feedback web page
// -------------------------------------------------------------------------
// Created: 5. March 2004 17:59
// Version: 5. March 2004 17:59
// =========================================================================
- (IBAction) goToFeedbackPage: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"mailto:support@edenwaith.com?subject=Untar%20Feedback"]];
}


// =========================================================================
// (IBAction) openHelp: (id) sender
// -------------------------------------------------------------------------
// The Help system contents are too large for Mac OS 10.1's Help Viewer to
// handle, so a web browser is opened to view the Help files for Mac OS 10.1
// Open with a web browser with pre-Panther systems due to the new style 
// for the Help files used.
// -------------------------------------------------------------------------
// Created: 31. January 2005 21:10
// Version: 3. January 2006 22:32
// =========================================================================
- (IBAction) openHelp: (id) sender
{
    if (os_version >= 1020)
    {    
        [NSApp showHelp: self];
    }
    else
    {
        [[NSWorkspace sharedWorkspace] openURL: [NSURL fileURLWithPath:[[[NSBundle mainBundle] pathForResource:@"Untar Help" ofType:@""]  stringByAppendingString: @"/index.html"] ] ];
    }
}

@end
