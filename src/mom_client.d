interface mom_client
{
	// set callback function for listener ()
	void set_callback(void function(byte* txt, int size, mom_client from_client) _message_acceptor);
	
        void get_count (out int cnt);
                                         
	// in thread listens to the queue and calls _message_acceptor
	
	version (D2)
	{
	void listener();
	}
	
	version (D1)
	{
	int listener();	
	}
	
	// sends a message to the specified queue
	int send(char* routingkey, char* messagebody, bool send_more);

	// forward to receiving the message
	char* get_message ();
}