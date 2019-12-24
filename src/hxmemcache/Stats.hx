package hxmemcache;

import haxe.ds.StringMap;
using StringTools;


class Stats
{
    public static var STAT_TYPES : StringMap<String->Dynamic> = [
        //  General stats
        'version' => Std.string,
        'rusage_user' => parse_float,
        'rusage_system' => parse_float,
        'hash_is_expanding' => parse_bool_int,
        'slab_reassign_running' => parse_bool_int,

        //  Settings stats
        'inter' => Std.string,
        'growth_factor' => Std.parseFloat,
        'stat_key_prefix' => Std.string,
        'umask' => parse_hex,
        'detail_enabled' => parse_bool_int,
        'cas_enabled' => parse_bool_int,
        'auth_enabled_sasl' => parse_bool_string_is_yes,
        'maxconns_fast' => parse_bool_int,
        'slab_reassign' => parse_bool_int,
        'slab_automove' => parse_bool_int,
    ];

    // Some of the values returned by the "stats" command need mapping into native types

    static function parse_bool_int( value : String ) return Std.parseInt(value) != 0;
    static function parse_bool_string_is_yes( value : String ) return value == 'yes';
    static function parse_float( value : String ) return Std.parseFloat(value.replace(':', '.'));
    static function parse_hex( value : String ) return Std.parseInt(value); //, 8)
}