package hxmemcache;

/**
 * Base exception class
 */
class MemcacheError extends haxe.Exception
{

}

/**
 * Raised when memcached fails to parse the arguments to a request,
 * likely due to a malformed key and/or value,
 * a bug in this library,
 * or a version mismatch with memcached.
 */
class MemcacheClientError extends MemcacheError
{

}

/**
 * Raised when memcached fails to parse a request,
 * likely due to a bug in this library
 * or a version mismatch with memcached.
 */
class MemcacheUnknownCommandError extends MemcacheClientError
{

}

/**
 * Raised when a key or value is not legal for Memcache
 * (see the class docs for Client for more details).
 */
class MemcacheIllegalInputError extends MemcacheClientError
{

}

/**
 * Raised when memcached reports a failure while processing a request,
 * likely due to a bug or transient issue in memcached.
 */
class MemcacheServerError extends MemcacheError
{

}

/**
 * Raised when this library receives a response from memcached that it cannot parse,
 * likely due to a bug in this library
 * or a version mismatch with memcached.
 */
class MemcacheUnknownError extends MemcacheError
{

}

/**
 * Raised when the connection with memcached closes unexpectedly.
 */
class MemcacheUnexpectedCloseError extends MemcacheServerError
{

}