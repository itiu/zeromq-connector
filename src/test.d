module test;

private import tango.io.Stdout;
private import mom_client;
private import Log;
private import tango.core.Thread;
private import tango.stdc.stringz;
private import tango.stdc.string;
private import tango.stdc.stdlib;

private import libzmq_headers;
private import libzmq_client;

void main(char[][] args)
{
	Stdout.format("main#1").newline;

	mom_client client = null;
	Stdout.format("main#2").newline;

	char* bind_to = "tcp://127.0.0.1:5555\0".ptr;
	client = new libzmq_client(bind_to);

	client.set_callback(&get_message);
	Stdout.format("main#4").newline;

	Thread thread = new Thread(&client.listener);
	thread.start;
	log.trace("start new Thread {:X4}", &thread);
	Thread.sleep(0.250);


}

int count = 0;

void get_message(byte* message, ulong message_size, mom_client from_client)
{
	count++;
	Stdout.format("[{}] data: {}", count, fromStringz(cast(char*) message)).newline;
	
	from_client.send ("", "test message");
	return;
}
