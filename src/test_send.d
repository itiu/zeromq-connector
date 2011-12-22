module test_send;

private import Log;
private import std.c.string;
private import std.c.stdlib;
private import core.thread;
private import core.stdc.stdio;

private import libzmq_headers;
private import mq_client;
private import zmq_point_to_poin_client;

void main(char[][] args)
{
	mq_client client = null;

	string bind_to = "tcp://127.0.0.1:5556";
	client = new zmq_point_to_poin_client(bind_to);

//	client.send("**", "$", false);
}
