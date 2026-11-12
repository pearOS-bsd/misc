# Build and run the standalone behaviour tests for the decompiled AppKit classes.
# Foundation only — no AppKit linked, so our reimplemented classes are the ones
# under test. Works with clang on macOS and with clang+libobjc2+gnustep-base on
# FreeBSD (override FOUNDATION_LDFLAGS and, if needed, OBJCFLAGS there).

CC ?= clang
OBJCFLAGS ?= -fobjc-arc -Wall -Wno-objc-root-class -g -O0
FOUNDATION_LDFLAGS ?= -framework Foundation -framework CoreGraphics

.PHONY: test clean
test: build/test_nsresponder build/test_nsview build/test_nscell build/test_nsactioncell build/test_nscontrol build/test_nsbutton build/test_nsmenuitem build/test_nsmenu build/test_nswindow build/test_nsapplication build/test_nstextfield build/test_nsbox build/test_nsstepper build/test_nsprogress build/test_nsslider build/test_nsimageview build/test_nslevelindicator build/test_nspopupbutton build/test_nstablecolumn build/test_nsscrollview build/test_nstabview build/test_nssplitview build/test_nscolorwell build/test_nssegmented build/test_nssearchfield build/test_nsdatepicker build/test_nsscroller build/test_nscombobox build/test_nstokenfield build/test_nsstackview build/test_nspathcontrol build/test_nstableview build/test_nsoutlineview build/test_nstoolbaritem build/test_nstoolbar build/test_nsstatusitem build/test_nsalert build/test_nspopover build/test_nsvisualeffectview build/test_nsstatusbar build/test_nsgesturerecognizer build/test_nsclickgesture build/test_nspangesture build/test_nsmaggesture build/test_nsrotationgesture build/test_nspressgesture build/test_nssound build/test_nspanel build/test_nssavepanel build/test_nsopenpanel build/test_nscursor build/test_nsscreen build/test_nsbezierpath build/test_nscolorspace build/test_nsparagraphstyle build/test_nscolor build/test_nsgradient build/test_nsshadow build/test_nstexttab build/test_nsfont build/test_nsfontdescriptor build/test_nstextlist build/test_nstextattachment build/test_nsappearance build/test_nstextcontainer build/test_nstrackingarea build/test_nsimage build/test_nsimagerep build/test_nsgraphicscontext build/test_nslayoutguide build/test_nscolorlist build/test_nsbitmapimagerep build/test_nspasteboard build/test_nsevent build/test_nstreenode build/test_nsviewcontroller build/test_nswindowcontroller build/test_nsdocument build/test_nsdocumentcontroller build/test_nssplitviewitem build/test_nscollectionviewitem build/test_nstabviewcontroller build/test_nssplitviewcontroller build/test_nsstoryboardsegue build/test_nstoolbaritemgroup build/test_nsdocktile build/test_nstitlebaraccessoryvc build/test_nsmenutoolbaritem build/test_nssearchtoolbaritem build/test_nspathcontrolitem build/test_nstouchbar build/test_nstouchbaritem build/test_nscustomtouchbaritem build/test_nscvlayoutattrs build/test_nsanimationcontext build/test_nshelpmanager build/test_nstextalternatives build/test_nsglyphinfo build/test_nsdraggingimagecomponent build/test_nsdraggingitem build/test_nspasteboarditem build/test_nsuicompressionoptions build/test_nsgridcell build/test_nsgridcolumn build/test_nsgridrow build/test_nsgridview build/test_nsrulermarker build/test_nscvupdateitem build/test_nsprintinfo build/test_nswindowtab build/test_nssymbolconfig build/test_nstablerowaction build/test_nstintconfiguration build/test_nsstringdrawingcontext build/test_nstextblock build/test_nstexttable build/test_nstexttableblock build/test_nssharingservice build/test_nsmenuitembadge build/test_nsaxcustomaction build/test_nsslideraccessorybehavior build/test_nspressureconfiguration build/test_nsswitch build/test_nsfontmanager build/test_nsaffinetransform build/test_nsanimation build/test_nsviewanimation build/test_nscollectionviewlayout build/test_nscollectionviewflowlayout build/test_nscollectionviewgridlayout build/test_nscontroller build/test_nsobjectcontroller build/test_nsarraycontroller build/test_nstreecontroller build/test_nsuserdefaultscontroller build/test_nsdictionarycontroller build/test_nsrunningapplication build/test_nsnib build/test_nscollectionviewtransitionlayout build/test_nstablecellview build/test_nssharingservicepicker build/test_nspredicateeditorrowtemplate build/test_nstextinputcontext build/test_nsstoryboard build/test_nsspellchecker build/test_nspagecontroller build/test_nsworkspaceopenconfiguration build/test_nsfilepromiseprovider build/test_nsfilepromisereceiver build/test_nscombobutton build/test_nsslideraccessory build/test_nstextinsertionindicator build/test_nsdraggingsession build/test_nspathcomponentcell build/test_nsstatusbarbutton build/test_nsformcell build/test_nsmatrix build/test_nsform build/test_nsscrubber build/test_nsscrubberselectionstyle build/test_nsscrubberlayoutattributes build/test_nsscrubberlayout build/test_nsscrubberflowlayout build/test_nsscrubberproportionallayout build/test_nsscrubberitemview build/test_nshapticfeedbackmanager build/test_nsaxcustomrotorsearchparameters build/test_nsaxcustomrotoritemresult build/test_nsaxcustomrotor build/test_nsaxcustomchooser build/test_nsbuttontouchbaritem build/test_nssteppertouchbaritem build/test_nsgrouptouchbaritem build/test_nspickertouchbaritem build/test_nsslidertouchbaritem build/test_nscolorsampler build/test_nscolorpickertouchbaritem build/test_nswindowtabgroup build/test_nspdfinfo build/test_nsspeechrecognizer build/test_nssharingservicepickertoolbaritem
	./build/test_nsresponder
	./build/test_nsview
	./build/test_nscell
	./build/test_nsactioncell
	./build/test_nscontrol
	./build/test_nsbutton
	./build/test_nsmenuitem
	./build/test_nsmenu
	./build/test_nswindow
	./build/test_nsapplication
	./build/test_nstextfield
	./build/test_nsbox
	./build/test_nsstepper
	./build/test_nsprogress
	./build/test_nsslider
	./build/test_nsimageview
	./build/test_nslevelindicator
	./build/test_nspopupbutton
	./build/test_nstablecolumn
	./build/test_nsscrollview
	./build/test_nstabview
	./build/test_nssplitview
	./build/test_nscolorwell
	./build/test_nssegmented
	./build/test_nssearchfield
	./build/test_nsdatepicker
	./build/test_nsscroller
	./build/test_nscombobox
	./build/test_nstokenfield
	./build/test_nsstackview
	./build/test_nspathcontrol
	./build/test_nstableview
	./build/test_nsoutlineview
	./build/test_nstoolbaritem
	./build/test_nstoolbar
	./build/test_nsstatusitem
	./build/test_nsalert
	./build/test_nspopover
	./build/test_nsvisualeffectview
	./build/test_nsstatusbar
	./build/test_nsgesturerecognizer
	./build/test_nsclickgesture
	./build/test_nspangesture
	./build/test_nsmaggesture
	./build/test_nsrotationgesture
	./build/test_nspressgesture
	./build/test_nssound
	./build/test_nspanel
	./build/test_nssavepanel
	./build/test_nsopenpanel
	./build/test_nscursor
	./build/test_nsscreen
	./build/test_nsbezierpath
	./build/test_nscolorspace
	./build/test_nsparagraphstyle
	./build/test_nscolor
	./build/test_nsgradient
	./build/test_nsshadow
	./build/test_nstexttab
	./build/test_nsfont
	./build/test_nsfontdescriptor
	./build/test_nstextlist
	./build/test_nstextattachment
	./build/test_nsappearance
	./build/test_nstextcontainer
	./build/test_nstrackingarea
	./build/test_nsimage
	./build/test_nsimagerep
	./build/test_nsgraphicscontext
	./build/test_nslayoutguide
	./build/test_nscolorlist
	./build/test_nsbitmapimagerep
	./build/test_nspasteboard
	./build/test_nsevent
	./build/test_nstreenode
	./build/test_nsviewcontroller
	./build/test_nswindowcontroller
	./build/test_nsdocument
	./build/test_nsdocumentcontroller
	./build/test_nssplitviewitem
	./build/test_nscollectionviewitem
	./build/test_nstabviewcontroller
	./build/test_nssplitviewcontroller
	./build/test_nsstoryboardsegue
	./build/test_nstoolbaritemgroup
	./build/test_nsdocktile
	./build/test_nstitlebaraccessoryvc
	./build/test_nsmenutoolbaritem
	./build/test_nssearchtoolbaritem
	./build/test_nspathcontrolitem
	./build/test_nstouchbar
	./build/test_nstouchbaritem
	./build/test_nscustomtouchbaritem
	./build/test_nscvlayoutattrs
	./build/test_nsanimationcontext
	./build/test_nshelpmanager
	./build/test_nstextalternatives
	./build/test_nsglyphinfo
	./build/test_nsdraggingimagecomponent
	./build/test_nsdraggingitem
	./build/test_nspasteboarditem
	./build/test_nsuicompressionoptions
	./build/test_nsgridcell
	./build/test_nsgridcolumn
	./build/test_nsgridrow
	./build/test_nsgridview
	./build/test_nsrulermarker
	./build/test_nscvupdateitem
	./build/test_nsprintinfo
	./build/test_nswindowtab
	./build/test_nssymbolconfig
	./build/test_nstablerowaction
	./build/test_nstintconfiguration
	./build/test_nsstringdrawingcontext
	./build/test_nstextblock
	./build/test_nstexttable
	./build/test_nstexttableblock
	./build/test_nssharingservice
	./build/test_nsmenuitembadge
	./build/test_nsaxcustomaction
	./build/test_nsslideraccessorybehavior
	./build/test_nspressureconfiguration
	./build/test_nsswitch
	./build/test_nsfontmanager
	./build/test_nsaffinetransform
	./build/test_nsanimation
	./build/test_nsviewanimation
	./build/test_nscollectionviewlayout
	./build/test_nscollectionviewflowlayout
	./build/test_nscollectionviewgridlayout
	./build/test_nscontroller
	./build/test_nsobjectcontroller
	./build/test_nsarraycontroller
	./build/test_nstreecontroller
	./build/test_nsuserdefaultscontroller
	./build/test_nsdictionarycontroller
	./build/test_nsrunningapplication
	./build/test_nsnib
	./build/test_nscollectionviewtransitionlayout
	./build/test_nstablecellview
	./build/test_nssharingservicepicker
	./build/test_nspredicateeditorrowtemplate
	./build/test_nstextinputcontext
	./build/test_nsstoryboard
	./build/test_nsspellchecker
	./build/test_nspagecontroller
	./build/test_nsworkspaceopenconfiguration
	./build/test_nsfilepromiseprovider
	./build/test_nsfilepromisereceiver
	./build/test_nscombobutton
	./build/test_nsslideraccessory
	./build/test_nstextinsertionindicator
	./build/test_nsdraggingsession
	./build/test_nspathcomponentcell
	./build/test_nsstatusbarbutton
	./build/test_nsformcell
	./build/test_nsmatrix
	./build/test_nsform
	./build/test_nsscrubber
	./build/test_nsscrubberselectionstyle
	./build/test_nsscrubberlayoutattributes
	./build/test_nsscrubberlayout
	./build/test_nsscrubberflowlayout
	./build/test_nsscrubberproportionallayout
	./build/test_nsscrubberitemview
	./build/test_nshapticfeedbackmanager
	./build/test_nsaxcustomrotorsearchparameters
	./build/test_nsaxcustomrotoritemresult
	./build/test_nsaxcustomrotor
	./build/test_nsaxcustomchooser
	./build/test_nsbuttontouchbaritem
	./build/test_nssteppertouchbaritem
	./build/test_nsgrouptouchbaritem
	./build/test_nspickertouchbaritem
	./build/test_nsslidertouchbaritem
	./build/test_nscolorsampler
	./build/test_nscolorpickertouchbaritem
	./build/test_nswindowtabgroup
	./build/test_nspdfinfo
	./build/test_nsspeechrecognizer
	./build/test_nssharingservicepickertoolbaritem

build/test_nsswitch: src/NSSwitch.m src/NSSwitch.h $(CONTROL_SRC) test/test_nsswitch.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSwitch.m $(CONTROL_SRC) test/test_nsswitch.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspressureconfiguration: src/NSPressureConfiguration.m src/NSPressureConfiguration.h test/test_nspressureconfiguration.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPressureConfiguration.m test/test_nspressureconfiguration.m $(FOUNDATION_LDFLAGS)

build/test_nsslideraccessorybehavior: src/NSSliderAccessoryBehavior.m src/NSSliderAccessoryBehavior.h test/test_nsslideraccessorybehavior.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSliderAccessoryBehavior.m test/test_nsslideraccessorybehavior.m $(FOUNDATION_LDFLAGS)

build/test_nsaxcustomaction: src/NSAccessibilityCustomAction.m src/NSAccessibilityCustomAction.h test/test_nsaccessibilitycustomaction.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAccessibilityCustomAction.m test/test_nsaccessibilitycustomaction.m $(FOUNDATION_LDFLAGS)

build/test_nsmenuitembadge: src/NSMenuItemBadge.m src/NSMenuItemBadge.h test/test_nsmenuitembadge.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMenuItemBadge.m test/test_nsmenuitembadge.m $(FOUNDATION_LDFLAGS)

build/test_nssharingservice: src/NSSharingService.m src/NSSharingService.h test/test_nssharingservice.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSharingService.m test/test_nssharingservice.m $(FOUNDATION_LDFLAGS)

build/test_nstexttableblock: src/NSTextTableBlock.m src/NSTextTableBlock.h src/NSTextTable.m src/NSTextBlock.m test/test_nstexttableblock.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextTableBlock.m src/NSTextTable.m src/NSTextBlock.m test/test_nstexttableblock.m $(FOUNDATION_LDFLAGS)

build/test_nstexttable: src/NSTextTable.m src/NSTextTable.h src/NSTextBlock.m test/test_nstexttable.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextTable.m src/NSTextBlock.m test/test_nstexttable.m $(FOUNDATION_LDFLAGS)

build/test_nstextblock: src/NSTextBlock.m src/NSTextBlock.h test/test_nstextblock.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextBlock.m test/test_nstextblock.m $(FOUNDATION_LDFLAGS)

build/test_nsstringdrawingcontext: src/NSStringDrawingContext.m src/NSStringDrawingContext.h test/test_nsstringdrawingcontext.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStringDrawingContext.m test/test_nsstringdrawingcontext.m $(FOUNDATION_LDFLAGS)

build/test_nstintconfiguration: src/NSTintConfiguration.m src/NSTintConfiguration.h test/test_nstintconfiguration.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTintConfiguration.m test/test_nstintconfiguration.m $(FOUNDATION_LDFLAGS)

build/test_nstablerowaction: src/NSTableViewRowAction.m src/NSTableViewRowAction.h test/test_nstableviewrowaction.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTableViewRowAction.m test/test_nstableviewrowaction.m $(FOUNDATION_LDFLAGS)

build/test_nssymbolconfig: src/NSImageSymbolConfiguration.m src/NSImageSymbolConfiguration.h test/test_nsimagesymbolconfiguration.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSImageSymbolConfiguration.m test/test_nsimagesymbolconfiguration.m $(FOUNDATION_LDFLAGS)

build/test_nswindowtab: src/NSWindowTab.m src/NSWindowTab.h test/test_nswindowtab.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSWindowTab.m test/test_nswindowtab.m $(FOUNDATION_LDFLAGS)

build/test_nsprintinfo: src/NSPrintInfo.m src/NSPrintInfo.h test/test_nsprintinfo.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPrintInfo.m test/test_nsprintinfo.m $(FOUNDATION_LDFLAGS)

build/test_nscvupdateitem: src/NSCollectionViewUpdateItem.m src/NSCollectionViewUpdateItem.h test/test_nscollectionviewupdateitem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewUpdateItem.m test/test_nscollectionviewupdateitem.m $(FOUNDATION_LDFLAGS)

build/test_nsrulermarker: src/NSRulerMarker.m src/NSRulerMarker.h test/test_nsrulermarker.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSRulerMarker.m test/test_nsrulermarker.m $(FOUNDATION_LDFLAGS)

build/test_nsgridview: src/NSGridView.m src/NSGridView.h src/NSGridRow.m src/NSGridColumn.m src/NSGridCell.m src/NSView.m src/NSResponder.m test/test_nsgridview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGridView.m src/NSGridRow.m src/NSGridColumn.m src/NSGridCell.m src/NSView.m src/NSResponder.m test/test_nsgridview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsgridrow: src/NSGridRow.m src/NSGridRow.h src/NSGridCell.m src/NSGridColumn.h test/test_nsgridrow.m src/NSView.m src/NSResponder.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGridRow.m src/NSGridCell.m src/NSView.m src/NSResponder.m test/test_nsgridrow.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsgridcolumn: src/NSGridColumn.m src/NSGridColumn.h src/NSGridCell.h test/test_nsgridcolumn.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGridColumn.m test/test_nsgridcolumn.m $(FOUNDATION_LDFLAGS)

build/test_nsgridcell: src/NSGridCell.m src/NSGridCell.h src/NSView.m src/NSResponder.m test/test_nsgridcell.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGridCell.m src/NSView.m src/NSResponder.m test/test_nsgridcell.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsuicompressionoptions: src/NSUserInterfaceCompressionOptions.m src/NSUserInterfaceCompressionOptions.h test/test_nsuicompressionoptions.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSUserInterfaceCompressionOptions.m test/test_nsuicompressionoptions.m $(FOUNDATION_LDFLAGS)

build/test_nspasteboarditem: src/NSPasteboardItem.m src/NSPasteboardItem.h test/test_nspasteboarditem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPasteboardItem.m test/test_nspasteboarditem.m $(FOUNDATION_LDFLAGS)

build/test_nsdraggingitem: src/NSDraggingItem.m src/NSDraggingItem.h src/NSDraggingImageComponent.m test/test_nsdraggingitem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDraggingItem.m src/NSDraggingImageComponent.m test/test_nsdraggingitem.m $(FOUNDATION_LDFLAGS)

build/test_nsdraggingimagecomponent: src/NSDraggingImageComponent.m src/NSDraggingImageComponent.h test/test_nsdraggingimagecomponent.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDraggingImageComponent.m test/test_nsdraggingimagecomponent.m $(FOUNDATION_LDFLAGS)

build/test_nsglyphinfo: src/NSGlyphInfo.m src/NSGlyphInfo.h test/test_nsglyphinfo.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGlyphInfo.m test/test_nsglyphinfo.m $(FOUNDATION_LDFLAGS)

build/test_nstextalternatives: src/NSTextAlternatives.m src/NSTextAlternatives.h test/test_nstextalternatives.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextAlternatives.m test/test_nstextalternatives.m $(FOUNDATION_LDFLAGS)

build/test_nshelpmanager: src/NSHelpManager.m src/NSHelpManager.h test/test_nshelpmanager.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSHelpManager.m test/test_nshelpmanager.m $(FOUNDATION_LDFLAGS)

build/test_nsanimationcontext: src/NSAnimationContext.m src/NSAnimationContext.h test/test_nsanimationcontext.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAnimationContext.m test/test_nsanimationcontext.m $(FOUNDATION_LDFLAGS)

build/test_nscvlayoutattrs: src/NSCollectionViewLayoutAttributes.m src/NSCollectionViewLayoutAttributes.h test/test_nscollectionviewlayoutattributes.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewlayoutattributes.m $(FOUNDATION_LDFLAGS)

build/test_nscustomtouchbaritem: src/NSCustomTouchBarItem.m src/NSCustomTouchBarItem.h src/NSTouchBarItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nscustomtouchbaritem.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCustomTouchBarItem.m src/NSTouchBarItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nscustomtouchbaritem.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstouchbaritem: src/NSTouchBarItem.m src/NSTouchBarItem.h test/test_nstouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTouchBarItem.m test/test_nstouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nstouchbar: src/NSTouchBar.m src/NSTouchBar.h test/test_nstouchbar.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTouchBar.m test/test_nstouchbar.m $(FOUNDATION_LDFLAGS)

build/test_nspathcontrolitem: src/NSPathControlItem.m src/NSPathControlItem.h test/test_nspathcontrolitem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPathControlItem.m test/test_nspathcontrolitem.m $(FOUNDATION_LDFLAGS)

build/test_nssearchtoolbaritem: src/NSSearchToolbarItem.m src/NSSearchToolbarItem.h src/NSToolbarItem.m test/test_nssearchtoolbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSearchToolbarItem.m src/NSToolbarItem.m test/test_nssearchtoolbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nsmenutoolbaritem: src/NSMenuToolbarItem.m src/NSMenuToolbarItem.h src/NSToolbarItem.m src/NSMenu.m src/NSMenuItem.m src/NSCell.m test/test_nsmenutoolbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMenuToolbarItem.m src/NSToolbarItem.m src/NSMenu.m src/NSMenuItem.m src/NSCell.m test/test_nsmenutoolbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nstitlebaraccessoryvc: src/NSTitlebarAccessoryViewController.m src/NSTitlebarAccessoryViewController.h src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nstitlebaraccessoryviewcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTitlebarAccessoryViewController.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nstitlebaraccessoryviewcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsdocktile: src/NSDockTile.m src/NSDockTile.h src/NSView.m src/NSResponder.m test/test_nsdocktile.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDockTile.m src/NSView.m src/NSResponder.m test/test_nsdocktile.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstoolbaritemgroup: src/NSToolbarItemGroup.m src/NSToolbarItemGroup.h src/NSToolbarItem.m test/test_nstoolbaritemgroup.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSToolbarItemGroup.m src/NSToolbarItem.m test/test_nstoolbaritemgroup.m $(FOUNDATION_LDFLAGS)

build/test_nsstoryboardsegue: src/NSStoryboardSegue.m src/NSStoryboardSegue.h test/test_nsstoryboardsegue.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStoryboardSegue.m test/test_nsstoryboardsegue.m $(FOUNDATION_LDFLAGS)

build/test_nssplitviewcontroller: src/NSSplitViewController.m src/NSSplitViewController.h src/NSSplitViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nssplitviewcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSplitViewController.m src/NSSplitViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nssplitviewcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstabviewcontroller: src/NSTabViewController.m src/NSTabViewController.h src/NSTabViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nstabviewcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTabViewController.m src/NSTabViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nstabviewcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscollectionviewitem: src/NSCollectionViewItem.m src/NSCollectionViewItem.h src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nscollectionviewitem.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nscollectionviewitem.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssplitviewitem: src/NSSplitViewItem.m src/NSSplitViewItem.h src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nssplitviewitem.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSplitViewItem.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nssplitviewitem.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsdocumentcontroller: src/NSDocumentController.m src/NSDocumentController.h src/NSDocument.m src/NSWindowController.m src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nsdocumentcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDocumentController.m src/NSDocument.m src/NSWindowController.m src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nsdocumentcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsdocument: src/NSDocument.m src/NSDocument.h src/NSWindowController.m src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nsdocument.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDocument.m src/NSWindowController.m src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nsdocument.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nswindowcontroller: src/NSWindowController.m src/NSWindowController.h src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nswindowcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSWindowController.m src/NSWindow.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nswindowcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsviewcontroller: src/NSViewController.m src/NSViewController.h src/NSView.m src/NSResponder.m test/test_nsviewcontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nsviewcontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstreenode: src/NSTreeNode.m src/NSTreeNode.h test/test_nstreenode.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTreeNode.m test/test_nstreenode.m $(FOUNDATION_LDFLAGS)

build/test_nsevent: src/NSEvent.m src/NSEvent.h test/test_nsevent.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSEvent.m test/test_nsevent.m $(FOUNDATION_LDFLAGS)

build/test_nspasteboard: src/NSPasteboard.m src/NSPasteboard.h test/test_nspasteboard.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPasteboard.m test/test_nspasteboard.m $(FOUNDATION_LDFLAGS)

build/test_nsbitmapimagerep: src/NSBitmapImageRep.m src/NSBitmapImageRep.h src/NSImageRep.m test/test_nsbitmapimagerep.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSBitmapImageRep.m src/NSImageRep.m test/test_nsbitmapimagerep.m $(FOUNDATION_LDFLAGS)

build/test_nscolorlist: src/NSColorList.m src/NSColorList.h src/NSColor.m src/NSColorSpace.m test/test_nscolorlist.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColorList.m src/NSColor.m src/NSColorSpace.m test/test_nscolorlist.m $(FOUNDATION_LDFLAGS)

build/test_nslayoutguide: src/NSLayoutGuide.m src/NSLayoutGuide.h test/test_nslayoutguide.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSLayoutGuide.m test/test_nslayoutguide.m $(FOUNDATION_LDFLAGS)

build/test_nsgraphicscontext: src/NSGraphicsContext.m src/NSGraphicsContext.h test/test_nsgraphicscontext.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGraphicsContext.m test/test_nsgraphicscontext.m $(FOUNDATION_LDFLAGS)

build/test_nsimagerep: src/NSImageRep.m src/NSImageRep.h src/NSImage.m src/NSImage.h test/test_nsimagerep.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSImageRep.m src/NSImage.m test/test_nsimagerep.m $(FOUNDATION_LDFLAGS)

build/test_nsimage: src/NSImage.m src/NSImage.h test/test_nsimage.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSImage.m test/test_nsimage.m $(FOUNDATION_LDFLAGS)

build/test_nstrackingarea: src/NSTrackingArea.m src/NSTrackingArea.h test/test_nstrackingarea.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTrackingArea.m test/test_nstrackingarea.m $(FOUNDATION_LDFLAGS)

build/test_nstextcontainer: src/NSTextContainer.m src/NSTextContainer.h src/NSParagraphStyle.h test/test_nstextcontainer.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextContainer.m test/test_nstextcontainer.m $(FOUNDATION_LDFLAGS)

build/test_nsappearance: src/NSAppearance.m src/NSAppearance.h test/test_nsappearance.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAppearance.m test/test_nsappearance.m $(FOUNDATION_LDFLAGS)

build/test_nstextattachment: src/NSTextAttachment.m src/NSTextAttachment.h test/test_nstextattachment.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextAttachment.m test/test_nstextattachment.m $(FOUNDATION_LDFLAGS)

build/test_nstextlist: src/NSTextList.m src/NSTextList.h test/test_nstextlist.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextList.m test/test_nstextlist.m $(FOUNDATION_LDFLAGS)

build/test_nsfontdescriptor: src/NSFontDescriptor.m src/NSFontDescriptor.h test/test_nsfontdescriptor.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFontDescriptor.m test/test_nsfontdescriptor.m $(FOUNDATION_LDFLAGS) -framework CoreText

build/test_nsfont: src/NSFont.m src/NSFont.h test/test_nsfont.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFont.m test/test_nsfont.m $(FOUNDATION_LDFLAGS) -framework CoreText

build/test_nstexttab: src/NSTextTab.m src/NSTextTab.h src/NSParagraphStyle.h test/test_nstexttab.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextTab.m test/test_nstexttab.m $(FOUNDATION_LDFLAGS)

build/test_nsshadow: src/NSShadow.m src/NSShadow.h src/NSColor.m src/NSColorSpace.m test/test_nsshadow.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSShadow.m src/NSColor.m src/NSColorSpace.m test/test_nsshadow.m $(FOUNDATION_LDFLAGS)

build/test_nsgradient: src/NSGradient.m src/NSGradient.h src/NSColor.m src/NSColorSpace.m test/test_nsgradient.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGradient.m src/NSColor.m src/NSColorSpace.m test/test_nsgradient.m $(FOUNDATION_LDFLAGS)

build/test_nscolor: src/NSColor.m src/NSColor.h src/NSColorSpace.m test/test_nscolor.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColor.m src/NSColorSpace.m test/test_nscolor.m $(FOUNDATION_LDFLAGS)

build/test_nsparagraphstyle: src/NSParagraphStyle.m src/NSParagraphStyle.h test/test_nsparagraphstyle.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSParagraphStyle.m test/test_nsparagraphstyle.m $(FOUNDATION_LDFLAGS)

build/test_nscolorspace: src/NSColorSpace.m src/NSColorSpace.h test/test_nscolorspace.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColorSpace.m test/test_nscolorspace.m $(FOUNDATION_LDFLAGS)

build/test_nsbezierpath: src/NSBezierPath.m src/NSBezierPath.h test/test_nsbezierpath.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSBezierPath.m test/test_nsbezierpath.m $(FOUNDATION_LDFLAGS)

build/test_nsscreen: src/NSScreen.m src/NSScreen.h test/test_nsscreen.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScreen.m test/test_nsscreen.m $(FOUNDATION_LDFLAGS)

build/test_nsslider: src/NSSlider.m src/NSSliderCell.m $(CONTROL_SRC) test/test_nsslider.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSlider.m src/NSSliderCell.m $(CONTROL_SRC) test/test_nsslider.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsprogress: src/NSProgressIndicator.m src/NSProgressIndicator.h src/NSView.m src/NSResponder.m test/test_nsprogress.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSProgressIndicator.m src/NSView.m src/NSResponder.m test/test_nsprogress.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsstepper: src/NSStepper.m src/NSStepperCell.m $(CONTROL_SRC) test/test_nsstepper.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStepper.m src/NSStepperCell.m $(CONTROL_SRC) test/test_nsstepper.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsbox: src/NSBox.m src/NSBox.h src/NSView.m src/NSResponder.m test/test_nsbox.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSBox.m src/NSView.m src/NSResponder.m test/test_nsbox.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstextfield: src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nstextfield.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nstextfield.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsapplication: src/NSApplication.m src/NSApplication.h src/NSResponder.m src/NSMenu.m src/NSMenuItem.m test/test_nsapplication.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSApplication.m src/NSResponder.m src/NSMenu.m src/NSMenuItem.m test/test_nsapplication.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nswindow: src/NSWindow.m src/NSWindow.h src/NSView.m src/NSResponder.m test/test_nswindow.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nswindow.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsmenu: src/NSMenu.m src/NSMenu.h src/NSMenuItem.m test/test_nsmenu.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMenu.m src/NSMenuItem.m test/test_nsmenu.m $(FOUNDATION_LDFLAGS)

build/test_nsmenuitem: src/NSMenuItem.m src/NSMenuItem.h src/NSCell.m test/test_nsmenuitem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMenuItem.m src/NSCell.m test/test_nsmenuitem.m $(FOUNDATION_LDFLAGS)

build/test_nsbutton: src/NSButton.m src/NSButtonCell.m $(CONTROL_SRC) test/test_nsbutton.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSButton.m src/NSButtonCell.m $(CONTROL_SRC) test/test_nsbutton.m test/stubs.m $(FOUNDATION_LDFLAGS)

CONTROL_SRC := src/NSControl.m src/NSView.m src/NSResponder.m src/NSCell.m src/NSActionCell.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m

build/test_nscontrol: $(CONTROL_SRC) src/NSControl.h test/test_nscontrol.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ $(CONTROL_SRC) test/test_nscontrol.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscell: src/NSCell.m src/NSCell.h test/test_nscell.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCell.m test/test_nscell.m $(FOUNDATION_LDFLAGS)

build/test_nsactioncell: src/NSActionCell.m src/NSActionCell.h src/NSCell.m src/NSCell.h test/test_nsactioncell.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSActionCell.m src/NSCell.m test/test_nsactioncell.m $(FOUNDATION_LDFLAGS)

build/test_nsresponder: src/NSResponder.m src/NSResponder.h test/test_nsresponder.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSResponder.m test/test_nsresponder.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsview: src/NSView.m src/NSView.h src/NSResponder.m src/NSResponder.h test/test_nsview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSView.m src/NSResponder.m test/test_nsview.m test/stubs.m $(FOUNDATION_LDFLAGS)

clean:
	rm -rf build

build/test_nsimageview: src/NSImageView.m src/NSImageCell.m $(CONTROL_SRC) test/test_nsimageview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSImageView.m src/NSImageCell.m $(CONTROL_SRC) test/test_nsimageview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nslevelindicator: src/NSLevelIndicator.m src/NSLevelIndicatorCell.m $(CONTROL_SRC) test/test_nslevelindicator.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSLevelIndicator.m src/NSLevelIndicatorCell.m $(CONTROL_SRC) test/test_nslevelindicator.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspopupbutton: src/NSPopUpButton.m src/NSPopUpButtonCell.m src/NSButton.m src/NSButtonCell.m src/NSMenu.m src/NSMenuItem.m $(CONTROL_SRC) test/test_nspopupbutton.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPopUpButton.m src/NSPopUpButtonCell.m src/NSButton.m src/NSButtonCell.m $(CONTROL_SRC) test/test_nspopupbutton.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstablecolumn: src/NSTableColumn.m src/NSTableColumn.h test/test_nstablecolumn.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTableColumn.m test/test_nstablecolumn.m $(FOUNDATION_LDFLAGS)

build/test_nsscrollview: src/NSScrollView.m src/NSClipView.m src/NSBox.m src/NSView.m src/NSResponder.m test/test_nsscrollview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrollView.m src/NSClipView.m src/NSBox.m src/NSView.m src/NSResponder.m test/test_nsscrollview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstabview: src/NSTabView.m src/NSTabViewItem.m src/NSView.m src/NSResponder.m test/test_nstabview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTabView.m src/NSTabViewItem.m src/NSView.m src/NSResponder.m test/test_nstabview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssplitview: src/NSSplitView.m src/NSView.m src/NSResponder.m test/test_nssplitview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSplitView.m src/NSView.m src/NSResponder.m test/test_nssplitview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscolorwell: src/NSColorWell.m $(CONTROL_SRC) test/test_nscolorwell.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColorWell.m $(CONTROL_SRC) test/test_nscolorwell.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssegmented: src/NSSegmentedControl.m src/NSSegmentedCell.m $(CONTROL_SRC) test/test_nssegmented.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSegmentedControl.m src/NSSegmentedCell.m $(CONTROL_SRC) test/test_nssegmented.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssearchfield: src/NSSearchField.m src/NSSearchFieldCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nssearchfield.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSearchField.m src/NSSearchFieldCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nssearchfield.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsdatepicker: src/NSDatePicker.m src/NSDatePickerCell.m $(CONTROL_SRC) test/test_nsdatepicker.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDatePicker.m src/NSDatePickerCell.m $(CONTROL_SRC) test/test_nsdatepicker.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsscroller: src/NSScroller.m $(CONTROL_SRC) test/test_nsscroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScroller.m $(CONTROL_SRC) test/test_nsscroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscombobox: src/NSComboBox.m src/NSComboBoxCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nscombobox.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSComboBox.m src/NSComboBoxCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nscombobox.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstokenfield: src/NSTokenField.m src/NSTokenFieldCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nstokenfield.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTokenField.m src/NSTokenFieldCell.m src/NSTextField.m src/NSTextFieldCell.m $(CONTROL_SRC) test/test_nstokenfield.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsstackview: src/NSStackView.m src/NSView.m src/NSResponder.m test/test_nsstackview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStackView.m src/NSView.m src/NSResponder.m test/test_nsstackview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspathcontrol: src/NSPathControl.m src/NSPathCell.m $(CONTROL_SRC) test/test_nspathcontrol.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPathControl.m src/NSPathCell.m $(CONTROL_SRC) test/test_nspathcontrol.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstableview: src/NSTableView.m src/NSTableColumn.m $(CONTROL_SRC) test/test_nstableview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTableView.m src/NSTableColumn.m $(CONTROL_SRC) test/test_nstableview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsoutlineview: src/NSOutlineView.m src/NSTableView.m src/NSTableColumn.m $(CONTROL_SRC) test/test_nsoutlineview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSOutlineView.m src/NSTableView.m src/NSTableColumn.m $(CONTROL_SRC) test/test_nsoutlineview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nstoolbaritem: src/NSToolbarItem.m src/NSToolbarItem.h test/test_nstoolbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSToolbarItem.m test/test_nstoolbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nstoolbar: src/NSToolbar.m src/NSToolbar.h test/test_nstoolbar.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSToolbar.m test/test_nstoolbar.m $(FOUNDATION_LDFLAGS)

build/test_nsstatusitem: src/NSStatusItem.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusitem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStatusItem.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusitem.m $(FOUNDATION_LDFLAGS)

build/test_nsalert: src/NSAlert.m src/NSButton.m src/NSButtonCell.m $(CONTROL_SRC) test/test_nsalert.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAlert.m src/NSButton.m src/NSButtonCell.m $(CONTROL_SRC) test/test_nsalert.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspopover: src/NSPopover.m src/NSResponder.m test/test_nspopover.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPopover.m src/NSResponder.m test/test_nspopover.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsvisualeffectview: src/NSVisualEffectView.m src/NSView.m src/NSResponder.m test/test_nsvisualeffectview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSVisualEffectView.m src/NSView.m src/NSResponder.m test/test_nsvisualeffectview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsstatusbar: src/NSStatusBar.m src/NSStatusItem.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusbar.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStatusBar.m src/NSStatusItem.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusbar.m $(FOUNDATION_LDFLAGS)

build/test_nsgesturerecognizer: src/NSGestureRecognizer.m test/test_nsgesturerecognizer.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGestureRecognizer.m test/test_nsgesturerecognizer.m $(FOUNDATION_LDFLAGS)

build/test_nsclickgesture: src/NSClickGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsclickgesture.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSClickGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsclickgesture.m $(FOUNDATION_LDFLAGS)

build/test_nspangesture: src/NSPanGestureRecognizer.m src/NSGestureRecognizer.m test/test_nspangesture.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPanGestureRecognizer.m src/NSGestureRecognizer.m test/test_nspangesture.m $(FOUNDATION_LDFLAGS)

build/test_nsmaggesture: src/NSMagnificationGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsmaggesture.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMagnificationGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsmaggesture.m $(FOUNDATION_LDFLAGS)

build/test_nsrotationgesture: src/NSRotationGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsrotationgesture.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSRotationGestureRecognizer.m src/NSGestureRecognizer.m test/test_nsrotationgesture.m $(FOUNDATION_LDFLAGS)

build/test_nspressgesture: src/NSPressGestureRecognizer.m src/NSGestureRecognizer.m test/test_nspressgesture.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPressGestureRecognizer.m src/NSGestureRecognizer.m test/test_nspressgesture.m $(FOUNDATION_LDFLAGS)

build/test_nssound: src/NSSound.m src/NSSound.h test/test_nssound.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSound.m test/test_nssound.m $(FOUNDATION_LDFLAGS)

build/test_nspanel: src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nspanel.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nspanel.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssavepanel: src/NSSavePanel.m src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nssavepanel.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSavePanel.m src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nssavepanel.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsopenpanel: src/NSOpenPanel.m src/NSSavePanel.m src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nsopenpanel.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSOpenPanel.m src/NSSavePanel.m src/NSPanel.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nsopenpanel.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscursor: src/NSCursor.m src/NSCursor.h test/test_nscursor.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCursor.m test/test_nscursor.m $(FOUNDATION_LDFLAGS)

build/test_nsfontmanager: src/NSFontManager.m src/NSFontManager.h src/NSFont.m src/NSFont.h test/test_nsfontmanager.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFontManager.m src/NSFont.m test/test_nsfontmanager.m $(FOUNDATION_LDFLAGS) -framework CoreText

build/test_nsaffinetransform: src/NSAffineTransform.m src/NSAffineTransform.h src/NSBezierPath.m src/NSBezierPath.h test/test_nsaffinetransform.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAffineTransform.m src/NSBezierPath.m test/test_nsaffinetransform.m $(FOUNDATION_LDFLAGS)

build/test_nsanimation: src/NSAnimation.m src/NSAnimation.h test/test_nsanimation.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAnimation.m test/test_nsanimation.m $(FOUNDATION_LDFLAGS)

build/test_nsviewanimation: src/NSViewAnimation.m src/NSViewAnimation.h src/NSAnimation.m src/NSAnimation.h test/test_nsviewanimation.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSViewAnimation.m src/NSAnimation.m test/test_nsviewanimation.m $(FOUNDATION_LDFLAGS)

build/test_nscollectionviewlayout: src/NSCollectionViewLayout.m src/NSCollectionViewLayout.h src/NSCollectionViewLayoutAttributes.m src/NSCollectionViewLayoutAttributes.h test/test_nscollectionviewlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewlayout.m $(FOUNDATION_LDFLAGS)

build/test_nscollectionviewflowlayout: src/NSCollectionViewFlowLayout.m src/NSCollectionViewFlowLayout.h src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewflowlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewFlowLayout.m src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewflowlayout.m $(FOUNDATION_LDFLAGS)

build/test_nscollectionviewgridlayout: src/NSCollectionViewGridLayout.m src/NSCollectionViewGridLayout.h src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewgridlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewGridLayout.m src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewgridlayout.m $(FOUNDATION_LDFLAGS)

build/test_nscontroller: src/NSController.m src/NSController.h test/test_nscontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSController.m test/test_nscontroller.m $(FOUNDATION_LDFLAGS)

build/test_nsobjectcontroller: src/NSObjectController.m src/NSObjectController.h src/NSController.m src/NSController.h test/test_nsobjectcontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSObjectController.m src/NSController.m test/test_nsobjectcontroller.m $(FOUNDATION_LDFLAGS)

build/test_nsarraycontroller: src/NSArrayController.m src/NSArrayController.h src/NSObjectController.m src/NSController.m test/test_nsarraycontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSArrayController.m src/NSObjectController.m src/NSController.m test/test_nsarraycontroller.m $(FOUNDATION_LDFLAGS)

build/test_nstreecontroller: src/NSTreeController.m src/NSTreeController.h src/NSObjectController.m src/NSController.m src/NSTreeNode.m src/NSTreeNode.h test/test_nstreecontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTreeController.m src/NSObjectController.m src/NSController.m src/NSTreeNode.m test/test_nstreecontroller.m $(FOUNDATION_LDFLAGS)

build/test_nsuserdefaultscontroller: src/NSUserDefaultsController.m src/NSUserDefaultsController.h src/NSController.m test/test_nsuserdefaultscontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSUserDefaultsController.m src/NSController.m test/test_nsuserdefaultscontroller.m $(FOUNDATION_LDFLAGS)

build/test_nsdictionarycontroller: src/NSDictionaryController.m src/NSDictionaryController.h src/NSArrayController.m src/NSObjectController.m src/NSController.m test/test_nsdictionarycontroller.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDictionaryController.m src/NSArrayController.m src/NSObjectController.m src/NSController.m test/test_nsdictionarycontroller.m $(FOUNDATION_LDFLAGS)

build/test_nsrunningapplication: src/NSRunningApplication.m src/NSRunningApplication.h test/test_nsrunningapplication.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSRunningApplication.m test/test_nsrunningapplication.m $(FOUNDATION_LDFLAGS)

build/test_nsnib: src/NSNib.m src/NSNib.h test/test_nsnib.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSNib.m test/test_nsnib.m $(FOUNDATION_LDFLAGS)

build/test_nscollectionviewtransitionlayout: src/NSCollectionViewTransitionLayout.m src/NSCollectionViewTransitionLayout.h src/NSCollectionViewFlowLayout.m src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewtransitionlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSCollectionViewTransitionLayout.m src/NSCollectionViewFlowLayout.m src/NSCollectionViewLayout.m src/NSCollectionViewLayoutAttributes.m test/test_nscollectionviewtransitionlayout.m $(FOUNDATION_LDFLAGS)

build/test_nstablecellview: src/NSTableCellView.m src/NSTableCellView.h src/NSView.m src/NSResponder.m src/NSDraggingImageComponent.m test/test_nstablecellview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTableCellView.m src/NSView.m src/NSResponder.m src/NSDraggingImageComponent.m test/test_nstablecellview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nssharingservicepicker: src/NSSharingServicePicker.m src/NSSharingServicePicker.h src/NSMenuItem.m src/NSMenu.m test/test_nssharingservicepicker.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSharingServicePicker.m src/NSMenuItem.m src/NSMenu.m test/test_nssharingservicepicker.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspredicateeditorrowtemplate: src/NSPredicateEditorRowTemplate.m src/NSPredicateEditorRowTemplate.h test/test_nspredicateeditorrowtemplate.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPredicateEditorRowTemplate.m test/test_nspredicateeditorrowtemplate.m $(FOUNDATION_LDFLAGS)

build/test_nstextinputcontext: src/NSTextInputContext.m src/NSTextInputContext.h test/test_nstextinputcontext.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextInputContext.m test/test_nstextinputcontext.m $(FOUNDATION_LDFLAGS)

build/test_nsstoryboard: src/NSStoryboard.m src/NSStoryboard.h test/test_nsstoryboard.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStoryboard.m test/test_nsstoryboard.m $(FOUNDATION_LDFLAGS)

build/test_nsspellchecker: src/NSSpellChecker.m src/NSSpellChecker.h test/test_nsspellchecker.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSpellChecker.m test/test_nsspellchecker.m $(FOUNDATION_LDFLAGS)

build/test_nspagecontroller: src/NSPageController.m src/NSPageController.h src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nspagecontroller.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPageController.m src/NSViewController.m src/NSView.m src/NSResponder.m test/test_nspagecontroller.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsworkspaceopenconfiguration: src/NSWorkspaceOpenConfiguration.m src/NSWorkspaceOpenConfiguration.h test/test_nsworkspaceopenconfiguration.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSWorkspaceOpenConfiguration.m test/test_nsworkspaceopenconfiguration.m $(FOUNDATION_LDFLAGS)

build/test_nsfilepromiseprovider: src/NSFilePromiseProvider.m src/NSFilePromiseProvider.h test/test_nsfilepromiseprovider.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFilePromiseProvider.m test/test_nsfilepromiseprovider.m $(FOUNDATION_LDFLAGS)

build/test_nsfilepromisereceiver: src/NSFilePromiseReceiver.m src/NSFilePromiseReceiver.h test/test_nsfilepromisereceiver.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFilePromiseReceiver.m test/test_nsfilepromisereceiver.m $(FOUNDATION_LDFLAGS)

build/test_nscombobutton: src/NSComboButton.m src/NSComboButton.h src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nscombobutton.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSComboButton.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nscombobutton.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsslideraccessory: src/NSSliderAccessory.m src/NSSliderAccessory.h test/test_nsslideraccessory.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSliderAccessory.m test/test_nsslideraccessory.m $(FOUNDATION_LDFLAGS)

build/test_nstextinsertionindicator: src/NSTextInsertionIndicator.m src/NSTextInsertionIndicator.h src/NSView.m src/NSResponder.m test/test_nstextinsertionindicator.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSTextInsertionIndicator.m src/NSView.m src/NSResponder.m test/test_nstextinsertionindicator.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsdraggingsession: src/NSDraggingSession.m src/NSDraggingSession.h src/NSDraggingItem.m src/NSDraggingImageComponent.m src/NSPasteboard.m test/test_nsdraggingsession.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSDraggingSession.m src/NSDraggingItem.m src/NSDraggingImageComponent.m src/NSPasteboard.m test/test_nsdraggingsession.m $(FOUNDATION_LDFLAGS)

build/test_nspathcomponentcell: src/NSPathComponentCell.m src/NSPathComponentCell.h src/NSTextFieldCell.m src/NSActionCell.m src/NSCell.m test/test_nspathcomponentcell.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPathComponentCell.m src/NSTextFieldCell.m src/NSActionCell.m src/NSCell.m test/test_nspathcomponentcell.m $(FOUNDATION_LDFLAGS)

build/test_nsstatusbarbutton: src/NSStatusBarButton.m src/NSStatusBarButton.h src/NSButton.m src/NSButtonCell.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusbarbutton.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStatusBarButton.m src/NSButton.m src/NSButtonCell.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsstatusbarbutton.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsformcell: src/NSFormCell.m src/NSFormCell.h src/NSActionCell.m src/NSCell.m test/test_nsformcell.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSFormCell.m src/NSActionCell.m src/NSCell.m test/test_nsformcell.m $(FOUNDATION_LDFLAGS)

build/test_nsmatrix: src/NSMatrix.m src/NSMatrix.h src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsmatrix.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSMatrix.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsmatrix.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsform: src/NSForm.m src/NSForm.h src/NSFormCell.m src/NSMatrix.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsform.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSForm.m src/NSFormCell.m src/NSMatrix.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m test/test_nsform.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubber: src/NSScrubber.m src/NSScrubber.h src/NSView.m src/NSResponder.m test/test_nsscrubber.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubber.m src/NSView.m src/NSResponder.m test/test_nsscrubber.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberselectionstyle: src/NSScrubberSelectionStyle.m src/NSScrubberSelectionStyle.h src/NSView.m src/NSResponder.m test/test_nsscrubberselectionstyle.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberSelectionStyle.m src/NSView.m src/NSResponder.m test/test_nsscrubberselectionstyle.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberlayoutattributes: src/NSScrubberLayoutAttributes.m src/NSScrubberLayoutAttributes.h test/test_nsscrubberlayoutattributes.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberLayoutAttributes.m test/test_nsscrubberlayoutattributes.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberlayout: src/NSScrubberLayout.m src/NSScrubberLayout.h src/NSScrubberLayoutAttributes.m test/test_nsscrubberlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberLayout.m src/NSScrubberLayoutAttributes.m test/test_nsscrubberlayout.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberflowlayout: src/NSScrubberFlowLayout.m src/NSScrubberFlowLayout.h src/NSScrubberLayout.m src/NSScrubberLayoutAttributes.m test/test_nsscrubberflowlayout.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberFlowLayout.m src/NSScrubberLayout.m src/NSScrubberLayoutAttributes.m test/test_nsscrubberflowlayout.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberproportionallayout: src/NSScrubberProportionalLayout.m src/NSScrubberProportionalLayout.h src/NSScrubberLayout.m src/NSScrubberLayoutAttributes.m src/NSScrubber.m src/NSView.m src/NSResponder.m test/test_nsscrubberproportionallayout.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberProportionalLayout.m src/NSScrubberLayout.m src/NSScrubberLayoutAttributes.m src/NSScrubber.m src/NSView.m src/NSResponder.m test/test_nsscrubberproportionallayout.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nsscrubberitemview: src/NSScrubberItemView.m src/NSScrubberItemView.h src/NSScrubberLayoutAttributes.m src/NSView.m src/NSResponder.m test/test_nsscrubberitemview.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSScrubberItemView.m src/NSScrubberLayoutAttributes.m src/NSView.m src/NSResponder.m test/test_nsscrubberitemview.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nshapticfeedbackmanager: src/NSHapticFeedbackManager.m src/NSHapticFeedbackManager.h test/test_nshapticfeedbackmanager.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSHapticFeedbackManager.m test/test_nshapticfeedbackmanager.m $(FOUNDATION_LDFLAGS)

build/test_nsaxcustomrotorsearchparameters: src/NSAccessibilityCustomRotorSearchParameters.m src/NSAccessibilityCustomRotorSearchParameters.h test/test_nsaxcustomrotorsearchparameters.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAccessibilityCustomRotorSearchParameters.m test/test_nsaxcustomrotorsearchparameters.m $(FOUNDATION_LDFLAGS)

build/test_nsaxcustomrotoritemresult: src/NSAccessibilityCustomRotorItemResult.m src/NSAccessibilityCustomRotorItemResult.h test/test_nsaxcustomrotoritemresult.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAccessibilityCustomRotorItemResult.m test/test_nsaxcustomrotoritemresult.m $(FOUNDATION_LDFLAGS)

build/test_nsaxcustomrotor: src/NSAccessibilityCustomRotor.m src/NSAccessibilityCustomRotor.h test/test_nsaxcustomrotor.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAccessibilityCustomRotor.m test/test_nsaxcustomrotor.m $(FOUNDATION_LDFLAGS)

build/test_nsaxcustomchooser: src/NSAccessibilityCustomChooserSearchPredicate.m src/NSAccessibilityCustomChooserSearchPredicate.h test/test_nsaxcustomchooser.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSAccessibilityCustomChooserSearchPredicate.m test/test_nsaxcustomchooser.m $(FOUNDATION_LDFLAGS)

build/test_nsbuttontouchbaritem: src/NSButtonTouchBarItem.m src/NSButtonTouchBarItem.h src/NSTouchBarItem.m test/test_nsbuttontouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSButtonTouchBarItem.m src/NSTouchBarItem.m test/test_nsbuttontouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nssteppertouchbaritem: src/NSStepperTouchBarItem.m src/NSStepperTouchBarItem.h src/NSTouchBarItem.m test/test_nssteppertouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSStepperTouchBarItem.m src/NSTouchBarItem.m test/test_nssteppertouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nsgrouptouchbaritem: src/NSGroupTouchBarItem.m src/NSGroupTouchBarItem.h src/NSTouchBar.m src/NSTouchBarItem.m src/NSCustomTouchBarItem.m test/test_nsgrouptouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSGroupTouchBarItem.m src/NSTouchBar.m src/NSTouchBarItem.m src/NSCustomTouchBarItem.m test/test_nsgrouptouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nspickertouchbaritem: src/NSPickerTouchBarItem.m src/NSPickerTouchBarItem.h src/NSTouchBarItem.m test/test_nspickertouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPickerTouchBarItem.m src/NSTouchBarItem.m test/test_nspickertouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nsslidertouchbaritem: src/NSSliderTouchBarItem.m src/NSSliderTouchBarItem.h src/NSTouchBarItem.m src/NSSlider.m src/NSSliderCell.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m src/NSSliderAccessory.m test/test_nsslidertouchbaritem.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSliderTouchBarItem.m src/NSTouchBarItem.m src/NSSlider.m src/NSSliderCell.m src/NSControl.m src/NSCell.m src/NSActionCell.m src/NSView.m src/NSResponder.m src/NSApplication.m src/NSMenu.m src/NSMenuItem.m src/NSSliderAccessory.m test/test_nsslidertouchbaritem.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nscolorsampler: src/NSColorSampler.m src/NSColorSampler.h test/test_nscolorsampler.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColorSampler.m test/test_nscolorsampler.m $(FOUNDATION_LDFLAGS)

build/test_nscolorpickertouchbaritem: src/NSColorPickerTouchBarItem.m src/NSColorPickerTouchBarItem.h src/NSTouchBarItem.m test/test_nscolorpickertouchbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSColorPickerTouchBarItem.m src/NSTouchBarItem.m test/test_nscolorpickertouchbaritem.m $(FOUNDATION_LDFLAGS)

build/test_nswindowtabgroup: src/NSWindowTabGroup.m src/NSWindowTabGroup.h src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nswindowtabgroup.m test/stubs.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSWindowTabGroup.m src/NSWindow.m src/NSView.m src/NSResponder.m test/test_nswindowtabgroup.m test/stubs.m $(FOUNDATION_LDFLAGS)

build/test_nspdfinfo: src/NSPDFInfo.m src/NSPDFInfo.h test/test_nspdfinfo.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSPDFInfo.m test/test_nspdfinfo.m $(FOUNDATION_LDFLAGS)

build/test_nsspeechrecognizer: src/NSSpeechRecognizer.m src/NSSpeechRecognizer.h test/test_nsspeechrecognizer.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSpeechRecognizer.m test/test_nsspeechrecognizer.m $(FOUNDATION_LDFLAGS)

build/test_nssharingservicepickertoolbaritem: src/NSSharingServicePickerToolbarItem.m src/NSSharingServicePickerToolbarItem.h src/NSToolbarItem.m test/test_nssharingservicepickertoolbaritem.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSSharingServicePickerToolbarItem.m src/NSToolbarItem.m test/test_nssharingservicepickertoolbaritem.m $(FOUNDATION_LDFLAGS)
