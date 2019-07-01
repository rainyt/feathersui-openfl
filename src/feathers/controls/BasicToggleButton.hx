/*
	Feathers
	Copyright 2019 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package feathers.controls;

import openfl.display.DisplayObject;
import openfl.events.Event;
import openfl.events.MouseEvent;
import feathers.core.FeathersControl;
import feathers.core.IMeasureObject;
import feathers.core.IUIControl;
import feathers.core.InvalidationFlag;
import feathers.core.IStateContext;
import feathers.core.IStateObserver;
import feathers.core.IValidating;
import feathers.events.FeathersEvent;
import feathers.layout.Measurements;
import feathers.utils.PointerToState;

/**
	A simple toggle button control with selection, pointer states, but no
	content, that is useful for purposes like skinning. For a more full-featured
	toggle button, with a label and icon, see `feathers.controls.ToggleButton`
	instead.

	@since 1.0.0

	@see `feathers.controls.ToggleButton`
**/
class BasicToggleButton extends FeathersControl implements IToggle implements IStateContext {
	public function new() {
		super();
		// MouseEvent.CLICK is dispatched only if the same object is under the
		// pointer for both MouseEvent.MOUSE_DOWN and MouseEvent.MOUSE_UP. The
		// button might change skins between ToggleButtonState.UP and
		// ToggleButtonState.DOWN, and this would prevent MouseEvent.CLICK.
		// setting mouseChildren to false keeps the toggle button as the target.
		this.mouseChildren = false;
		// when focused, keyboard space/enter trigger MouseEvent.CLICK
		this.buttonMode = true;
		// a hand cursor only makes sense for hyperlinks
		this.useHandCursor = false;

		this.addEventListener(MouseEvent.CLICK, basicToggleButton_clickHandler);
	}

	/**
		The current state of the toggle button.

		@see `feathers.controls.ToggleButtonState`
		@see `FeathersEvent.STATE_CHANGE`

		@since 1.0.0
	**/
	public var currentState(get, null):String;

	private function get_currentState():String {
		var result = this.currentState;
		if (this.selected) {
			result += "AndSelected";
		}
		return result;
	}

	override private function set_enabled(value:Bool):Bool {
		super.enabled = value;
		if (this.enabled) {
			if (Reflect.field(this, "currentState") == ToggleButtonState.DISABLED) {
				this.changeState(ToggleButtonState.UP);
			}
		} else {
			this.changeState(ToggleButtonState.DISABLED);
		}
		return this.enabled;
	}

	@:isVar
	public var selected(get, set):Bool = false;

	private function get_selected():Bool {
		return this.selected;
	}

	private function set_selected(value:Bool):Bool {
		if (this.selected == value) {
			return this.selected;
		}
		this.selected = value;
		this.setInvalid(InvalidationFlag.SELECTION);
		this.setInvalid(InvalidationFlag.STATE);
		FeathersEvent.dispatch(this, Event.CHANGE);
		FeathersEvent.dispatch(this, FeathersEvent.STATE_CHANGE);
		return this.selected;
	}

	public var toggleable(default, set):Bool = true;

	private function set_toggleable(value:Bool):Bool {
		if (this.toggleable == value) {
			return this.toggleable;
		}
		this.toggleable = value;
		return this.toggleable;
	}

	private var _pointerToState:PointerToState = null;
	private var _backgroundSkinMeasurements:Measurements = null;
	private var _currentBackgroundSkin:DisplayObject = null;

	@style
	public var keepDownStateOnRollOut(default, set):Bool = false;

	private function set_keepDownStateOnRollOut(value:Bool):Bool {
		if (!this.setStyle("keepDownStateOnRollOut")) {
			return this.keepDownStateOnRollOut;
		}
		if (this.keepDownStateOnRollOut == value) {
			return this.keepDownStateOnRollOut;
		}
		this.keepDownStateOnRollOut = value;
		this.setInvalid(InvalidationFlag.STYLES);
		return this.keepDownStateOnRollOut;
	}

	/**
		The default background skin for the toggle button, which is used when no
		other skin is defined for the current state with `setSkinForState()`.

		The following example gives the toggle button a default skin to use for
		all states when no specific skin is available:

		```hx
		button.backgroundSkin = new Bitmap(bitmapData);
		```

		@default null

		@see `BasicToggleButton.getSkinForState()`
		@see `BasicToggleButton.setSkinForState()`

		@since 1.0.0
	**/
	@style
	public var backgroundSkin(default, set):DisplayObject = null;

	private function set_backgroundSkin(value:DisplayObject):DisplayObject {
		if (!this.setStyle("backgroundSkin")) {
			return this.backgroundSkin;
		}
		if (this.backgroundSkin == value) {
			return this.backgroundSkin;
		}
		if (this.backgroundSkin != null && this.backgroundSkin == this._currentBackgroundSkin) {
			this.removeCurrentBackgroundSkin(this.backgroundSkin);
			this._currentBackgroundSkin = null;
		}
		this.backgroundSkin = value;
		this.setInvalid(InvalidationFlag.STYLES);
		return this.backgroundSkin;
	}

	private var _stateToSkin:Map<String, DisplayObject> = new Map();

	/**
		Gets the skin to be used by the toggle button when its `currentState`
		property matches the specified state value.

		If a skin is not defined for a specific state, returns `null`.

		@see `feathers.controls.ToggleButtonState`
		@see `BasicToggleButton.backgroundSkin`
		@see `BasicToggleButton.setSkinForState()`
		@see `BasicToggleButton.currentState`

		@since 1.0.0
	**/
	public function getSkinForState(state:ToggleButtonState):DisplayObject {
		return this._stateToSkin.get(state);
	}

	/**
		Set the skin to be used by the toggle button when its `currentState`
		property matches the specified state value.

		If a skin is not defined for a specific state, the value of the
		`backgroundSkin` property will be used instead.

		@see `feathers.controls.ToggleButtonState`
		@see `BasicToggleButton.backgroundSkin`
		@see `BasicToggleButton.getSkinForState()`
		@see `BasicToggleButton.currentState`

		@since 1.0.0
	**/
	@style
	public function setSkinForState(state:ToggleButtonState, skin:DisplayObject):Void {
		if (!this.setStyle("setSkinForState", state)) {
			return;
		}
		var oldSkin = this._stateToSkin.get(state);
		if (oldSkin != null && oldSkin == this._currentBackgroundSkin) {
			this.removeCurrentBackgroundSkin(oldSkin);
			this._currentBackgroundSkin = null;
		}
		if (skin == null) {
			this._stateToSkin.remove(state);
		} else {
			this._stateToSkin.set(state, skin);
		}
		this.setInvalid(InvalidationFlag.STYLES);
	}

	override private function initialize():Void {
		super.initialize();

		if (this._pointerToState == null) {
			this._pointerToState = new PointerToState(this, this.changeState);
		}
	}

	override private function update():Void {
		var selectionInvalid = this.isInvalid(InvalidationFlag.SELECTION);
		var stylesInvalid = this.isInvalid(InvalidationFlag.STYLES);
		var stateInvalid = this.isInvalid(InvalidationFlag.STATE);

		if (selectionInvalid || stateInvalid || stylesInvalid) {
			this.refreshBackgroundSkin();
		}

		if (stylesInvalid) {
			this.refreshInteractivity();
		}

		this.autoSizeIfNeeded();
		this.layoutBackgroundSkin();
	}

	private function refreshInteractivity():Void {
		this._pointerToState.keepDownStateOnRollOut = this.keepDownStateOnRollOut;
	}

	private function refreshBackgroundSkin():Void {
		var oldSkin = this._currentBackgroundSkin;
		this._currentBackgroundSkin = this.getCurrentBackgroundSkin();
		if (this._currentBackgroundSkin == oldSkin) {
			return;
		}
		this.removeCurrentBackgroundSkin(oldSkin);
		if (this._currentBackgroundSkin == null) {
			this._backgroundSkinMeasurements = null;
			return;
		}
		if (Std.is(this._currentBackgroundSkin, IUIControl)) {
			cast(this._currentBackgroundSkin, IUIControl).initializeNow();
		}
		if (this._backgroundSkinMeasurements == null) {
			this._backgroundSkinMeasurements = new Measurements(this._currentBackgroundSkin);
		} else {
			this._backgroundSkinMeasurements.save(this._currentBackgroundSkin);
		}
		if (Std.is(this._currentBackgroundSkin, IStateObserver)) {
			cast(this._currentBackgroundSkin, IStateObserver).stateContext = this;
		}
		this.addChildAt(this._currentBackgroundSkin, 0);
	}

	private function getCurrentBackgroundSkin():DisplayObject {
		var result = this._stateToSkin.get(this.currentState);
		if (result != null) {
			return result;
		}
		return this.backgroundSkin;
	}

	private function removeCurrentBackgroundSkin(skin:DisplayObject):Void {
		if (skin == null) {
			return;
		}
		if (Std.is(skin, IStateObserver)) {
			cast(skin, IStateObserver).stateContext = null;
		}
		if (skin.parent == this) {
			// we need to restore these values so that they won't be lost the
			// next time that this skin is used for measurement
			this.removeChild(skin);
		}
	}

	/**
		If the component's dimensions have not been set explicitly, it will
		measure its content and determine an ideal size for itself. For
		instance, if the `explicitWidth` property is set, that value will be
		used without additional measurement. If `explicitWidth` is set, but
		`explicitHeight` is not (or the other way around), the dimension with
		the explicit value will not be measured, but the other non-explicit
		dimension will still require measurement.

		Calls `saveMeasurements()` to set up the `actualWidth` and
		`actualHeight` member variables used for layout.

		Meant for internal use, and subclasses may override this function with a
		custom implementation.

		@see `FeathersControl.saveMeasurements()`
		@see `FeathersControl.explicitWidth`
		@see `FeathersControl.explicitHeight`
		@see `FeathersControl.actualWidth`
		@see `FeathersControl.actualHeight`

		@since 1.0.0
	**/
	@:dox(show)
	private function autoSizeIfNeeded():Bool {
		var needsWidth = this.explicitWidth == null;
		var needsHeight = this.explicitHeight == null;
		var needsMinWidth = this.explicitMinWidth == null;
		var needsMinHeight = this.explicitMinHeight == null;
		var needsMaxWidth = this.explicitMaxWidth == null;
		var needsMaxHeight = this.explicitMaxHeight == null;
		if (!needsWidth && !needsHeight && !needsMinWidth && !needsMinHeight && !needsMaxWidth && !needsMaxHeight) {
			return false;
		}

		if (this._currentBackgroundSkin != null) {
			this._backgroundSkinMeasurements.resetTargetFluidlyForParent(this._currentBackgroundSkin, this);
		}

		var measureSkin:IMeasureObject = null;
		if (Std.is(this._currentBackgroundSkin, IMeasureObject)) {
			measureSkin = cast(this._currentBackgroundSkin, IMeasureObject);
		}

		if (Std.is(this._currentBackgroundSkin, IValidating)) {
			cast(this._currentBackgroundSkin, IValidating).validateNow();
		}

		var newWidth = this.explicitWidth;
		if (needsWidth) {
			if (this._currentBackgroundSkin != null) {
				newWidth = this._currentBackgroundSkin.width;
			} else {
				newWidth = 0;
			}
		}

		var newHeight = this.explicitHeight;
		if (needsHeight) {
			if (this._currentBackgroundSkin != null) {
				newHeight = this._currentBackgroundSkin.height;
			} else {
				newHeight = 0;
			}
		}

		var newMinWidth = this.explicitMinWidth;
		if (needsMinWidth) {
			if (measureSkin != null) {
				newMinWidth = measureSkin.minWidth;
			} else if (this._backgroundSkinMeasurements != null) {
				newMinWidth = this._backgroundSkinMeasurements.minWidth;
			} else {
				newMinWidth = 0;
			}
		}

		var newMinHeight = this.explicitMinHeight;
		if (needsMinHeight) {
			if (measureSkin != null) {
				newMinHeight = measureSkin.minHeight;
			} else if (this._backgroundSkinMeasurements != null) {
				newMinHeight = this._backgroundSkinMeasurements.minHeight;
			} else {
				newMinHeight = 0;
			}
		}
		var newMaxWidth = this.explicitMaxWidth;
		if (needsMaxWidth) {
			if (measureSkin != null) {
				newMaxWidth = measureSkin.maxWidth;
			} else if (this._backgroundSkinMeasurements != null) {
				newMaxWidth = this._backgroundSkinMeasurements.maxWidth;
			} else {
				newMaxWidth = Math.POSITIVE_INFINITY;
			}
		}

		var newMaxHeight = this.explicitMaxHeight;
		if (needsMaxHeight) {
			if (measureSkin != null) {
				newMaxHeight = measureSkin.maxHeight;
			} else if (this._backgroundSkinMeasurements != null) {
				newMaxHeight = this._backgroundSkinMeasurements.maxHeight;
			} else {
				newMaxHeight = Math.POSITIVE_INFINITY;
			}
		}

		return this.saveMeasurements(newWidth, newHeight, newMinWidth, newMinHeight, newMaxWidth, newMaxHeight);
	}

	private function layoutBackgroundSkin():Void {
		if (this._currentBackgroundSkin == null) {
			return;
		}
		this._currentBackgroundSkin.x = 0;
		this._currentBackgroundSkin.y = 0;

		// don't set the width or height explicitly unless necessary because if
		// our explicit dimensions are cleared later, the measurement may not be
		// accurate anymore
		if (this._currentBackgroundSkin.width != this.actualWidth) {
			this._currentBackgroundSkin.width = this.actualWidth;
		}
		if (this._currentBackgroundSkin.height != this.actualHeight) {
			this._currentBackgroundSkin.height = this.actualHeight;
		}
		if (Std.is(this._currentBackgroundSkin, IValidating)) {
			cast(this._currentBackgroundSkin, IValidating).validateNow();
		}
	}

	private function changeState(state:String):Void {
		if (!this.enabled) {
			state = ToggleButtonState.DISABLED;
		}
		if (this.currentState == state) {
			return;
		}
		this.currentState = state;
		this.setInvalid(InvalidationFlag.STATE);
		FeathersEvent.dispatch(this, FeathersEvent.STATE_CHANGE);
	}

	private function basicToggleButton_clickHandler(event:MouseEvent):Void {
		if (!this.enabled) {
			event.stopImmediatePropagation();
			return;
		}
		if (!this.toggleable) {
			return;
		}
		this.selected = !this.selected;
	}
}
