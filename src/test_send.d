module test_send;

private import mom_client;
private import Log;
private import std.c.string;
private import std.c.stdlib;
private import std.thread;

private import libzmq_headers;
private import libzmq_client;

void main(char[][] args)
{
	mom_client client = null;

	char* bind_to = "tcp://127.0.0.1:5556".ptr;
	client = new libzmq_client(bind_to);

	client.send("**", "$", false);
}
