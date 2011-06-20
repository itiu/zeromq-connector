// TODO переделать на абстрактную модель, отправитель <---> получатель (socket --> uid)

private import std.outbuffer;

interface mq_client
{
	// set callback function for listener ()
	void set_callback(void function(byte* data, int size, mq_client from_client, ref ubyte[]) _message_acceptor);

	void get_count(out int cnt);

	version(D2)
	{
		// in thread listens to the queue and calls _message_acceptor
		void listener();
	}
	version(D1)
	{
		// in thread listens to the queue and calls _message_acceptor
		int listener();
	}

	// sends a message to the specified socket
	void* connect_as_req (string connect_to);
	int send(void* soc, char* messagebody, int message_size, bool send_more);
	char* reciev(void* soc);
}