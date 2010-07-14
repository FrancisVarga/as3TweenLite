/**
 * VERSION: 1.55
 * DATE: 2010-06-22
 * AS3
 * UPDATES AND DOCUMENTATION AT: http://www.greensock.com/autofitarea/
 **/
package com.greensock.layout {
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
/**
 * AutoFitArea allows you to define a rectangular area and then <code>attach()</code> DisplayObjects 
 * so that they automatically fill the area, scaling/stretching in any of the following modes: <code>STRETCH, 
 * PROPORTIONAL_INSIDE, PROPORTIONAL_OUTSIDE, NONE, WIDTH_ONLY,</code> or <code>HEIGHT_ONLY</code>. Horizontally 
 * align the attached DisplayObjects left, center, or right. Vertically align them top, center, or bottom.
 * AutoFitArea extends the <code>Shape</code> class, so you can alter the width/height/scaleX/scaleY/x/y 
 * properties of the AutoFitArea and then all of the attached objects will automatically be affected. 
 * Attach as many DisplayObjects as you want. To make visualization easy, you can set the <code>previewColor</code>
 * to any color and set the <code>preview</code> property to true in order to see the area on the stage
 * (or simply use it like a regular Shape by adding it to the display list with <code>addChild()</code>, but the 
 * <code>preview</code> property makes it simpler because it automatically ensures that it is behind 
 * all of its attached DisplayObjects in the stacking order).
 * <br /><br />
 * 
 * When you <code>attach()</code> a DisplayObject, you can define a minimum and maximum width and height.
 * AutoFitArea doesn't require that the DisplayObject's registration point be in its upper left corner
 * either. You can even set the <code>calculateVisible</code> parameter to true when attaching an object
 * so that AutoFitArea will ignore masked areas inside the DisplayObject (this is more processor-intensive, 
 * so beware).<br /><br />
 * 
 * For scaling, AutoFitArea alters the DisplayObject's <code>width</code> and/or <code>height</code>
 * properties unless it is rotated in which case it alters the DisplayObject's <code>transform.matrix</code> 
 * directly so that accurate stretching/skewing can be accomplished. <br /><br />
 * 
 * There is also a <code>LiquidArea</code> class that extends AutoFitArea and integrates with 
 * <a href="http://www.greensock.com/liquidstage/">LiquidStage</a> so that it automatically 
 * adjusts its size whenever the stage is resized. This makes it simple to create things like 
 * a background that proportionally fills the stage or a bar that always stretches horizontally 
 * to fill the stage but stays stuck to the bottom, etc.<br /><br />
 *	
 * @example Example AS3 code:<listing version="3.0">
import com.greensock.layout.~~;

//create a 300x100 rectangular area at x:50, y:70 that stretches when the stage resizes (as though its top left and bottom right corners are pinned to their corresponding PinPoints on the stage)
var area:AutoFitArea = new AutoFitArea(this, 50, 70, 300, 100);

//attach a "myImage" Sprite to the area and set its ScaleMode to PROPORTIONAL_INSIDE and horizontally and vertically align it in the center of the area
area.attach(myImage, ScaleMode.PROPORTIONAL_INSIDE, AlignMode.CENTER, AlignMode.CENTER);

//if you'd like to preview the area visually, set preview to true (by default previewColor is red)
area.preview = true;
 
//attach a CHANGE event listener to the area
area.addEventListener(Event.CHANGE, onAreaUpdate);
function onAreaUpdate(event:Event):void {
	trace("updated AutoFitArea");
}

//to create an AutoFitArea exactly around a "myImage" DisplayObject so that it conforms its initial dimensions around the DisplayObject, use the static createAround() method:
var area:AutoFitArea = AutoFitArea.createAround(myImage);

</listing>
 *
 * 
 * <b>Copyright 2010, GreenSock. All rights reserved.</b> This work is subject to the license that came with your Club GreenSock membership and is <b>ONLY</b> to be used by corporate or "Shockingly Green" Club GreenSock members. To learn more about Club GreenSock, visit <a href="http://www.greensock.com/club/">http://www.greensock.com/club/</a>.
 * 
 * @author Jack Doyle, jack@greensock.com
 */	 
	public class AutoFitArea extends Shape {
		/** @private **/
		public static const version:Number = 1.55;
		
		/** @private **/
		private static var _bd:BitmapData;
		/** @private **/
		private static var _rect:Rectangle = new Rectangle(0, 0, 2800, 2800);
		/** @private **/
		private static var _matrix:Matrix = new Matrix();
		
		/** @private **/
		protected var _parent:DisplayObjectContainer;
		/** @private **/
		protected var _previewColor:uint;
		/** @private **/
		protected var _rootItem:AutoFitItem;
		/** @private **/
		protected var _hasListener:Boolean;
		/** @private **/
		protected var _preview:Boolean;
		/** @private **/
		protected var _tweenMode:Boolean;
		
		/**
		 * Constructor
		 * 
		 * @param parent The parent DisplayObjectContainer in which the AutoFitArea should be created. All objects that get attached must share the same parent.
		 * @param x x coordinate of the AutoFitArea's upper left corner
		 * @param y y coordinate of the AutoFitArea's upper left corner
		 * @param width width of the AutoFitArea
		 * @param height height of the AutoFitArea
		 * @param previewColor color of the AutoFitArea (which won't be seen unless you set preview to true or manually add it to the display list with addChild())
		 */
		public function AutoFitArea(parent:DisplayObjectContainer, x:Number=0, y:Number=0, width:Number=100, height:Number=100, previewColor:uint=0xFF0000) {
			super();
			super.x = x;
			super.y = y;
			if (parent == null) {
				throw new Error("AutoFitArea parent cannot be null");
			}
			_parent = parent;
			
			var g:Graphics = this.graphics;
			g.clear();
			g.beginFill(previewColor, 1);
			g.drawRect(0, 0, width, height);
			g.endFill();
			
			this.previewColor = previewColor;
		}
		
		/**
		 * Creates an AutoFitArea with its initial dimensions fit precisely around a target DisplayObject. It also attaches
		 * the target DisplayObject immediately.
		 * 
		 * @param target The target DisplayObject whose position and dimensions the AutoFitArea should match initially.
		 * @param scaleMode Determines how the target should be scaled to fit the AutoFitArea. ScaleMode choices are: <code>STRETCH, PROPORTIONAL_INSIDE, PROPORTIONAL_OUTSIDE, NONE, WIDTH_ONLY,</code> or <code>HEIGHT_ONLY</code>.
		 * @param hAlign Horizontal alignment of the target inside the AutoFitArea. AlignMode choices are: <code>LEFT</code>, <code>CENTER</code>, and <code>RIGHT</code>.
		 * @param vAlign Vertical alignment of the target inside the AutoFitArea. AlignMode choices are: <code>TOP</code>, <code>CENTER</code>, and <code>BOTTOM</code>.
		 * @param crop If true, a mask will be created so that the target will be cropped wherever it exceeds the bounds of the AutoFitArea.
		 * @param minWidth Minimum width to which the target is allowed to scale
		 * @param minHeight Minimum height to which the target is allowed to scale
		 * @param maxWidth Maximum width to which the target is allowed to scale
		 * @param maxHeight Maximum height to which the target is allowed to scale
		 * @param previewColor color of the AutoFitArea (which won't be seen unless you set preview to true or manually add it to the display list with addChild())
		 * @param calculateVisible If true, only the visible portions of the target will be taken into account when determining its position and scale which can be useful for objects that have masks applied (otherwise, Flash reports their width/height and getBounds() values including the masked portions). Setting <code>calculateVisible</code> to <code>true</code> degrades performance, so only use it when absolutely necessary.
		 * @return An AutoFitArea instance
		 */
		public static function createAround(target:DisplayObject, scaleMode:String="proportionalInside", hAlign:String="center", vAlign:String="center", crop:Boolean=false, minWidth:Number=0, minHeight:Number=0, maxWidth:Number=999999999, maxHeight:Number=999999999, previewColor:uint=0xFF0000, calculateVisible:Boolean=false):AutoFitArea {
			var bounds:Rectangle = (calculateVisible) ? getVisibleBounds(target, target.parent) : target.getBounds(target.parent);
			var afa:AutoFitArea = new AutoFitArea(target.parent, bounds.x, bounds.y, bounds.width, bounds.height, previewColor);
			afa.attach(target, scaleMode, hAlign, vAlign, crop, minWidth, maxWidth, minHeight, maxHeight, calculateVisible);
			return afa;
		}
		
		/**
		 * Attaches a DisplayObject, causing it to automatically scale to fit the area in one of the
		 * following ScaleModes: <code>STRETCH, PROPORTIONAL_INSIDE, PROPORTIONAL_OUTSIDE, NONE, WIDTH_ONLY,</code> 
		 * or <code>HEIGHT_ONLY</code>. Horizontally and vertically align the object within the area as well.
		 * When the area resizes, all attached DisplayObjects will automatically be moved/scaled accordingly.
		 * 
		 * @param target The DisplayObject to attach and scale/stretch to fit within the area.
		 * @param scaleMode Determines how the target should be scaled to fit the area. ScaleMode choices are: <code>STRETCH, PROPORTIONAL_INSIDE, PROPORTIONAL_OUTSIDE, NONE, WIDTH_ONLY,</code> or <code>HEIGHT_ONLY</code>.
		 * @param hAlign Horizontal alignment of the target inside the area. AlignMode choices are: <code>LEFT</code>, <code>CENTER</code>, and <code>RIGHT</code>.
		 * @param vAlign Vertical alignment of the target inside the area. AlignMode choices are: <code>TOP</code>, <code>CENTER</code>, and <code>BOTTOM</code>.
		 * @param crop If true, a mask will be created and added to the display list so that the target will be cropped wherever it exceeds the bounds of the AutoFitArea.
		 * @param minWidth Minimum width to which the target is allowed to scale
		 * @param maxWidth Maximum width to which the target is allowed to scale
		 * @param minHeight Minimum height to which the target is allowed to scale
		 * @param maxHeight Maximum height to which the target is allowed to scale
		 * @param calculateVisible If true, only the visible portions of the target will be taken into account when determining its position and scale which can be useful for objects that have masks applied (otherwise, Flash reports their width/height and getBounds() values including the masked portions). Setting <code>calculateVisible</code> to <code>true</code> degrades performance, so only use it when absolutely necessary.
		 * @param customAspectRatio Normally if you set the <code>scaleMode</code> to <code>PROPORTIONAL_INSIDE</code> or <code>PROPORTIONAL_OUTSIDE</code>, its native (unscaled) dimensions will be used to determine the proportions (aspect ratio), but if you prefer to define a custom width-to-height ratio, use <code>customAspectRatio</code>. For example, if an item is 100 pixels wide and 50 pixels tall at its native size, the aspect ratio would be 100/50 or 2. If, however, you want it to be square (a 1-to-1 ratio), the <code>customAspectRatio</code> would be 1. 
		 */
		public function attach(target:DisplayObject, scaleMode:String="proportionalInside", hAlign:String="center", vAlign:String="center", crop:Boolean=false, minWidth:Number=0, maxWidth:Number=999999999, minHeight:Number=0, maxHeight:Number=999999999, calculateVisible:Boolean=false, customAspectRatio:Number=NaN):void {
			if (target.parent != _parent) {
				throw new Error("The parent of the DisplayObject " + target.name + " added to AutoFitArea " + this.name + " doesn't share the same parent.");
			}
			release(target);
			_rootItem = new AutoFitItem(target, scaleMode, hAlign, vAlign, minWidth, maxWidth, minHeight, maxHeight, calculateVisible, customAspectRatio, _rootItem);
			if (crop) {
				var shape:Shape = new Shape();
				var bounds:Rectangle = this.getBounds(this);
				shape.graphics.beginFill(_previewColor, 1);
				shape.graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height);
				shape.graphics.endFill();
				shape.visible = false;
				_parent.addChild(shape);
				_rootItem.mask = shape;
				target.mask = shape;
			}
			if (_preview) {
				this.preview = true;
			}
			update(null);
		}
		
		/**
		 * Releases control of an attached DisplayObject.
		 * 
		 * @param target The DisplayObject to release
		 * @return if the target was found and released, this value will be true. If the target isn't attached, it will be false.
		 */
		public function release(target:DisplayObject):Boolean {
			var item:AutoFitItem = getItem(target);
			if (item == null) {
				return false;
			}
			if (item.mask != null) {
				if (item.mask.parent) {
					item.mask.parent.removeChild(item.mask);
				}
				target.mask = null;
				item.mask = null;
			}
			if (item.next) {
				item.next.prev = item.prev;
			}
			if (item.prev) {
				item.prev.next = item.next;
			} else if (item == _rootItem) {
				_rootItem = item.next;
			}
			item.next = item.prev = null;
			return true;
		}
		
		/**
		 * Returns an Array of all attached DisplayObjects.
		 * 
		 * @return An array of all attached objects
		 */
		public function getAttachedObjects():Array {
			var a:Array = [];
			var cnt:uint = 0;
			var item:AutoFitItem = _rootItem;
			while (item) {
				a[cnt++] = item.target;
				item = item.next;
			}
			return a;
		}
		
		/** @private **/
		protected function getItem(target:DisplayObject):AutoFitItem {
			var item:AutoFitItem = _rootItem;
			while (item) {
				if (item.target == target) {
					return item;
				}
				item = item.next;
			}
			return null;
		}
		
		
		/** 
		 * Forces the area to update, making any necessary adjustments to the scale/position of attached objects. 
		 * @param event An optional event (which is unused internally) - this makes it possible to have an ENTER_FRAME or some other listener call this method if, for example, you want the AutoFitArea to constantly update and make any adjustments to attached objects that may have resized or been manually moved.
		 **/
		public function update(event:Event=null):void {
			//create local variables to speed things up
			var width:Number = this.width;
			var height:Number = this.height;
			var x:Number = this.x;
			var y:Number = this.y;
			var matrix:Matrix = this.transform.matrix;
			
			var item:AutoFitItem = _rootItem;
			var w:Number, h:Number, target:DisplayObject, bounds:Rectangle, tRatio:Number, scaleMode:String, ratio:Number, angle:Number, sin:Number, cos:Number, m:Matrix, mScale:Number, mPrev:Matrix;
			while (item) {
				target = item.target;
				scaleMode = item.scaleMode;
				
				if (scaleMode != ScaleMode.NONE) {
					
					bounds = (item.calculateVisible) ? (item.bounds = getVisibleBounds(target, target)) : target.getBounds(target);
					tRatio = (item.hasCustomRatio) ? item.aspectRatio : bounds.width / bounds.height;
					
					m = target.transform.matrix;
					if (m.b != 0 || m.a == 0 || m.d == 0) {
						//if the width/height is zero, we cannot accurately measure the angle.
						if (m.a == 0 || m.d == 0) {
							m = target.transform.matrix = item.matrix;
						} else {
							//inline operations are about 10 times faster than doing item.matrix = m.clone();
							mPrev = item.matrix;
							mPrev.a = m.a;
							mPrev.b = m.b;
							mPrev.c = m.c;
							mPrev.d = m.d;
							mPrev.tx = m.tx;
							mPrev.ty = m.ty;
						}
						angle = Math.atan2(m.b, m.a);
						if (m.a < 0 && m.d >= 0) {
							if (angle <= 0) {
								angle += Math.PI;
							} else {
								angle -= Math.PI;
							}
						}
						sin = Math.sin(angle);
						if (sin < 0) {
							sin = -sin;
						}
						cos = Math.cos(angle);
						if (cos < 0) {
							cos = -cos;
						}
						tRatio = (tRatio * cos + sin) / (tRatio * sin + cos);
					}
					
					w = (width > item.maxWidth) ? item.maxWidth : (width < item.minWidth) ? item.minWidth : width;
					h = (height > item.maxHeight) ? item.maxHeight : (height < item.minHeight) ? item.minHeight : height;
					ratio = w / h;
					
					if ((tRatio < ratio && scaleMode == ScaleMode.PROPORTIONAL_INSIDE) || (tRatio > ratio && scaleMode == ScaleMode.PROPORTIONAL_OUTSIDE)) {
						w = h * tRatio;
						if (w > item.maxWidth) {
							w = item.maxWidth;
							h = w / tRatio;
						} else if (w < item.minWidth) {
							w = item.minWidth;
							h = w / tRatio;
						}
					}
					if ((tRatio > ratio && scaleMode == ScaleMode.PROPORTIONAL_INSIDE) || (tRatio < ratio && scaleMode == ScaleMode.PROPORTIONAL_OUTSIDE)) {
						h = w / tRatio;
						if (h > item.maxHeight) {
							h = item.maxHeight;
							w = h * tRatio;
						} else if (h < item.minHeight) {
							h = item.minHeight;
							w = h * tRatio;
						}
					}
					if (scaleMode != ScaleMode.HEIGHT_ONLY) {
						if (item.calculateVisible) {
							item.setVisibleWidth(w);
						} else if (m.b != 0) {
							mScale = w / target.width;
							m.a *= mScale;
							m.c *= mScale;
							target.transform.matrix = m;
						} else {
							target.width = w;
						}
					}
					if (scaleMode != ScaleMode.WIDTH_ONLY) {
						if (item.calculateVisible) {
							item.setVisibleHeight(h);
						} else if (m.b != 0) {
							mScale = h / target.height;
							m.d *= mScale;
							m.b *= mScale;
							target.transform.matrix = m;
						} else {
							target.height = h;
						}
					}
					
				} 
				
				bounds = (item.calculateVisible) ? getVisibleBounds(target, _parent) : target.getBounds(_parent);
				
				if (item.hAlign == AlignMode.LEFT) {
					target.x += (x - bounds.x);
				} else if (item.hAlign == AlignMode.CENTER) {
					target.x += (x - bounds.x) + ((width - target.width) * 0.5);
				} else {
					target.x += (x - bounds.x) + (width - target.width);
				}
				
				if (item.vAlign == AlignMode.TOP) {
					target.y += (y - bounds.y);
				} else if (item.vAlign == AlignMode.CENTER) {
					target.y += (y - bounds.y) + ((height - target.height) * 0.5);
				} else {
					target.y += (y - bounds.y) + (height - target.height);
				}
				
				if (item.mask) {
					item.mask.transform.matrix = matrix;
				}
				
				item = item.next;
			}
			
			if (_hasListener) {
				dispatchEvent(new Event(Event.CHANGE));
			}
		}
		
		/** 
		 * Enables the area's tween mode; normally, any changes to the area's transform properties like 
		 * <code>x, y, scaleX, scaleY, width,</code> or <code>height</code> will force an immediate 
		 * <code>update()</code> call but when the area is in tween mode, that automatic <code>update()</code> 
		 * is suspended. This effects perfomance because if, for example, you tween the area's <code>x, y, width</code>, 
		 * and <code>height</code> properties simultaneously, <code>update()</code> would get called 4 times 
		 * each frame (once for each property) even though it only really needs to be called once after all 
		 * properties were updated inside the tween. So to maximize performance during a tween, it is best 
		 * to use the tween's <code>onStart</code> to call <code>enableTweenMode()</code> at the beginning 
		 * of the tween, use the tween's <code>onUpdate</code> to call the area's <code>update()</code> method, 
		 * and then the tween's <code>onComplete</code> to call <code>disableTweenMode()</code> like so:<br /><br /><code>
		 * 
		 * TweenLite.to(myArea, 3, {x:100, y:50, width:300, height:250, onStart:myArea.enableTweenMode, onUpdate:myArea.update, onComplete:myArea.disableTweenMode});</code>
		 **/
		public function enableTweenMode():void {
			_tweenMode = true;
		}
		
		/** 
		 * Disables the area's tween mode; normally, any changes to the area's transform properties like 
		 * <code>x, y, scaleX, scaleY, width,</code> or <code>height</code> will force an immediate 
		 * <code>update()</code> call but when the area is in tween mode, that automatic <code>update()</code> 
		 * is suspended. This effects perfomance because if, for example, you tween the area's <code>x, y, width</code>, 
		 * and <code>height</code> properties simultaneously, <code>update()</code> would get called 4 times 
		 * each frame (once for each property) even though it only really needs to be called once after all 
		 * properties were updated inside the tween. So to maximize performance during a tween, it is best 
		 * to use the tween's <code>onStart</code> to call <code>enableTweenMode()</code> at the beginning 
		 * of the tween, use the tween's <code>onUpdate</code> to call the area's <code>update()</code> method, 
		 * and then the tween's <code>onComplete</code> to call <code>disableTweenMode()</code> like so:<br /><br /><code>
		 * 
		 * TweenLite.to(myArea, 3, {x:100, y:50, width:300, height:250, onStart:myArea.enableTweenMode, onUpdate:myArea.update, onComplete:myArea.disableTweenMode});</code>
		 **/
		public function disableTweenMode():void {
			_tweenMode = false;
		}
		
		/**
		 * Allows you to add an <code>Event.CHANGE</code> event listener.
		 *  
		 * @param type Event type (<code>Event.CHANGE</code>)
		 * @param listener Listener function
		 * @param useCapture useCapture
		 * @param priority Priority level
		 * @param useWeakReference Use weak references
		 */
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void {
			_hasListener = true;
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}
		
		/** Destroys the instance by releasing all DisplayObjects, setting preview to false, and nulling references to the parent, ensuring that garbage collection isn't hindered. **/
		public function destroy():void {
			if (_preview) {
				this.preview = false;
			}
			var nxt:AutoFitItem;
			var item:AutoFitItem = _rootItem;
			while (item) {
				nxt = item.next;
				release(item.target);
				item = nxt;
			}
			_bd.dispose();
			_bd = null;
			_parent = null;
		}
		
		/** @private For objects with masks, the only way to accurately report the bounds of the visible areas is to use BitmapData. **/
		protected static function getVisibleBounds(target:DisplayObject, targetCoordinateSpace:DisplayObject):Rectangle {
			if (_bd == null) {
				_bd = new BitmapData(2800, 2800, true, 0x00FFFFFF);
			}
			_bd.fillRect(_rect, 0x00FFFFFF);
			_matrix.tx = _matrix.ty = 0;
			var offset:Rectangle = target.getBounds(targetCoordinateSpace);
			var m:Matrix = (targetCoordinateSpace == target) ? _matrix : target.transform.matrix;
			m.tx -= offset.x;
			m.ty -= offset.y;
			_bd.draw(target, m, null, "normal", _rect, false);
			var bounds:Rectangle = _bd.getColorBoundsRect(0xFF000000, 0x00000000, false);
			bounds.x += offset.x;
			bounds.y += offset.y;
			return bounds;
		}
		
//---- GETTERS / SETTERS ---------------------------------------------------------------------------
		
		/** @inheritDoc **/
		override public function set x(value:Number):void {
			super.x = value;
			if (!_tweenMode) {
				update();
			}
		}
		
		/** @inheritDoc **/
		override public function set y(value:Number):void {
			super.y = value;
			if (!_tweenMode) {
				update();
			}
		}
		
		/** @inheritDoc **/
		override public function set width(value:Number):void {
			super.width = value;
			if (!_tweenMode) {
				update();
			}
		}
		
		/** @inheritDoc **/
		override public function set height(value:Number):void {
			super.height = value;
			if (!_tweenMode) {
				update();
			}
		}
		
		/** @inheritDoc **/
		override public function set scaleX(value:Number):void {
			super.scaleX = value;
			update();
		}
		
		/** @inheritDoc **/
		override public function set scaleY(value:Number):void {
			super.scaleY = value;
			update();
		}
		
		/** @inheritDoc **/
		override public function set rotation(value:Number):void {
			trace("Warning: AutoFitArea instances should not be rotated.");
		}
		
		/** The preview color with which the area should be filled, making it easy to visualize on the stage. You will not see this color unless you set <code>preview</code> to true or manually add the area to the display list with addChild(). **/
		public function get previewColor():uint {
			return _previewColor;
		}
		public function set previewColor(value:uint):void {
			_previewColor = value;
			var ct:ColorTransform = this.transform.colorTransform;
			ct.color = value;
			this.transform.colorTransform = ct;
		}
		
		/** To see a visual representation of the area on the screen, set <code>preview</code> to <code>true</code>. Doing so will add the area to the display list behind any DisplayObjects that have been attached. **/
		public function get preview():Boolean {
			return _preview;
		}
		public function set preview(value:Boolean):void {
			_preview = value;
			if (this.parent == _parent) {
				_parent.removeChild(this);
			}
			if (value) {
				var level:uint = (_rootItem == null) ? 0 : 999999999;
				var index:uint;
				var item:AutoFitItem = _rootItem;
				while (item) {
					if (item.target.parent == _parent) {
						index = _parent.getChildIndex(item.target);
						if (index < level) {
							level = index;
						}
					}
					item = item.next;
				}
				_parent.addChildAt(this, level);
				this.visible = true;
			}
		}
		
	}
}

import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.Shape;
import flash.geom.Matrix;
import flash.geom.Rectangle;

internal class AutoFitItem {
	public var target:DisplayObject;
	public var scaleMode:String;
	public var hAlign:String;
	public var vAlign:String;
	public var minWidth:Number;
	public var maxWidth:Number;
	public var minHeight:Number;
	public var maxHeight:Number;
	public var aspectRatio:Number;
	public var mask:Shape;
	public var matrix:Matrix;
	public var hasCustomRatio:Boolean;
	
	public var next:AutoFitItem;
	public var prev:AutoFitItem;
	
	public var calculateVisible:Boolean;
	public var bounds:Rectangle;
	
	/** @private **/
	public function AutoFitItem(target:DisplayObject, scaleMode:String, hAlign:String, vAlign:String, minWidth:Number, maxWidth:Number, minHeight:Number, maxHeight:Number, calculateVisible:Boolean, customAspectRatio:Number, next:AutoFitItem) {
		this.target = target;
		this.scaleMode = scaleMode;
		this.hAlign = hAlign;
		this.vAlign = vAlign;
		this.minWidth = minWidth;
		this.maxWidth = maxWidth;
		this.minHeight = minHeight;
		this.maxHeight = maxHeight;
		this.matrix = target.transform.matrix;
		this.calculateVisible = calculateVisible;
		if (!isNaN(customAspectRatio)) {
			this.aspectRatio = customAspectRatio;
			this.hasCustomRatio = true;
		}
		if (next) {
			next.prev = this;
			this.next = next;
		}
	}
	
	/** @private **/
	public function setVisibleWidth(value:Number):void {
		var m:Matrix = this.target.transform.matrix;
		if ((m.a == 0 && m.c == 0) || (m.d == 0 && m.b == 0)) {
			m.a = this.matrix.a;
			m.c = this.matrix.c;
		}
		var curWidth:Number = (m.a < 0) ? -m.a * this.bounds.width : m.a * this.bounds.width;
		curWidth += (m.c < 0) ? -m.c * this.bounds.height : m.c * this.bounds.height;
		if (curWidth != 0) {
			var scale:Number = value / curWidth;
			m.a *= scale;
			m.c *= scale;
			this.target.transform.matrix = m;
			if (value != 0) {
				this.matrix = m;
			}
		}
	}
	
	/** @private **/
	public function setVisibleHeight(value:Number):void {
		var m:Matrix = this.target.transform.matrix;
		if ((m.a == 0 && m.c == 0) || (m.d == 0 && m.b == 0)) {
			m.b = this.matrix.b;
			m.d = this.matrix.d;
		}
		var curHeight:Number = (m.b < 0) ? -m.b * this.bounds.width : m.b * this.bounds.width;
		curHeight += (m.d < 0) ? -m.d * this.bounds.height : m.d * this.bounds.height;
		if (curHeight != 0) {
			var scale:Number = value / curHeight;
			m.b *= scale;
			m.d *= scale;
			this.target.transform.matrix = m;
			if (value != 0) {
				this.matrix = m;
			}
		}
	}
	
}