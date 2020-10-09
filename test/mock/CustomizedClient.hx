package mock;

import haxe.ds.StringMap;
import hxmemcache.Client;

class CustomizedClient extends Client
{
	override function extractValue(expectCas:Bool, line:String, remappedKeys:StringMap<String>, prefixedKeys:Array<String>):{key:String, value:Dynamic}
	{
		super.extractValue(expectCas, line, remappedKeys, prefixedKeys);
		return {
			key: 'key',
			value: 'value'
		};
	}
}