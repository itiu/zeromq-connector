private import std.outbuffer;

interface mq_client
{
	// set callback function for listener ()

	void set_callback(void function(byte* data, int size, mq_client from_client, ref ubyte[]) _message_acceptor);

	void get_count(out int cnt);

	// in thread listens to the queue and calls _message_acceptor

	version(D2)
	{
		void listener();
	}

	version(D1)
	{
		int listener();
	}

	// sends a message to the specified queue
//	int send(char* queue_name, char* messagebody, int size, bool send_more);
}