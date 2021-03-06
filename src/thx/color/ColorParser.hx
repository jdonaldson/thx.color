/**
 * ...
 * @author Franco Ponticelli
 */

package thx.color;

import thx.core.Floats;
import thx.core.Ints;

class ColorParser
{
	static var parser(default, null) = new ColorParser();
	public static function parseColor(s : String) : ColorInfo
	{
		return parser.processColor(s);
	}
	
	public static function parseChannel(s : String) : ChannelInfo
	{
		return parser.processChannel(s);
	}
	
	var pattern_color : EReg;
	var pattern_channel : EReg;
	public function new()
	{
		pattern_color   = ~/^\s*([^(]+)\s*\(([^)]*)\)\s*$/i;
		pattern_channel = ~/^\s*(\d*.\d+|\d+)(%|deg|º)?\s*$/i;
	}
	
	public function processHex(s : String) : ColorInfo
	{
		if (s.substr(0, 1) == "#")
			s = "0x" + s.substr(1);
		else if (s != "0x")
			return null;
		if (s.length == 5)
		{
			s = "0x" + s.charAt(2) + s.charAt(2) + s.charAt(3) + s.charAt(3) + s.charAt(4) + s.charAt(4);
		} else if(s.length == 6) {
			s = "0x" + s.charAt(2) + s.charAt(2) + s.charAt(3) + s.charAt(3) + s.charAt(4) + s.charAt(4) + s.charAt(5) + s.charAt(5);
		} else if (s.length != 8 && s.length != 10)
			return null;
		var i = Ints.parse(s),
			has_alpha = s.length == 10;
		if (has_alpha)
			return new ColorInfo("rgb", true, [CIInt8((i >> 24) & 0xFF), CIInt8((i >> 16) & 0xFF), CIInt8((i >> 8) & 0xFF), CIFloat((i & 0xFF)/255)]);
		else
			return new ColorInfo("rgb", false, [CIInt8((i >> 16) & 0xFF), CIInt8((i >> 8) & 0xFF), CIInt8(i & 0xFF)]);
	}
	
	public function processColor(s : String) : ColorInfo
	{
		var hex = processHex(s);
		if (null != hex)
			return hex;
		if (!pattern_color.match(s))
			return null;
		
		var name = pattern_color.matched(1);
		if (null == name) return null;
		
		name = name.toLowerCase();
		var has_alpha = name.length > 1 && name.substr(-1) == "a";
		if (has_alpha) name = name.substr(0, name.length - 1);
		
		var m2 = pattern_color.matched(2),
			s_channels = null == m2 ? [] : m2.split(","),
			channels = [],
			channel;
		for (s_channel in s_channels)
		{
			channel = processChannel(s_channel);
			if (null == channel) return null;
			channels.push(channel);
		}
		return new ColorInfo(name, has_alpha, channels);
	}
	
	public function processChannel(s : String) : ChannelInfo
	{
		if (!pattern_channel.match(s)) return null;
		var value = pattern_channel.matched(1),
			unit  = pattern_channel.matched(2);
		if (unit == null) unit = "";
		return switch(unit)
		{
			case "%" if (Floats.canParse(value)) :
				CIPercent(Floats.parse(value));
			case ("deg" | "DEG" | "º") if (Floats.canParse(value)) :
				CIDegree(Floats.parse(value));
			case "" if (Ints.canParse(value)) :
				var i = Ints.parse(value);
				if (i == 0 || i == 1) CI0or1(i) else if (i < 256) CIInt8(i) else CIInt(i);
			case "" if (Floats.canParse(value)) :
				CIFloat(Floats.parse(value));
			default: null;
		}
	}

	public static function getFloatChannel(channel : ChannelInfo)
	{
		return switch(channel) {
			case CI0or1(v) :
				v;
			case CIFloat(v) :
				v;
			case CIPercent(v) :
				v / 100;
			default :
				null;
		};
	}

	public static function getInt8Channel(channel : ChannelInfo)
	{
		return switch(channel) {
			case CI0or1(v) | CIInt8(v) :
				v;
			default :
				null;
		};
	}
}

class ColorInfo
{
	public var name(default, null) : String;
	public var hasAlpha(default, null) : Bool;
	public var channels(default, null) : Array<ChannelInfo>;
	
	public function new(name : String, has_alpha : Bool, channels : Array<ChannelInfo>)
	{
		this.name = name;
		this.hasAlpha = has_alpha;
		this.channels = channels;
	}
	
	public function toString()
		return '$name, has alpha: $hasAlpha, channels: $channels';
}

enum ChannelInfo
{
	CIPercent(value : Float);
	CIFloat(value : Float);
	CIDegree(value : Float);
	CIInt8(value : Int);
	CIInt(value : Int);
	CI0or1(value : Int);
}

class ColorAssembler<T : Color>
{
	public function toSolid(info : ColorInfo) : Null<T>
	{
		return throw "abstract method";
	}
	
	public function toColor(info : ColorInfo) : Null<Color>
	{
		var color = toSolid(info);
		if (null == color)
			return null;
		if (!info.hasAlpha)
			return color;
		if (null == info.channels[info.channels.length-1])
			return null;
		var alpha = ColorParser.getFloatChannel(info.channels[info.channels.length-1]);
		if (null == alpha)
			return null;
		return withAlpha(color, alpha);
	}
	
	@:access(thx.color.ColorAlpha)
	inline public function withAlpha(color : Color, alpha : Float)
	{
		return new ColorAlpha(color, alpha);
	}
}