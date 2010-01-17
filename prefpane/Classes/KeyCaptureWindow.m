#import "KeyCaptureWindow.h"

#import "KeyRemapEntry.h"
#import "KeyCombo.h"
#import "KeyCodeTransformer.h"
#import "WindowShaker.h"

@interface KeyCaptureWindow ()
-(BOOL)isValidModifier:(unsigned int)modifier;
-(int)countFlags:(unsigned int)currentFlags;
-(void)addModifierKeyWithKeyCode:(unsigned int)keyCode toArray:(NSMutableArray*)array;
-(void)removeModifierKeyWithKeyCode:(unsigned int)keyCode fromArray:(NSMutableArray*)array;
-(void)assignNewComboWithModifiers:(unsigned int)modifiers keyCode:(int)keyCode;
-(void)displayDefaultMessage;
-(void)displayFromMessage;
-(void)displayToMessage;
-(void)displaySameShortcutMessage;
-(void)displayRemapExists;
@end


@implementation KeyCaptureWindow

@synthesize statusLabel;
@synthesize mapFrom;
@synthesize mapTo;

-(void)awakeFromNib
{
  newRemapEntry = [[KeyRemapEntry alloc] init];
  remapFromModifierKeys = [[NSMutableArray alloc] init];
  remapToModifierKeys = [[NSMutableArray alloc] init];
  [self displayDefaultMessage];
  [acceptButton setEnabled:NO];
}

-(void)clearFields
{
  [mapFrom setStringValue:@""];
  [mapTo setStringValue:@""];
}

-(void)textFieldFocusChanged:(NSTextField*)textField
{
  if(currentFocus != mapFrom && textField == mapFrom)
  {
    [newRemapEntry setRemapFrom:nil];
    fromRemapSet = NO;
    [self displayFromMessage];
  }
  else if(currentFocus != mapTo && textField == mapTo)
  {
    [newRemapEntry setRemapTo:nil];
    toRemapSet = NO;
    [self displayToMessage];
  }
  [textField setStringValue:@" "];
  currentFocus = textField;
}

-(void)flagsChanged:(NSEvent *)event
{
  if(![self isValidModifier:[event modifierFlags]]) return;
  unsigned int newFlagCount = [self countFlags:[event modifierFlags]];
  
  if(previousFlagCount > newFlagCount)
  {
    if(previousFlagCount == 1)
    {
     [self assignNewComboWithModifiers:previousModifierFlags keyCode:[event keyCode]];
      previousFlagCount = 0;
      previousModifierFlags = 0;
    }
    else
    {
      if(currentFocus == mapFrom)
        [self removeModifierKeyWithKeyCode:[event keyCode] fromArray:remapFromModifierKeys];
      else
        [self removeModifierKeyWithKeyCode:[event keyCode] fromArray:remapToModifierKeys];
    }
  }
  else
  {
    if(currentFocus == mapFrom)
      [self addModifierKeyWithKeyCode:[event keyCode] toArray:remapFromModifierKeys];
    else
      [self addModifierKeyWithKeyCode:[event keyCode] toArray:remapToModifierKeys];
  }
  
  [currentFocus setStringValue:[KeyCodeTransformer stringRepresentationForModifiers:[event modifierFlags]]];
  
  previousFlagCount = newFlagCount;
  previousModifierFlags = [event modifierFlags];
}
-(BOOL)isValidModifier:(unsigned int)modifier
{
  return ((!(modifier & NSFunctionKeyMask)) &&
          ((modifier & NSShiftKeyMask) ||
          (modifier & NSControlKeyMask) ||
          (modifier & NSAlternateKeyMask) ||
          (modifier & NSCommandKeyMask) ||
          (modifier & (1<<8))));
}
-(int)countFlags:(unsigned int)currentFlags
{
  int retval = 0;
  if(currentFlags & NSShiftKeyMask) retval++;
  if(currentFlags & NSControlKeyMask) retval++;
  if(currentFlags & NSAlternateKeyMask) retval++;
  if(currentFlags & NSCommandKeyMask) retval++;
  return retval;
}
-(void)addModifierKeyWithKeyCode:(unsigned int)keyCode toArray:(NSMutableArray*)array
{
  KeyModifier* newModifier = [[[KeyModifier alloc] initWithModifierKey:keyCode 
                                                           keyLocation:[KeyCodeTransformer locationForKeyCode:keyCode]] autorelease];
  [array addObject:newModifier];
  
}
-(void)removeModifierKeyWithKeyCode:(unsigned int)keyCode fromArray:(NSMutableArray*)array
{
  for(KeyModifier* modifier in array)
  {
    if([modifier modifierKey] == keyCode)
      [array removeObject:modifier];
    break;
  }
}

-(void)keyDown:(NSEvent*)event
{
  [self assignNewComboWithModifiers:[event modifierFlags] keyCode:[event keyCode]];
}
-(void)assignNewComboWithModifiers:(unsigned int)modifierFlags keyCode:(int)keyCode
{
  KeyCombo* newCombo = nil; 
  NSString* comboStringRepresentation = nil;
  
  BOOL success = NO;
  
  if(currentFocus == nil) return;
  
  if(currentFocus == mapFrom)
  {
    newCombo = [[[KeyCombo alloc] initWithModifierKeys:remapFromModifierKeys
                                         modifierFlags:modifierFlags
                                               keyCode:keyCode] autorelease];
    [remapFromModifierKeys release];
    remapFromModifierKeys = [[NSMutableArray alloc] init];
    
    if(![[newRemapEntry remapTo] isEqualToCombo:newCombo])
    {
      [newRemapEntry setRemapFrom:newCombo];
      fromRemapSet = YES;
      success = YES;
    }
  }
  else
  {
    newCombo = [[[KeyCombo alloc] initWithModifierKeys:remapToModifierKeys
                                         modifierFlags:modifierFlags
                                               keyCode:keyCode] autorelease];
    [remapToModifierKeys release];
    remapToModifierKeys = [[NSMutableArray alloc] init];
    
    if(![[newRemapEntry remapFrom] isEqualToCombo:newCombo])
    {
      [newRemapEntry setRemapTo:newCombo];
      toRemapSet = YES;
      success = YES;
    }
  }
  
  comboStringRepresentation = [KeyCodeTransformer stringRepresentationForKeyCombo:newCombo];
  if(!success)
  {
    [self displaySameShortcutMessage];
    [WindowShaker shakeWindow:self];
    comboStringRepresentation = @"";
    success = NO;    
  }
  [currentFocus setStringValue:comboStringRepresentation];
  currentFocus = nil;
  previousFlagCount = 0;
  previousModifierFlags = 0; 
  
  if(success)
  {
    [self displayDefaultMessage];
    if(fromRemapSet && toRemapSet)
      [acceptButton setEnabled:YES];
  }
}

-(IBAction)acceptButtonClicked:(NSButton*)sender
{
  if(fromRemapSet && toRemapSet)
  {
    if([[self delegate] capturePanelCanAddNewEntry:newRemapEntry])
    {
      [[self delegate] capturePanelAddNewEntry:newRemapEntry];
      [newRemapEntry release];
      newRemapEntry = [[KeyRemapEntry alloc] init];
      [NSApp endSheet:self returnCode:NSOKButton];
    }
    else
    {
      [WindowShaker shakeWindow:self];
      [self displayRemapExists];
    }
  }
}
-(IBAction)cancelButtonClicked:(NSButton*)sender
{
  [NSApp endSheet:self returnCode:NSCancelButton];
}

-(void)displayDefaultMessage
{
  [statusLabel setStringValue:@"Click in a text field to begin capturing."];
}
-(void)displayFromMessage
{
  [statusLabel setStringValue:@"Capturing shortcut to map from."];
}
-(void)displayToMessage
{
  [statusLabel setStringValue:@"Capturing shortcut to map to."];
}
-(void)displaySameShortcutMessage
{
  [statusLabel setStringValue:@"You may not assign a shortcut to itself."];
}
-(void)displayRemapExists
{
  [statusLabel setStringValue:@"This remap already exists."];
}

@end