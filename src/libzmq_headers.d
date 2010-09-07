/*
    Copyright (c) 2007-2010 iMatix Corporation

    This file is part of 0MQ.

    0MQ is free software; you can redistribute it and/or modify it under
    the terms of the Lesser GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    0MQ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    Lesser GNU General Public License for more details.

    You should have received a copy of the Lesser GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


/******************************************************************************/
/*  0MQ versioning support.                                                    */
/******************************************************************************/

extern (C) void zmq_version (int *major, int *minor, int *patch);

/******************************************************************************/
//  0MQ errors.
/******************************************************************************/

/*  A number random anough not to collide with different errno ranges on      */
/*  different OSes. The assumption is that error_t is at least 32-bit type.   */
enum error_code
{
/*  A number random anough not to collide with different errno ranges on      */
/*  different OSes. The assumption is that error_t is at least 32-bit type.   */
ZMQ_HAUSNUMERO=156384712,

/*  On Windows platform some of the standard POSIX errnos are not defined.    */
ENOTSUP=(ZMQ_HAUSNUMERO + 1),
EPROTONOSUPPORT=(ZMQ_HAUSNUMERO + 2),
ENOBUFS=(ZMQ_HAUSNUMERO + 3),
ENETDOWN=(ZMQ_HAUSNUMERO + 4),
EADDRINUSE=(ZMQ_HAUSNUMERO + 5),
EADDRNOTAVAIL=(ZMQ_HAUSNUMERO + 6),
ECONNREFUSED=(ZMQ_HAUSNUMERO + 7),
EINPROGRESS=(ZMQ_HAUSNUMERO + 8),

/*  Native 0MQ error codes.                                                   */
EFSM=(ZMQ_HAUSNUMERO + 51),
ENOCOMPATPROTO=(ZMQ_HAUSNUMERO + 52),
ETERM=(ZMQ_HAUSNUMERO + 53)
}

/*  This function retrieves the errno as it is known to 0MQ library. The goal */
/*  of this function is to make the code 100% portable, including where 0MQ   */
/*  compiled with certain CRT library (on Windows) is linked to an            */
/*  application that uses different CRT library.                              */
extern (C) int zmq_errno ();

/*  Resolves system errors and 0MQ errors to human-readable string.           */
extern (C) char *zmq_strerror (int errnum);

/******************************************************************************/
/*  0MQ message definition.                                                   */
/******************************************************************************/

enum msg_def
{
/*  Maximal size of "Very Small Message". VSMs are passed by value            */
/*  to avoid excessive memory allocation/deallocation.                        */
/*  If VMSs larger than 255 bytes are required, type of 'vsm_size'            */
/*  field in zmq_msg_t structure should be modified accordingly.              */
ZMQ_MAX_VSM_SIZE= 30,

/*  Message types. These integers may be stored in 'content' member of the    */
/*  message instead of regular pointer to the data.                           */
ZMQ_DELIMITER= 31,
ZMQ_VSM= 32,

/*  Message flags. ZMQ_MSG_SHARED is strictly speaking not a message flag     */
/*  (it has no equivalent in the wire format), however, making  it a flag     */
/*  allows us to pack the stucture tigher and thus improve performance.       */
ZMQ_MSG_MORE= 1,
ZMQ_MSG_SHARED= 128
}

/*  A message. Note that 'content' is not a pointer to the raw data.          */
/*  Rather it is pointer to zmq::msg_content_t structure                      */
/*  (see src/msg_content.hpp for its definition).                             */
extern (C) struct zmq_msg_t
{
    void *content;
    ubyte flags;
    ubyte vsm_size;
    ubyte vsm_data [msg_def.ZMQ_MAX_VSM_SIZE];
};

typedef void (zmq_free_fn) (void *data, void *hint);

extern (C) int zmq_msg_init (zmq_msg_t *msg);
extern (C) int zmq_msg_init_size (zmq_msg_t *msg, size_t size);
extern (C) int zmq_msg_init_data (zmq_msg_t *msg, void *data, size_t size, zmq_free_fn *ffn, void *hint);
extern (C) int zmq_msg_close (zmq_msg_t *msg);
extern (C) int zmq_msg_move (zmq_msg_t *dest, zmq_msg_t *src);
extern (C) int zmq_msg_copy (zmq_msg_t *dest, zmq_msg_t *src);
extern (C) void *zmq_msg_data (zmq_msg_t *msg);
extern (C) size_t zmq_msg_size (zmq_msg_t *msg);

/******************************************************************************/
/*  0MQ infrastructure (a.k.a. context) initialisation & termination.         */
/******************************************************************************/

extern (C) void *zmq_init (int io_threads);
extern (C) int zmq_term (void *context);

/******************************************************************************/
/*  0MQ socket definition.                                                    */
/******************************************************************************/

/*  Socket types. */ 

enum soc_type
{
ZMQ_PAIR= 0,
ZMQ_PUB= 1,
ZMQ_SUB= 2,
ZMQ_REQ= 3,
ZMQ_REP= 4,
ZMQ_XREQ= 5,
ZMQ_XREP= 6,
ZMQ_UPSTREAM= 7,
ZMQ_DOWNSTREAM= 8
}

/*  Socket options.                                                           */
enum soc_opt
{
ZMQ_HWM= 1,
ZMQ_SWAP= 3,
ZMQ_AFFINITY= 4,
ZMQ_IDENTITY= 5,
ZMQ_SUBSCRIBE= 6,
ZMQ_UNSUBSCRIBE= 7,
ZMQ_RATE= 8,
ZMQ_RECOVERY_IVL= 9,
ZMQ_MCAST_LOOP= 10,
ZMQ_SNDBUF= 11,
ZMQ_RCVBUF= 12,
ZMQ_RCVMORE= 13,
ZMQ_FD= 14,
ZMQ_EVENTS= 15
}

/*  Send/recv options.                                                        */
enum send_recv_opt
{
ZMQ_NOBLOCK= 1,
ZMQ_SNDMORE= 2
}

extern (C) void *zmq_socket (void *context, int type);
extern (C) int zmq_close (void *s);
extern (C) int zmq_setsockopt (void *s, int option, void *optval, size_t optvallen); 
extern (C) int zmq_getsockopt (void *s, int option, void *optval, size_t *optvallen);
extern (C) int zmq_bind (void *s, char *addr);
extern (C) int zmq_connect (void *s, char *addr);
extern (C) int zmq_send (void *s, zmq_msg_t *msg, int flags);
extern (C) int zmq_recv (void *s, zmq_msg_t *msg, int flags);

