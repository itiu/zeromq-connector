module Log;

private import std.format;
private import std.c.stdio;
private import std.date;

import std.array: appender;

private import std.stdio;
private import std.datetime;
import std.c.linux.linux;

byte trace_msg[1100];

public class Logger
{
	private int count = 0;
	private int prev_time = 0; 
	private string trace_logfilename = "app";
	private string ext = "log";
	
	private FILE* ff = null;
	private string src = "";

	this(string log_name, string _ext, string _src)
	{		
		trace_logfilename = log_name;
		src = _src;
		ext = _ext;
		open_new_file ();
	}

	~this()
	{
		fclose(ff);
	}

	private void open_new_file ()
	{
		count = 0;
		int tt = time(null);
		tm* ptm = localtime(&tt);
		int year = ptm.tm_year + 1900;
		int month = ptm.tm_mon + 1;
		int day = ptm.tm_mday;
		int hour = ptm.tm_hour;
		int minute = ptm.tm_min;
		int second = ptm.tm_sec;

		auto writer = appender!string();

		formattedWrite(writer, "%s_%04d-%02d-%02d_%02d:%02d:%02d.%s", trace_logfilename, year, month, day, hour, minute, second, ext);

		writer.put(cast(char) 0);
		
		if (ff !is null)
		{
			fflush(ff);
			fclose(ff);
		}
		
		ff = fopen(writer.data.ptr, "aw");
	}
	
	void trace_io(bool io, byte* data, int len)
	{		
		string str_io;

		if(io == true)
			str_io = "INPUT";
		else
			str_io = "OUTPUT";
			
		int tt = time(null);
		tm* ptm = localtime(&tt);
		int year = ptm.tm_year + 1900;
		int month = ptm.tm_mon + 1;
		int day = ptm.tm_mday;
		int hour = ptm.tm_hour;
		int minute = ptm.tm_min;
		int second = ptm.tm_sec;
		d_time now = getUTCtime();
		int milliseconds = msFromTime(now);

		count ++;

		if (prev_time > 0 && day != prev_time || count > 1_000_000)
		{
			open_new_file ();
		}
		
		auto writer = appender!string();

		formattedWrite(writer, "[%04d-%02d-%02d %02d:%02d:%02d.%03d]\n%s\n", year, month, day, hour, minute, second, milliseconds, str_io);

		fwrite (cast(char*)writer.data , 1 , writer.data.length , ff);
		
		fwrite (data , 1 , len - 1, ff);

		fputc('\r', ff);
		
		fflush(ff);
		
		prev_time = day;		
	}

	string trace(Char, A...)(in Char[] fmt, A args)
	{
		int tt = time(null);
		tm* ptm = localtime(&tt);
		int year = ptm.tm_year + 1900;
		int month = ptm.tm_mon + 1;
		int day = ptm.tm_mday;
		int hour = ptm.tm_hour;
		int minute = ptm.tm_min;
		int second = ptm.tm_sec;
		d_time now = getUTCtime();
		int milliseconds = msFromTime(now);

		count++;
		if (prev_time > 0 && day != prev_time || count > 1_000_000)
		{
			open_new_file ();
		}
		
		//	       StopWatch sw1; sw1.start();
		auto writer = appender!string();

		if (src.length > 0)
		formattedWrite(writer, "[%04d-%02d-%02d %02d:%02d:%02d.%03d] [%s] ", year, month, day, hour, minute, second, milliseconds, src);
		else
			formattedWrite(writer, "[%04d-%02d-%02d %02d:%02d:%02d.%03d] ", year, month, day, hour, minute, second, milliseconds);

		formattedWrite(writer, fmt, args);
		writer.put(cast(char) 0);

		fputs(cast(char*) writer.data, ff);
		fputc('\n', ff);

		//    		sw1.stop();
		//               writeln (cast(long) sw1.peek().microseconds);

		fflush(ff);

		prev_time = day;		

		return writer.data;
	}

	void trace_log_and_console(Char, A...)(in Char[] fmt, A args)
	{
		write(trace(fmt, args), "\n");
	}
}
