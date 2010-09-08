interface mom_client
{
	// set callback function for listener ()
	void set_callback(void function(byte* txt, ulong size, mom_client from_client) _message_acceptor);

	// in thread listens to the queue and calls _message_acceptor
	void listener();
	
	// sends a message to the specified queue
	int send(char* routingkey, char* messagebody);

	// forward to receiving the message
	char* get_message ();
}