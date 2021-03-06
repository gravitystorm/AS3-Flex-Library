package org.babelfx.utils.debug
{
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import mx.logging.ILogger;
	import mx.logging.ILoggingTarget;
	import mx.logging.LogEvent;
	import mx.logging.LogEventLevel;
	
	public class LocaleLogger extends EventDispatcher implements ILogger
	{
		public static var defaultFilters : Array = [ 	"org.babelfx.maps.*",
														"org.babelfx.commands.*",
														"org.babelfx.injectors.*"
												];
		/**
		 * 
		 * @param target
		 * @param fullPath
		 * @return 
		 * 
		 */
		public static function getLogger( target:Object, fullPath:Boolean = true):ILogger
		{
			loggers ||= new Dictionary();
			
			// Target is a class or instance; we want the fully-qualified Classname
			var className:String  = getQualifiedClassName( target );
			var logger:LocaleLogger = loggers[ className ];
			
			// if the logger doesn't already exist, create and store it
			if( logger == null )
			{
				logger = new LocaleLogger( getCategoryFor(target,fullPath), new ConstructorLock);
				loggers[ className ] = logger;
			}
			
			// check for existing targets interested in this logger
			for each( var logTarget:ILoggingTarget in loggingTargets ) {
				
				if( categoryMatchInFilterList( logger.category, logTarget.filters ) )
					logTarget.addLogger( logger );
			}
			
			return logger;
		}
		
		/**
		 * 
		 * @param target
		 * @param fullPath
		 * @return 
		 * 
		 */
		public static function getCategoryFor(target:Object, fullPath:Boolean=true):String {
			// Target is a class or instance; we want the fully-qualified Classname
			var className:String  = getQualifiedClassName( target );
			var category : String = fullPath 					 ?  className 									: 
									className.indexOf("::") >= 0 ?	className.substr(className.indexOf("::")+2)	:
									className;
			
			return category;
		}
		
		public static function addToFilters(target:Object):void {
			var clazzName   : String  = (target is String) ? (target as String) : getQualifiedClassName(target);
			var path    	: String  = clazzName.indexOf(":") >= 0 ? clazzName.substr(0,clazzName.indexOf(":")) + ".*" : "";

			defaultFilters = smartAddFilter(path,defaultFilters);
		}
		
		
		public static function get sharedTarget():ILoggingTarget {
			loggingTargets ||= [];
			return loggingTargets.length ? loggingTargets[0] as ILoggingTarget : null;
		}

		/**
		 * 
		 * @param it
		 * 
		 */
		public static function addLoggingTarget( it:ILoggingTarget ):void {
			loggingTargets ||= [];
			
			if (it == null) return;
			
			if( loggingTargets.indexOf( it ) < 0 ) {
				initializeTarget(it);
				loggingTargets.push( it );
			}
			
			if( loggers != null ) {
				
				for each( var logger:ILogger in loggers ) {
					if( categoryMatchInFilterList( logger.category, it.filters ) )
						it.addLogger( logger );
				}
			}
		}
		
		
		/**
		 * 
		 * @param it
		 * 
		 */
		public static function removeLoggingTarget(it:ILoggingTarget):void {
			if (it == null) return;
			
			if( loggingTargets.indexOf( it ) >= 0 ) {
				
				for each( var logger:ILogger in loggers ) {
					if( categoryMatchInFilterList( logger.category, it.filters ) ) {
						it.removeLogger( logger );
					}
				}
			}
		}
		
		/**
		 *  This method checks that the specified category matches any of the filter
		 *  expressions provided in the <code>filters</code> Array.
		 *
		 *  @param category The category to match against
		 *  @param filters A list of Strings to check category against.
		 *  @return <code>true</code> if the specified category matches any of the
		 *            filter expressions found in the filters list, <code>false</code>
		 *            otherwise.
		 */
		public static function categoryMatchInFilterList( category:String, filters:Array ):Boolean
		{
			var result:Boolean = false;
			var filter:String;
			var index:int = -1;
			for( var i:uint = 0; i < filters.length; i++ )
			{
				filter = filters[ i ];
				// first check to see if we need to do a partial match
				// do we have an asterisk?
				index = filter.indexOf( "*" );
				
				if( index == 0 )
					return true;
				
				index = index < 0 ? index = category.length : index - 1;
				
				if( category.substring( 0, index ) == filter.substring( 0, index ) )
					return true;
			}
			return false;
		}
		
		/**
		 * If the LoggingTarget appears to be un-initialized, then
		 * configure to DEBUG all pertinent l10nInjection packages
		 *  
		 * @param val ILoggingTarget instance
		 * 
		 */
		private static function initializeTarget(val:ILoggingTarget):void {
			if (val != null) {
				var concat : Boolean = !((val.filters.length == 1) && (val.filters[0] == "*")); 
				
				val.filters = concat ? val.filters.concat(defaultFilters) : defaultFilters;
				val.level   = (val.level == LogEventLevel.ALL) ? LogEventLevel.DEBUG : val.level;
			}
		}
		
		// ========================================
		// static stuff above
		// ========================================
		// ========================================
		// instance stuff below
		// ========================================
		
		protected var _category:String;
		
		public function LocaleLogger( className:String , locker:ConstructorLock)
		{
			super();
			
			_category = className;
		}
		
		/**
		 *  The category this logger send messages for.
		 */
		public function get category():String
		{
			return _category;
		}
		
		protected function constructMessage( msg:String, params:Array ):String
		{
			// replace all of the parameters in the msg string
			for( var i:int = 0; i < params.length; i++ )
			{
				msg = msg.replace( new RegExp( "\\{" + i + "\\}", "g" ), params[ i ] );
			}
			return msg;
		}
		
		// ========================================
		// public methods
		// ========================================
		
		/**
		 *  @inheritDoc
		 */
		public function log( level:int, msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), level ) );
			}
		}
		
		/**
		 *  @inheritDoc
		 */
		public function debug( msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), LogEventLevel.DEBUG ) );
			}
		}
		
		/**
		 *  @inheritDoc
		 */
		public function info( msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), LogEventLevel.INFO ) );
			}
		}
		
		/**
		 *  @inheritDoc
		 */
		public function warn( msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), LogEventLevel.WARN ) );
			}
		}
		
		/**
		 *  @inheritDoc
		 */
		public function error( msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), LogEventLevel.ERROR ) );
			}
		}
		
		/**
		 *  @inheritDoc
		 */
		public function fatal( msg:String, ... rest ):void
		{
			if( hasEventListener( LogEvent.LOG ) )
			{
				dispatchEvent( new LogEvent( constructMessage( msg, rest ), LogEventLevel.FATAL ) );
			}
		}

		protected static var loggers		:Dictionary = new Dictionary();
		protected static var loggingTargets	:Array		= [];
		
		private static function smartAddFilter(src:String,filters:Array):Array {
			var results : Array   = [];
			var len     : int 	  = src.indexOf( "*" ) - 1;
			var found   : Boolean = false;
			
			for each (var it:String in filters) {
				// Remove default wildcard "match all" filter 
				if (it == "*") 			continue;
				
				if (src.substring(0, len) != it.substring(0, len)) {
					// existing filter item to keep
					results.push(it);	
				}
			}
			
			// Add newest filter category filter was not in list... so add it!
			results.push(src);
			
			return results;
		}
	}
}

class ConstructorLock {
}

