module Log;

version (D1)
{
private import std.stdio;
}

version (D2)
{
private import core.stdc.stdio;
}

import std.stdarg;

package
{
	Log log;
}

private
{
	public class Log
	{

		static string trace_logfilename = "zero-mq.log";
		static FILE* fplog;

		static this()
		{
			fplog = fopen(trace_logfilename.ptr, "w");

			log = new Log();
		}

		static ~this()
		{
			fclose(fplog);
			delete log;
		}

		void trace(string format, ...)
		{
			va_list ap;
			ap = cast(va_list) &format;
			ap += format.sizeof;
			vfprintf(fplog, ("[time]" ~ format).ptr, ap);
			fflush(fplog);
		}
	//"datetime" ~ tl).ptr,
	}

}
