# Build and run the standalone behaviour tests for the decompiled AppKit classes.
# Foundation only — no AppKit linked, so our reimplemented classes are the ones
# under test. Works with clang on macOS and with clang+libobjc2+gnustep-base on
# FreeBSD (override FOUNDATION_LDFLAGS and, if needed, OBJCFLAGS there).

CC ?= clang
OBJCFLAGS ?= -fobjc-arc -Wall -Wno-objc-root-class -g -O0
FOUNDATION_LDFLAGS ?= -framework Foundation -framework CoreGraphics

.PHONY: test clean
test: build/test_nsresponder build/test_nsview build/test_nscell build/test_nsactioncell build/test_nscontrol build/test_nsbutton build/test_nsmenuitem build/test_nsmenu build/test_nswindow build/test_nsapplication build/test_nstextfield build/test_nsbox build/test_nsstepper build/test_nsprogress build/test_nsslider build/test_nsimageview build/test_nslevelindicator build/test_nspopupbutton build/test_nstablecolumn build/test_nsscrollview build/test_nstabview build/test_nssplitview build/test_nscolorwell build/test_nssegmented build/test_nssearchfield build/test_nsdatepicker build/test_nsscroller build/test_nscombobox build/test_nstokenfield build/test_nsstackview build/test_nspathcontrol build/test_nstableview build/test_nsoutlineview build/test_nstoolbaritem
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
